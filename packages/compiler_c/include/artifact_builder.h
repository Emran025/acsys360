#ifndef ARABICC_ARTIFACT_BUILDER_H
#define ARABICC_ARTIFACT_BUILDER_H

#include <stddef.h>

int artifact_path_is_within_root(const char *root_path, const char *candidate_path);
void artifact_ensure_directory(const char *path);
int artifact_build_native(const char *artifact_dir,
                          const char *assembly_path,
                          char *artifact_path,
                          size_t artifact_path_size,
                          char *error,
                          size_t error_size);

#endif
