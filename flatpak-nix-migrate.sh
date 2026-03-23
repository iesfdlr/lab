#!/usr/bin/env bash
set -euo pipefail

# flatpak-nix-migrate: detect duplicates and migrate data from Flatpak to Nix
# usage: flatpak-nix-migrate [--migrate <flatpak-id>]

FLATPAK_DATA_BASE="$HOME/.var/app"

# map of Flatpak ID -> typical Nix config/data directory name
# format: "flatpak-id:nix-config-dir:nix-data-dir"
declare -a APP_MAPPINGS=(
	"org.chromium.Chromium:chromium:chromium"
	"com.google.Chrome:google-chrome:google-chrome"
	"org.mozilla.firefox:firefox:mozilla"
	"com.visualstudio.code:Code:Code"
	"com.vscodium.codium:VSCodium:VSCodium"
	"com.jetbrains.PyCharm-Community:JetBrains/PyCharm:JetBrains/PyCharm"
	"com.jetbrains.PyCharm-Professional:JetBrains/PyCharm:JetBrains/PyCharm"
	"com.jetbrains.DataGrip:JetBrains/DataGrip:JetBrains/DataGrip"
	"org.kde.kdenlive:kdenlive:kdenlive"
	"com.getpostman.Postman:Postman:Postman"
	"org.gimp.GIMP:GIMP:gimp"
	"org.freecad.FreeCAD:FreeCAD:FreeCAD"
	"org.freecadweb.FreeCAD:FreeCAD:FreeCAD"
	"cc.arduino.IDE2:arduino-ide:arduino15"
	"cc.arduino.arduinoide:arduino-ide:arduino15"
	"org.wireshark.Wireshark:wireshark:wireshark"
	"org.libreoffice.LibreOffice:libreoffice:libreoffice"
)

get_nix_dir() {
	local flatpak_id="$1"
	for mapping in "${APP_MAPPINGS[@]}"; do
		IFS=':' read -r fp_id config_dir data_dir <<<"$mapping"
		if [[ "$fp_id" == "$flatpak_id" ]]; then
			echo "$config_dir:$data_dir"
			return
		fi
	done
	# fallback: use flatpak id without reverse domain
	local name
	name=$(echo "$flatpak_id" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
	echo "$name:$name"
}

check_nix_package() {
	local pkg_name="$1"
	# check if package is in nix store or system profile
	if nix-store -q --requisites /run/current-system/sw 2>/dev/null | grep -q "$pkg_name"; then
		return 0
	fi
	return 1
}

list_flatpak_apps() {
	flatpak list --app --columns=application 2>/dev/null | tail -n +1
}

find_duplicates() {
	echo "=== Checking for Flatpak/Nix duplicates ==="
	echo ""

	local found_duplicates=0
	local flatpak_apps
	flatpak_apps=$(list_flatpak_apps)

	if [[ -z "$flatpak_apps" ]]; then
		echo "No Flatpak apps installed."
		return
	fi

	while IFS= read -r flatpak_id; do
		[[ -z "$flatpak_id" ]] && continue

		local mapping
		mapping=$(get_nix_dir "$flatpak_id")
		IFS=':' read -r nix_config nix_data <<<"$mapping"

		# check various possible nix package names
		local pkg_names=()
		pkg_names+=("$(echo "$flatpak_id" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')")

		for pkg in "${pkg_names[@]}"; do
			if check_nix_package "$pkg"; then
				echo "DUPLICATE: $flatpak_id (Nix package: $pkg)"
				echo "  Flatpak data: $FLATPAK_DATA_BASE/$flatpak_id/"
				echo "  Nix config:   ~/.config/$nix_config/"
				echo "  Nix data:     ~/.local/share/$nix_data/"
				echo ""
				found_duplicates=1
				break
			fi
		done
	done <<<"$flatpak_apps"

	if [[ $found_duplicates -eq 0 ]]; then
		echo "No duplicates found."
	fi
}

migrate_app() {
	local flatpak_id="$1"
	local mapping
	mapping=$(get_nix_dir "$flatpak_id")

	if [[ -z "$mapping" ]]; then
		echo "Error: Unknown Flatpak ID: $flatpak_id"
		exit 1
	fi

	IFS=':' read -r nix_config nix_data <<<"$mapping"

	local flatpak_dir="$FLATPAK_DATA_BASE/$flatpak_id"
	local config_src="$flatpak_dir/config"
	local data_src="$flatpak_dir/data"
	local cache_src="$flatpak_dir/cache"

	local config_dest="$HOME/.config/$nix_config"
	local data_dest="$HOME/.local/share/$nix_data"
	local cache_dest="$HOME/.cache/$nix_config"

	echo "=== Migrating $flatpak_id ==="
	echo ""

	# migrate config
	if [[ -d "$config_src" ]]; then
		if [[ -d "$config_dest" ]]; then
			echo "WARNING: $config_dest already exists. Skipping config migration."
		else
			echo "Migrating config: $config_src -> $config_dest"
			mkdir -p "$(dirname "$config_dest")"
			cp -r "$config_src" "$config_dest"
		fi
	else
		echo "No config to migrate (directory doesn't exist: $config_src)"
	fi

	# migrate data
	if [[ -d "$data_src" ]]; then
		if [[ -d "$data_dest" ]]; then
			echo "WARNING: $data_dest already exists. Skipping data migration."
		else
			echo "Migrating data: $data_src -> $data_dest"
			mkdir -p "$(dirname "$data_dest")"
			cp -r "$data_src" "$data_dest"
		fi
	else
		echo "No data to migrate (directory doesn't exist: $data_src)"
	fi

	echo ""
	echo "Migration complete!"
	echo ""
	echo "Next steps:"
	echo "  1. Verify the migrated app works correctly"
	echo "  2. Remove Flatpak version: flatpak uninstall $flatpak_id"
	echo "  3. Optionally remove old Flatpak data: rm -rf $flatpak_dir"
}

main() {
	if [[ "${1:-}" == "--migrate" && -n "${2:-}" ]]; then
		migrate_app "$2"
	elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
		echo "Usage: flatpak-nix-migrate [--migrate <flatpak-id>]"
		echo ""
		echo "Without arguments: lists all Flatpak apps that have Nix equivalents"
		echo "With --migrate: migrates data from Flatpak to Nix for the given app"
		echo ""
		echo "Examples:"
		echo "  flatpak-nix-migrate                  # find duplicates"
		echo "  flatpak-nix-migrate --migrate org.mozilla.firefox"
	else
		find_duplicates
	fi
}

main "$@"
