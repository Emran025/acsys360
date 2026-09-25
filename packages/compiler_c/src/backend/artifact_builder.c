#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L
#endif

#include "artifact_builder.h"
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
#include <limits.h>
extern char *realpath(const char *path, char *resolved_path);
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
  {
    char resolved_candidate[4096];
    if (realpath(candidate, resolved_candidate) != NULL) {
      strcpy(candidate, resolved_candidate);
    }
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

int artifact_build_native(const char *artifact_dir,
                                 const char *assembly_path,
                                 char *artifact_path,
                                 size_t artifact_path_size,
                                 char *error,
                                 size_t error_size) {
  char object_path[2048];
  const char *nasm = toolchain_path("nasm");
  const char *gcc = toolchain_path("gcc");
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
  toolchain_ensure_directory(artifact_dir);
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
    if (toolchain_run_process(nasm, arguments) != 0) {
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
    if (toolchain_run_process(gcc, arguments) != 0) {
      snprintf(error, error_size, "فشل تشغيل GCC لربط الملف التنفيذي");
      return 0;
    }
  }
#endif
  if (!toolchain_file_exists(artifact_path)) {
    snprintf(error, error_size, "لم ينتج backend الملف التنفيذي المتوقع");
    return 0;
  }
  return 1;
}
