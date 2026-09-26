#include "asm_x86_64.h"
#include <inttypes.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#define ASM_FMT_REG "rcx"
#define ASM_VAL_REG "rdx"
#define ASM_SCAN_REG "rdx"
#define ASM_SCAN_FMT_REG "rcx"
#define ASM_FLUSH_REG "rcx"
#else
#define ASM_FMT_REG "rdi"
#define ASM_VAL_REG "rsi"
#define ASM_SCAN_REG "rsi"
#define ASM_SCAN_FMT_REG "rdi"
#define ASM_FLUSH_REG "rdi"
#endif

typedef struct { char **items; size_t count, capacity; } Strings;
static char *dup(const char *s){size_t n=strlen(s?s:"");char *p=malloc(n+1);if(p)memcpy(p,s?s:"",n+1);return p;}
static int append(char **text,size_t *len,size_t *cap,const char *fmt,...){va_list ap,copy;va_start(ap,fmt);va_copy(copy,ap);int n=vsnprintf(NULL,0,fmt,copy);va_end(copy);if(n<0){va_end(ap);return 0;}size_t need=*len+(size_t)n+1;if(need>*cap){size_t next=*cap?*cap:2048;while(next<need)next*=2;char *p=realloc(*text,next);if(!p){va_end(ap);return 0;}*text=p;*cap=next;}vsnprintf(*text+*len,*cap-*len,fmt,ap);va_end(ap);*len+=(size_t)n;return 1;}
static void diag(CAssemblyResult *r,const CTacInstruction *i,const char *fmt,...){char b[512];va_list ap;va_start(ap,fmt);vsnprintf(b,sizeof b,fmt,ap);va_end(ap);size_t n=r->diagnostic_count;r->diagnostics=realloc(r->diagnostics,(n+1)*sizeof(*r->diagnostics));r->diagnostic_offsets=realloc(r->diagnostic_offsets,(n+1)*sizeof(*r->diagnostic_offsets));r->diagnostic_lines=realloc(r->diagnostic_lines,(n+1)*sizeof(*r->diagnostic_lines));r->diagnostic_columns=realloc(r->diagnostic_columns,(n+1)*sizeof(*r->diagnostic_columns));r->diagnostic_lengths=realloc(r->diagnostic_lengths,(n+1)*sizeof(*r->diagnostic_lengths));r->diagnostics[n]=dup(b);r->diagnostic_offsets[n]=i?i->offset:0;r->diagnostic_lines[n]=i&&i->line?i->line:1;r->diagnostic_columns[n]=i&&i->column?i->column:1;r->diagnostic_lengths[n]=1;r->diagnostic_count++;}
static int slot(const CSemanticResult *s,const char *name){if(name&&name[0]=='$'&&name[1]=='t'&&name[2]>='0'&&name[2]<='9')return (int)((s->count+1+strtoul(name+2,NULL,10))*8);for(size_t i=0;i<s->count;i++)if(!strcmp(s->items[i].name,name))return (int)((i+1)*8);return 0;}
static const char *type_of(const CSemanticResult *s,const char *name,const char *hint){if(hint&&strcmp(hint,"غير معروف")&&strcmp(hint,""))return hint;for(size_t i=0;i<s->count;i++)if(!strcmp(s->items[i].name,name))return s->items[i].type;return NULL;}
static int quoted(const char *s){
  if (!s || !s[0]) return 0;
  const size_t n = strlen(s);
  if ((s[0]=='"' && n>1 && s[n-1]=='"') || (s[0]=='\'' && n>1 && s[n-1]=='\'')) return 1;
  return n >= 6 && (unsigned char)s[0] == 0xe2 && (unsigned char)s[1] == 0x80 &&
         (unsigned char)s[2] == 0x99 && (unsigned char)s[n-3] == 0xe2 &&
         (unsigned char)s[n-2] == 0x80 && (unsigned char)s[n-1] == 0x98;
}
static int add_string(Strings *ss,const char *v){if(!quoted(v))return 1;for(size_t i=0;i<ss->count;i++)if(!strcmp(ss->items[i],v))return 1;if(ss->count==ss->capacity){size_t c=ss->capacity?ss->capacity*2:8;char **p=realloc(ss->items,c*sizeof(*p));if(!p)return 0;ss->items=p;ss->capacity=c;}ss->items[ss->count++]=dup(v);return ss->items[ss->count-1]!=NULL;}
static int sindex(const Strings *ss,const char *v){for(size_t i=0;i<ss->count;i++)if(!strcmp(ss->items[i],v))return (int)i;return -1;}
static int real_lit(const char *s){if(!s||!s[0])return 0;int dot=0,digit=0;for(size_t i=0;s[i];i++){if(s[i]=='.')dot++;else if(s[i]>='0'&&s[i]<='9')digit=1;else return 0;}return dot==1&&digit;}
static int emit_value(char **text,size_t *len,size_t *cap,const CSemanticResult *sem,const Strings *strings,const char *value,const char *type){
  const char *t=type_of(sem,value,type); if(quoted(value)){int i=sindex(strings,value);return i>=0&&append(text,len,cap,"    lea rax, [rel text%d]\n",i);}
  if((t&&!strcmp(t,"حقيقي"))||real_lit(value)) { if(real_lit(value)) return append(text,len,cap,"    mov rax, __real@%s\n",value); }
  if(t&&!strcmp(t,"منطقي") && (!strcmp(value,"صح")||!strcmp(value,"خطأ"))) return append(text,len,cap,"    mov rax, %d\n",!strcmp(value,"صح"));
  if(value&&value[0]>='0'&&value[0]<='9') return append(text,len,cap,"    mov rax, %s\n",value);
  int off=slot(sem,value); return off&&append(text,len,cap,"    mov rax, [rbp-%d]\n",off);
}
static int emit_real(char **text,size_t *len,size_t *cap,const CSemanticResult *sem,const char *v,const char *type){
  if(real_lit(v)){ double value=strtod(v,NULL); uint64_t bits=0; memcpy(&bits,&value,sizeof bits); return append(text,len,cap,"    mov rax, 0x%" PRIx64 "\n    movq xmm0, rax\n",bits); }
  if(v && v[0]>='0'&&v[0]<='9') return append(text,len,cap,"    mov rax, %s\n    cvtsi2sd xmm0, rax\n",v);
  int off=slot(sem,v);
  if (!off) return 0;
  if (type && strcmp(type,"حقيقي") != 0)
    return append(text,len,cap,"    mov rax, [rbp-%d]\n    cvtsi2sd xmm0, rax\n",off);
  return append(text,len,cap,"    movsd xmm0, [rbp-%d]\n",off);
}
static int real_value(const CTacResult *t,const CSemanticResult *s,const char *v) {
  if (!v) return 0;
  if (real_lit(v)) return 1;
  for (size_t i=0;i<s->count;i++) if (!strcmp(s->items[i].name,v)) return s->items[i].type && !strcmp(s->items[i].type,"حقيقي");
  for (size_t i=0;i<t->count;i++) if (t->items[i].result && !strcmp(t->items[i].result,v)) return t->items[i].type && !strcmp(t->items[i].type,"حقيقي");
  return 0;
}
static int max_temp(const CTacResult *t){int max=-1;for(size_t i=0;i<t->count;i++)if(t->items[i].result&&t->items[i].result[0]=='$'&&t->items[i].result[1]=='t')max=max>(int)strtoul(t->items[i].result+2,NULL,10)?max:(int)strtoul(t->items[i].result+2,NULL,10);return max;}
static int emit_bytes(char **text,size_t *len,size_t *cap,const char *v) {
  if (!append(text,len,cap,"db ")) return 0;
  for (size_t i=0; v && v[i]; i++) if (!append(text,len,cap,"%s%u", i ? ", " : "", (unsigned char)v[i])) return 0;
  return append(text,len,cap,", 0\n");
}
static int emit_string(char **text,size_t *len,size_t *cap,const char *v){
 const unsigned char *p=(const unsigned char*)v; size_t n=strlen(v), end=n;
 if (n>=6 && p[0]==0xe2 && p[1]==0x80 && p[2]==0x99) { p+=3; end=n-3; }
 else if (*p=='"'||*p=='\'') { p++; end=n>0?n-1:0; }
 if(!append(text,len,cap,"    db ")) return 0;
 int first=1;
 while((size_t)(p-(const unsigned char*)v)<end){unsigned char c=*p++;if(c=='\\'&&*p){char e=*p++;if(e=='n')c='\n';else if(e=='t')c='\t';else c=(unsigned char)e;}if(!first&&!append(text,len,cap,", "))return 0;if(!append(text,len,cap,"%u",c))return 0;first=0;}return append(text,len,cap,", 0\n");}
int c_generate_nasm_x86_64(const CTacResult *tac,const CSemanticResult *semantic,CAssemblyResult *result){
 if(!tac||!semantic||!result) return 0;
 memset(result,0,sizeof(*result));Strings strings={0};size_t reads=0;for(size_t i=0;i<tac->count;i++){CTacInstruction *x=&tac->items[i];if(x->opcode==C_TAC_READ)reads++;if(x->opcode==C_TAC_PRINT||x->opcode==C_TAC_ASSIGN||x->opcode==C_TAC_BINARY||x->opcode==C_TAC_UNARY){if(!add_string(&strings,x->left)||!add_string(&strings,x->right))goto fail;}}
 size_t len=0,cap=0;int temps=max_temp(tac)+1;size_t frame=(semantic->count+(size_t)temps)*8; if(frame<16)frame=16;frame=(frame+15)&~15U;
 if(!append(&result->text,&len,&cap,"; generated by arabicc C from 3AC\ndefault rel\nglobal main\nextern printf\nextern scanf\nextern fflush\nsection .data\nfmt_int: db \"%%ld\", 10, 0\nfmt_real: db \"%%.15g\", 10, 0\nfmt_str: db \"%%s\", 10, 0\nfmt_bool_true: db \"صح\", 10, 0\nfmt_bool_false: db \"خطأ\", 10, 0\nfmt_read_int: db \"%%ld\", 0\nfmt_read_real: db \"%%lf\", 0\nfmt_read_bool: db \"%%d\", 0\nfmt_read_char: db \"%%255s\", 0\nfmt_read_str: db \"%%255s\", 0\n"))goto fail;
 for(size_t i=0;i<strings.count;i++){if(!append(&result->text,&len,&cap,"text%zu: ",i)||!emit_string(&result->text,&len,&cap,strings.items[i]))goto fail;}
 size_t request_count=0; for(size_t i=0;i<tac->count;i++) if(tac->items[i].opcode==C_TAC_READ) { const char *rt=type_of(semantic,tac->items[i].result,NULL); const char *rn=tac->items[i].result?tac->items[i].result:""; char request[1024]; snprintf(request,sizeof(request),"{\"requestType\":\"input\",\"name\":\"%s\",\"type\":\"%s\"}\n",rn,rt?rt:"غير معروف"); if(!append(&result->text,&len,&cap,"fmt_input_request%zu: ",request_count++)||!emit_bytes(&result->text,&len,&cap,request))goto fail; }
 if(!append(&result->text,&len,&cap,"section .text\nmain:\n    push rbp\n    mov rbp, rsp\n    sub rsp, %zu\n",frame+32+reads*256))goto fail;
 size_t read_index=0;int ok=1;
 for(size_t i=0;i<tac->count&&ok;i++){CTacInstruction *x=&tac->items[i];int dst=slot(semantic,x->result);const char *t=type_of(semantic,x->result,x->type);
  switch(x->opcode){
   case C_TAC_ALLOC: break;
   case C_TAC_LABEL: ok=append(&result->text,&len,&cap,"%s:\n",x->result);break;
   case C_TAC_JUMP: ok=append(&result->text,&len,&cap,"    jmp %s\n",x->result);break;
   case C_TAC_BRANCH: ok=emit_value(&result->text,&len,&cap,semantic,&strings,x->left,x->type)&&append(&result->text,&len,&cap,"    cmp rax, 0\n    je %s\n",x->result);break;
   case C_TAC_BINARY:
    if((x->type&&!strcmp(x->type,"حقيقي"))||real_value(tac,semantic,x->left)||real_value(tac,semantic,x->right)){ok=emit_real(&result->text,&len,&cap,semantic,x->left,real_value(tac,semantic,x->left)?"حقيقي":"صحيح")&&append(&result->text,&len,&cap,"    sub rsp, 8\n    movsd [rsp], xmm0\n")&&emit_real(&result->text,&len,&cap,semantic,x->right,real_value(tac,semantic,x->right)?"حقيقي":"صحيح")&&append(&result->text,&len,&cap,"    movsd xmm1, [rsp]\n    add rsp, 8\n");const char *op=x->operator;if(ok){if(!strcmp(op,"+"))ok=append(&result->text,&len,&cap,"    addsd xmm1, xmm0\n    movsd [rbp-%d], xmm1\n",dst);else if(!strcmp(op,"-"))ok=append(&result->text,&len,&cap,"    subsd xmm1, xmm0\n    movsd [rbp-%d], xmm1\n",dst);else if(!strcmp(op,"*"))ok=append(&result->text,&len,&cap,"    mulsd xmm1, xmm0\n    movsd [rbp-%d], xmm1\n",dst);else if(!strcmp(op,"/"))ok=append(&result->text,&len,&cap,"    divsd xmm1, xmm0\n    movsd [rbp-%d], xmm1\n",dst);else {const char *set=!strcmp(op,"==")?"sete":!strcmp(op,"!=")?"setne":!strcmp(op,"<")?"setb":!strcmp(op,"<=")?"setbe":!strcmp(op,">")?"seta":!strcmp(op,">=")?"setae":NULL;ok=set&&append(&result->text,&len,&cap,"    ucomisd xmm1, xmm0\n    %s al\n    movzx rax, al\n    mov [rbp-%d], rax\n",set,dst);}}}
    else {ok=emit_value(&result->text,&len,&cap,semantic,&strings,x->left,x->type)&&append(&result->text,&len,&cap,"    push rax\n")&&emit_value(&result->text,&len,&cap,semantic,&strings,x->right,x->type)&&append(&result->text,&len,&cap,"    mov rcx, rax\n    pop rax\n");if(ok){const char *op=x->operator;if(!strcmp(op,"+"))ok=append(&result->text,&len,&cap,"    add rax, rcx\n");else if(!strcmp(op,"-"))ok=append(&result->text,&len,&cap,"    sub rax, rcx\n");else if(!strcmp(op,"*"))ok=append(&result->text,&len,&cap,"    imul rax, rcx\n");else if(!strcmp(op,"/"))ok=append(&result->text,&len,&cap,"    cqo\n    idiv rcx\n");else if(!strcmp(op,"%"))ok=append(&result->text,&len,&cap,"    cqo\n    idiv rcx\n    mov rax, rdx\n");else if(!strcmp(op,"\\"))ok=append(&result->text,&len,&cap,"    cqo\n    idiv rcx\n");else if(!strcmp(op,"^"))ok=append(&result->text,&len,&cap,"    mov r8, rax\n    mov rax, 1\npow_loop_%zu:\n    test rcx, rcx\n    jz pow_done_%zu\n    imul rax, r8\n    dec rcx\n    jmp pow_loop_%zu\npow_done_%zu:\n",i,i,i,i);else if(!strcmp(op,"&&"))ok=append(&result->text,&len,&cap,"    and rax, rcx\n");else if(!strcmp(op,"||"))ok=append(&result->text,&len,&cap,"    or rax, rcx\n");else {const char *set=!strcmp(op,"==")?"sete":!strcmp(op,"!=")?"setne":!strcmp(op,"<")?"setl":!strcmp(op,"<=")?"setle":!strcmp(op,">")?"setg":!strcmp(op,">=")?"setge":NULL;ok=set&&append(&result->text,&len,&cap,"    cmp rax, rcx\n    %s al\n    movzx rax, al\n",set);}if(ok)ok=append(&result->text,&len,&cap,"    mov [rbp-%d], rax\n",dst);}}break;
   case C_TAC_UNARY: if(x->type&&!strcmp(x->type,"حقيقي")&&!strcmp(x->operator,"-")){ok=emit_real(&result->text,&len,&cap,semantic,x->left,"حقيقي")&&append(&result->text,&len,&cap,"    mov rax, 0x8000000000000000\n    movq xmm1, rax\n    xorpd xmm0, xmm1\n    movsd [rbp-%d], xmm0\n",dst);}else {ok=emit_value(&result->text,&len,&cap,semantic,&strings,x->left,x->type);if(ok&&!strcmp(x->operator,"-"))ok=append(&result->text,&len,&cap,"    neg rax\n");else if(ok&&!strcmp(x->operator,"!"))ok=append(&result->text,&len,&cap,"    cmp rax, 0\n    sete al\n    movzx rax, al\n");if(ok)ok=append(&result->text,&len,&cap,"    mov [rbp-%d], rax\n",dst);}break;
   case C_TAC_ASSIGN: {const char *target_type=type_of(semantic,x->result,NULL);if(target_type&&!strcmp(target_type,"حقيقي"))ok=emit_real(&result->text,&len,&cap,semantic,x->left,x->type)&&append(&result->text,&len,&cap,"    movsd [rbp-%d], xmm0\n",dst);else ok=emit_value(&result->text,&len,&cap,semantic,&strings,x->left,x->type)&&append(&result->text,&len,&cap,"    mov [rbp-%d], rax\n",dst);break;}
   case C_TAC_PRINT: {const char *pt=type_of(semantic,x->left,x->type);if(pt&&!strcmp(pt,"حقيقي"))ok=emit_real(&result->text,&len,&cap,semantic,x->left,pt)&&append(&result->text,&len,&cap,"    movq " ASM_VAL_REG ", xmm0\n    lea " ASM_FMT_REG ", [rel fmt_real]\n    mov eax, 1\n    call printf\n");else if(pt&&!strcmp(pt,"منطقي"))ok=emit_value(&result->text,&len,&cap,semantic,&strings,x->left,pt)&&append(&result->text,&len,&cap,"    cmp rax, 0\n    jne bool_true_%zu\n    lea " ASM_FMT_REG ", [rel fmt_bool_false]\n    xor eax, eax\n    call printf\n    jmp bool_done_%zu\nbool_true_%zu:\n    lea " ASM_FMT_REG ", [rel fmt_bool_true]\n    xor eax, eax\n    call printf\nbool_done_%zu:\n",i,i,i,i);else {const char *fmt=pt&&(!strcmp(pt,"خيط_رمزي")||!strcmp(pt,"حرفي"))?"fmt_str":"fmt_int";ok=emit_value(&result->text,&len,&cap,semantic,&strings,x->left,pt)&&append(&result->text,&len,&cap,"    mov " ASM_VAL_REG ", rax\n    lea " ASM_FMT_REG ", [rel %s]\n    xor eax, eax\n    call printf\n",fmt);}break;}
   case C_TAC_READ: {const char *rt=type_of(semantic,x->result,x->type);const char *fmt=rt&&!strcmp(rt,"حقيقي")?"fmt_read_real":rt&&!strcmp(rt,"منطقي")?"fmt_read_bool":rt&&!strcmp(rt,"خيط_رمزي")?"fmt_read_str":rt&&!strcmp(rt,"حرفي")?"fmt_read_char":"fmt_read_int";int target=slot(semantic,x->result);int text_input=rt&&(!strcmp(rt,"خيط_رمزي")||!strcmp(rt,"حرفي"));int input_slot=(int)(frame+32+read_index*256);ok=target&&append(&result->text,&len,&cap,"    lea " ASM_FMT_REG " , [rel fmt_input_request%zu]\n    xor eax, eax\n    call printf\n    xor " ASM_FLUSH_REG ", " ASM_FLUSH_REG "\n    call fflush\n    lea " ASM_SCAN_REG ", [rbp-%d]\n    lea " ASM_FMT_REG ", [rel %s]\n    xor eax, eax\n    call scanf\n",read_index,text_input?input_slot:target,fmt);if(ok&&text_input)ok=append(&result->text,&len,&cap,"    lea rax, [rbp-%d]\n    mov [rbp-%d], rax\n",input_slot,target);read_index++;break;}
   case C_TAC_PARAM: break;
   case C_TAC_CALL: diag(result,x,"تعليمة استدعاء الإجراء لا تملك ABI في NASM backend");ok=0;break;
   default: ok=0;break;
  }
 }
 if(!ok){if(!result->diagnostic_count)diag(result,NULL,"تعذر تحويل 3AC إلى NASM");goto finish;}
 append(&result->text,&len,&cap,"    xor eax, eax\n    leave\n    ret\nsection .note.GNU-stack noalloc noexec nowrite progbits\n");
 finish:for(size_t i=0;i<strings.count;i++)free(strings.items[i]);free(strings.items);return 1;
 fail:for(size_t i=0;i<strings.count;i++)free(strings.items[i]);free(strings.items);c_assembly_result_free(result);return 0;
}
void c_assembly_result_free(CAssemblyResult *r){if(!r)return;free(r->text);for(size_t i=0;i<r->diagnostic_count;i++)free(r->diagnostics[i]);free(r->diagnostics);free(r->diagnostic_offsets);free(r->diagnostic_lines);free(r->diagnostic_columns);free(r->diagnostic_lengths);memset(r,0,sizeof(*r));}
