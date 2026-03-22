#!/usr/bin/env bash

set -euo pipefail

repo_url="https://github.com/iesfdlr/lab.git"
flake_host="nixos"
target_root="/mnt"
repo_dir="$target_root/etc/nixos"
swap_size="4GiB"

usage() {
  cat <<'EOF'
Usage: install.sh DISK [-f|--force] [--swap-size SIZE]

Examples:
  sudo ./install.sh /dev/nvme0n1
  sudo ./install.sh /dev/sda --swap-size 16GiB

This script will erase the selected disk, partition it, format it,
clone this repository into /etc/nixos, and install NixOS.
EOF
}

require_root() {
  if [ "${EUID}" -ne 0 ]; then
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

main() {
  require_root

  local disk=""
  local force=0

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

  if [ -z "$disk" ] || [ ! -b "$disk" ]; then
    usage
    exit 1
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
  nixos-generate-config --root "$target_root"
  write_install_local "$disk"

  echo "Installing NixOS from flake $flake_host..."
  nixos-install --no-root-passwd --flake "$repo_dir#$flake_host"

  echo
  echo "Installation complete."
}

main "$@"
