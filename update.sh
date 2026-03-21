#!/bin/bash

set -e

echo "Actualizando el sistema..."
git pull --rebase --autostash

nixos-rebuild switch --flake path:.#nixos
