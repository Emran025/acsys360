#include "protocol_internal.h"
#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Simple AST Execution for the Execution Output Tab */
typedef struct {
  int kind; /* 0 numeric, 1 string, 2 boolean, 3 character */
  double number;
  char *text;
} ExecValue;
typedef struct { char *name; const char *type; ExecValue value; } ExecVar;
static const char *g_input_values_payload = NULL;
static int g_interactive_execution = 0;
static int g_input_error = 0;
static const CAstNode *g_input_program = NULL;
static ExecValue exec_number(double n);
static ExecValue exec_bool(int b);

static const char *input_type_for(const char *name) {
  if (!g_input_program || !name) return NULL;
  for (size_t i = 0; i < g_input_program->data.program.declarations.count; i++) {
    const CAstNode *declaration =
        g_input_program->data.program.declarations.items[i];
    if (declaration->kind != C_AST_VARIABLE_DECLARATION ||
        !declaration->data.variable.type ||
        !declaration->data.variable.type->name) {
      continue;
    }
    for (size_t j = 0; j < declaration->data.variable.name_count; j++) {
      if (strcmp(declaration->data.variable.names[j], name) == 0) {
        return declaration->data.variable.type->name;
      }
    }
  }
  return NULL;
}

static const char *literal_type(const CAstNode *node) {
  if (!node || node->kind != C_AST_LITERAL) return NULL;
  switch (node->data.literal.literal_kind) {
    case C_TOKEN_INTEGER: return "صحيح";
    case C_TOKEN_REAL: return "حقيقي";
    case C_TOKEN_BOOLEAN: return "منطقي";
    case C_TOKEN_CHARACTER: return "حرفي";
    case C_TOKEN_STRING: return "خيط_رمزي";
    default: return NULL;
  }
}

static int utf8_value_length(const char *value) {
  int count = 0;
  for (const unsigned char *p = (const unsigned char *)value; *p; p++) {
    if ((*p & 0xC0) != 0x80) count++;
  }
  return count;
}

static int input_matches_type(const char *value, const char *type) {
  if (!value || !type) return 0;
  if (strcmp(type, "خيط_رمزي") == 0) return 1;
  if (strcmp(type, "منطقي") == 0) {
    return strcmp(value, "صح") == 0 || strcmp(value, "خطأ") == 0;
  }
  if (strcmp(type, "حرفي") == 0) return utf8_value_length(value) == 1;
  char *end = NULL;
  errno = 0;
  const double number = strtod(value, &end);
  if (end == value || *end != '\0' || errno == ERANGE || !isfinite(number)) {
    return 0;
  }
  if (strcmp(type, "صحيح") == 0) {
    return strchr(value, '.') == NULL && strchr(value, 'e') == NULL &&
        strchr(value, 'E') == NULL;
  }
  return strcmp(type, "حقيقي") == 0;
}

static void input_type_error(const char *name, const char *type) {
  char message[256];
  snprintf(message, sizeof(message),
           "قيمة الإدخال للمتغير «%s» يجب أن تكون من النوع «%s»",
           name ? name : "input", type ? type : "معروف");
  fprintf(stderr, "%s\n", message);
}

static ExecValue exec_value_from_text(const char *text) {
  if (!text) return exec_number(0);
  if (strcmp(text, "صح") == 0) return exec_bool(1);
  if (strcmp(text, "خطأ") == 0) return exec_bool(0);
  char *end = NULL;
  const double number = strtod(text, &end);
  if (end != text && *end == '\0') return exec_number(number);
  ExecValue value = {1, 0, protocol_strdup(text)};
  return value;
}

static ExecValue exec_interactive_input(const char *name) {
  char line[4096];
  const char *type = input_type_for(name);
  for (;;) {
    printf("{\"requestType\":\"input\",\"name\":\"%s\",\"type\":\"%s\"}\n",
           name, type ? type : "خيط_رمزي");
    fflush(stdout);
    if (!fgets(line, sizeof(line), stdin)) {
      g_input_error = 1;
      return exec_number(0);
    }
    const char *value = strstr(line, "\"value\"");
    value = value ? strchr(value + strlen("\"value\""), ':') : NULL;
    if (!value) {
      g_input_error = 1;
      return exec_number(0);
    }
    while (*++value == ' ' || *value == '\t' || *value == '\n' || *value == '\r') {}
    if (*value == '"') value++;
    char parsed[1024];
    size_t length = 0;
    while (*value && *value != '"' && *value != '\n' && *value != '\r' &&
           length + 1 < sizeof(parsed)) {
      parsed[length++] = *value++;
    }
    parsed[length] = '\0';
    if (input_matches_type(parsed, type)) return exec_value_from_text(parsed);
    input_type_error(name, type);
  }
}

static ExecValue exec_input_value(const char *name) {
  if (g_interactive_execution) return exec_interactive_input(name);
  if (!g_input_values_payload || !name) {
    g_input_error = 1;
    return exec_number(0);
  }
  char key[256];
  snprintf(key, sizeof(key), "\"%s\"", name);
  const char *p = strstr(g_input_values_payload, key);
  if (!p) {
    g_input_error = 1;
    return exec_number(0);
  }
  p = strchr(p + strlen(key), ':');
  if (!p) {
    g_input_error = 1;
    return exec_number(0);
  }
  while (*++p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') {}
  char value[256];
  if (*p != '"') {
    size_t length = 0;
    while (*p && *p != ',' && *p != '}' && length + 1 < sizeof(value)) {
      value[length++] = *p++;
    }
    while (length > 0 && (value[length - 1] == ' ' || value[length - 1] == '\t')) length--;
    value[length] = '\0';
  } else {
    p++;
    size_t length = 0;
    while (*p && *p != '"' && length + 1 < sizeof(value)) value[length++] = *p++;
    value[length] = '\0';
  }
  const char *type = input_type_for(name);
  if (!input_matches_type(value, type)) {
    input_type_error(name, type);
    g_input_error = 1;
    return exec_number(0);
  }
  return exec_value_from_text(value);
}

static ExecValue exec_number(double n) { return (ExecValue){0, n, NULL}; }
static ExecValue exec_bool(int b) { return (ExecValue){2, b ? 1.0 : 0.0, NULL}; }
static double exec_num(ExecValue v) { return v.kind == 2 ? (v.number != 0) : v.number; }
static ExecValue exec_lookup(ExecVar *vars, size_t count, const char *name) {
  for (size_t i = 0; i < count; i++) if (strcmp(vars[i].name, name) == 0) return vars[i].value;
  return exec_number(0);
}
static long long eval_ast_expr(const CAstNode *, ExecVar *, size_t);
static size_t literal_quote_width(const char *text, size_t len, size_t offset) {
  if (offset >= len) return 0;
  if (text[offset] == '"' || text[offset] == '\'') return 1;
  if (len - offset >= 3 &&
      (unsigned char)text[offset] == 0xE2 &&
      (unsigned char)text[offset + 1] == 0x80 &&
      ((unsigned char)text[offset + 2] == 0x98 ||
       (unsigned char)text[offset + 2] == 0x99)) return 3;
  return 0;
}
static char *exec_access_key(const char *name, const CAstNodeList *selectors, ExecVar *vars, size_t count) {
  size_t cap = 256, len = strlen(name); char *key = malloc(cap); strcpy(key, name);
  for (size_t i=0; i<selectors->count; i++) {
    const CAstNode *sel=selectors->items[i]; char part[96];
    if (sel->data.reference.name && strcmp(sel->data.reference.name,"[]")==0) snprintf(part,sizeof(part),"[%lld]",eval_ast_expr(sel->data.reference.selectors.items[0],vars,count));
    else snprintf(part,sizeof(part),".%s",sel->data.reference.name ? sel->data.reference.name : "");
    size_t plen=strlen(part); if(len+plen+1>cap){cap*=2;key=realloc(key,cap);} strcpy(key+len,part);len+=plen;
  }
  return key;
}

static ExecValue eval_ast_value(const CAstNode *e, ExecVar *vars, size_t count) {
  if (!e) return exec_number(0);
  if (e->kind == C_AST_LITERAL) {
    const char *raw = e->data.literal.value ? e->data.literal.value : "";
    if (e->data.literal.literal_kind == C_TOKEN_STRING || e->data.literal.literal_kind == C_TOKEN_CHARACTER) {
      size_t len = strlen(raw), begin = literal_quote_width(raw, len, 0);
      size_t trailing_quote = 0;
      if (len > begin) {
        if (len >= 3) trailing_quote = literal_quote_width(raw, len, len - 3);
        if (!trailing_quote) trailing_quote = literal_quote_width(raw, len, len - 1);
      }
      size_t end = len >= begin + trailing_quote ? len - trailing_quote : len;
      char *text = malloc(end - begin + 1); memcpy(text, raw + begin, end - begin); text[end - begin] = '\0';
      ExecValue v = {e->data.literal.literal_kind == C_TOKEN_CHARACTER ? 3 : 1, 0, text}; return v;
    }
    if (e->data.literal.literal_kind == C_TOKEN_BOOLEAN) return exec_bool(strcmp(raw, "صح") == 0);
    return exec_number(strtod(raw, NULL));
  }
  if (e->kind == C_AST_VARIABLE_REFERENCE && e->data.reference.name) { char *key=exec_access_key(e->data.reference.name,&e->data.reference.selectors,vars,count); ExecValue v=exec_lookup(vars,count,key); free(key); return v; }
  if (e->kind == C_AST_UNARY) {
    ExecValue v = eval_ast_value(e->data.unary.operand, vars, count);
    if (strcmp(e->data.unary.operator, "!") == 0) return exec_bool(!exec_num(v));
    return exec_number(strcmp(e->data.unary.operator, "-") == 0 ? -exec_num(v) : exec_num(v));
  }
  if (e->kind == C_AST_BINARY) {
    ExecValue l = eval_ast_value(e->data.binary.left, vars, count), r = eval_ast_value(e->data.binary.right, vars, count);
    const char *op = e->data.binary.operator ? e->data.binary.operator : "+";
    if (strcmp(op, "+") == 0 && (l.kind == 1 || l.kind == 3 || r.kind == 1 || r.kind == 3)) {
      char a[128], b[128]; snprintf(a, sizeof(a), "%s", l.text ? l.text : ""); snprintf(b, sizeof(b), "%s", r.text ? r.text : "");
      char *joined = malloc(strlen(a)+strlen(b)+1); strcpy(joined,a); strcat(joined,b); ExecValue v={1,0,joined}; return v;
    }
    double a=exec_num(l), b=exec_num(r);
    if (strcmp(op,"+")==0) return exec_number(a+b);
    if (strcmp(op,"-")==0) return exec_number(a-b);
    if (strcmp(op,"*")==0) return exec_number(a*b);
    if (strcmp(op,"/")==0) return exec_number(b!=0?a/b:0);
    if (strcmp(op,"^")==0) return exec_number(pow(a, b));
    if (strcmp(op,"%")==0 || strcmp(op,"\\")==0) return exec_number(b != 0 ? (strcmp(op, "%") == 0 ? fmod(a, b) : trunc(a / b)) : 0);
    if (strcmp(op,"==")==0) return exec_bool(l.kind==r.kind && (l.text ? strcmp(l.text,r.text)==0 : a==b));
    if (strcmp(op,"!=")==0) return exec_bool(!(l.kind==r.kind && (l.text ? strcmp(l.text,r.text)==0 : a==b)));
    if (strcmp(op,"<")==0) return exec_bool(a<b);
    if (strcmp(op,">")==0) return exec_bool(a>b);
    if (strcmp(op,"<=")==0) return exec_bool(a<=b);
    if (strcmp(op,">=")==0) return exec_bool(a>=b);
    if (strcmp(op,"&&")==0) return exec_bool(a!=0 && b!=0);
    if (strcmp(op,"||")==0) return exec_bool(a!=0 || b!=0);
  }
  return exec_number(0);
}
static long long eval_ast_expr(const CAstNode *e, ExecVar *vars, size_t count) { return (long long)exec_num(eval_ast_value(e, vars, count)); }
static void set_exec_var(ExecVar *vars, size_t *count, const char *name,
                         const char *type, ExecValue value) {
  for (size_t i=0;i<*count;i++) if (strcmp(vars[i].name,name)==0) {
    vars[i].value=value;
    if (type) vars[i].type=type;
    return;
  }
  if (*count<128) {
    vars[*count]=(ExecVar){protocol_strdup(name),type,value};
    (*count)++;
  }
}

static void execute_statements(ProtocolResponse *resp, const CAstNodeList *statements, ExecVar *vars, size_t *count);
static void execute_print(ProtocolResponse *resp, const CAstNode *s, ExecVar *vars, size_t count) {
  for (size_t j=0;j<s->data.print.values.count;j++) { ExecValue v=eval_ast_value(s->data.print.values.items[j],vars,count); char buf[256];
    if (v.text) snprintf(buf,sizeof(buf),"%s",v.text); else if (v.kind==2) snprintf(buf,sizeof(buf),"%s",v.number?"صح":"خطأ"); else if (fabs(v.number-round(v.number))<1e-9) snprintf(buf,sizeof(buf),"%.0f",v.number); else snprintf(buf,sizeof(buf),"%.15g",v.number); protocol_add_output(resp,buf);
  }
}
static void execute_statement(ProtocolResponse *resp,const CAstNode *s,ExecVar *vars,size_t *count) {
  if(!s)return;
  if(s->kind==C_AST_PROGRAM) execute_statements(resp,&s->data.program.statements,vars,count);
  else if(s->kind==C_AST_READ&&s->data.access.name) set_exec_var(vars,count,s->data.access.name,input_type_for(s->data.access.name),exec_input_value(s->data.access.name));
  else if(s->kind==C_AST_ASSIGNMENT&&s->data.assignment.name) { char *key=exec_access_key(s->data.assignment.name,&s->data.assignment.selectors,vars,*count); set_exec_var(vars,count,key,input_type_for(s->data.assignment.name),eval_ast_value(s->data.assignment.expression,vars,*count)); free(key); }
  else if(s->kind==C_AST_PRINT) execute_print(resp,s,vars,*count);
  else if(s->kind==C_AST_REPEAT){long long from=eval_ast_expr(s->data.repeat.from,vars,*count),to=eval_ast_expr(s->data.repeat.to,vars,*count),step=s->data.repeat.step?eval_ast_expr(s->data.repeat.step,vars,*count):1;if(!step)step=1;for(long long v=from;step>0?v<=to:v>=to;v+=step){set_exec_var(vars,count,s->data.repeat.variable,"صحيح",exec_number(v));execute_statements(resp,&s->data.repeat.body,vars,count);if((step>0&&v>to-step)||(step<0&&v<to-step))break;}}
  else if(s->kind==C_AST_WHILE){size_t guard=0;while(eval_ast_expr(s->data.loop.condition,vars,*count)&&guard++<100000)execute_statements(resp,&s->data.loop.body,vars,count);}
  else if(s->kind==C_AST_IF){const CAstNodeList *b=eval_ast_expr(s->data.conditional.condition,vars,*count)?&s->data.conditional.then_branch:&s->data.conditional.else_branch;execute_statements(resp,b,vars,count);}
}
static void execute_statements(ProtocolResponse *resp,const CAstNodeList *statements,ExecVar *vars,size_t *count){for(size_t i=0;i<statements->count && !g_input_error;i++)execute_statement(resp,statements->items[i],vars,count);}
void runtime_execute_ast(ProtocolResponse *resp,const CAstNode *root){if(!root||root->kind!=C_AST_PROGRAM)return;ExecVar vars[128];size_t count=0;g_input_program=root;for(size_t i=0;i<root->data.program.declarations.count;i++){CAstNode*d=root->data.program.declarations.items[i];if(d->kind==C_AST_CONSTANT_DECLARATION)set_exec_var(vars,&count,d->data.constant.name,literal_type(d->data.constant.value),eval_ast_value(d->data.constant.value,vars,count));else if(d->kind==C_AST_VARIABLE_DECLARATION)for(size_t n=0;n<d->data.variable.name_count;n++)set_exec_var(vars,&count,d->data.variable.names[n],d->data.variable.type ? d->data.variable.type->name : NULL,exec_number(0));}execute_statements(resp,&root->data.program.statements,vars,&count);g_input_program=NULL;}


void runtime_begin(const char *input_values_payload, int interactive) {
  g_input_values_payload = input_values_payload;
  g_interactive_execution = interactive;
  g_input_error = 0;
}

int runtime_had_error(void) { return g_input_error; }

void runtime_end(void) {
  g_interactive_execution = 0;
  g_input_values_payload = NULL;
  g_input_error = 0;
}
