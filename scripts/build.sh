#!/usr/bin/env bash
#
# Builds the distributable Android artifacts on the source side and writes
# them, with the metadata needed to identify them later, into an output
# directory (default: dist/).
#
# The output directory is the whole deliverable. Copying it to wherever the
# build is handed out from is all that is needed there — no repository, no
# Flutter SDK, no Android SDK.
#
# Usage:
#   ./scripts/build.sh                # APK + AAB, release, into dist/
#   ./scripts/build.sh apk            # APK only
#   ./scripts/build.sh aab out        # AAB only, into out/
#   ./scripts/build.sh --help
#
# Environment:
#   BUILD_MODE=release|debug   Build variant (default: release)
#   BUILD_NUMBER=<n>           Android versionCode (default: git commit count)
#
# Output (= the distribution bundle):
#   <base>-<version>-<variant>.apk   installable build
#   <base>-<version>-<variant>.aab   Play Store upload
#   manifest.env                     commit / branch / version / signing / files
#   manifest.sha256                  checksums, to detect a damaged transfer
#
# A release build is signed with android/key.properties when that file
# exists, and falls back to the debug keystore when it does not (see
# android/app/build.gradle). The fallback is fine for internal testing but
# must not be handed out — the manifest records which key was used.
#
# Prerequisites: flutter on PATH and a working Android SDK.
set -euo pipefail

log() { printf '[flutterbase] %s\n' "$*" >&2; }
die() { printf '[flutterbase][error] %s\n' "$*" >&2; exit 1; }

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# ─── Arguments ─────────────────────────────────────────────────────────────
# The target is picked from any argument position so that callers which pass
# extra words through (scripts/build-remote-container.sh) keep working.
targets=all
out_dir=dist

for arg in "$@"; do
  case "$arg" in
    -h | --help) sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    apk | aab | all) targets="$arg" ;;
    -*) die "unknown option: $arg (try --help)" ;;
    *) out_dir="$arg" ;;
  esac
done

variant="${BUILD_MODE:-release}"
case "$variant" in
  release | debug) ;;
  *) die "BUILD_MODE must be 'release' or 'debug': $variant" ;;
esac

command -v flutter >/dev/null 2>&1 || die "flutter is not on PATH."

# ─── Build identity ────────────────────────────────────────────────────────
git_commit="$(git rev-parse HEAD 2>/dev/null || printf unknown)"
git_commit_short="$(git rev-parse --short HEAD 2>/dev/null || printf unknown)"
git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf unknown)"
build_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Version name, without the +build suffix — Gradle receives the same value
# through local.properties and puts it in the artifact filename.
version="$(sed -n 's/^version: *//p' pubspec.yaml | sed 's/+.*//' | tr -d '[:space:]')"
[[ -n "$version" ]] || die "could not read 'version:' from pubspec.yaml."

build_number="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || printf 1)}"
[[ "$build_number" =~ ^[0-9]+$ ]] || die "BUILD_NUMBER must be a positive integer: $build_number"

# The artifact base name Gradle derives, so the expected filenames can be
# named exactly rather than globbed — a stale artifact from an earlier
# version left in build/ must never be picked up as this build's output.
# Keep in step with `appArchivesBase` in android/app/build.gradle.
archives_base="$(sed -n 's/^ *app\.archivesBaseName *= *//p' android/gradle.properties 2>/dev/null | tr -d '[:space:]')"
if [[ -z "$archives_base" ]]; then
  application_id="$(sed -n 's/^ *def appApplicationId *= *"\(.*\)".*/\1/p' android/app/build.gradle)"
  [[ -n "$application_id" ]] || die "could not read appApplicationId from android/app/build.gradle."
  archives_base="${application_id##*.}"
fi

# android/app/build.gradle decides on the storeFile property, not on the file
# existing: an empty or half-filled key.properties leaves `hasKeystore` false
# and the release build is signed with the debug key, without failing. Read
# the same property here, so the manifest cannot claim a release signature
# the build did not use.
keystore_store_file=''
if [[ -f android/key.properties ]]; then
  keystore_store_file="$(sed -n 's/^[[:space:]]*storeFile[[:space:]]*[=:][[:space:]]*//p' android/key.properties | head -1 | tr -d '[:space:]')"
fi

if [[ "$variant" == release && -n "$keystore_store_file" ]]; then
  signing="release-keystore"
else
  signing="debug-keystore"
fi

log "═══════════════════════════════════════════════"
log "  target      : $targets"
log "  variant     : $variant"
log "  version     : $version+$build_number"
log "  commit      : $git_commit_short ($git_branch)"
log "  signing     : $signing"
log "  output      : $out_dir"
log "═══════════════════════════════════════════════"

if [[ "$variant" == release && "$signing" == debug-keystore ]]; then
  if [[ -f android/key.properties ]]; then
    log "WARNING  android/key.properties has no storeFile, so Gradle signs this release"
  else
    log "WARNING  android/key.properties is missing, so Gradle signs this release"
  fi
  log "         build with the debug keystore. Usable for internal testing only."
fi

# ─── Build ─────────────────────────────────────────────────────────────────
# lib/shared/build_info.dart is generated but committed, so a build would
# otherwise leave the working tree dirty and break the next `git pull
# --ff-only` on a build host. Keep a copy of whatever is there — committed
# content or a developer's uncommitted edits, both of which the generator
# below overwrites — and put it back on the way out, including when the
# build fails.
build_info=lib/shared/build_info.dart
build_info_backup=''
restore_generated_build_info() {
  [[ -n "$build_info_backup" && -f "$build_info_backup" ]] || return 0
  mv -f "$build_info_backup" "$build_info"
  build_info_backup=''
}
if [[ -f "$build_info" ]]; then
  build_info_backup="$(mktemp)"
  cp -p "$build_info" "$build_info_backup"
  trap restore_generated_build_info EXIT
fi

# build/ is not cleaned between runs, so the paths this build is about to
# write are removed first. Otherwise an artifact left there by an earlier
# build of the same version could be picked up below and published under
# this build's manifest.
clear_artifact_paths() {
  local dir="$1" ext="$2"
  rm -f "$dir/${archives_base}-${version}-${variant}.${ext}" "$dir/app-${variant}.${ext}"
}

log "resolving dependencies ..."
flutter pub get

# The generator gets the same build number that Gradle and the manifest use,
# so the About screen cannot disagree with the artifact's versionCode.
log "generating build info ..."
BUILD_NUMBER="$build_number" bash scripts/generate_build_info.sh >/dev/null

if [[ "$targets" == all || "$targets" == apk ]]; then
  log "building APK ($variant) ..."
  clear_artifact_paths build/app/outputs/flutter-apk apk
  flutter build apk "--$variant" --build-number="$build_number"
fi

if [[ "$targets" == all || "$targets" == aab ]]; then
  log "building AAB ($variant) ..."
  clear_artifact_paths "build/app/outputs/bundle/${variant}" aab
  flutter build appbundle "--$variant" --build-number="$build_number"
fi

# ─── Distribution bundle ───────────────────────────────────────────────────
# Prefer the per-app named copy android/app/build.gradle writes next to
# Gradle's own output; fall back to that generic output when the copy is
# absent (a fork may have dropped it).
resolve_artifact() {
  local dir="$1" ext="$2"
  local named="$dir/${archives_base}-${version}-${variant}.${ext}"
  local generic="$dir/app-${variant}.${ext}"
  if [[ -f "$named" ]]; then printf '%s\n' "$named"; return 0; fi
  if [[ -f "$generic" ]]; then printf '%s\n' "$generic"; return 0; fi
  return 1
}

mkdir -p "$out_dir"
# Artifacts of an earlier build go first, so the directory always holds
# exactly what this run produced. It is copied wholesale to the machine that
# hands builds out, and an older APK sitting next to the new one there is
# indistinguishable from the real one — including when this run built only
# one of the two kinds.
rm -f "$out_dir"/*.apk "$out_dir"/*.aab
manifest="$out_dir/manifest.sha256"
: >"$manifest"

write_manifest_kv() {
  local key="$1" value="$2" quoted
  printf -v quoted '%q' "$value"
  printf '%s=%s\n' "$key" "$quoted"
}

{
  write_manifest_kv commit "$git_commit"
  write_manifest_kv branch "$git_branch"
  write_manifest_kv version "$version"
  write_manifest_kv build_number "$build_number"
  write_manifest_kv variant "$variant"
  write_manifest_kv signing "$signing"
  write_manifest_kv build_date "$build_date"
} >"$out_dir/manifest.env"

# publish_artifact <kind> <ext> <source dir>
publish_artifact() {
  local kind="$1" ext="$2" dir="$3" src name
  src="$(resolve_artifact "$dir" "$ext")" \
    || die "no ${ext} produced under ${dir} (expected ${archives_base}-${version}-${variant}.${ext})."
  name="$(basename "$src")"
  log "publishing: $src → $out_dir/$name"
  cp -f "$src" "$out_dir/$name"
  chmod 644 "$out_dir/$name"
  (cd "$out_dir" && sha256sum "$name") >>"$manifest"
  write_manifest_kv "${kind}_file" "$name" >>"$out_dir/manifest.env"
}

if [[ "$targets" == all || "$targets" == apk ]]; then
  publish_artifact apk apk build/app/outputs/flutter-apk
fi

if [[ "$targets" == all || "$targets" == aab ]]; then
  publish_artifact aab aab "build/app/outputs/bundle/${variant}"
fi

log "done. $out_dir/ holds the build and its manifest."
