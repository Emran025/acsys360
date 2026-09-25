#include "protocol_internal.h"
#include "tac.h"
#include "asm_x86_64.h"
#include "artifact_builder.h"
#include "toolchain.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct yy_buffer_state *YY_BUFFER_STATE;
extern YY_BUFFER_STATE yy_scan_string(const char *str);
extern void yy_delete_buffer(YY_BUFFER_STATE buffer);
extern int yyparse(void);
extern CAstNode *g_root_ast;
extern ProtocolResponse *g_protocol_response;
extern int current_line;
extern int current_column;
extern int current_offset;
extern char g_source_path_storage[1024];
extern const char *g_current_source_path;

int compiler_driver_run(const char *payload) {
  if (payload == NULL || payload[0] == '\0') {
    fputs("{\"protocolVersion\":\"" ARABICC_PROTOCOL_VERSION "\",\"success\":false,\"diagnostics\":[{\"severity\":\"error\",\"phase\":\"driver\",\"code\":\"P001\",\"message\":\"حزمة الطلب فارغة\",\"span\":null}],\"tokens\":[],\"syntaxTree\":null,\"symbolTable\":[],\"threeAddressCode\":[],\"assembly\":\"\",\"executionOutput\":[],\"artifacts\":[],\"intermediateRepresentation\":{}}\n", stdout);
    return 1;
  }

  /* Handle assist request */
  if (strstr(payload, "\"requestType\"") != NULL && strstr(payload, "\"assist\"") != NULL) {
    return protocol_handle_assist(payload);
  }

  /* Compilation response */
  ProtocolResponse resp;
  protocol_response_init(&resp);
  resp.success = 1;

  /* Check for entryPath */
  char *entry_path = protocol_extract_string_value(payload, "\"entryPath\"");
  if (entry_path && entry_path[0] != '\0') {
    strncpy(g_source_path_storage, entry_path, sizeof(g_source_path_storage) - 1);
    g_current_source_path = g_source_path_storage;
    free(entry_path);
  }
  char *root_path = protocol_extract_string_value(payload, "\"rootPath\"");

  char *source = protocol_extract_source_code(payload);
  if (source && source[0] != '\0') {
    g_protocol_response = &resp;
    current_line = 1;
    current_column = 1;
    current_offset = 0;
    g_root_ast = NULL;

    YY_BUFFER_STATE buffer = yy_scan_string(source);
    int parse_res = yyparse();
    yy_delete_buffer(buffer);
    const int parse_failed = parse_res != 0 || g_root_ast == NULL;

    if (parse_res == 0 && g_root_ast != NULL) {
      /* 1. Syntax Tree */
      char *st_json = protocol_ast_to_json(g_root_ast);
      if (st_json) {
        protocol_set_syntax_tree_json(&resp, st_json);
        free(st_json);
      }

      /* 2. Semantic analysis */
      CSemanticResult semantic;
      memset(&semantic, 0, sizeof(semantic));
      if (c_analyze_semantics(g_root_ast, &semantic)) {
        for (size_t i = 0; i < semantic.count; i++) {
          ProtocolSpan span = {
            g_current_source_path[0] != '\0' ? g_current_source_path : NULL,
            semantic.items[i].offset,
            semantic.items[i].line,
            semantic.items[i].column,
            0
          };
          protocol_add_symbol(&resp, semantic.items[i].name, "variable", semantic.items[i].type, span);
        }

        /* 3. Assembly */
        CAssemblyResult assembly;
        memset(&assembly, 0, sizeof(assembly));
        char *backend_target = protocol_extract_string_value(payload, "\"target\"");
        const int requires_native_backend =
            backend_target && strcmp(backend_target, "dart-native") == 0;
        const int assembly_ok =
            c_generate_nasm_x86_64(g_root_ast, &semantic, &assembly);
        if (assembly_ok && assembly.text && assembly.diagnostic_count == 0) {
          protocol_set_assembly(&resp, assembly.text);
        }
        if (requires_native_backend &&
            (!assembly_ok || assembly.diagnostic_count > 0)) {
          resp.success = 0;
          for (size_t i = 0; i < assembly.diagnostic_count; i++) {
            ProtocolSpan span = {
              g_current_source_path[0] != '\0' ? g_current_source_path : NULL,
              assembly.diagnostic_offsets[i],
              assembly.diagnostic_lines[i],
              assembly.diagnostic_columns[i],
              assembly.diagnostic_lengths[i]
            };
            protocol_add_diagnostic(&resp, SEVERITY_ERROR, "backend", "A001",
                                    assembly.diagnostics[i], &span);
          }
          if (assembly.diagnostic_count == 0) {
            protocol_add_diagnostic(&resp, SEVERITY_ERROR, "backend", "A001",
                                    "فشل توليد Assembly للبرنامج", NULL);
          }
        }
        free(backend_target);
        c_assembly_result_free(&assembly);
      }

      for (size_t i = 0; i < semantic.diagnostic_count; i++) {
        ProtocolSpan span = {
          g_current_source_path[0] != '\0' ? g_current_source_path : NULL,
          semantic.diagnostics[i].offset,
          semantic.diagnostics[i].line,
          semantic.diagnostics[i].column,
          semantic.diagnostics[i].length
        };
        protocol_add_diagnostic(&resp, SEVERITY_ERROR, "semantic", "SEM001",
                                semantic.diagnostics[i].message, &span);
      }

      /* 4. Typed IR */
      char *ir_json = protocol_generate_typed_ir(g_root_ast, &semantic);
      if (ir_json) {
        protocol_set_ir_json(&resp, ir_json);
        free(ir_json);
      }
      c_semantic_result_free(&semantic);

      /* 5. Three Address Code (3AC) */
      CTacResult tac = {0};
      if (c_generate_tac(g_root_ast, &tac)) {
        for (size_t i = 0U; i < tac.count; i++) {
          char *text = c_tac_instruction_to_text(&tac.items[i]);
          if (text) {
            protocol_add_tac(&resp, text);
            free(text);
          }
        }
      }
      c_tac_result_free(&tac);

      /* 6. Execution output. Analysis requests must not run read() with a
         missing value: that used to make an unprovided input look like 0. */
      if (protocol_request_executes(payload)) {
        runtime_begin(strstr(payload, "\"inputValues\""), protocol_request_interactive(payload));
        runtime_execute_ast(&resp, g_root_ast);
        if (runtime_had_error()) {
          resp.success = 0;
          protocol_add_diagnostic(
              &resp, SEVERITY_ERROR, "runtime", "R001",
              "توقف التنفيذ لأن قناة الإدخال لم تُرجع قيمة صالحة", NULL);
        }
        runtime_end();
      }

      /* 7. Artifacts */
      char *artifact_dir = protocol_extract_string_value(payload, "\"artifactDirectory\"");
      if (artifact_dir && artifact_dir[0] != '\0') {
        char *artifact_target = protocol_extract_string_value(payload, "\"target\"");
        char asm_path[1024];
        const int artifact_path_allowed =
            root_path && artifact_path_is_within_root(root_path, artifact_dir);
        const int asm_length = snprintf(asm_path, sizeof(asm_path), "%s%carabicc.asm",
                 artifact_dir,
#ifdef _WIN32
                 '\\'
#else
                 '/'
#endif
        );
        if (!artifact_path_allowed) {
          resp.success = 0;
          protocol_add_diagnostic(
              &resp, SEVERITY_ERROR, "backend", "A003",
              "مسار artifact يجب أن يكون داخل مجلد المشروع", NULL);
        } else if (asm_length < 0 || (size_t)asm_length >= sizeof(asm_path)) {
          resp.success = 0;
          protocol_add_diagnostic(
              &resp, SEVERITY_ERROR, "backend", "A004",
              "مسار artifact طويل جدًا", NULL);
        } else if (resp.assembly && resp.assembly[0] != '\0') {
          toolchain_ensure_directory(artifact_dir);
          FILE *af = fopen(asm_path, "w");
          if (af) {
            fputs(resp.assembly, af);
            fclose(af);
            protocol_add_artifact(&resp, asm_path);
            if (artifact_target &&
                strcmp(artifact_target, "dart-native") == 0) {
              char native_path[2048];
              char build_error[256];
              if (artifact_build_native(
                      artifact_dir,
                      asm_path,
                      native_path,
                      sizeof(native_path),
                      build_error,
                      sizeof(build_error))) {
                protocol_add_artifact(&resp, native_path);
              } else {
                resp.success = 0;
                protocol_add_diagnostic(
                    &resp,
                    SEVERITY_ERROR,
                    "backend",
                    "A002",
                    build_error,
                    NULL);
              }
            }
          } else {
            resp.success = 0;
            protocol_add_diagnostic(
                &resp, SEVERITY_ERROR, "backend", "A005",
                "تعذر إنشاء ملف Assembly الناتج", NULL);
          }
        }
        free(artifact_target);
        free(artifact_dir);
      }

      c_ast_free(g_root_ast);
      g_root_ast = NULL;
    }
    free(source);
    if (parse_failed) {
      if (resp.diagnostic_count == 0) {
        protocol_add_diagnostic(&resp, SEVERITY_ERROR, "syntax", "S001",
                                "تعذر تحليل المصدر", NULL);
      }
    }
  } else {
    protocol_add_diagnostic(&resp, SEVERITY_ERROR, "driver", "P003",
                            "لم يحتوي الطلب على مصدر قابل للترجمة", NULL);
  }
  free(root_path);

  char *json_out = protocol_serialize_response(&resp);
  if (json_out) {
    fputs(json_out, stdout);
    free(json_out);
  }
  const int exit_code = resp.success ? 0 : 1;
  protocol_response_free(&resp);
  return exit_code;
}
