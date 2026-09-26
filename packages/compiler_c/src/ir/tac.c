#include "tac.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const CAstNode *g_root;
static const CAstNode *constant_value(const char *name) { if (!g_root || !name) return NULL; for (size_t i=0;i<g_root->data.program.declarations.count;i++){const CAstNode *d=g_root->data.program.declarations.items[i];if(d->kind==C_AST_CONSTANT_DECLARATION && d->data.constant.name && !strcmp(d->data.constant.name,name)) return d->data.constant.value;} return NULL; }
static char *dup(const char *value) {
  const char *source = value ? value : "";
  size_t length = strlen(source);
  char *copy = malloc(length + 1U);
  if (copy) memcpy(copy, source, length + 1U);
  return copy;
}
static int reserve(CTacResult *result) {
  if (result->count < result->capacity) return 1;
  size_t next = result->capacity ? result->capacity * 2U : 32U;
  CTacInstruction *items = realloc(result->items, next * sizeof(*items));
  if (!items) return 0;
  result->items = items; result->capacity = next; return 1;
}
static int add(CTacResult *result, CTacOpcode opcode, const char *r,
               const char *l, const char *op, const char *right,
               const char *type, size_t argc, const CAstNode *node) {
  if (!reserve(result)) return 0;
  CTacInstruction *item = &result->items[result->count++];
  memset(item, 0, sizeof(*item));
  item->opcode = opcode; item->result = dup(r); item->left = dup(l);
  item->operator = dup(op); item->right = dup(right); item->type = dup(type);
  item->argument_count = argc;
  item->offset = node ? node->offset : 0U; item->line = node ? node->line : 1U;
  item->column = node ? node->column : 1U;
  return item->result && item->left && item->operator && item->right && item->type;
}
static const char *expr_type(const CAstNode *n) {
  if (!n) return "غير معروف";
  if (n->kind == C_AST_LITERAL) {
    switch (n->data.literal.literal_kind) {
      case C_TOKEN_INTEGER: return "صحيح"; case C_TOKEN_REAL: return "حقيقي";
      case C_TOKEN_BOOLEAN: return "منطقي"; case C_TOKEN_CHARACTER: return "حرفي";
      case C_TOKEN_STRING: return "خيط_رمزي"; default: return "غير معروف";
    }
  }
  if (n->kind == C_AST_BINARY) {
    const char *l = expr_type(n->data.binary.left), *r = expr_type(n->data.binary.right);
    const char *op = n->data.binary.operator;
    if (!strcmp(op, "==") || !strcmp(op, "!=") || !strcmp(op, "<") || !strcmp(op, ">") || !strcmp(op, "<=") || !strcmp(op, ">=") || !strcmp(op, "&&") || !strcmp(op, "||")) return "منطقي";
    if (!strcmp(op, "^")) {
      if (n->data.binary.right != NULL &&
          n->data.binary.right->kind == C_AST_LITERAL &&
          n->data.binary.right->data.literal.literal_kind == C_TOKEN_INTEGER &&
          n->data.binary.right->data.literal.value != NULL &&
          n->data.binary.right->data.literal.value[0] != '-') {
        return !strcmp(l, "حقيقي") ? "حقيقي" : "صحيح";
      }
      return "حقيقي";
    }
    if (!strcmp(l, "حقيقي") || !strcmp(r, "حقيقي")) return "حقيقي";
    if (!strcmp(l, "خيط_رمزي") || !strcmp(r, "خيط_رمزي")) return "خيط_رمزي";
    return l;
  }
  if (n->kind == C_AST_UNARY) return !strcmp(n->data.unary.operator, "!") ? "منطقي" : expr_type(n->data.unary.operand);
  if (n->kind == C_AST_VARIABLE_REFERENCE) {
    const CAstNode *constant = constant_value(n->data.reference.name);
    if (constant) return expr_type(constant);
    if (g_root) for (size_t i=0;i<g_root->data.program.declarations.count;i++) {
      const CAstNode *d=g_root->data.program.declarations.items[i];
      if (d->kind==C_AST_VARIABLE_DECLARATION && d->data.variable.type && d->data.variable.type->name)
        for (size_t j=0;j<d->data.variable.name_count;j++) if (!strcmp(d->data.variable.names[j],n->data.reference.name)) return d->data.variable.type->name;
    }
    return "غير معروف";
  }
  return "غير معروف";
}
static const char *declared_type(const char *name) {
  if (!g_root || !name) return NULL;
  for (size_t i=0;i<g_root->data.program.declarations.count;i++) {
    const CAstNode *d=g_root->data.program.declarations.items[i];
    if (d->kind==C_AST_VARIABLE_DECLARATION && d->data.variable.type && d->data.variable.type->name)
      for (size_t j=0;j<d->data.variable.name_count;j++)
        if (!strcmp(d->data.variable.names[j],name)) return d->data.variable.type->name;
  }
  return NULL;
}
static char *expression(const CAstNode *node, CTacResult *out, size_t *temporary) {
  if (!node) return dup("0");
  if (node->kind == C_AST_LITERAL) return dup(node->data.literal.value);
  if (node->kind == C_AST_VARIABLE_REFERENCE) { const CAstNode *constant = constant_value(node->data.reference.name); if (constant) return expression(constant, out, temporary); return dup(node->data.reference.name); }
  if (node->kind == C_AST_BINARY || node->kind == C_AST_UNARY) {
    char *left = expression(node->kind == C_AST_BINARY ? node->data.binary.left : node->data.unary.operand, out, temporary);
    char *right = node->kind == C_AST_BINARY ? expression(node->data.binary.right, out, temporary) : NULL;
    char name[32]; snprintf(name, sizeof(name), "$t%zu", (*temporary)++);
    int ok = add(out, node->kind == C_AST_BINARY ? C_TAC_BINARY : C_TAC_UNARY, name, left,
                 node->kind == C_AST_BINARY ? node->data.binary.operator : node->data.unary.operator,
                 right, expr_type(node), 0U, node);
    free(left); free(right); return ok ? dup(name) : NULL;
  }
  return dup("0");
}
static int statements(const CAstNodeList *list, CTacResult *out, size_t *temp, size_t *label) {
  for (size_t i = 0; i < list->count; i++) {
    const CAstNode *s = list->items[i]; if (!s) continue;
    if (s->kind == C_AST_PROGRAM) { if (!statements(&s->data.program.statements, out, temp, label)) return 0; continue; }
    if (s->kind == C_AST_IF) {
      char els[32], done[32]; snprintf(els,sizeof(els),"if_else%zu",(*label)++); snprintf(done,sizeof(done),"if_done%zu",(*label)++);
      char *condition = expression(s->data.conditional.condition,out,temp);
      if (!condition || !add(out,C_TAC_BRANCH,els,condition,NULL,done,"منطقي",0U,s) || !statements(&s->data.conditional.then_branch,out,temp,label) || !add(out,C_TAC_JUMP,done,NULL,NULL,NULL,"",0U,s) || !add(out,C_TAC_LABEL,els,NULL,NULL,NULL,"",0U,s) || !statements(&s->data.conditional.else_branch,out,temp,label) || !add(out,C_TAC_LABEL,done,NULL,NULL,NULL,"",0U,s)) { free(condition); return 0; } free(condition); continue;
    }
    if (s->kind == C_AST_WHILE) {
      char head[32], done[32]; snprintf(head,sizeof(head),"L%zu",(*label)++); snprintf(done,sizeof(done),"L%zu",(*label)++);
      if (!add(out,C_TAC_LABEL,head,NULL,NULL,NULL,"",0U,s)) return 0;
      char *condition=expression(s->data.loop.condition,out,temp); if (!condition || !add(out,C_TAC_BRANCH,done,condition,NULL,head,"منطقي",0U,s) || !statements(&s->data.loop.body,out,temp,label) || !add(out,C_TAC_JUMP,head,NULL,NULL,NULL,"",0U,s) || !add(out,C_TAC_LABEL,done,NULL,NULL,NULL,"",0U,s)) { free(condition); return 0; } free(condition); continue;
    }
    if (s->kind == C_AST_REPEAT) {
      char *from = expression(s->data.repeat.from, out, temp);
      if (!from || !add(out, C_TAC_ASSIGN, s->data.repeat.variable, from, NULL, NULL,
                        expr_type(s->data.repeat.from), 0U, s)) { free(from); return 0; }
      free(from);
      char head[32], done[32];
      snprintf(head, sizeof(head), "L%zu", (*label)++);
      snprintf(done, sizeof(done), "L%zu", (*label)++);
      if (!add(out, C_TAC_LABEL, head, NULL, NULL, NULL, "", 0U, s)) return 0;
      char *limit = expression(s->data.repeat.to, out, temp);
      char *current = dup(s->data.repeat.variable);
      const CAstNode *step_node = s->data.repeat.step;
      const int descending = step_node && ((step_node->kind == C_AST_UNARY &&
                                             step_node->data.unary.operator &&
                                             !strcmp(step_node->data.unary.operator, "-")) ||
                                            (step_node->kind == C_AST_LITERAL &&
                                             step_node->data.literal.value &&
                                             step_node->data.literal.value[0] == '-'));
      const char *bound_operator = descending ? ">=" : "<=";
      char condition_name[32]; snprintf(condition_name, sizeof(condition_name), "$t%zu", (*temp)++);
      if (!limit || !current || !add(out, C_TAC_BINARY, condition_name, current, bound_operator, limit,
                                      "منطقي", 0U, s) ||
          !add(out, C_TAC_BRANCH, done, condition_name, NULL, head, "منطقي", 0U, s) ||
          !statements(&s->data.repeat.body, out, temp, label)) {
        free(limit); free(current); return 0;
      }
      free(limit); free(current);
      char *step = s->data.repeat.step ? expression(s->data.repeat.step, out, temp) : dup("1");
      char *value = dup(s->data.repeat.variable);
      char increment_name[32]; snprintf(increment_name, sizeof(increment_name), "$t%zu", (*temp)++);
      if (!step || !value || !add(out, C_TAC_BINARY, increment_name, value, "+", step,
                                  "صحيح", 0U, s) ||
          !add(out, C_TAC_ASSIGN, s->data.repeat.variable, increment_name, NULL, NULL,
               "صحيح", 0U, s) || !add(out, C_TAC_JUMP, head, NULL, NULL, NULL, "", 0U, s) ||
          !add(out, C_TAC_LABEL, done, NULL, NULL, NULL, "", 0U, s)) {
        free(step); free(value); return 0;
      }
      free(step); free(value); continue;
    }
    if (s->kind == C_AST_REPEAT_UNTIL) {
      char head[32], done[32];
      snprintf(head, sizeof(head), "L%zu", (*label)++);
      snprintf(done, sizeof(done), "L%zu", (*label)++);
      if (!add(out, C_TAC_LABEL, head, NULL, NULL, NULL, "", 0U, s) ||
          !statements(&s->data.repeat_until.body, out, temp, label)) return 0;
      char *condition = expression(s->data.repeat_until.condition, out, temp);
      if (!condition || !add(out, C_TAC_BRANCH, head, condition, NULL, done,
                             "منطقي", 0U, s) ||
          !add(out, C_TAC_LABEL, done, NULL, NULL, NULL, "", 0U, s)) {
        free(condition); return 0;
      }
      free(condition); continue;
    }
    if (s->kind == C_AST_ASSIGNMENT) {
      char *v=expression(s->data.assignment.expression,out,temp);
      const char *target_type=declared_type(s->data.assignment.name);
      if (!v) return 0;
      if (target_type && !strcmp(target_type,"حقيقي") && v[0]=='t') {
        for (size_t j=0;j<out->count;j++) if (out->items[j].result && !strcmp(out->items[j].result,v)) {
          free(out->items[j].type); out->items[j].type=dup("حقيقي"); break;
        }
      }
      if (!add(out,C_TAC_ASSIGN,s->data.assignment.name,v,NULL,NULL,
               target_type && !strcmp(target_type,"حقيقي") ? "حقيقي" : expr_type(s->data.assignment.expression),0U,s)) { free(v); return 0; }
      free(v); continue;
    }
    if (s->kind == C_AST_READ) { if (!add(out,C_TAC_READ,s->data.access.name,NULL,NULL,NULL,"غير معروف",0U,s)) return 0; continue; }
    if (s->kind == C_AST_PRINT) { for (size_t j=0;j<s->data.print.values.count;j++) { char *v=expression(s->data.print.values.items[j],out,temp); if (!v || !add(out,C_TAC_PRINT,NULL,v,NULL,NULL,expr_type(s->data.print.values.items[j]),1U,s)) { free(v); return 0; } free(v); } continue; }
    if (s->kind == C_AST_CALL) { for (size_t j=0;j<s->data.call.arguments.count;j++) { char *v=expression(s->data.call.arguments.items[j],out,temp); if (!v || !add(out,C_TAC_PARAM,NULL,v,NULL,NULL,expr_type(s->data.call.arguments.items[j]),1U,s)) { free(v); return 0; } free(v); } if (!add(out,C_TAC_CALL,s->data.call.name,NULL,NULL,NULL,"إجراء",s->data.call.arguments.count,s)) return 0; continue; }
    if (s->kind != C_AST_EMPTY) return 0;
  }
  return 1;
}
int c_generate_tac(const CAstNode *root, CTacResult *result) {
  if (!root || !result || root->kind != C_AST_PROGRAM) return 0; g_root = root; memset(result,0,sizeof(*result)); size_t temp=0,label=0;
  for (size_t i=0;i<root->data.program.declarations.count;i++) { const CAstNode *d=root->data.program.declarations.items[i]; if (d->kind==C_AST_VARIABLE_DECLARATION) for(size_t j=0;j<d->data.variable.name_count;j++) if(!add(result,C_TAC_ALLOC,d->data.variable.names[j],NULL,NULL,NULL,d->data.variable.type&&d->data.variable.type->name?d->data.variable.type->name:"نوع مركب",0U,d)) { c_tac_result_free(result); return 0; } }
  if (!statements(&root->data.program.statements,result,&temp,&label)) { c_tac_result_free(result); return 0; } return 1;
}
const char *c_tac_opcode_name(CTacOpcode opcode) { switch(opcode){case C_TAC_ALLOC:return "ALLOC";case C_TAC_ASSIGN:return "ASSIGN";case C_TAC_BINARY:return "BINARY";case C_TAC_UNARY:return "UNARY";case C_TAC_PARAM:return "PARAM";case C_TAC_CALL:return "CALL";case C_TAC_LABEL:return "LABEL";case C_TAC_JUMP:return "JUMP";case C_TAC_BRANCH:return "BRANCH";case C_TAC_READ:return "READ";case C_TAC_PRINT:return "PRINT";default:return "UNKNOWN";} }
char *c_tac_instruction_to_text(const CTacInstruction *i) { if(!i)return NULL; char b[512]; switch(i->opcode){case C_TAC_ALLOC:snprintf(b,sizeof(b),"ALLOC %s, %s",i->result,i->type);break;case C_TAC_ASSIGN:snprintf(b,sizeof(b),"%s = %s",i->result,i->left);break;case C_TAC_BINARY:snprintf(b,sizeof(b),"%s = %s %s %s",i->result,i->left,i->operator,i->right);break;case C_TAC_UNARY:snprintf(b,sizeof(b),"%s = %s%s",i->result,i->operator,i->left);break;case C_TAC_PARAM:snprintf(b,sizeof(b),"PARAM %s",i->left);break;case C_TAC_CALL:snprintf(b,sizeof(b),"CALL %s, %zu",i->result,i->argument_count);break;case C_TAC_LABEL:snprintf(b,sizeof(b),"LABEL %s",i->result);break;case C_TAC_JUMP:snprintf(b,sizeof(b),"JUMP %s",i->result);break;case C_TAC_BRANCH:snprintf(b,sizeof(b),"BRANCH %s, %s, %s",i->left,i->result,i->right);break;case C_TAC_READ:snprintf(b,sizeof(b),"READ %s",i->result);break;case C_TAC_PRINT:snprintf(b,sizeof(b),"PRINT %s",i->left);break;default:return NULL;} return dup(b); }
void c_tac_result_free(CTacResult *result){if(!result)return;for(size_t i=0;i<result->count;i++){free(result->items[i].result);free(result->items[i].left);free(result->items[i].operator);free(result->items[i].right);free(result->items[i].type);}free(result->items);memset(result,0,sizeof(*result));}
