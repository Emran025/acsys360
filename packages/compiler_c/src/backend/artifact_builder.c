#include "artifact_builder.h"

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
#include <limits.h>
#endif

int artifact_path_is_within_root(const char *root_path, const char *candidate_path) {
#ifdef _WIN32
  char root[2048];
#else
  char root[4096];
#endif
  char candidate[2048];
  size_t root_length;
  if (!root_path || !candidate_path || root_path[0] == '\0' ||
      candidate_path[0] == '\0') return 0;
#ifdef _WIN32
  if (!_fullpath(root, root_path, sizeof(root)) ||
      !_fullpath(candidate, candidate_path, sizeof(candidate))) return 0;
  for (char *p = root; *p; p++) {
    if (*p == '/') *p = '\\';
  }
  for (char *p = candidate; *p; p++) {
    if (*p == '/') *p = '\\';
  }
  root_length = strlen(root);
  if (root_length > 0U &&
      (root[root_length - 1U] == '\\' || root[root_length - 1U] == '/')) {
    root[root_length - 1U] = '\0';
    root_length--;
  }
  for (size_t i = 0U; i < strlen(candidate); i++) {
    if (candidate[i] == '.' && candidate[i + 1U] == '.' &&
        (i == 0U || candidate[i - 1U] == '\\') &&
        (candidate[i + 2U] == '\0' || candidate[i + 2U] == '\\')) return 0;
  }
  if (_strnicmp(root, candidate, root_length) != 0) return 0;
#else
  if (realpath(root_path, root) == NULL) return 0;
  if (candidate_path[0] == '/') {
    if (strlen(candidate_path) >= sizeof(candidate)) return 0;
    strcpy(candidate, candidate_path);
  } else {
    if (getcwd(candidate, sizeof(candidate)) == NULL) return 0;
    if (strlen(candidate) + 1U + strlen(candidate_path) >= sizeof(candidate)) return 0;
    strcat(candidate, "/");
    strcat(candidate, candidate_path);
  }
  root_length = strlen(root);
  while (root_length > 1U && root[root_length - 1U] == '/') root[--root_length] = '\0';
  for (size_t i = 0U; candidate[i] != '\0'; i++) {
    if (candidate[i] == '.' && candidate[i + 1U] == '.' &&
        (i == 0U || candidate[i - 1U] == '/') &&
        (candidate[i + 2U] == '\0' || candidate[i + 2U] == '/')) return 0;
  }
  if (strncmp(root, candidate, root_length) != 0) return 0;
#endif
  return candidate[root_length] == '\0' || candidate[root_length] == '\\' ||
         candidate[root_length] == '/';
}

static int file_exists(const char *path) {
  FILE *file = fopen(path, "rb");
  if (file == NULL) return 0;
  fclose(file);
  return 1;
}

void artifact_ensure_directory(const char *path) {
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

static const char *tool_path(const char *tool) {
  const char *bundled_dir = getenv("ACSYS360_TOOLCHAIN_DIR");
#ifdef _WIN32
  static char bundled_paths[2][1024];
  static char paths[2][260];
  const size_t index = tool[0] == 'n' ? 0U : 1U;
  char *path = paths[index];
  if (bundled_dir && bundled_dir[0] != '\0') {
    snprintf(bundled_paths[index], sizeof(bundled_paths[index]), "%s\\%s.exe", bundled_dir, tool);
    if (file_exists(bundled_paths[index])) return bundled_paths[index];
  }
  const char *directories[] = {
    "C:\\msys64\\ucrt64\\bin",
    "C:\\msys64\\usr\\bin",
    "C:\\msys64\\mingw64\\bin"
  };
  for (size_t i = 0U; i < sizeof(directories) / sizeof(directories[0]); i++) {
    snprintf(path, sizeof(paths[0]), "%s\\%s.exe", directories[i], tool);
    if (file_exists(path)) return path;
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
static int run_process(const char *executable, char *const arguments[]) {
  pid_t child = fork();
  if (child < 0) return -1;
  if (child == 0) {
    /* tool_path() resolves an absolute executable; do not search PATH again. */
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

int artifact_build_native(const char *artifact_dir,
                                 const char *assembly_path,
                                 char *artifact_path,
                                 size_t artifact_path_size,
                                 char *error,
                                 size_t error_size) {
  char object_path[2048];
  const char *nasm = tool_path("nasm");
  const char *gcc = tool_path("gcc");
  if (!artifact_dir || !assembly_path || !artifact_path ||
      !error || artifact_path_size == 0U || error_size == 0U) return 0;
  if (!nasm || !gcc) {
    snprintf(error, error_size, "تعذر العثور على أدوات NASM وGCC في مسارات موثوقة");
    return 0;
  }
  snprintf(object_path, sizeof(object_path), "%s%carabicc.obj",
           artifact_dir,
#ifdef _WIN32
           '\\'
#else
           '/'
#endif
  );
  snprintf(artifact_path, artifact_path_size, "%s%carabicc_program_%lu%s",
           artifact_dir,
#ifdef _WIN32
           '\\',
           (unsigned long)_getpid(),
           ".exe"
#else
           '/',
           (unsigned long)getpid(),
           ""
#endif
  );
  artifact_ensure_directory(artifact_dir);
#ifdef _WIN32
  {
    const char *arguments[] = {
      nasm, "-f", "win64", assembly_path, "-o", object_path, NULL
    };
    if (_spawnv(_P_WAIT, nasm, arguments) != 0) {
      snprintf(error, error_size, "فشل تشغيل NASM لبناء الملف التنفيذي");
      return 0;
    }
  }
#else
  {
    char *arguments[] = {
      (char *)nasm, "-f", "elf64", (char *)assembly_path,
      "-o", object_path, NULL
    };
    if (run_process(nasm, arguments) != 0) {
      snprintf(error, error_size, "فشل تشغيل NASM لبناء الملف التنفيذي");
      return 0;
    }
  }
#endif
#ifdef _WIN32
  {
    const char *arguments[] = {
      gcc, object_path, "-o", artifact_path, NULL
    };
    const int exit_code = _spawnv(_P_WAIT, gcc, arguments);
    if (exit_code != 0) {
      snprintf(error, error_size,
               "فشل تشغيل GCC لربط الملف التنفيذي (exit=%d، object=%.*s)",
               exit_code, 150, object_path);
      return 0;
    }
  }
#endif
#ifndef _WIN32
  {
    char *arguments[] = {
      (char *)gcc, "-no-pie", object_path, "-o", artifact_path, NULL
    };
    if (run_process(gcc, arguments) != 0) {
      snprintf(error, error_size, "فشل تشغيل GCC لربط الملف التنفيذي");
      return 0;
    }
  }
#endif
  if (!file_exists(artifact_path)) {
    snprintf(error, error_size, "لم ينتج backend الملف التنفيذي المتوقع");
    return 0;
  }
  return 1;
}
