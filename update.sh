#!/bin/bash

set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# When running from a systemd timer/cron, set display variables
# so that kdialog/notify-send can reach the X11 session.
if [ -z "${DISPLAY:-}" ]; then
  export DISPLAY=":0"
  dbus_addr="$(systemctl --user show-environment 2>/dev/null | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d= -f2-)" || true
  if [ -n "${dbus_addr:-}" ]; then
    export DBUS_SESSION_BUS_ADDRESS="$dbus_addr"
  fi
fi

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

timestamp="$(date +%Y%m%d-%H%M%S)"
log_dir="/var/log/lab-updates"
mkdir -p "$log_dir" 2>/dev/null || log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/lab-updates"
mkdir -p "$log_dir"

log_file="$log_dir/update-$timestamp.log"
exec > >(tee -a "$log_file") 2>&1

notify() {
  local title="$1"
  local message="$2"
  local mode="${3:-info}"

  if command -v kdialog >/dev/null 2>&1 && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
    case "$mode" in
      reboot)
        if kdialog \
          --title "$title" \
          --yes-label "Reiniciar ahora" \
          --no-label "Más tarde" \
          --yesno "$message\n\nRegistro: $log_file"; then
          systemctl reboot
        fi
        ;;
      error)
        kdialog --title "$title" --error "$message\n\nRegistro:\n$log_file"
        ;;
      *)
        kdialog --title "$title" --msgbox "$message\n\nRegistro: $log_file"
        ;;
    esac
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send -t 0 --urgency=critical "$title" "$message\nRegistro: $log_file"
  fi
}

trap 'code=$?; [ "$code" -eq 0 ] || notify "Actualizacion fallida" "La actualizacion ha fallado (codigo $code)." error' EXIT

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
notify "Actualizacion completada" "La actualizacion del sistema ha terminado correctamente." reboot
