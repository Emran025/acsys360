#include "lexer.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *keywords[] = {
  "برنامج", "ثابت", "نوع", "متغير", "اجراء", "بالقيمة", "بالمرجع",
  "قائمة", "من", "سجل", "صحيح", "حقيقي", "منطقي", "حرفي", "خيط_رمزي",
  "اطبع", "اقرا", "اذا", "فان", "والا", "طالما", "استمر", "كرر", "الى",
  "اضف", "اعد", "حتى", NULL
};

static char *duplicate_string(const char *source) {
  const size_t length = strlen(source);
  char *value = malloc(length + 1U);
  if (value == NULL) return NULL;
  memcpy(value, source, length + 1U);
  return value;
}

static char *copy_range(const char *source, size_t start, size_t end) {
  const size_t length = end - start;
  char *value = malloc(length + 1U);
  if (value == NULL) return NULL;
  memcpy(value, source + start, length);
  value[length] = '\0';
  return value;
}

static int push_token(CLexResult *result, CToken token) {
  if (result->count == result->capacity) {
    const size_t capacity = result->capacity == 0U ? 32U : result->capacity * 2U;
    CToken *items = realloc(result->items, capacity * sizeof(*items));
    if (items == NULL) return 0;
    result->items = items;
    result->capacity = capacity;
  }
  result->items[result->count++] = token;
  return 1;
}

static int push_diagnostic(CLexResult *result, const char *message) {
  if (result->diagnostic_count == result->diagnostic_capacity) {
    const size_t capacity = result->diagnostic_capacity == 0U
        ? 4U
        : result->diagnostic_capacity * 2U;
    char **items = realloc(result->diagnostics, capacity * sizeof(*items));
    if (items == NULL) return 0;
    result->diagnostics = items;
    result->diagnostic_capacity = capacity;
  }
  result->diagnostics[result->diagnostic_count] = duplicate_string(message);
  if (result->diagnostics[result->diagnostic_count] == NULL) return 0;
  result->diagnostic_count++;
  return 1;
}

static int is_keyword(const char *value) {
  for (size_t index = 0U; keywords[index] != NULL; index++) {
    if (strcmp(value, keywords[index]) == 0) return 1;
  }
  return 0;
}

static int is_boolean(const char *value) {
  return strcmp(value, "صح") == 0 || strcmp(value, "خطأ") == 0;
}

static size_t utf8_width(unsigned char value) {
  if (value < 0x80U) return 1U;
  if ((value & 0xE0U) == 0xC0U) return 2U;
  if ((value & 0xF0U) == 0xE0U) return 3U;
  if ((value & 0xF8U) == 0xF0U) return 4U;
  return 1U;
}

static int is_arabic_codepoint(unsigned int codepoint) {
  if (codepoint == 0x060CU || codepoint == 0x061BU) return 0;
  return (codepoint >= 0x0600U && codepoint <= 0x06FFU) ||
      (codepoint >= 0x0750U && codepoint <= 0x077FU) ||
      (codepoint >= 0x08A0U && codepoint <= 0x08FFU);
}

static unsigned int decode_codepoint(const char *source, size_t offset,
                                     size_t *width) {
  const unsigned char first = (unsigned char)source[offset];
  *width = utf8_width(first);
  if (*width == 1U) return first;
  unsigned int value = first & ((1U << (8U - *width - 1U)) - 1U);
  for (size_t index = 1U; index < *width; index++) {
    const unsigned char part = (unsigned char)source[offset + index];
    if ((part & 0xC0U) != 0x80U) {
      *width = 1U;
      return first;
    }
    value = (value << 6U) | (part & 0x3FU);
  }
  return value;
}

static int is_identifier_start(const char *source, size_t offset,
                               size_t *width) {
  const unsigned int codepoint = decode_codepoint(source, offset, width);
  return codepoint == '_' || is_arabic_codepoint(codepoint);
}

static int is_identifier_part(const char *source, size_t offset,
                              size_t *width) {
  const unsigned int codepoint = decode_codepoint(source, offset, width);
  return codepoint == '_' || is_arabic_codepoint(codepoint) ||
      (codepoint >= '0' && codepoint <= '9');
}

static void advance(const char *source, size_t *offset, size_t *logical_offset,
                    size_t *line, size_t *column) {
  size_t width = 1U;
  const unsigned int codepoint = decode_codepoint(source, *offset, &width);
  if (source[*offset] == '\n') {
    *line += 1U;
    *column = 1U;
  } else {
    *column += 1U;
  }
  *offset += width;
  *logical_offset += codepoint > 0xFFFFU ? 2U : 1U;
}

static int is_space_at(const char *source, size_t offset) {
  const unsigned char value = (unsigned char)source[offset];
  return value == ' ' || value == '\t' || value == '\r' || value == '\n' ||
      value == '\f';
}

static CTokenKind classify_identifier(const char *lexeme) {
  if (is_boolean(lexeme)) return C_TOKEN_BOOLEAN;
  return is_keyword(lexeme) ? C_TOKEN_KEYWORD : C_TOKEN_IDENTIFIER;
}

static int is_punctuation(unsigned char value) {
  return value == '{' || value == '}' || value == '(' || value == ')' ||
      value == '[' || value == ']' || value == ';' || value == ',' ||
      value == '.' || value == ':';
}

static int is_arabic_punctuation(const char *source, size_t offset) {
  const unsigned char first = (unsigned char)source[offset];
  const unsigned char second = (unsigned char)source[offset + 1U];
  return first == 0xD8U && (second == 0x8CU || second == 0x9BU);
}

static int is_operator_char(unsigned char value) {
  return value == '+' || value == '-' || value == '*' || value == '/' ||
      value == '%' || value == '\\' || value == '^' || value == '!' ||
      value == '=' || value == '<' || value == '>' || value == '&' ||
      value == '|';
}

static int push_simple_token(const char *source, CLexResult *result,
                             CTokenKind kind, size_t start, size_t end,
                             size_t logical_start, size_t logical_end,
                             size_t line, size_t column) {
  CToken token = {
    .kind = kind,
    .lexeme = copy_range(source, start, end),
    .offset = logical_start,
    .line = line,
    .column = column,
    .length = logical_end - logical_start,
  };
  if (token.lexeme == NULL || !push_token(result, token)) {
    free(token.lexeme);
    return 0;
  }
  return 1;
}

int c_lex(const char *source, CLexResult *result) {
  if (source == NULL || result == NULL) return 0;
  memset(result, 0, sizeof(*result));
  size_t offset = 0U;
  size_t logical_offset = 0U;
  size_t line = 1U;
  size_t column = 1U;
  while (source[offset] != '\0') {
    while (source[offset] != '\0') {
      if (source[offset] == '/' && source[offset + 1U] == '/') {
        while (source[offset] != '\0' && source[offset] != '\n') {
          advance(source, &offset, &logical_offset, &line, &column);
        }
      } else if (is_space_at(source, offset)) {
        advance(source, &offset, &logical_offset, &line, &column);
      } else {
        break;
      }
    }
    if (source[offset] == '\0') break;
    const size_t start = offset;
    const size_t start_line = line;
    const size_t start_column = column;
    const size_t start_logical = logical_offset;
    size_t width = 1U;
    if (is_identifier_start(source, offset, &width)) {
      advance(source, &offset, &logical_offset, &line, &column);
      while (source[offset] != '\0') {
        if (!is_identifier_part(source, offset, &width)) break;
        advance(source, &offset, &logical_offset, &line, &column);
      }
      char *lexeme = copy_range(source, start, offset);
      if (lexeme == NULL) return 0;
      const CTokenKind kind = classify_identifier(lexeme);
      CToken token = {
        .kind = kind,
        .lexeme = lexeme,
        .offset = start_logical,
        .line = start_line,
        .column = start_column,
        .length = logical_offset - start_logical,
      };
      if (!push_token(result, token)) {
        free(lexeme);
        return 0;
      }
      continue;
    }
    if (isdigit((unsigned char)source[offset])) {
      CTokenKind kind = C_TOKEN_INTEGER;
      advance(source, &offset, &logical_offset, &line, &column);
      while (isdigit((unsigned char)source[offset])) {
        advance(source, &offset, &logical_offset, &line, &column);
      }
      if (source[offset] == '.' && isdigit((unsigned char)source[offset + 1U])) {
        kind = C_TOKEN_REAL;
        advance(source, &offset, &logical_offset, &line, &column);
        while (isdigit((unsigned char)source[offset])) {
          advance(source, &offset, &logical_offset, &line, &column);
        }
      }
      if (!push_simple_token(source, result, kind, start, offset, start_logical,
                             logical_offset, start_line, start_column)) return 0;
      continue;
    }
    if (source[offset] == '"') {
      advance(source, &offset, &logical_offset, &line, &column);
      while (source[offset] != '\0' && source[offset] != '"') {
        advance(source, &offset, &logical_offset, &line, &column);
      }
      if (source[offset] == '\0') {
        if (!push_diagnostic(result, "سلسلة نصية غير مغلقة")) return 0;
      } else {
        advance(source, &offset, &logical_offset, &line, &column);
      }
      if (!push_simple_token(source, result, C_TOKEN_STRING, start, offset,
                             start_logical, logical_offset, start_line, start_column)) return 0;
      continue;
    }
    if (source[offset] == '\xE2' &&
        (unsigned char)source[offset + 1U] == 0x80U &&
        ((unsigned char)source[offset + 2U] == 0x98U ||
         (unsigned char)source[offset + 2U] == 0x99U)) {
      advance(source, &offset, &logical_offset, &line, &column);
      if (source[offset] != '\0') advance(source, &offset, &logical_offset, &line, &column);
      if ((unsigned char)source[offset] != 0xE2U ||
          (unsigned char)source[offset + 1U] != 0x80U ||
          ((unsigned char)source[offset + 2U] != 0x98U &&
           (unsigned char)source[offset + 2U] != 0x99U)) {
        if (!push_diagnostic(result, "محرف غير مغلق")) return 0;
      } else {
        advance(source, &offset, &logical_offset, &line, &column);
      }
      if (!push_simple_token(source, result, C_TOKEN_CHARACTER, start, offset,
                             start_logical, logical_offset, start_line, start_column)) return 0;
      continue;
    }
    if (is_punctuation((unsigned char)source[offset]) ||
        is_arabic_punctuation(source, offset)) {
      const int is_arabic = is_arabic_punctuation(source, offset);
      advance(source, &offset, &logical_offset, &line, &column);
      if (!push_simple_token(source, result, C_TOKEN_PUNCTUATION, start, offset,
                             start_logical, logical_offset, start_line, start_column)) return 0;
      if (is_arabic) {
        CToken *token = &result->items[result->count - 1U];
        free(token->lexeme);
        token->lexeme = duplicate_string(
            (unsigned char)source[start + 1U] == 0x9BU ? ";" : ",");
        if (token->lexeme == NULL) return 0;
      }
      continue;
    }
    if (is_operator_char((unsigned char)source[offset])) {
      const unsigned char first = (unsigned char)source[offset];
      const unsigned char second = (unsigned char)source[offset + 1U];
      const int is_pair = (first == '&' && second == '&') ||
          (first == '|' && second == '|') || (first == '=' && second == '=') ||
          (first == '!' && second == '=') || (first == '=' && second == '<') ||
          (first == '=' && second == '>');
      if (!is_pair && (first == '&' || first == '|')) {
        char message[128];
        (void)snprintf(message, sizeof(message), "رمز غير معروف عند offset %zu", logical_offset);
        if (!push_diagnostic(result, message)) return 0;
        advance(source, &offset, &logical_offset, &line, &column);
        continue;
      }
      advance(source, &offset, &logical_offset, &line, &column);
      if (is_pair) advance(source, &offset, &logical_offset, &line, &column);
      if (!push_simple_token(source, result, C_TOKEN_OPERATOR, start, offset,
                             start_logical, logical_offset, start_line, start_column)) return 0;
      continue;
    }
    char message[128];
    (void)snprintf(message, sizeof(message), "رمز غير معروف عند offset %zu", offset);
    if (!push_diagnostic(result, message)) return 0;
    advance(source, &offset, &logical_offset, &line, &column);
  }
  if (!push_simple_token(source, result, C_TOKEN_EOF, offset, offset,
                             logical_offset, logical_offset, line, column)) {
    return 0;
  }
  return 1;
}

void c_lex_result_free(CLexResult *result) {
  if (result == NULL) return;
  for (size_t index = 0U; index < result->count; index++) {
    free(result->items[index].lexeme);
  }
  for (size_t index = 0U; index < result->diagnostic_count; index++) {
    free(result->diagnostics[index]);
  }
  free(result->items);
  free(result->diagnostics);
  memset(result, 0, sizeof(*result));
}

const char *c_token_kind_name(CTokenKind kind) {
  switch (kind) {
    case C_TOKEN_KEYWORD: return "keyword";
    case C_TOKEN_BOOLEAN: return "boolean";
    case C_TOKEN_IDENTIFIER: return "identifier";
    case C_TOKEN_INTEGER: return "integer";
    case C_TOKEN_REAL: return "real";
    case C_TOKEN_STRING: return "string";
    case C_TOKEN_CHARACTER: return "character";
    case C_TOKEN_PUNCTUATION: return "punctuation";
    case C_TOKEN_OPERATOR: return "operator";
    case C_TOKEN_EOF: return "eof";
  }
  return "unknown";
}
