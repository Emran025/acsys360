#ifndef _WIN32
#ifdef __APPLE__
#define _DARWIN_C_SOURCE
#endif
#define _POSIX_C_SOURCE 200809L
#endif

#include "artifact_builder.h"
#include "toolchain.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef _WIN32
#include <sys/stat.h>
#include <unistd.h>
#else
#include <direct.h>
#include <windows.h>
#endif

int main(void) {
#ifdef _WIN32
  char temporary_directory[MAX_PATH];
  char unique_path[MAX_PATH];
  char root[MAX_PATH];
  char decoy[MAX_PATH];
  char gcc_path[MAX_PATH + 16];
  char nasm_path[MAX_PATH + 16];
  char path_environment[(MAX_PATH * 2) + 8];
  const DWORD temporary_length =
      GetTempPathA((DWORD)sizeof(temporary_directory), temporary_directory);
  if (temporary_length == 0 || temporary_length >= sizeof(temporary_directory) ||
      GetTempFileNameA(temporary_directory, "acx", 0, unique_path) == 0) {
    return 1;
  }
  if (_unlink(unique_path) != 0) return 1;
  const int root_length = snprintf(root, sizeof(root), "%s path", unique_path);
  const int decoy_length = snprintf(decoy, sizeof(decoy), "%s empty", unique_path);
  if (root_length <= 0 || (size_t)root_length >= sizeof(root) ||
      decoy_length <= 0 || (size_t)decoy_length >= sizeof(decoy) ||
      _mkdir(decoy) != 0 || _mkdir(root) != 0) {
    return 1;
  }
  const int gcc_path_length = snprintf(gcc_path, sizeof(gcc_path), "%s\\GCC.EXE", root);
  const int nasm_path_length = snprintf(nasm_path, sizeof(nasm_path), "%s\\NASM.EXE", root);
  const int path_length = snprintf(path_environment, sizeof(path_environment),
                                   "\"%s\";\"%s\"", decoy, root);
  if (gcc_path_length <= 0 || (size_t)gcc_path_length >= sizeof(gcc_path) ||
      nasm_path_length <= 0 || (size_t)nasm_path_length >= sizeof(nasm_path) ||
      path_length <= 0 || (size_t)path_length >= sizeof(path_environment)) {
    return 1;
  }
  FILE *gcc_file = fopen(gcc_path, "wb");
  FILE *nasm_file = fopen(nasm_path, "wb");
  if (!gcc_file || !nasm_file) {
    if (gcc_file) fclose(gcc_file);
    if (nasm_file) fclose(nasm_file);
    return 1;
  }
  fclose(gcc_file);
  fclose(nasm_file);

  if (_putenv_s("ACSYS360_TOOLCHAIN_DIR", "") != 0 ||
      _putenv_s("ACSYS360_TOOLCHAIN_ONLY", "") != 0 ||
      _putenv_s("Path", path_environment) != 0) {
    return 1;
  }
  const char *resolved_gcc = toolchain_path("gcc");
  const char *resolved_nasm = toolchain_path("nasm");
  const int path_lookup_passed = resolved_gcc && resolved_nasm &&
      _stricmp(resolved_gcc, gcc_path) == 0 &&
      _stricmp(resolved_nasm, nasm_path) == 0;

  _unlink(gcc_path);
  _unlink(nasm_path);
  _rmdir(root);
  _rmdir(decoy);
  if (!path_lookup_passed) {
    fprintf(stderr, "Windows toolchain PATH lookup failed: gcc=%s nasm=%s\n",
            resolved_gcc ? resolved_gcc : "<missing>",
            resolved_nasm ? resolved_nasm : "<missing>");
    return 1;
  }
  return 0;
#else
  char template[] = "/tmp/arabicc-security-XXXXXX";
  char *root = mkdtemp(template);
  if (!root) return 1;

  char outside[1024];
  char linked[1024];
  char traversal[1024];
  snprintf(outside, sizeof(outside), "%s-outside", root);
  snprintf(linked, sizeof(linked), "%s/linked", root);
  snprintf(traversal, sizeof(traversal), "%s/../%s-outside", root, strrchr(root, '/') + 1);

  if (mkdir(outside, 0700) != 0 || symlink(outside, linked) != 0) return 1;
  const int traversal_allowed = artifact_path_is_within_root(root, traversal);
  const int symlink_allowed = artifact_path_is_within_root(root, linked);
  char nested[1024];
  snprintf(nested, sizeof(nested), "%s/new-artifacts", root);
  const int nested_allowed = artifact_path_is_within_root(root, nested);

  unlink(linked);
  rmdir(outside);
  rmdir(root);

  if (traversal_allowed || symlink_allowed || !nested_allowed) {
    fprintf(stderr, "artifact containment check failed: traversal=%d symlink=%d nested=%d\n",
            traversal_allowed, symlink_allowed, nested_allowed);
    return 1;
  }
  return 0;
#endif
}
