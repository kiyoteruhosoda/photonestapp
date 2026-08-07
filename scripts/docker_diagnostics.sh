#!/usr/bin/env bash
set -Eeuo pipefail

# Print Docker/Compose diagnostics using only command output.
# Intended to be called from deploy.sh error traps, for example:
#   scripts/docker_diagnostics.sh --project stg --compose-file compose.yml --since 30m

PROJECT_NAME=""
SINCE="30m"
TAIL="200"
COMPOSE_FILES=()
SERVICES=()

usage() {
  cat <<'USAGE'
Usage: scripts/docker_diagnostics.sh [options] [service...]

Options:
  -p, --project NAME        Docker Compose project name
  -f, --compose-file FILE   Compose file path; repeatable
      --since DURATION      Log window passed to docker logs/compose logs (default: 30m)
      --tail LINES          Log lines per service/container (default: 200)
  -h, --help                Show this help

Examples:
  scripts/docker_diagnostics.sh --project stg --since 15m
  scripts/docker_diagnostics.sh -f compose.yml api web mariadb
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)
      PROJECT_NAME="${2:?missing project name}"
      shift 2
      ;;
    -f|--compose-file)
      COMPOSE_FILES+=("${2:?missing compose file}")
      shift 2
      ;;
    --since)
      SINCE="${2:?missing since value}"
      shift 2
      ;;
    --tail)
      TAIL="${2:?missing tail value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      SERVICES+=("$@")
      break
      ;;
    *)
      SERVICES+=("$1")
      shift
      ;;
  esac
done

section() {
  printf '\n[idp:diagnostics] ===== %s =====\n' "$*"
}

run() {
  printf '[idp:diagnostics] $'
  printf ' %q' "$@"
  printf '\n'
  "$@" || printf '[idp:diagnostics][warn] command failed: %s\n' "$*"
}

compose_args() {
  local args=(compose)
  if [[ -n "$PROJECT_NAME" ]]; then
    args+=(--project-name "$PROJECT_NAME")
  fi
  for file in "${COMPOSE_FILES[@]}"; do
    args+=(--file "$file")
  done
  printf '%s\n' "${args[@]}"
}

compose() {
  local args=()
  mapfile -t args < <(compose_args)
  docker "${args[@]}" "$@"
}

project_container_ids() {
  if [[ ${#SERVICES[@]} -gt 0 ]]; then
    compose ps -q "${SERVICES[@]}" 2>/dev/null || true
    return
  fi

  if [[ -n "$PROJECT_NAME" ]]; then
    docker ps -a --filter "label=com.docker.compose.project=$PROJECT_NAME" --format '{{.ID}}' 2>/dev/null || true
    return
  fi

  compose ps -q 2>/dev/null || true
}

main() {
  section 'docker version'
  run docker version

  section 'docker compose version'
  run docker compose version

  section 'compose ps'
  run compose ps -a

  section 'compose logs'
  if [[ ${#SERVICES[@]} -gt 0 ]]; then
    run compose logs --no-color --timestamps --since "$SINCE" --tail "$TAIL" "${SERVICES[@]}"
  else
    run compose logs --no-color --timestamps --since "$SINCE" --tail "$TAIL"
  fi

  mapfile -t containers < <(project_container_ids)
  if [[ ${#containers[@]} -eq 0 ]]; then
    section 'container diagnostics'
    printf '[idp:diagnostics][warn] no compose containers found\n'
    return
  fi

  section 'container summary'
  run docker ps -a --no-trunc --filter "id=${containers[0]}"
  for container in "${containers[@]:1}"; do
    run docker ps -a --no-trunc --filter "id=$container"
  done

  for container in "${containers[@]}"; do
    section "inspect $container"
    run docker inspect \
      --format 'name={{.Name}} state={{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}} oom={{.State.OOMKilled}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} started={{.State.StartedAt}} finished={{.State.FinishedAt}} image={{.Config.Image}}' \
      "$container"

    section "health log $container"
    run docker inspect \
      --format '{{if .State.Health}}{{range .State.Health.Log}}{{printf "exit=%d started=%s ended=%s output=%q\n" .ExitCode .Start .End .Output}}{{else}}no health log{{end}}{{else}}no healthcheck{{end}}' \
      "$container"

    section "docker logs $container"
    run docker logs --timestamps --since "$SINCE" --tail "$TAIL" "$container"
  done

  section 'recent docker events'
  local until
  until="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  run docker events --since "$SINCE" --until "$until" \
    --filter type=container \
    --format '{{.Time}} {{.Type}} {{.Action}} {{.Actor.Attributes.name}} {{json .Actor.Attributes}}'
}

main
