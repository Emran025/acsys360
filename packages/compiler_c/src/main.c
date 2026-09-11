#include "protocol.h"
#include "ast.h"

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

int main(int argc, char **argv) {
  if (argc >= 2 && (strcmp(argv[1], "--protocol") == 0 || strcmp(argv[1], "--assist") == 0)) {
    char *payload = read_stdin();
    if (payload == NULL) {
      fputs("{\"protocolVersion\":\"0.5.0\",\"success\":false,\"diagnostics\":[{\"severity\":\"error\",\"phase\":\"driver\",\"code\":\"P002\",\"message\":\"فشل قراءة الدخل القياسي\",\"span\":null}],\"tokens\":[],\"syntaxTree\":null,\"symbolTable\":[],\"threeAddressCode\":[],\"assembly\":\"\",\"executionOutput\":[],\"artifacts\":[],\"intermediateRepresentation\":null}\n", stdout);
      return 70;
    }
    const int result = c_run_protocol(payload);
    free(payload);
    return result;
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
