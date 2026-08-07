#!/usr/bin/env bash
#
# scripts/build-remote-container.sh — one-host build for machines that have
# neither git nor a Flutter toolchain (a NAS, a file server, a release box).
#
# Source checkout and the build itself happen inside a dev container on the
# same host — the container is what holds git, the Flutter SDK and the
# Android SDK. The dist/ it produces is then picked up through the host-
# visible workspace path into the directory builds are handed out from.
#
# Five steps, one command:
#   SYNC    … git pull inside the dev container (latest source)
#   BUILD   … scripts/build.sh inside the dev container (produces dist/)
#   PICK    … copy the finished dist/ into a staging directory
#   VERIFY  … check the staged copy against manifest.sha256
#   PUBLISH … swap the verified build in, replacing the previous one
#
# The previous build stays downloadable until VERIFY passes: a copy that
# fails halfway, or a damaged build, leaves it in place rather than taking
# it out.
#
# Self-update: this script is a hand-placed bootstrap and is not part of
# dist/, so git pull never updates it. After SYNC it is compared byte for
# byte with the copy inside the dev container and, when they differ, replaces
# itself with the newer one and re-runs with the same arguments. This happens
# on every run, not just the first. The re-run goes through the interpreter
# that is already running, so it works whether or not the host copy carries
# the execute bit. It only works if the copy already on the host is a
# self-update-aware one; an older copy has to be replaced by hand once, after
# which it keeps itself current.
#
# Usage (on the build host; the target is read from any argument position,
# default all):
#   ./build-remote-container.sh            # APK + AAB
#   ./build-remote-container.sh apk
#   ./build-remote-container.sh aab
#
# Configuration comes from environment variables or from
# `build-remote-container.env` (below). **Do not edit the defaults in this
# file** — self-update replaces it wholesale, so edits are lost on the next
# run.
#   APP_PROJECT        Project name (default: taken from the directory, below)
#   APP_DEV_CONTAINER  Name of the dev container that runs the build
#   APP_DEV_USER       User to run the build as inside the container
#   APP_DEV_WORKDIR    Repository working dir inside the container
#                      (where scripts/build.sh lives)
#   APP_DIST_DIR       Absolute host-visible path of the built dist/ (required)
#   APP_ARTIFACT_DIR   Where builds are handed out from
#                      (default: the directory holding this script)
#   BUILD_MODE         Passed through to build.sh (release|debug)
#
# The assumed layout is **/<project>/<channel>** (for example
# /volume1/builds/flutterbase/internal), from which the project name is taken
# as the parent directory name. Precedence: APP_PROJECT > the config file's
# PROJECT > parent directory name > the default, flutterbase. Following that
# layout means PROJECT never has to be set.
#
# Configuration can also live in `build-remote-container.env` next to this
# script, as plain KEY=VALUE lines (no `export`, no commands). `{PROJECT}` in
# a value expands to the resolved project name:
#     APP_DEV_CONTAINER=ubuntu-dev
#     APP_DEV_WORKDIR=/work/project/{PROJECT}
#     APP_DIST_DIR=/volume1/homes/user/work/project/{PROJECT}/dist
#
# Prerequisites: docker on this host, and a running dev container.
set -euo pipefail

# ─── Configuration file (optional) ─────────────────────────────────────────
# <this script's directory>/build-remote-container.env, read as KEY=VALUE
# lines only (never sourced or eval'd). Variables already set in the
# environment win; the file only fills in the ones that are unset. Comment
# lines, blank lines and invalid keys are ignored; values are trimmed, as is
# a trailing ` # ...` comment (a `#` with no space before it stays part of
# the value).
_config_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build-remote-container.env"
_config_loaded_keys=()
if [[ -f "$_config_file" ]]; then
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    _line="${_line%$'\r'}"
    [[ "$_line" =~ ^[[:space:]]*# ]] && continue
    [[ "$_line" == *=* ]] || continue
    _key="${_line%%=*}"
    _val="${_line#*=}"
    _key="${_key//[[:space:]]/}"
    _val="${_val%%[[:space:]]#*}"
    _val="${_val#"${_val%%[![:space:]]*}"}"
    _val="${_val%"${_val##*[![:space:]]}"}"
    [[ "$_key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    if [[ -z "${!_key:-}" ]]; then
      export "$_key=$_val"
      _config_loaded_keys+=("$_key")
    fi
  done <"$_config_file"
fi

log() { printf '[flutterbase:container] %s\n' "$*" >&2; }
die() { printf '[flutterbase:container][error] %s\n' "$*" >&2; exit 1; }

# ─── Artifact directory and this script's own path ─────────────────────────
artifact_dir="${APP_ARTIFACT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# Resolve to an absolute, normalised path before taking the parent, so that a
# relative or unnormalised APP_ARTIFACT_DIR (`internal`, a trailing `/.`)
# still yields the right project name.
artifact_dir="$(cd "$artifact_dir" 2>/dev/null && pwd)" \
  || die "APP_ARTIFACT_DIR does not exist: ${APP_ARTIFACT_DIR:-(the directory holding this script)}"
# Fix this script's absolute path once, here, before any cd: self-update
# replaces the file at this path, and re-resolving a relative BASH_SOURCE[0]
# after cd would point somewhere else.
self_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# ─── Defaults (override through build-remote-container.env or the
#     environment — never by editing them here) ───────────────────────────
_project_from_dir="$(basename "$(dirname "$artifact_dir")")"
case "$_project_from_dir" in '' | '/' | '.' | '..') _project_from_dir='' ;; esac
project="${APP_PROJECT:-${PROJECT:-${_project_from_dir:-flutterbase}}}"
# Where the name came from, so the startup log answers "why this value".
if [[ -n "${APP_PROJECT:-}" ]]; then project_source="environment APP_PROJECT"
elif [[ -n "${PROJECT:-}" ]]; then project_source="config file PROJECT"
elif [[ -n "$_project_from_dir" ]]; then project_source="directory (parent of $artifact_dir)"
else project_source="default"
fi
dev_container="${APP_DEV_CONTAINER:-ubuntu-dev}"
dev_user="${APP_DEV_USER:-sshuser}"
dev_workdir="${APP_DEV_WORKDIR:-/work/project/$project}"
dist_dir="${APP_DIST_DIR:-}"
build_mode="${BUILD_MODE:-}"

# Expand {PROJECT} in paths. In the replacement half of ${var//pat/rep},
# bash 5.2 treats `&` (the whole match) and `\` specially, so both are
# escaped before the project name is substituted in.
_project_repl="${project//\\/\\\\}"
_project_repl="${_project_repl//&/\\&}"
dev_workdir="${dev_workdir//\{PROJECT\}/$_project_repl}"
dist_dir="${dist_dir//\{PROJECT\}/$_project_repl}"

# The build target is picked from any argument position, so extra leading
# words do no harm. Default: all.
target=all
for arg in "$@"; do
  case "$arg" in apk | aab | all) target="$arg" ;; esac
done

channel="$(basename "$artifact_dir")"

# ─── Startup banner (what is built, where, and how each value was resolved) ─
log "══════════════════════════════════════════════"
log "  channel    : $channel"
log "  target     : $target"
log "  project    : $project"
log "══════════════════════════════════════════════"
log "  arguments   : $([[ $# -gt 0 ]] && printf '%q ' "$@" || printf '(none → default %s)' "$target")"
if [[ -f "$_config_file" ]]; then
  if [[ ${#_config_loaded_keys[@]} -gt 0 ]]; then
    log "  config file : $_config_file (loaded: ${_config_loaded_keys[*]})"
  else
    log "  config file : $_config_file (nothing loaded — all set in the environment)"
  fi
else
  log "  config file : none ($_config_file absent; environment and defaults only)"
fi
log "  resolved:"
log "    PROJECT           = $project (source: $project_source)"
log "    APP_DEV_CONTAINER = $dev_container"
log "    APP_DEV_USER      = $dev_user"
log "    APP_DEV_WORKDIR   = $dev_workdir"
log "    APP_DIST_DIR      = ${dist_dir:-(unset)}"
log "    APP_ARTIFACT_DIR  = $artifact_dir (channel=$channel)"
log "    BUILD_MODE        = ${build_mode:-(unset → build.sh default, release)}"

command -v docker >/dev/null 2>&1 || die "docker not found."
[[ -n "$dist_dir" ]] || die "set APP_DIST_DIR (the host-visible absolute path of the built dist/)."
if [[ -n "$build_mode" && "$build_mode" != release && "$build_mode" != debug ]]; then
  die "BUILD_MODE must be 'release' or 'debug': $build_mode"
fi

cd "$artifact_dir"

# ─── SYNC (git pull only; the build comes after self-update) ───────────────
# Pulling before self-update is what makes the comparison below see the
# newest version of this script.
log "SYNC   git pull in dev container '$dev_container' ($dev_workdir) ..."
docker exec -u "$dev_user" "$dev_container" bash -lc "
  set -e
  cd '$dev_workdir'
  git pull --ff-only
" || die "git pull inside the dev container failed."

# ─── SELF-UPDATE (replace this script when the container has a newer one) ──
# APP_SELF_UPDATED bounds this to a single re-run, so a mismatch that somehow
# persists cannot loop. On the re-run the pull is a no-op and this block is
# skipped, so it goes straight to BUILD.
if [[ "${APP_SELF_UPDATED:-0}" != "1" ]]; then
  if _self_tmp="$(mktemp "$(dirname "$self_path")/.build-remote-container.XXXXXX" 2>/dev/null)"; then
    if docker exec -u "$dev_user" "$dev_container" \
      bash -lc "cat '$dev_workdir/scripts/build-remote-container.sh'" >"$_self_tmp" 2>/dev/null \
      && [[ -s "$_self_tmp" ]] && ! cmp -s "$_self_tmp" "$self_path"; then
      log "SELF-UPDATE  newer build-remote-container.sh found; replacing and re-running."
      # mktemp creates 0600, which would lock out other users and automation
      # accounts. Carry over the existing permissions instead — plus execute,
      # which a copy placed by hand over a file share usually lacks and which
      # carrying the mode over would otherwise perpetuate. Execute is granted
      # only where read already is, so a deliberately narrow mode stays narrow:
      # a bare `chmod +x` takes its classes from the umask, which would turn
      # 0640 into 0751 and hand execute to users who cannot read the file.
      _self_mode="$(stat -c '%a' "$self_path" 2>/dev/null \
        || stat -f '%Lp' "$self_path" 2>/dev/null || true)"
      if [[ "$_self_mode" =~ ^[0-7]{3,4}$ ]]; then
        # Everything above the last three digits is setuid/setgid/sticky and
        # is carried over untouched.
        _self_new_mode="${_self_mode%???}"
        for ((_i = ${#_self_mode} - 3; _i < ${#_self_mode}; _i++)); do
          _digit="${_self_mode:_i:1}"
          if ((_digit & 4)); then _digit=$((_digit | 1)); fi
          _self_new_mode+="$_digit"
        done
        chmod "$_self_new_mode" "$_self_tmp" 2>/dev/null || chmod 0755 "$_self_tmp"
      else
        # No usable stat: carry the mode over as is and add execute for the
        # owner only, the one class that can restore the rest with chmod.
        chmod --reference="$self_path" "$_self_tmp" 2>/dev/null || chmod 0755 "$_self_tmp"
        chmod u+x "$_self_tmp" 2>/dev/null || true
      fi
      # Same-directory rename, so the swap is atomic: the running process
      # keeps the old inode through its open fd, and the exec below opens the
      # new one by path.
      mv -f "$_self_tmp" "$self_path"
      export APP_SELF_UPDATED=1
      # Re-run through the interpreter that is already running rather than
      # executing the file. Executing it needs the execute bit and a mount
      # that allows execution; when either is missing the re-run dies with
      # "bad interpreter: Permission denied" (exit 126) and no build happens
      # — even though the same shell had just been running that very script.
      if [[ -n "${BASH:-}" && -x "${BASH}" ]]; then
        exec "$BASH" "$self_path" "$@"
      fi
      exec "$self_path" "$@"
    fi
    rm -f "$_self_tmp"
  else
    log "SELF-UPDATE  skipped — could not create a temp file (check write permission on $(dirname "$self_path"))."
  fi
fi

# ─── BUILD (inside the dev container; SYNC already pulled) ─────────────────
log "BUILD  scripts/build.sh $target in dev container '$dev_container' ..."
docker_env=()
if [[ -n "$build_mode" ]]; then
  docker_env=(-e "BUILD_MODE=$build_mode")
fi
# ${a[@]+"${a[@]}"} — an empty array is unset under `set -u` on bash < 4.4.
docker exec -u "$dev_user" ${docker_env[@]+"${docker_env[@]}"} "$dev_container" bash -lc "
  set -e
  cd '$dev_workdir'
  ./scripts/build.sh '$target'
" || die "the build inside the dev container failed."

# ─── PICK (bring the finished dist/ over, into a staging directory) ────────
# The copy lands beside the published artifacts rather than on top of them.
# A copy that fails halfway, or a build that turns out to be damaged, must
# not take out the previous build: until VERIFY passes, what people download
# is still the last one that was known good.
log "PICK   $dist_dir → $artifact_dir"
[[ -d "$dist_dir" ]] || die "dist not found: $dist_dir (check build.sh's output directory or APP_DIST_DIR)."
[[ -f "$dist_dir/manifest.sha256" ]] || die "no manifest.sha256 in $dist_dir — that directory is not a build.sh output."
staging="$(mktemp -d "$artifact_dir/.incoming.XXXXXX")" \
  || die "could not create a staging directory in $artifact_dir (check write permission)."
discard_staging() { [[ -n "${staging:-}" ]] && rm -rf "$staging"; }
trap discard_staging EXIT
cp -a "$dist_dir/." "$staging/" || die "copying the build out of $dist_dir failed."

# ─── VERIFY (the copy is what was built) ───────────────────────────────────
log "VERIFY checksums against manifest.sha256 ..."
(cd "$staging" && sha256sum -c manifest.sha256) \
  || die "checksum mismatch — the copied build differs from the one that was built (the published artifacts are untouched)."

# ─── PUBLISH (swap the verified build in) ──────────────────────────────────
# Previous artifacts go first: the incoming build holds exactly what was just
# built, and an older APK left beside it is indistinguishable from the real
# one. What remains is always what manifest.sha256 lists. Renames within the
# same directory keep the window in which neither build is complete down to
# a few filesystem operations.
log "PUBLISH swapping the verified build into $artifact_dir ..."
rm -f "$artifact_dir"/*.apk "$artifact_dir"/*.aab
for _staged in "$staging"/*; do
  mv -f "$_staged" "$artifact_dir/" || die "could not publish $(basename "$_staged") into $artifact_dir."
done

log "END    channel=$channel target=$target (done)"
log "       artifacts in $artifact_dir:"
shopt -s nullglob
for _artifact in "$artifact_dir"/*.apk "$artifact_dir"/*.aab; do
  log "         $(basename "$_artifact")"
done
shopt -u nullglob
