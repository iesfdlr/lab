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
  local terminal choice log_dir branch branches_raw
  local -a menu_args

  terminal="$(pick_terminal)" || {
    if command -v kdialog >/dev/null 2>&1; then
      kdialog --error "No se ha encontrado ningun terminal compatible para abrir los registros."
    else
      echo "No se ha encontrado ningun terminal compatible para abrir los registros." >&2
    fi
    exit 1
  }

  if command -v kdialog >/dev/null 2>&1; then
    choice="$(
      kdialog \
        --title "Actualizaciones de la distribución" \
        --menu "Que quieres hacer?" \
        run "Ejecutar actualizacion y seguir registro" \
        watch "Ver el ultimo registro" \
        branch "Cambiar de rama del repositorio" \
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
    branch)
      branches_raw="$("$monitor_bin" --list-branches 2>/dev/null || true)"

      if [ -z "$branches_raw" ]; then
        if command -v kdialog >/dev/null 2>&1; then
          kdialog --error "No se han podido listar las ramas del repositorio."
        else
          echo "No se han podido listar las ramas del repositorio." >&2
        fi
        exit 1
      fi

      if command -v kdialog >/dev/null 2>&1; then
        menu_args=()
        while IFS= read -r b; do
          [ -n "$b" ] || continue
          menu_args+=("$b" "$b")
        done <<< "$branches_raw"

        branch="$(kdialog --title "Cambiar de rama" --menu "Elige la rama:" "${menu_args[@]}")" || exit 0
      else
        branch="$(printf '%s\n' "$branches_raw" | head -n 1)"
      fi

      [ -n "$branch" ] || exit 0
      open_terminal "$terminal" "$monitor_bin" --switch-branch "$branch"
      ;;
    folder)
      log_dir="$("$monitor_bin" --print-log-dir)"
      exec xdg-open "$log_dir"
      ;;
  esac
}

main "$@"
