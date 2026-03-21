{ config, lib, pkgs, ... }:

let
  username = "usuario";
in
{
  imports =
    lib.optional (builtins.pathExists ./hardware-configuration.nix)
      ./hardware-configuration.nix
    ++ [
      (import ./locale-es.nix { inherit lib username; })
    ];

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
  services.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.defaultSession = "plasma";
  services.desktopManager.plasma6.enable = true;

  services.xserver.displayManager.sessionCommands = ''
    # disable heavy effects
    kwriteconfig5 --file kwinrc --group Plugins --key blurEnabled false
    kwriteconfig5 --file kwinrc --group Plugins --key contrastEnabled false

    # reduce animations
    kwriteconfig5 --file kwinrc --group Compositing --key AnimationSpeed 2
  '';

  # lock down plasma desktop for the user
  environment.etc = {
    "xdg/kdeglobals".text = ''
      [KDE Action Restrictions][$i]
      action/configdesktop=false
      plasma/allow_configure_when_locked=false
      plasma/plasmashell/unlockedDesktop=false
      ghns=false
    '';

    "kde5rc".text = ''
      [KDE Control Module Restrictions][$i]
      kcm_wallpaper=false
    '';
  };

  services.pipewire.enable = true;

  # user configuration
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "dialout" # arduino serial access
    ];
    password = username;
  };
  users.users.root.initialPassword = "toor";

  environment.systemPackages = with pkgs; [
    firefox
    git
    gh
    vim
    vscode
    chromium
    jetbrains.pycharm
    kdePackages.kdenlive
    postman
    gimp
    freecad
    # using appimage because it seems to be one major version up
    cura-appimage
    arduino-ide

    # python stuff goes here
    (python314.withPackages (ps: with ps; [
      numpy
      pandas
      matplotlib
      scipy
      jupyter
    ]))
  ];

  # sudo configuration
  security.sudo.wheelNeedsPassword = true;

  nixpkgs.config.allowUnfree = true;
}
