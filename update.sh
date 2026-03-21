#!/bin/bash

set -e

echo "Actualizando el sistema..."
old_rev="$(git rev-parse HEAD)"
git pull --rebase --autostash

new_rev="$(git rev-parse HEAD)"

if [ "$old_rev" != "$new_rev" ]; then
  echo "Hay cambios nuevos en el repositorio. Construyendo el sistema..."
  nixos-rebuild switch --flake path:.#nixos
else
  echo "No hay cambios nuevos en el repositorio. Omitiendo nixos-rebuild."
fi
