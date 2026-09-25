#ifndef ARABICC_TOOLCHAIN_H
#define ARABICC_TOOLCHAIN_H

int toolchain_file_exists(const char *path);
void toolchain_ensure_directory(const char *path);
const char *toolchain_path(const char *tool);
#ifndef _WIN32
int toolchain_run_process(const char *executable, char *const arguments[]);
#endif

#endif
