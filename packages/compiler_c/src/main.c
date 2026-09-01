#include "lexer.h"
#include "protocol.h"

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
  if (argc == 2 && strcmp(argv[1], "--protocol") == 0) {
    char *payload = read_stdin();
    if (payload == NULL) return 70;
    const int result = c_run_protocol(payload);
    free(payload);
    return result;
  }
  if (argc == 2 && strcmp(argv[1], "--lex") == 0) {
    char *source = read_stdin();
    if (source == NULL) return 70;
    CLexResult result;
    const int success = c_lex(source, &result);
    if (success) {
      for (size_t index = 0U; index < result.count; index++) {
        printf("%s\t%s\t%zu\t%zu\t%zu\n",
               c_token_kind_name(result.items[index].kind),
               result.items[index].lexeme,
               result.items[index].line,
               result.items[index].column,
               result.items[index].length);
      }
    }
    c_lex_result_free(&result);
    free(source);
    return success ? 0 : 70;
  }
  fputs("usage: arabicc_c --protocol | --lex\n", stderr);
  return 64;
}
