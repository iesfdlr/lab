#!/bin/bash

echo "Actualizando el sistema..."
git pull

if [ $? -ne 0 ]; then
	echo "error al actualizar el repositorio, no se contunará."
	exit 1
fi

nixos-rebuild switch --flake .#