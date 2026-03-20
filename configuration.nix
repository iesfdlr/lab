{ config, lib, pkgs, ... }:

{
  imports = lib.optional (builtins.pathExists ./hardware-configuration.nix)
    ./hardware-configuration.nix;

  assertions = [
    {
      assertion = builtins.pathExists ./hardware-configuration.nix;
      message = ''
        Missing ./hardware-configuration.nix.

        Generate it on the target machine with:
          sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix

        Then rebuild with:
          sudo nixos-rebuild switch --flake .#
      '';
    }
  ];

  # nixos version
  system.stateVersion = "25.05";

  # bootloader config stuff
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking
  # networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # timezone
  time.timeZone = "Europe/Madrid";

  # xfce, x11...
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  # spanish keyboard layout
  services.xserver.xkb.layout = "es";

  services.pipewire.enable = true;

  # user configuration
  users.users.usuario = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" ];
    password = "usuario";
  };
  users.users.root.initialPassword = "toor";

  environment.systemPackages = with pkgs; [
    firefox
    git
    vim
    python3
    vscode
    chromium
  ];

  # sudo configuration
  security.sudo.wheelNeedsPassword = true;
}
