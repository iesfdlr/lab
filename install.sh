#!/usr/bin/env bash

set -euo pipefail

repo_url="https://github.com/iesfdlr/lab.git"
flake_host="nixos"
target_root="/mnt"
repo_dir="$target_root/etc/nixos"
swap_size="4GiB"

usage() {
  cat <<'EOF'
Usage: install.sh DISK [-f|--force] [--swap-size SIZE] [--no-andared]
                       [--andared-username USER] [--andared-password PASS]
                       [--root-password PASS]

Examples:
  sudo ./install.sh /dev/nvme0n1
  sudo ./install.sh /dev/sda --swap-size 16GiB
  sudo ./install.sh /dev/sda --no-andared
  sudo ./install.sh /dev/sda --andared-username usuario --andared-password clave
  sudo ./install.sh /dev/sda --root-password nueva-clave-root

This script will erase the selected disk, partition it, format it,
clone this repository into /etc/nixos, and install NixOS.

By default the script will prompt for Andared Wi-Fi credentials.
Press Enter on an empty username to skip.  Use --no-andared to
suppress the prompt entirely.

If a TTY is available, the installer will prompt you to set a root
password. You must provide a root password to proceed with installation.
EOF
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
  fi
}

run_git() {
  if command -v git >/dev/null 2>&1; then
    git "$@"
  else
    nix-shell -p git --run "$(printf '%q ' git "$@")"
  fi
}

prompt_secret() {
  local prompt="$1"
  local value=""

  if [ -c /dev/tty ]; then
    printf '%s' "$prompt" > /dev/tty
    stty -echo < /dev/tty
    IFS= read -r value < /dev/tty || value=""
    stty echo < /dev/tty
    printf '\n' > /dev/tty
  else
    echo "Cannot prompt for secrets without /dev/tty." >&2
    exit 1
  fi

  printf '%s' "$value"
}

prompt_secret_confirm() {
  local prompt="$1"
  local value confirm

  value="$(prompt_secret "$prompt")"
  if [ -z "$value" ]; then
    echo "La contraseña no puede estar vacía." >&2
    return 1
  fi

  confirm="$(prompt_secret 'Repite la contraseña: ')"
  if [ "$value" != "$confirm" ]; then
    echo "Las contraseñas no coinciden." >&2
    return 1
  fi

  printf '%s' "$value"
}

hash_password() {
  local password="$1"

  if command -v openssl >/dev/null 2>&1; then
    printf '%s' "$password" | openssl passwd -6 -stdin
    return 0
  fi

  echo "openssl is required to hash the root password during installation." >&2
  exit 1
}

set_installed_root_password() {
  local password="$1"
  local password_hash

  password_hash="$(hash_password "$password")"
  printf 'root:%s\n' "$password_hash" | chpasswd -e -R "$target_root"
}

is_uefi() {
  [ -d /sys/firmware/efi/efivars ]
}

part_path() {
  local disk="$1"
  local number="$2"

  case "$disk" in
    *nvme*|*mmcblk*|*loop*)
      printf '%sp%s\n' "$disk" "$number"
      ;;
    *)
      printf '%s%s\n' "$disk" "$number"
      ;;
  esac
}

cleanup_mounts() {
  swapoff --all 2>/dev/null || true

  if mountpoint -q "$target_root/boot"; then
    umount "$target_root/boot"
  fi

  if mountpoint -q "$target_root"; then
    umount -R "$target_root"
  fi
}

partition_disk() {
  local disk="$1"
  local swap_start="-$swap_size"

  echo "Partitioning $disk..."
  wipefs -af "$disk"

  if is_uefi; then
    parted -s "$disk" mklabel gpt
    parted -s "$disk" mkpart ESP fat32 1MiB 512MiB
    parted -s "$disk" set 1 esp on
    parted -s -- "$disk" mkpart root ext4 512MiB "$swap_start"
    parted -s -- "$disk" mkpart swap linux-swap "$swap_start" 100%
  else
    parted -s "$disk" mklabel msdos
    parted -s -- "$disk" mkpart primary ext4 1MiB "$swap_start"
    parted -s "$disk" set 1 boot on
    parted -s -- "$disk" mkpart primary linux-swap "$swap_start" 100%
  fi

  partprobe "$disk"
  udevadm settle
}

format_and_mount() {
  local disk="$1"
  local root_partition
  local boot_partition=""
  local swap_partition

  if is_uefi; then
    boot_partition="$(part_path "$disk" 1)"
    root_partition="$(part_path "$disk" 2)"
    swap_partition="$(part_path "$disk" 3)"
  else
    root_partition="$(part_path "$disk" 1)"
    swap_partition="$(part_path "$disk" 2)"
  fi

  echo "Formatting partitions..."
  mkfs.ext4 -F -L nixos "$root_partition"
  mkswap -f -L swap "$swap_partition"

  if [ -n "$boot_partition" ]; then
    mkfs.fat -F 32 -n boot "$boot_partition"
  fi

  echo "Mounting target filesystems..."
  mkdir -p "$target_root"
  mount "$root_partition" "$target_root"

  if [ -n "$boot_partition" ]; then
    mkdir -p "$target_root/boot"
    mount -o umask=077 "$boot_partition" "$target_root/boot"
  fi

  swapon "$swap_partition"
}

write_install_local() {
  local disk="$1"

  if is_uefi; then
    cat > "$repo_dir/install-local.nix" <<'EOF'
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
EOF
  else
    cat > "$repo_dir/install-local.nix" <<EOF
{
  boot.loader.grub = {
    enable = true;
    device = "$disk";
  };
}
EOF
  fi
}

write_andared_connection() {
  local username="$1"
  local password="$2"
  local profile_dir="$target_root/etc/NetworkManager/system-connections"
  local profile_path="$profile_dir/Andared_Corporativo-installed.nmconnection"
  local old_umask

  mkdir -p "$profile_dir"
  old_umask="$(umask)"
  umask 077

  cat > "$profile_path" <<EOF
[connection]
id=Andared_Corporativo (instalado)
uuid=dcf7cfd0-02f7-4df9-8a15-f51cbeb15566
type=wifi
permissions=
autoconnect=true
autoconnect-priority=10

[wifi]
mode=infrastructure
ssid=Andared_Corporativo

[wifi-security]
key-mgmt=wpa-eap

[802-1x]
eap=ttls;
identity=$username
password=$password
phase2-auth=gtc
system-ca-certs=false

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto
EOF

  chmod 600 "$profile_path"
  umask "$old_umask"
}

main() {
  require_root

  local disk=""
  local force=0
  local andared_username=""
  local andared_password=""
  local no_andared=0
  local root_password=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f|--force)
        force=1
        shift
        ;;
      --swap-size)
        if [ "$#" -lt 2 ]; then
          echo "Missing value for --swap-size." >&2
          exit 1
        fi
        swap_size="$2"
        shift 2
        ;;
      --andared-username)
        if [ "$#" -lt 2 ]; then
          echo "Missing value for --andared-username." >&2
          exit 1
        fi
        andared_username="$2"
        shift 2
        ;;
      --andared-password)
        if [ "$#" -lt 2 ]; then
          echo "Missing value for --andared-password." >&2
          exit 1
        fi
        andared_password="$2"
        shift 2
        ;;
      --no-andared)
        no_andared=1
        shift
        ;;
      --root-password)
        if [ "$#" -lt 2 ]; then
          echo "Missing value for --root-password." >&2
          exit 1
        fi
        root_password="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        if [ -z "$disk" ]; then
          disk="$1"
          shift
        else
          echo "Unexpected argument: $1" >&2
          usage
          exit 1
        fi
        ;;
    esac
  done

  if { [ -n "$andared_username" ] && [ -z "$andared_password" ]; } || { [ -z "$andared_username" ] && [ -n "$andared_password" ]; }; then
    echo "Provide both --andared-username and --andared-password together." >&2
    exit 1
  fi

  if [ -n "$root_password" ]; then
    echo "Warning: --root-password may be visible in shell history." >&2
  fi

  if [ "$no_andared" -eq 0 ] && [ -z "$andared_username" ]; then
    if [ -c /dev/tty ]; then
      printf '\n' > /dev/tty
      printf '┌─────────────────────────────────────────────────────┐\n' > /dev/tty
      printf '│  Andared_Corporativo — Wi-Fi del centro educativo   │\n' > /dev/tty
      printf '│                                                     │\n' > /dev/tty
      printf '│  Introduce tu usuario y contraseña para dejar la    │\n' > /dev/tty
      printf '│  conexión configurada. Pulsa Enter para omitir.     │\n' > /dev/tty
      printf '└─────────────────────────────────────────────────────┘\n' > /dev/tty
      printf '\n' > /dev/tty
      printf 'Usuario Andared: ' > /dev/tty
      IFS= read -r andared_username < /dev/tty || andared_username=""

      if [ -n "$andared_username" ]; then
        andared_password="$(prompt_secret 'Contraseña Andared: ')"
        if [ -z "$andared_password" ]; then
          echo "Se ha introducido un usuario pero no una contraseña. Abortando." >&2
          exit 1
        fi
      fi
    else
      echo "Nota: no se pueden pedir credenciales Andared sin /dev/tty. Omitiendo." >&2
    fi
  fi

  if [ -z "$disk" ] || [ ! -b "$disk" ]; then
    usage
    exit 1
  fi

  if [ "$force" -eq 0 ]; then
    echo
    echo "WARNING: This will ERASE ALL DATA on $disk."
    printf 'Type "yes" to continue: '
    # Use /dev/tty if available, otherwise fallback to stdin
    if [ -c /dev/tty ]; then
      read -r confirm < /dev/tty || confirm="no"
    else
      read -r confirm || confirm="no"
    fi

    if [ "$confirm" != "yes" ]; then
      echo "Aborted (confirmation failed or not in a terminal)." >&2
      exit 1
    fi
  fi

  if [ -z "$root_password" ]; then
    if [ -c /dev/tty ]; then
      printf '\n' > /dev/tty
      while [ -z "$root_password" ]; do
        root_password="$(prompt_secret_confirm 'Contraseña root (obligatoria): ')" || root_password=""
      done
    else
      echo "Se requiere una contraseña root. Usa --root-password o ejecuta en una terminal." >&2
      exit 1
    fi
  fi

  cleanup_mounts
  partition_disk "$disk"
  format_and_mount "$disk"

  if [ "$force" -eq 1 ] && [ -d "$repo_dir/.git" ]; then
    rm -rf "$repo_dir"
  fi

  echo "Cloning repository into $repo_dir..."
  run_git clone "$repo_url" "$repo_dir"

  echo "Generating machine-specific configuration..."
  nixos-generate-config --root "$target_root" --show-hardware-config > "$repo_dir/hardware-configuration.nix"

  write_install_local "$disk"

  echo "Installing NixOS from flake $flake_host..."
  nixos-install --no-root-passwd --flake "path:$repo_dir#$flake_host"

  if [ -n "$andared_username" ] && [ -n "$andared_password" ]; then
    echo "Writing Andared Wi-Fi credentials to the installed system..."
    write_andared_connection "$andared_username" "$andared_password"
  fi

  if [ -n "$root_password" ]; then
    echo "Setting custom root password in the installed system..."
    set_installed_root_password "$root_password"
  fi

  echo
  echo "Installation complete."
}

main "$@"
