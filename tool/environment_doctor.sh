#!/usr/bin/env bash
set -u

EXPECTED_FLUTTER_VERSION="${EXPECTED_FLUTTER_VERSION:-3.44.5}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STRICT=0
DOCTOR=0

for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --doctor) DOCTOR=1 ;;
    -h|--help)
      cat <<'USAGE'
Usage: tool/environment_doctor.sh [--strict] [--doctor]

Print the local development tools, project pins, and Flutter desktop readiness.
--strict exits non-zero when Flutter is missing or its version differs from
         EXPECTED_FLUTTER_VERSION (default: 3.44.5).
--doctor runs `flutter doctor -v` when Flutter is available.
USAGE
      exit 0
      ;;
  esac
done

cd "$ROOT_DIR"

command_path() {
  command -v "$1" 2>/dev/null || printf '%s' 'missing'
}

version_line() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '%s' 'missing'
    return
  fi
  case "$command_name" in
    flutter) flutter --version 2>/dev/null | head -1 ;;
    dart) dart --version 2>&1 | head -1 ;;
    *) "$command_name" --version 2>&1 | head -1 ;;
  esac
}

printf '%s\n' 'acsys360 environment doctor'
printf 'Project: %s\n' "$ROOT_DIR"
printf 'Expected Flutter: %s\n\n' "$EXPECTED_FLUTTER_VERSION"

printf '%-12s %-45s %s\n' 'Tool' 'Path' 'Version'
printf '%-12s %-45s %s\n' '----' '----' '-------'
for tool in flutter dart git gh docker podman cmake ninja clang python3 node pnpm; do
  printf '%-12s %-45s %s\n' "$tool" "$(command_path "$tool")" "$(version_line "$tool")"
done

printf '\n%s\n' 'Project pins'
printf 'pubspec SDK: '
grep -E '^  sdk:' pubspec.yaml | head -1 || printf '%s\n' 'missing'
printf 'file_picker: '
grep -E '^  file_picker:' pubspec.yaml | head -1 || printf '%s\n' 'missing'
printf 'CI Flutter: '
grep -RhoE 'flutter-version: *[0-9]+\.[0-9]+\.[0-9]+' .github/workflows 2>/dev/null | sort -u || printf '%s\n' 'missing'
printf 'Dev Container Flutter: '
grep -RhoE '3\.[0-9]+\.[0-9]+' .devcontainer 2>/dev/null | sort -u || printf '%s\n' 'missing'

printf '\n%s\n' 'Desktop readiness'
for package in clang cmake ninja-build pkg-config libgtk-3-dev; do
  if command -v "$package" >/dev/null 2>&1 || dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
    printf '[ok]      %s\n' "$package"
  else
    printf '[missing] %s\n' "$package"
  fi
done

status=0
if ! command -v flutter >/dev/null 2>&1; then
  printf '\n[warning] Flutter is not on PATH. Run this script on the development machine or activate its SDK path.\n'
  status=1
else
  actual_flutter="$(flutter --version 2>/dev/null | head -1 | sed -n 's/.*Flutter \([0-9][0-9.]*\).*/\1/p')"
  if [[ "$actual_flutter" != "$EXPECTED_FLUTTER_VERSION" ]]; then
    printf '\n[warning] Found Flutter %s; expected %s.\n' "${actual_flutter:-unknown}" "$EXPECTED_FLUTTER_VERSION"
    status=1
  else
    printf '\n[ok] Flutter version matches %s.\n' "$EXPECTED_FLUTTER_VERSION"
  fi
fi

if (( DOCTOR )) && command -v flutter >/dev/null 2>&1; then
  printf '\n%s\n' 'flutter doctor -v'
  flutter doctor -v
fi

if (( STRICT && status != 0 )); then
  exit 1
fi
exit 0
