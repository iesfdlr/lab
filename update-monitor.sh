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

usage() {
  cat <<'EOF'
Uso: lab-update-monitor [--watch|--run|--run-or-watch|--has-active-update|--print-log-dir]

  --watch             Sigue la actualizacion en curso o el ultimo registro disponible.
  --run               Inicia una actualizacion con permisos de administrador y sigue su registro.
  --run-or-watch      Si hay una actualizacion activa, se engancha a ella; si no, inicia una.
  --has-active-update Sale con codigo 0 si hay una actualizacion activa.
  --print-log-dir     Muestra la carpeta de registros.
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
