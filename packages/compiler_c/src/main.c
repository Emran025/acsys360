#include "protocol.h"
#include "ast.h"
#include "semantic.h"
#include "asm_x86_64.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *read_stdin(void) {
  size_t length = 0U;
  size_t capacity = 1024U;
  char *buffer = malloc(capacity);
  if (buffer == NULL) return NULL;
  int value;
  while ((value = fgetc(stdin)) != EOF) {
    if (length + 1U >= capacity) {
      capacity *= 2U;
      char *next = realloc(buffer, capacity);
      if (next == NULL) {
        free(buffer);
        return NULL;
      }
      buffer = next;
    }
    buffer[length++] = (char)value;
  }
  buffer[length] = '\0';
  return buffer;
}

static char *read_stdin_line(void) {
  size_t length = 0U;
  size_t capacity = 1024U;
  char *buffer = malloc(capacity);
  if (buffer == NULL) return NULL;
  int value;
  while ((value = fgetc(stdin)) != EOF && value != '\n') {
    if (length + 1U >= capacity) {
      capacity *= 2U;
      char *next = realloc(buffer, capacity);
      if (next == NULL) {
        free(buffer);
        return NULL;
      }
      buffer = next;
    }
    buffer[length++] = (char)value;
  }
  buffer[length] = '\0';
  return buffer;
}

int main(int argc, char **argv) {
  if (argc >= 2 && (strcmp(argv[1], "--protocol") == 0 || strcmp(argv[1], "--assist") == 0)) {
    char *payload = read_stdin_line();
    if (payload == NULL) {
      fputs("{\"protocolVersion\":\"0.5.0\",\"success\":false,\"diagnostics\":[{\"severity\":\"error\",\"phase\":\"driver\",\"code\":\"P002\",\"message\":\"فشل قراءة الدخل القياسي\",\"span\":null}],\"tokens\":[],\"syntaxTree\":null,\"symbolTable\":[],\"threeAddressCode\":[],\"assembly\":\"\",\"executionOutput\":[],\"artifacts\":[],\"intermediateRepresentation\":null}\n", stdout);
      return 70;
    }
    const int result = c_run_protocol(payload);
    free(payload);
    return result;
  }

  if (argc >= 2 && strcmp(argv[1], "--asm") == 0) {
    char *source = read_stdin();
    if (source == NULL) return 70;
    typedef struct yy_buffer_state *YY_BUFFER_STATE;
    extern YY_BUFFER_STATE yy_scan_string(const char *str);
    extern void yy_delete_buffer(YY_BUFFER_STATE buffer);
    extern int yyparse(void);
    extern CAstNode *g_root_ast;

    YY_BUFFER_STATE buffer = yy_scan_string(source);
    int parse_res = yyparse();
    yy_delete_buffer(buffer);

    if (parse_res == 0 && g_root_ast != NULL) {
      CSemanticResult semantic;
      memset(&semantic, 0, sizeof(semantic));
      if (c_analyze_semantics(g_root_ast, &semantic) && semantic.diagnostic_count == 0) {
        CAssemblyResult assembly;
        memset(&assembly, 0, sizeof(assembly));
        if (c_generate_nasm_x86_64(g_root_ast, &semantic, &assembly) && assembly.text) {
          fputs(assembly.text, stdout);
          c_assembly_result_free(&assembly);
          c_semantic_result_free(&semantic);
          free(source);
          return 0;
        }
        c_assembly_result_free(&assembly);
      }
      c_semantic_result_free(&semantic);
    }
    free(source);
    return 1;
  }

  if (argc >= 2 && (strcmp(argv[1], "--version") == 0 || strcmp(argv[1], "-v") == 0)) {
    printf("arabicc version %s (C / Flex+Bison backend)\n", ARABICC_PROTOCOL_VERSION);
    return 0;
  }

  if (argc >= 2 && (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0)) {
    printf("الاستخدام: arabicc [خيارات]\n");
    printf("الخيارات:\n");
    printf("  --protocol    تشغيل وضع بروتوكول التواصل مع محرر Flutter (عبر stdin/stdout)\n");
    printf("  --assist      تشغيل وضع المساعدة والإكمال التلقائي\n");
    printf("  --version     عرض إصدار المترجم\n");
    printf("  --help        عرض هذه المساعدة\n");
    return 0;
  }

  /* الوضع الافتراضي: إذا لم يُمرر معامل، يتم قراءة stdin كبروتوكول افتراضي */
  char *payload = read_stdin();
  if (payload != NULL && payload[0] != '\0') {
    const int result = c_run_protocol(payload);
    free(payload);
    return result;
  }

  fputs("استخدام المترجم: arabicc --protocol\n", stderr);
  return 64;
}
