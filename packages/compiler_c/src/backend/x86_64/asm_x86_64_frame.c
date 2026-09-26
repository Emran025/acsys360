#include "asm_x86_64_internal.h"

#include <stddef.h>

size_t c_asm_frame_size(const CSemanticResult *semantic)
{
  return ((semantic->count * 8U) + 15U) & ~15U;
}

size_t c_asm_read_count(const CAstNodeList *statements)
{
  size_t count = 0U;
  for (size_t i = 0; i < statements->count; i++)
    if (statements->items[i]->kind == C_AST_READ)
      count++;
  return count;
}

int c_asm_emit_prologue(char **text, size_t *length, size_t *capacity,
                        size_t frame_size, size_t read_count)
{
  return c_asm_append(text, length, capacity,
                      "section .text\n"
                      "main:\n"
                      "    push rbp\n"
                      "    mov rbp, rsp\n"
                      "    sub rsp, %zu\n",
                      (frame_size == 0 ? 16 : frame_size) + 32U +
                          read_count * 256U);
}

int c_asm_emit_epilogue(char **text, size_t *length, size_t *capacity)
{
  return c_asm_append(text, length, capacity,
                      "    xor eax, eax\n    leave\n    ret\n"
                      "section .note.GNU-stack noalloc noexec nowrite progbits\n");
}
