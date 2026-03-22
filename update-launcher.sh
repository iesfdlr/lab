#!/bin/bash

set -euo pipefail

monitor_bin="${LAB_UPDATE_MONITOR_BIN:-lab-update-monitor}"

pick_terminal() {
  local candidate

  for candidate in konsole xterm; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

open_terminal() {
  local terminal="$1"
  shift

  case "$terminal" in
    konsole)
      exec "$terminal" --hold -e "$@"
      ;;
    xterm)
      exec "$terminal" -hold -e "$@"
      ;;
  esac
}

main() {
  local terminal choice log_dir

  terminal="$(pick_terminal)" || {
    if command -v kdialog >/dev/null 2>&1; then
      kdialog --error "No se ha encontrado ningun terminal compatible para abrir los registros."
    else
      echo "No se ha encontrado ningun terminal compatible para abrir los registros." >&2
    fi
    exit 1
  }

  if "$monitor_bin" --has-active-update; then
    open_terminal "$terminal" "$monitor_bin" --watch
  fi

  if command -v kdialog >/dev/null 2>&1; then
    choice="$(
      kdialog \
        --title "Actualizaciones del laboratorio" \
        --menu "Que quieres hacer?" \
        run "Ejecutar actualizacion y seguir registro" \
        watch "Ver el ultimo registro" \
        folder "Abrir la carpeta de registros"
    )" || exit 0
  else
    choice="run"
  fi

  case "$choice" in
    run)
      open_terminal "$terminal" "$monitor_bin" --run
      ;;
    watch)
      open_terminal "$terminal" "$monitor_bin" --watch
      ;;
    folder)
      log_dir="$("$monitor_bin" --print-log-dir)"
      exec xdg-open "$log_dir"
      ;;
  esac
}

main "$@"
