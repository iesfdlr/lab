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

  system.stateVersion = "25.11";

  # bootloader config stuff
  boot.loader.systemd-boot.enable = true;
  boot.loader.timeout = 0;

  # networking
  # networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # timezone
  time.timeZone = "Europe/Madrid";

  # kde plasma under x11
  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.defaultSession = "plasma";
  services.xserver.desktopManager.plasma6.enable = true;

  services.xserver.desktopManager.plasma6.extraSessionCommands = ''
    # disable heavy effects
    kwriteconfig5 --file kwinrc --group Plugins --key blurEnabled false
    kwriteconfig5 --file kwinrc --group Plugins --key contrastEnabled false

    # reduce animations
    kwriteconfig5 --file kwinrc --group Compositing --key AnimationSpeed 2
  '';

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

  nixpkgs.config.allowUnfree = true;
}
