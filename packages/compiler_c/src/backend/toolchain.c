#include "toolchain.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#include <io.h>
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

const char *toolchain_gcc_prefix(void) {
#ifdef _WIN32
  static char prefix[1024];
  const char *bundled_dir = getenv("ACSYS360_TOOLCHAIN_DIR");
  size_t length;
  if (!bundled_dir || bundled_dir[0] == '\0') return NULL;
  length = strlen(bundled_dir);
  if (length < 4U || length + 2U >= sizeof(prefix)) return NULL;
  memcpy(prefix, bundled_dir, length + 1U);
  while (length > 0U && (prefix[length - 1U] == '\\' || prefix[length - 1U] == '/')) {
    prefix[--length] = '\0';
  }
  /* ACSYS360_TOOLCHAIN_DIR points at .../toolchain/windows/bin. */
  while (length > 0U && prefix[length - 1U] != '\\' && prefix[length - 1U] != '/') {
    prefix[--length] = '\0';
  }
  if (length == 0U) return NULL;
  prefix[length] = '\0';
  return prefix;
#else
  return NULL;
#endif
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

int toolchain_run_process_capture(const char *executable,
                                  char *const arguments[],
                                  char *stderr_output,
                                  size_t stderr_output_size) {
  if (stderr_output && stderr_output_size > 0U) stderr_output[0] = '\0';
#ifdef _WIN32
  /* _spawnv does not expose stderr. Redirect only the inherited descriptor
     while the child runs, then restore it so the desktop app stays intact.
     The CRT's _spawnv already receives the executable separately; passing
     argv[0] again makes it a real child argument. NASM then interprets its
     own executable path as a second input file. Keep argv[0] for execv
     compatibility on Unix, but omit it from the Windows _spawnv call. */
  char *const *spawn_arguments = arguments;
  if (arguments && arguments[0] && executable &&
      strcmp(arguments[0], executable) == 0) {
    spawn_arguments = arguments + 1;
  }
  FILE *capture = tmpfile();
  if (!capture) {
    return _spawnv(_P_WAIT, executable, (const char *const *)spawn_arguments);
  }
  const int saved_stderr = _dup(_fileno(stderr));
  if (saved_stderr < 0 || _dup2(_fileno(capture), _fileno(stderr)) != 0) {
    if (saved_stderr >= 0) _close(saved_stderr);
    fclose(capture);
    return _spawnv(_P_WAIT, executable, (const char *const *)spawn_arguments);
  }
  const int exit_code = _spawnv(_P_WAIT, executable,
                                (const char *const *)spawn_arguments);
  fflush(stderr);
  (void)_dup2(saved_stderr, _fileno(stderr));
  _close(saved_stderr);
  if (stderr_output && stderr_output_size > 0U) {
    rewind(capture);
    (void)fread(stderr_output, 1U, stderr_output_size - 1U, capture);
    stderr_output[stderr_output_size - 1U] = '\0';
  }
  fclose(capture);
  return exit_code;
#else
  return toolchain_run_process(executable, arguments);
#endif
}
