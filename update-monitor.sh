#!/bin/bash

set -euo pipefail

log_dir=""
active_log_file=""
active_pid_file=""
latest_log_link=""

init_paths() {
  if [ -d /var/log/lab-updates ]; then
    log_dir="/var/log/lab-updates"
  else
    log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/lab-updates"
  fi

  active_log_file="$log_dir/active.log"
  active_pid_file="$log_dir/active.pid"
  latest_log_link="$log_dir/latest.log"
}

is_pid_alive() {
  local pid="${1:-}"
  [ -n "$pid" ] && [ -d "/proc/$pid" ]
}

active_pid() {
  init_paths
  if [ -r "$active_pid_file" ]; then
    head -n 1 "$active_pid_file" 2>/dev/null || true
  fi
}

active_log() {
  init_paths
  local log=""

  if [ -r "$active_log_file" ]; then
    log="$(head -n 1 "$active_log_file" 2>/dev/null || true)"
    if [ -n "$log" ] && [ -e "$log" ]; then
      printf '%s\n' "$log"
      return 0
    fi
  fi

  return 1
}

latest_log() {
  init_paths
  local log=""

  if [ -L "$latest_log_link" ] && [ -e "$latest_log_link" ]; then
    log="$(readlink -f "$latest_log_link" 2>/dev/null || true)"
  fi

  if [ -z "$log" ] || [ ! -e "$log" ]; then
    log="$(ls -1t "$log_dir"/update-*.log 2>/dev/null | head -n 1 || true)"
  fi

  if [ -n "$log" ] && [ -e "$log" ]; then
    printf '%s\n' "$log"
    return 0
  fi

  return 1
}

has_active_update() {
  init_paths
  local pid

  pid="$(active_pid)"
  is_pid_alive "$pid"
}

watch_log() {
  local log=""
  local follow=0

  if has_active_update; then
    log="$(active_log || true)"
    follow=1
  fi

  if [ -z "$log" ]; then
    log="$(latest_log || true)"
  fi

  if [ -z "$log" ]; then
    echo "Todavia no hay registros de actualizaciones."
    exit 1
  fi

  if [ "$follow" -eq 1 ]; then
    echo "Siguiendo registro: $log"
    tail -n 200 -F "$log"
  else
    echo "Mostrando el ultimo registro: $log"
    tail -n 200 "$log"
  fi
}

start_update_and_watch() {
  if has_active_update; then
    watch_log
    return 0
  fi

  if ! command -v pkexec >/dev/null 2>&1; then
    echo "No se ha encontrado pkexec para iniciar la actualizacion." >&2
    exit 1
  fi

  echo "Solicitando permisos de administrador para iniciar la actualizacion..."

  # Run pkexec in the foreground so the user sees output directly from
  # update.sh (which tees to both stdout and its own log file).
  pkexec /etc/nixos/update.sh
}

list_branches() {
  local repo_dir="/etc/nixos"

  if [ ! -d "$repo_dir/.git" ]; then
    echo "No se ha encontrado el repositorio en $repo_dir." >&2
    return 1
  fi

  git -C "$repo_dir" fetch --all --prune >/dev/null 2>&1 || true
  git -C "$repo_dir" for-each-ref --format='%(refname:short)' refs/remotes/origin \
    | sed 's#^origin/##' \
    | grep -v '^HEAD$'
}

switch_branch() {
  local branch="$1"

  if [ -z "$branch" ]; then
    echo "Debes indicar el nombre de la rama." >&2
    exit 1
  fi

  if has_active_update; then
    echo "Ya hay una actualizacion en marcha; no se puede cambiar de rama ahora." >&2
    watch_log
    return 0
  fi

  if ! command -v pkexec >/dev/null 2>&1; then
    echo "No se ha encontrado pkexec para cambiar de rama." >&2
    exit 1
  fi

  echo "Solicitando permisos de administrador para cambiar a la rama '$branch'..."

  # Same pattern as start_update_and_watch: pkexec runs update.sh in the
  # foreground so its output streams straight to this terminal/log.
  pkexec /etc/nixos/update.sh --branch "$branch"
}

usage() {
  cat <<'EOF'
Uso: lab-update-monitor [--watch|--run|--run-or-watch|--has-active-update|--print-log-dir|--list-branches|--switch-branch NOMBRE]

  --watch             Sigue la actualizacion en curso o el ultimo registro disponible.
  --run               Inicia una actualizacion con permisos de administrador y sigue su registro.
  --run-or-watch      Si hay una actualizacion activa, se engancha a ella; si no, inicia una.
  --has-active-update Sale con codigo 0 si hay una actualizacion activa.
  --print-log-dir     Muestra la carpeta de registros.
  --list-branches     Lista las ramas disponibles en el repositorio remoto.
  --switch-branch     Cambia a la rama indicada con permisos de administrador.
EOF
}

main() {
  init_paths

  case "${1:---run-or-watch}" in
    --watch)
      watch_log
      ;;
    --run)
      start_update_and_watch
      ;;
    --run-or-watch)
      if has_active_update; then
        watch_log
      else
        start_update_and_watch
      fi
      ;;
    --has-active-update)
      has_active_update
      ;;
    --print-log-dir)
      printf '%s\n' "$log_dir"
      ;;
    --list-branches)
      list_branches
      ;;
    --switch-branch)
      switch_branch "${2:-}"
      ;;
    --help|-h)
      usage
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
