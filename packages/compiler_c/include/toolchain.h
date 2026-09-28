#ifndef ARABICC_TOOLCHAIN_H
#define ARABICC_TOOLCHAIN_H

#include <stddef.h>

int toolchain_file_exists(const char *path);
void toolchain_ensure_directory(const char *path);
const char *toolchain_path(const char *tool);
const char *toolchain_gcc_prefix(void);
int toolchain_run_process_capture(const char *executable,
                                  char *const arguments[],
                                  char *stderr_output,
                                  size_t stderr_output_size);
#ifndef _WIN32
int toolchain_run_process(const char *executable, char *const arguments[]);
#endif

#endif
