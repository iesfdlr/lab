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

  services.pipewire.enable = true;

  # user configuration
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" ];
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
