#!/bin/bash

set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

force_update=0
for arg in "$@"; do
  case "$arg" in
    --force-update|-f)
      force_update=1
      ;;
    *)
      echo "Uso: $0 [--force-update|-f]" >&2
      exit 1
      ;;
  esac
done

log_dir="/var/log/lab-updates"
mkdir -p "$log_dir" 2>/dev/null || log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/lab-updates"
mkdir -p "$log_dir"

lock_file="$log_dir/update.lock"
active_log_file="$log_dir/active.log"
active_pid_file="$log_dir/active.pid"
latest_log_link="$log_dir/latest.log"

timestamp="$(date +%Y%m%d-%H%M%S)"
log_file="$log_dir/update-$timestamp.log"
touch "$log_file"
chmod 0644 "$log_file"

exec 9>"$lock_file"
if ! flock -n 9; then
  current_log=""
  if [ -r "$active_log_file" ]; then
    current_log="$(head -n 1 "$active_log_file" 2>/dev/null || true)"
  fi

  echo "Ya hay otra actualización en marcha."
  if [ -n "$current_log" ]; then
    echo "Registro activo: $current_log"
  fi
  exit 0
fi

printf '%s\n' "$log_file" > "$active_log_file"
printf '%s\n' "$$" > "$active_pid_file"
ln -sfn "$log_file" "$latest_log_link"
chmod 0644 "$active_log_file" "$active_pid_file"

exec > >(tee -a "$log_file") 2>&1

cleanup() {
  local code="$1"

  if [ -r "$active_pid_file" ] && [ "$(head -n 1 "$active_pid_file" 2>/dev/null || true)" = "$$" ]; then
    rm -f "$active_log_file" "$active_pid_file"
  fi

  if [ "$code" -ne 0 ]; then
    notify "Actualizacion fallida" "La actualizacion ha fallado (codigo $code)." error
  fi

  exit "$code"
}

desktop_user=""
desktop_uid=""
desktop_display=""

discover_desktop_session() {
  local session uid user state type remote class display

  while read -r session uid user _; do
    [ -n "$session" ] || continue

    state="$(loginctl show-session "$session" -p State --value 2>/dev/null || true)"
    type="$(loginctl show-session "$session" -p Type --value 2>/dev/null || true)"
    remote="$(loginctl show-session "$session" -p Remote --value 2>/dev/null || true)"
    class="$(loginctl show-session "$session" -p Class --value 2>/dev/null || true)"
    display="$(loginctl show-session "$session" -p Display --value 2>/dev/null || true)"

    [ "$state" = "active" ] || continue
    [ "$remote" = "no" ] || continue
    [ "$class" = "user" ] || continue

    case "$type" in
      x11|wayland)
        desktop_user="$user"
        desktop_uid="$uid"
        desktop_display="$display"
        return 0
        ;;
    esac
  done < <(loginctl list-sessions --no-legend 2>/dev/null || true)

  return 1
}

run_in_desktop_session() {
  if [ -z "$desktop_user" ] || [ -z "$desktop_uid" ]; then
    discover_desktop_session || return 1
  fi

  local -a env_vars=(
    "XDG_RUNTIME_DIR=/run/user/$desktop_uid"
    "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$desktop_uid/bus"
    "PATH=$PATH"
  )

  if [ -n "$desktop_display" ]; then
    env_vars+=("DISPLAY=$desktop_display")
  fi

  runuser -u "$desktop_user" -- env "${env_vars[@]}" "$@"
}

notify() {
  local title="$1"
  local message="$2"
  local mode="${3:-info}"
  local full_message urgency

  printf -v full_message '%s\n\nRegistro: %s' "$message" "$log_file"

  case "$mode" in
    error)
      urgency="critical"
      ;;
    *)
      urgency="normal"
      ;;
  esac

  if command -v notify-send >/dev/null 2>&1; then
    run_in_desktop_session \
      notify-send \
      --app-name="Actualizaciones del laboratorio" \
      --icon="system-software-update" \
      --urgency="$urgency" \
      -t 0 \
      "$title" \
      "$full_message" \
      && return 0
  fi

  printf '%s\n%s\n' "$title" "$full_message" >&2
}

trap 'cleanup "$?"' EXIT
trap 'exit 130' INT TERM

echo "Actualizando el sistema..."
echo "Guardando registro en: $log_file"

old_rev="$(git rev-parse HEAD)"
git pull --rebase --autostash
new_rev="$(git rev-parse HEAD)"

if [ "$old_rev" = "$new_rev" ] && [ "$force_update" -eq 0 ]; then
  echo "No hay cambios nuevos en el repositorio. Omitiendo nixos-rebuild."
  notify "Actualizacion completada" "No habia cambios nuevos. El sistema ya estaba actualizado."
  exit 0
fi

if [ "$force_update" -eq 1 ] && [ "$old_rev" = "$new_rev" ]; then
  echo "No hay cambios nuevos en el repositorio, pero se ha solicitado --force-update."
else
  echo "Hay cambios nuevos en el repositorio. Construyendo el sistema..."
fi

nixos-rebuild switch --flake path:.#nixos
notify "Actualizacion completada" "La actualizacion del sistema ha terminado correctamente. Reinicia el equipo cuando te venga bien."
