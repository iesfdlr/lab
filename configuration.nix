{ config, lib, pkgs, ... }:

let
  username = "usuario";
  learningml-desktop = pkgs.callPackage ./pkgs/learningml-desktop.nix { };
  andaredConnectScript = pkgs.writeShellScriptBin "andared-connect" (builtins.readFile ./andared-connect.sh);
in
{
  imports =
    lib.optionals (builtins.pathExists ./hardware-configuration.nix) [
      ./hardware-configuration.nix
    ]
    ++ lib.optionals (builtins.pathExists ./install-local.nix) [
      ./install-local.nix
    ]
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
  nixpkgs.config.allowUnfree = true;

  boot = {
    plymouth = {
      enable = true;
      theme = "rings";
      themePackages = with pkgs; [
        # todo: change this to a good simple theme
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "rings" ];
        })
      ];
    };

    # silent boot options
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "systemd.show_status=auto"
    ];
    # hide bootloader menu (can still be accessed by holding shift during boot)
    loader.timeout = 0;
  };

  # networking
  # networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # timezone
  time.timeZone = "Europe/Madrid";

  # BELOW IS THE KDE PLASMA CONFIG ZONE
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "plasmax11";
  services.displayManager.sddm.wayland.enable = false;
  services.desktopManager.plasma6.enable = true;

  services.xserver.displayManager.sessionCommands = ''
    # disable heavy effects
    kwriteconfig5 --file kwinrc --group Plugins --key blurEnabled false
    kwriteconfig5 --file kwinrc --group Plugins --key contrastEnabled false

    # reduce animations
    kwriteconfig5 --file kwinrc --group Compositing --key AnimationSpeed 2
  '';

  # kde kiosk configs + disable wallpaper configuration for all users
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

    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };

    # andared_corporativo network manager settings
    "NetworkManager/system-connections/Andared_Corporativo.nmconnection" = {
      mode = "0600";
      text = ''
        [connection]
        id=Andared_Corporativo
        uuid=9c4ef8e2-f9fc-4a33-b64b-cb79e5e2ca62
        type=wifi
        permissions=
        autoconnect=false
        autoconnect-priority=-1

        [wifi]
        mode=infrastructure
        ssid=Andared_Corporativo

        [wifi-security]
        key-mgmt=wpa-eap

        [802-1x]
        eap=ttls;
        phase2-auth=gtc
        password-flags=2
        system-ca-certs=false

        [ipv4]
        method=auto

        [ipv6]
        addr-gen-mode=default
        method=auto
      '';
    };
  };
  
  # todo: this doesnt actually work so we might just configure it thru kde
  services.logind.settings.Login = {
    IdleAction = "poweroff";
    IdleActionSec = "30min";
  };

  services.pipewire.enable = true;

  # using rootless docker to avoid literally giving out root access
  virtualisation.docker = {
    enable = false;

    rootless = {
      enable = true;
      setSocketVariable = true;
      # i'm not sure if we need this? it comes from the nix docs so
      daemon.settings = {
        dns = [ "1.1.1.1" "1.0.0.1" ];
      };
    };
  };

  # user configuration
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "dialout" # arduino serial access
      "docker"
    ];
    password = username;
  };
  users.users.root.initialPassword = "toor";

  environment.systemPackages = with pkgs; [
    git
    gh
    vim
    vscode
    jetbrains.pycharm
    jetbrains.datagrip
    kdePackages.kdenlive
    postman
    gimp
    freecad
    # using appimage because it seems to be one major version up
    cura-appimage
    arduino-ide
    # from local repo
    learningml-desktop
    wireshark
    andaredConnectScript
    xdg-user-dirs

    # python stuff goes here
    (python314.withPackages (ps: with ps; [
      numpy
      pandas
      matplotlib
      scipy
      jupyter
    ]))
  ];

  # firefox config, source: https://wiki.nixos.org/wiki/Firefox/en#Advanced
  programs.firefox = {
    enable = true;
    languagePacks = [ "es-ES" ];

    policies = {
      # Updates & Background Services
      AppAutoUpdate                 = false;
      BackgroundAppUpdate           = false;

      # Feature Disabling
      DisableFirefoxStudies         = true;
      DisableFirefoxAccounts        = true;
      DisableFirefoxScreenshots     = true;
      DisableProfileImport          = true;
      DisableProfileRefresh         = true;
      DisableSetDesktopBackground   = true;
      DisablePocket                 = true;
      DisableTelemetry              = true;
      DisableFormHistory            = true;

      # Access Restrictions
      BlockAboutConfig              = false;
      BlockAboutProfiles            = true;
      BlockAboutSupport             = true;

	    # UI and Behavior
	    DontCheckDefaultBrowser       = true;
	    HardwareAcceleration          = false;
	    OfferToSaveLogins             = false;
      # force private browsing mode
	    PrivateBrowsingModeAvailability = 2;

      # Extensions
      ExtensionSettings = let
        moz = short: "https://addons.mozilla.org/firefox/downloads/latest/${short}/latest.xpi";
      in {
        "*".installation_mode = "blocked";

        "uBlock0@raymondhill.net" = {
          install_url       = moz "ublock-origin";
          installation_mode = "force_installed";
          updates_disabled  = true;
          private_browsing  = true;
        };
      };
    };
  };

  programs.chromium = {
    enable = true;
    extensions = [
      "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx"
    ];
    extraOpts = {
      # force incognito mode, source: https://chromeenterprise.google/policies/#IncognitoModeAvailability
      IncognitoModeAvailability = 2;
    };
  };

  # sudo configuration
  security.sudo.wheelNeedsPassword = true;

  # timers and stuff
  systemd.timers.lab-updater = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15m";
      OnUnitActiveSec = "15m";
      Unit = "lab-updater.service";
    };
  };
  systemd.services.lab-updater = {
    description = "actualizaciones automáticas del sistema";
    path = with pkgs; [ git nix coreutils kdePackages.kdialog libnotify config.system.build.nixos-rebuild ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/nixos/update.sh";
    };
  };

  systemd.timers.bye-descargas = {
    description = "limpia la carpeta de descargas semanalmente";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      Unit = "bye-descargas.service";
    };
  };
  systemd.services.bye-descargas = {
    description = "bye bye";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.findutils}/bin/find /home/usuario/Descargas -mindepth 1 -mtime +14 -delete";
    };
  };
}
