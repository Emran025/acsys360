#include "toolchain.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#include <process.h>
#else
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

int toolchain_file_exists(const char *path) {
  FILE *file = fopen(path, "rb");
  if (file == NULL) return 0;
  fclose(file);
  return 1;
}

void toolchain_ensure_directory(const char *path) {
  char buffer[2048];
  size_t length;
  if (!path) return;
  length = strlen(path);
  if (length == 0 || length >= sizeof(buffer)) return;
  memcpy(buffer, path, length + 1U);
  for (size_t i = 1U; i < length; i++) {
    if (buffer[i] == '/' || buffer[i] == '\\') {
      char saved = buffer[i];
      buffer[i] = '\0';
#ifdef _WIN32
      (void)_mkdir(buffer);
#else
      (void)mkdir(buffer, 0775);
#endif
      buffer[i] = saved;
    }
  }
#ifdef _WIN32
  (void)_mkdir(buffer);
#else
  (void)mkdir(buffer, 0775);
#endif
}

const char *toolchain_path(const char *tool) {
  const char *bundled_dir = getenv("ACSYS360_TOOLCHAIN_DIR");
  const char *toolchain_only = getenv("ACSYS360_TOOLCHAIN_ONLY");
#ifdef _WIN32
  static char bundled_paths[2][1024];
  static char paths[2][260];
  const size_t index = tool[0] == 'n' ? 0U : 1U;
  char *path = paths[index];
  if (bundled_dir && bundled_dir[0] != '\0') {
    snprintf(bundled_paths[index], sizeof(bundled_paths[index]), "%s\\%s.exe", bundled_dir, tool);
    if (toolchain_file_exists(bundled_paths[index])) return bundled_paths[index];
  }
  if (toolchain_only && strcmp(toolchain_only, "1") == 0) return NULL;
  const char *directories[] = {
    "C:\\msys64\\ucrt64\\bin",
    "C:\\msys64\\usr\\bin",
    "C:\\msys64\\mingw64\\bin"
  };
  for (size_t i = 0U; i < sizeof(directories) / sizeof(directories[0]); i++) {
    snprintf(path, sizeof(paths[0]), "%s\\%s.exe", directories[i], tool);
    if (toolchain_file_exists(path)) return path;
  }
#else
  static char bundled_paths[2][1024];
  static char paths[2][512];
  const size_t index = tool[0] == 'n' ? 0U : 1U;
  char *path = paths[index];
  if (bundled_dir && bundled_dir[0] != '\0') {
    snprintf(bundled_paths[index], sizeof(bundled_paths[index]), "%s/%s", bundled_dir, tool);
    if (access(bundled_paths[index], X_OK) == 0) return bundled_paths[index];
  }
  if (toolchain_only && strcmp(toolchain_only, "1") == 0) return NULL;
  const char *directories[] = {
    "/usr/local/bin",
    "/usr/bin",
    "/bin",
    "/opt/homebrew/bin"
  };
  for (size_t i = 0U; i < sizeof(directories) / sizeof(directories[0]); i++) {
    snprintf(path, sizeof(paths[index]), "%s/%s", directories[i], tool);
    if (access(path, X_OK) == 0) return path;
  }
#endif
  return NULL;
}

#ifndef _WIN32
int toolchain_run_process(const char *executable, char *const arguments[]) {
  pid_t child = fork();
  if (child < 0) return -1;
  if (child == 0) {
    /* toolchain_path() resolves an absolute executable; do not search PATH again. */
    execv(executable, arguments);
    _exit(127);
  }
  int status;
  do {
    if (waitpid(child, &status, 0) < 0) return -1;
  } while (!WIFEXITED(status) && !WIFSIGNALED(status));
  return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}
#endif
