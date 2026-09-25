#include "tac.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *duplicate_string(const char *value) {
  const char *source = value ? value : "";
  const size_t length = strlen(source);
  char *copy = (char *)malloc(length + 1U);
  if (copy) memcpy(copy, source, length + 1U);
  return copy;
}

static int reserve(CTacResult *result) {
  if (result->count < result->capacity) return 1;
  const size_t next = result->capacity == 0U ? 16U : result->capacity * 2U;
  CTacInstruction *items = (CTacInstruction *)realloc(
      result->items, next * sizeof(CTacInstruction));
  if (!items) return 0;
  result->items = items;
  result->capacity = next;
  return 1;
}

static int add(CTacResult *result, CTacInstruction instruction) {
  if (!reserve(result)) return 0;
  result->items[result->count++] = instruction;
  return 1;
}

static CTacInstruction instruction(CTacOpcode opcode, const char *result,
                                   const char *left, const char *operator,
                                   const char *right, const char *type,
                                   size_t argument_count) {
  CTacInstruction item = {0};
  item.opcode = opcode;
  item.result = duplicate_string(result);
  item.left = duplicate_string(left);
  item.operator = duplicate_string(operator);
  item.right = duplicate_string(right);
  item.type = duplicate_string(type);
  item.argument_count = argument_count;
  return item;
}

static char *expression(const CAstNode *node, CTacResult *result, size_t *temporary) {
  if (!node) return duplicate_string("0");
  if (node->kind == C_AST_LITERAL) {
    return duplicate_string(node->data.literal.value ? node->data.literal.value : "0");
  }
  if (node->kind == C_AST_VARIABLE_REFERENCE) {
    return duplicate_string(node->data.reference.name ? node->data.reference.name : "");
  }
  if (node->kind == C_AST_BINARY) {
    char *left = expression(node->data.binary.left, result, temporary);
    char *right = expression(node->data.binary.right, result, temporary);
    if (!left || !right) {
      free(left);
      free(right);
      return NULL;
    }
    char name[32];
    (void)snprintf(name, sizeof(name), "t%zu", (*temporary)++);
    const CTacInstruction item = instruction(
        C_TAC_BINARY, name, left,
        node->data.binary.operator ? node->data.binary.operator : "+", right,
        "غير معروف", 0U);
    free(left);
    free(right);
    if (!add(result, item)) {
      free(item.result); free(item.left); free(item.operator); free(item.right);
      free(item.type);
      return NULL;
    }
    return duplicate_string(name);
  }
  return duplicate_string("0");
}

int c_generate_tac(const CAstNode *root, CTacResult *result) {
  if (!root || !result || root->kind != C_AST_PROGRAM) return 0;
  memset(result, 0, sizeof(*result));
  size_t temporary = 0U;
  for (size_t i = 0U; i < root->data.program.declarations.count; i++) {
    const CAstNode *declaration = root->data.program.declarations.items[i];
    if (!declaration || declaration->kind != C_AST_VARIABLE_DECLARATION) continue;
    for (size_t j = 0U; j < declaration->data.variable.name_count; j++) {
      const char *type = declaration->data.variable.type &&
                                 declaration->data.variable.type->name
                             ? declaration->data.variable.type->name
                             : "صحيح";
      if (!add(result, instruction(C_TAC_ALLOC,
                                   declaration->data.variable.names[j], NULL,
                                   NULL, NULL, type, 0U))) {
        c_tac_result_free(result);
        return 0;
      }
    }
  }
  for (size_t i = 0U; i < root->data.program.statements.count; i++) {
    const CAstNode *statement = root->data.program.statements.items[i];
    if (!statement) continue;
    if (statement->kind == C_AST_ASSIGNMENT && statement->data.assignment.name) {
      char *value = expression(statement->data.assignment.expression, result, &temporary);
      if (!value || !add(result, instruction(C_TAC_ASSIGN,
                                              statement->data.assignment.name,
                                              value, NULL, NULL, "غير معروف", 0U))) {
        free(value);
        c_tac_result_free(result);
        return 0;
      }
      free(value);
    } else if (statement->kind == C_AST_PRINT) {
      for (size_t j = 0U; j < statement->data.print.values.count; j++) {
        char *value = expression(statement->data.print.values.items[j], result, &temporary);
        if (!value || !add(result, instruction(C_TAC_PARAM, NULL, value, NULL,
                                                NULL, "غير معروف", 1U)) ||
            !add(result, instruction(C_TAC_CALL, "print", NULL, NULL, NULL,
                                     "إجراء", 1U))) {
          free(value);
          c_tac_result_free(result);
          return 0;
        }
        free(value);
      }
    }
  }
  return 1;
}

const char *c_tac_opcode_name(CTacOpcode opcode) {
  switch (opcode) {
    case C_TAC_ALLOC: return "ALLOC";
    case C_TAC_ASSIGN: return "ASSIGN";
    case C_TAC_BINARY: return "BINARY";
    case C_TAC_PARAM: return "PARAM";
    case C_TAC_CALL: return "CALL";
    default: return "UNKNOWN";
  }
}

char *c_tac_instruction_to_text(const CTacInstruction *item) {
  if (!item) return NULL;
  char buffer[512];
  switch (item->opcode) {
    case C_TAC_ALLOC:
      (void)snprintf(buffer, sizeof(buffer), "ALLOC %s, %s", item->result, item->type);
      break;
    case C_TAC_ASSIGN:
      (void)snprintf(buffer, sizeof(buffer), "%s = %s", item->result, item->left);
      break;
    case C_TAC_BINARY:
      (void)snprintf(buffer, sizeof(buffer), "%s = %s %s %s", item->result,
                     item->left, item->operator, item->right);
      break;
    case C_TAC_PARAM:
      (void)snprintf(buffer, sizeof(buffer), "PARAM %s", item->left);
      break;
    case C_TAC_CALL:
      (void)snprintf(buffer, sizeof(buffer), "CALL %s, %zu", item->result,
                     item->argument_count);
      break;
    default:
      return NULL;
  }
  return duplicate_string(buffer);
}

void c_tac_result_free(CTacResult *result) {
  if (!result) return;
  for (size_t i = 0U; i < result->count; i++) {
    free(result->items[i].result);
    free(result->items[i].left);
    free(result->items[i].operator);
    free(result->items[i].right);
    free(result->items[i].type);
  }
  free(result->items);
  memset(result, 0, sizeof(*result));
}
