#!/usr/bin/env bash
#
# Full quality gate. Every check that guards the codebase runs from here, so
# `./scripts/ci.sh` locally and CI enforce exactly the same rules.
#
# Exits non-zero as soon as any check fails, unless --keep-going is passed,
# in which case every check runs and the summary at the end lists what broke.
#
# Usage:
#   ./scripts/ci.sh                 # everything
#   ./scripts/ci.sh --fast          # skip the APK build (the slow step)
#   ./scripts/ci.sh --keep-going    # run all checks, report at the end
#   ./scripts/ci.sh --help
#
set -uo pipefail

cd "$(dirname "$0")/.."

FAST=0
KEEP_GOING=0

for arg in "$@"; do
  case "$arg" in
    --fast)       FAST=1 ;;
    --keep-going) KEEP_GOING=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's|^# \{0,1\}||'
      exit 0
      ;;
    *)
      echo "ci: unknown argument '$arg' (try --help)" >&2
      exit 2
      ;;
  esac
done

# ─── Output helpers ────────────────────────────────────────────────────────

if [ -t 1 ]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
else
  BOLD=''; RED=''; GREEN=''; DIM=''; OFF=''
fi

FAILED=()
STEP=0

# run <name> <command...>
#
# Runs a check, prints a banner, records the outcome. Honours --keep-going.
run() {
  local name="$1"; shift
  STEP=$((STEP + 1))
  printf '\n%s━━━ [%d] %s %s\n' "$BOLD" "$STEP" "$name" "$OFF"
  printf '%s$ %s%s\n' "$DIM" "$*" "$OFF"

  local status=0
  "$@" || status=$?

  if [ "$status" -eq 0 ]; then
    printf '%s✓ %s%s\n' "$GREEN" "$name" "$OFF"
    return 0
  fi

  printf '%s✗ %s (exit %d)%s\n' "$RED" "$name" "$status" "$OFF"
  FAILED+=("$name")
  if [ "$KEEP_GOING" -eq 0 ]; then
    summary
    exit "$status"
  fi
  return "$status"
}

summary() {
  printf '\n%s━━━ summary %s\n' "$BOLD" "$OFF"
  if [ ${#FAILED[@]} -eq 0 ]; then
    printf '%sAll checks passed.%s\n' "$GREEN" "$OFF"
    return 0
  fi
  printf '%sFailed checks:%s\n' "$RED" "$OFF"
  for name in "${FAILED[@]}"; do
    printf '  - %s\n' "$name"
  done
  return 1
}

# Returns 0 when the project uses build_runner code generation.
uses_code_generation() {
  [ -f build.yaml ] && return 0
  grep -rlqE "part +'.*\.(g|freezed)\.dart'" lib 2>/dev/null && return 0
  return 1
}

# ─── Checks ────────────────────────────────────────────────────────────────

command -v flutter >/dev/null 2>&1 || {
  echo "ci: flutter is not on PATH." >&2
  exit 2
}

printf '%sFlutter toolchain%s\n' "$BOLD" "$OFF"
flutter --version

run "pub get" flutter pub get

# Code generation, when the project uses it. Generated output is committed, so
# a dirty tree after regenerating means someone edited a source without
# re-running the generator.
if uses_code_generation; then
  run "build_runner" dart run build_runner build --delete-conflicting-outputs
  run "generated output is committed" git diff --exit-code
else
  printf '\n%s━━━ code generation %s\n' "$BOLD" "$OFF"
  printf '%sskipped — no build.yaml and no *.g.dart / *.freezed.dart parts%s\n' \
    "$DIM" "$OFF"
fi

run "format" dart format --output=none --set-exit-if-changed .

run "analyze" flutter analyze --fatal-infos --fatal-warnings

run "architecture" dart run tool/check_architecture.dart

run "dependencies" dart run tool/check_dependencies.dart

run "tests" flutter test --coverage

run "coverage thresholds" dart run tool/check_coverage.dart --verbose

if [ "$FAST" -eq 1 ]; then
  printf '\n%s━━━ apk build %s\n' "$BOLD" "$OFF"
  printf '%sskipped — --fast%s\n' "$DIM" "$OFF"
else
  run "apk build" flutter build apk --debug
fi

summary
