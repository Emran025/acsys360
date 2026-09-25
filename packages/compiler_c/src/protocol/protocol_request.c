#include "protocol_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  const char *keyword;
  const char *title;
  const char *syntax;
  const char *description;
  const char *completion_insert;
  const char *kind;
  const char *detail;
} KeywordDoc;

static const KeywordDoc g_catalog[] = {
  { "برنامج", "تصريح البرنامج الرئيسي", "برنامج <الاسم>؛ {\n  <التعليمات>\n}.", "نقطة انطلاق البرنامج العربي، ويحتوي على قسم التصريحات وقسم التعليمات.", "برنامج رئيسي؛ {\n  \n}.", "keyword", "هيكل البرنامج" },
  { "متغير", "تصريح عن متغير", "متغير <الاسم>: <النوع>؛", "تعريف متغير جديد مع نوع بياناته (صحيح، حقيقي، خيط_رمزي، منطقي، حرفي).", "متغير س: صحيح؛", "keyword", "تصريح متغير" },
  { "ثابت", "تصريح عن قيمة ثابتة", "ثابت <الاسم> = <القيمة>؛", "تعريف ثابت لا يمكن تعديل قيمته أثناء التنفيذ.", "ثابت ط = 3.14؛", "keyword", "تصريح ثابت" },
  { "نوع", "تعريف نوع مخصص", "نوع <الاسم> = سجل { ... }؛", "تعريف نوع بيانات جديد مركب مثل السجلات أو القوائم.", "نوع نقطة = سجل {\n  متغير س: صحيح؛\n  متغير ص: صحيح؛\n}؛", "keyword", "تعريف نوع" },
  { "اجراء", "تعريف إجراء فرعي", "اجراء <الاسم>(<المعاملات>) {\n  <التعليمات>\n}", "كتلة من التعليمات المنظمة يمكن استدعاؤها لتنفيذ مهمة محددة.", "اجراء ترحيب() {\n  اطبع(\"مرحباً\")؛\n}", "keyword", "إجراء فرعي" },
  { "اطبع", "دالة الطباعة", "اطبع(<تعبير_أو_نص>)؛", "طباعة المخرجات والنصوص والمتغيرات إلى نافذة المخرجات.", "اطبع(\"\")؛", "function", "دالة طباعة" },
  { "اقرا", "دالة القراءة", "اقرا(<المتغير>)؛", "قراءة مدخلات المستخدم وتخزينها في المتغير المحدد.", "اقرا(س)؛", "function", "دالة قراءة" },
  { "اذا", "جملة شرطية", "اذا (<شرط>) فان {\n  <تعليمات>\n} والا {\n  <تعليمات_بديلة>\n}", "تنفيذ فرع من التعليمات عند تحقق شرط منطقي، مع إمكانية تحديد فرع بديل.", "اذا () فان {\n  \n}", "keyword", "تحكم شرطي" },
  { "طالما", "حلقة تكرار شرطية", "طالما (<شرط>) استمر {\n  <التعليمات>\n}", "تكرار تنفيذ مجموعة من التعليمات طالما بقي الشرط محققاً.", "طالما () استمر {\n  \n}", "keyword", "حلقة تكرار" },
  { "كرر", "حلقة تكرار بعداد", "كرر <متغير> من <بداية> الى <نهاية> اضف <خطوة> {\n  <التعليمات>\n} اعد؛", "تكرار تنفيذ التعليمات لعدد محدد من المرات باستخدام متغير عداد.", "كرر س من 1 الى 10 {\n  \n} اعد؛", "keyword", "حلقة بعداد" },
  { "صحيح", "نوع الأعداد الصحيحة", "متغير س: صحيح؛", "يمثل أعداداً صحيحة 64-bit موجبة أو سالبة بدون فاصلة عشرية.", "صحيح", "type", "نوع بيانات" },
  { "حقيقي", "نوع الأعداد العشرية", "متغير ص: حقيقي؛", "يمثل أعداداً بفاصلة عائمة (عشرية).", "حقيقي", "type", "نوع بيانات" },
  { "خيط_رمزي", "نوع السلاسل النصية", "متغير ن: خيط_رمزي؛", "يمثل نصوصاً وسلاسل رمزية بين علامتي اقتباس.", "خيط_رمزي", "type", "نوع بيانات" },
  { "منطقي", "نوع القيم المنطقية", "متغير ب: منطقي؛", "يمثل إحدى القيمتين المنطقيتين: صح أو خطأ.", "منطقي", "type", "نوع بيانات" },
  { "حرفي", "نوع الحروف", "متغير ح: حرفي؛", "يمثل حرفاً واحداً فقط.", "حرفي", "type", "نوع بيانات" },
  { "قائمة", "نوع القوائم والمصفوفات", "نوع جدول = قائمة [10] من صحيح؛", "يمثل مصفوفة من عناصر متتالية من نفس النوع.", "قائمة [10] من صحيح", "type", "مصفوفة" },
  { "سجل", "نوع السجلات (Structures)", "سجل {\n  متغير حقل: نوع؛\n}", "تجميعة من الحقول المتنوعة تمثل كياناً واحداً.", "سجل {\n  \n}", "type", "سجل بيانات" },
  { "صح", "قيمة منطقية موجبة", "صح", "القيمة المنطقية true.", "صح", "constant", "قيمة منطقية" },
  { "خطأ", "قيمة منطقية سالبة", "خطأ", "القيمة المنطقية false.", "خطأ", "constant", "قيمة منطقية" }
};
static const size_t g_catalog_count = sizeof(g_catalog) / sizeof(g_catalog[0]);

int protocol_handle_assist(const char *payload) {
  int is_help = (strstr(payload, "\"action\":\"help\"") != NULL);
  char *source_text = protocol_extract_string_value(payload, "\"sourceText\"");
  int offset = 0;
  const char *p_off = strstr(payload, "\"offset\":");
  if (p_off) {
    p_off += 9;
    offset = atoi(p_off);
  }

  char word[128] = "";
  size_t replace_start = (size_t)offset;
  size_t replace_length = 0;

  if (source_text && source_text[0] != '\0') {
    size_t byte_idx = 0;
    size_t char_count = 0;
    size_t slen = strlen(source_text);
    while (byte_idx < slen && char_count < (size_t)offset) {
      if (((unsigned char)source_text[byte_idx] & 0xC0) != 0x80) {
        char_count++;
      }
      byte_idx++;
    }

    size_t start_byte = byte_idx;
    while (start_byte > 0) {
      unsigned char prev = (unsigned char)source_text[start_byte - 1];
      if (prev == ' ' || prev == '\t' || prev == '\n' || prev == '\r' ||
          prev == '(' || prev == ')' || prev == '{' || prev == '}' ||
          prev == ';' || prev == ',' || prev == ':' || prev == '"' ||
          prev == '\'' || (prev == 0xD8 && start_byte >= 2 && (unsigned char)source_text[start_byte - 2] == ';')) {
        break;
      }
      start_byte--;
    }

    size_t end_byte = byte_idx;
    while (end_byte < slen) {
      unsigned char next = (unsigned char)source_text[end_byte];
      if (next == ' ' || next == '\t' || next == '\n' || next == '\r' ||
          next == '(' || next == ')' || next == '{' || next == '}' ||
          next == ';' || next == ',' || next == ':' || next == '"' ||
          next == '\'') {
        break;
      }
      end_byte++;
    }

    size_t wlen = end_byte - start_byte;
    if (wlen > 0 && wlen < sizeof(word)) {
      memcpy(word, source_text + start_byte, wlen);
      word[wlen] = '\0';
    }

    size_t start_char = 0;
    for (size_t i = 0; i < start_byte; i++) {
      if (((unsigned char)source_text[i] & 0xC0) != 0x80) start_char++;
    }
    size_t word_chars = 0;
    for (size_t i = start_byte; i < end_byte; i++) {
      if (((unsigned char)source_text[i] & 0xC0) != 0x80) word_chars++;
    }
    replace_start = start_char;
    replace_length = word_chars;
  }

  JsonBuffer b;
  json_buf_init(&b);
  json_buf_append(&b, "{\"protocolVersion\":\"" ARABICC_PROTOCOL_VERSION "\",\"success\":true,\"requestType\":\"assist\",\"action\":");
  json_buf_append(&b, is_help ? "\"help\"" : "\"completion\"");
  json_buf_append(&b, ",\"expected\":\"\",\"prefix\":");
  json_buf_append_escaped(&b, word);
  json_buf_append(&b, ",\"replaceStart\":");
  char num[32];
  snprintf(num, sizeof(num), "%zu", replace_start);
  json_buf_append(&b, num);
  json_buf_append(&b, ",\"replaceLength\":");
  snprintf(num, sizeof(num), "%zu", replace_length);
  json_buf_append(&b, num);

  if (is_help) {
    json_buf_append(&b, ",\"items\":[]");
    const KeywordDoc *match = NULL;
    if (word[0] != '\0') {
      for (size_t i = 0; i < g_catalog_count; i++) {
        if (strcmp(g_catalog[i].keyword, word) == 0) {
          match = &g_catalog[i];
          break;
        }
      }
      if (!match) {
        for (size_t i = 0; i < g_catalog_count; i++) {
          if (strstr(g_catalog[i].keyword, word) != NULL || strstr(word, g_catalog[i].keyword) != NULL) {
            match = &g_catalog[i];
            break;
          }
        }
      }
    }
    if (!match) {
      match = &g_catalog[0];
    }
    json_buf_append(&b, ",\"help\":{\"keyword\":");
    json_buf_append_escaped(&b, match->keyword);
    json_buf_append(&b, ",\"title\":");
    json_buf_append_escaped(&b, match->title);
    json_buf_append(&b, ",\"description\":");
    json_buf_append_escaped(&b, match->description);
    json_buf_append(&b, ",\"syntax\":");
    json_buf_append_escaped(&b, match->syntax);
    json_buf_append(&b, "}}");
  } else {
    json_buf_append(&b, ",\"help\":null,\"items\":[");
    size_t matched_count = 0;
    for (size_t i = 0; i < g_catalog_count; i++) {
      int include = (word[0] == '\0') || (strncmp(g_catalog[i].keyword, word, strlen(word)) == 0);
      if (include) {
        if (matched_count > 0) json_buf_append_char(&b, ',');
        json_buf_append(&b, "{\"label\":");
        json_buf_append_escaped(&b, g_catalog[i].keyword);
        json_buf_append(&b, ",\"insertText\":");
        json_buf_append_escaped(&b, g_catalog[i].completion_insert);
        json_buf_append(&b, ",\"kind\":");
        json_buf_append_escaped(&b, g_catalog[i].kind);
        json_buf_append(&b, ",\"detail\":");
        json_buf_append_escaped(&b, g_catalog[i].detail);
        json_buf_append_char(&b, '}');
        matched_count++;
      }
    }
    json_buf_append(&b, "]}");
  }

  json_buf_append(&b, "\n");
  fputs(b.data, stdout);
  free(b.data);
  if (source_text) free(source_text);
  return 0;
}

int protocol_request_executes(const char *payload) {
  const char *p = payload ? strstr(payload, "\"execute\"") : NULL;
  if (!p) return 1;
  p = strchr(p + strlen("\"execute\""), ':');
  if (!p) return 1;
  while (*++p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') {}
  return strncmp(p, "false", 5) != 0;
}

int protocol_request_interactive(const char *payload) {
  const char *p = payload ? strstr(payload, "\"interactive\"") : NULL;
  if (!p) return 0;
  p = strchr(p + strlen("\"interactive\""), ':');
  if (!p) return 0;
  while (*++p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') {}
  return strncmp(p, "true", 4) == 0;
}
