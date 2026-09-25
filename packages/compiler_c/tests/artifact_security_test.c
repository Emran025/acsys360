#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L
#endif

#include "artifact_builder.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef _WIN32
#include <sys/stat.h>
#include <unistd.h>
#endif

int main(void) {
#ifdef _WIN32
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
