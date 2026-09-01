#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

reference_ref=${1:-origin/main}
printf 'reference=%s\nbranch=%s\n' "$reference_ref" "$(git branch --show-current)"
printf 'merge_base=%s\n' "$(git merge-base HEAD "$reference_ref")"
printf '%s\n' '--- branch delta ---'
git diff --stat "$reference_ref...HEAD"
printf '%s\n' '--- C compiler tests ---'
rm -rf /tmp/acsys360-compiler-c-compare-build
cmake -S packages/compiler_c -B /tmp/acsys360-compiler-c-compare-build -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build /tmp/acsys360-compiler-c-compare-build --parallel >/dev/null
ctest --test-dir /tmp/acsys360-compiler-c-compare-build --output-on-failure
printf '%s\n' '--- reference Dart tests ---'
if command -v dart >/dev/null 2>&1; then
  (cd packages/compiler_core && dart run bin/self_test.dart)
else
  printf '%s\n' 'dart unavailable locally; CI must run compiler_core self-test'
fi
printf '%s\n' 'comparison_status=pass'
