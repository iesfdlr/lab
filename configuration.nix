{ config, lib, pkgs, ... }:

let
  username = "usuario";
  learningml-desktop = pkgs.callPackage ./pkgs/learningml-desktop.nix { };
  andaredConnectScript = pkgs.writeShellScriptBin "andared-connect" (builtins.readFile ./andared-connect.sh);
  labUpdateMonitor = pkgs.writeShellScriptBin "lab-update-monitor" (builtins.readFile ./update-monitor.sh);
  labUpdateLauncher = pkgs.writeShellScriptBin "lab-update-launcher" (builtins.readFile ./update-launcher.sh);
  # flatpak app IDs that overlap with nix-installed packages — blocked from
  # being installed via Flatpak (both CLI and Discover) using a remote filter.
  blockedFlatpakIds = [
    "org.chromium.Chromium"
    "com.google.Chrome"
    "org.mozilla.firefox"
    "com.visualstudio.code"
    "com.vscodium.codium"
    "com.jetbrains.PyCharm-Community"
    "com.jetbrains.PyCharm-Professional"
    "com.jetbrains.DataGrip"
    "org.kde.kdenlive"
    "com.getpostman.Postman"
    "org.gimp.GIMP"
    "org.freecad.FreeCAD"
    "org.freecadweb.FreeCAD"
    "cc.arduino.IDE2"
    "cc.arduino.arduinoide"
    "org.wireshark.Wireshark"
    "org.libreoffice.LibreOffice"
  ];

  flathubFilter = pkgs.writeText "lab-flathub.filter" (
    lib.concatMapStringsSep "\n" (id: "deny ${id}") blockedFlatpakIds + "\n"
  );
  labUpdateDesktop = pkgs.makeDesktopItem {
    name = "lab-updates";
    desktopName = "Actualizaciones de la distribución";
    genericName = "Registro y lanzador de actualizaciones";
    comment = "Sigue la actualizacion activa, revisa registros o lanza una nueva actualizacion";
    exec = "lab-update-launcher";
    icon = "system-software-update";
    terminal = false;
    categories = [ "System" "Settings" ];
  };
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
  services.flatpak.enable = true;

  services.xserver.displayManager.sessionCommands = ''
    # disable heavy effects
    kwriteconfig5 --file kwinrc --group Plugins --key blurEnabled false
    kwriteconfig5 --file kwinrc --group Plugins --key contrastEnabled false

    # reduce animations
    kwriteconfig5 --file kwinrc --group Compositing --key AnimationSpeed 2
  '';

  # kde kiosk configs + disable wallpaper configuration for all users
  environment.etc = {
    "nixos/update.sh" = {
      mode = "0755";
      source = ./update.sh;
    };

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

    "xdg/user-dirs.defaults".text = ''
      DESKTOP=Escritorio
      DOWNLOAD=Descargas
      DOCUMENTS=Documentos
      MUSIC=Música
      PICTURES=Imágenes
      VIDEOS=Vídeos
      TEMPLATES=Plantillas
      PUBLICSHARE=Público
    '';

    "xdg/autostart/xdg-user-dirs.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Update XDG user dirs
      Exec=${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update
      NoDisplay=true
      X-KDE-autostart-phase=1
    '';
  };

  # auto power-off after 30 minutes of inactivity
  # logind IdleAction doesn't work reliably with KDE (powerdevil manages idle
  # detection itself and doesn't always set the session IdleHint), so we
  # configure it directly through KDE's powermanagementprofilesrc.
  # source: https://nix-community.github.io/plasma-manager/options.xhtml (powerdevil options)
  #         https://blogs.kde.org/2024/04/23/powerdevil-in-plasma-6.0-and-beyond/
  #         KConfig suspendType values: 0=nothing, 1=sleep, 2=hibernate, 8=shutdown
  environment.etc."xdg/powermanagementprofilesrc".text = ''
    [AC][SuspendSession]
    idleTime=1800000
    suspendThenHibernate=false
    suspendType=8

    [Battery][SuspendSession]
    idleTime=1800000
    suspendThenHibernate=false
    suspendType=8

    [LowBattery][SuspendSession]
    idleTime=1800000
    suspendThenHibernate=false
    suspendType=8
  '';

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


  environment.systemPackages = with pkgs; [
    chromium
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
    labUpdateMonitor
    labUpdateLauncher
    labUpdateDesktop
    xdg-user-dirs
    libnotify
    util-linux
    kdePackages.kdialog
    kdePackages.konsole
    libreoffice-qt
    hunspell
    hunspellDicts.es_ES
    hyphenDicts.es_ES

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

  # protect XDG user directories from being deleted by the user
  # sticky bit (1) + root ownership means the user can create/delete their OWN
  # files inside, but cannot delete or rename the directory itself.
  # source: https://unix.stackexchange.com/questions/20104 (sticky bit approach)
  #         man tmpfiles.d (systemd-tmpfiles rule format)
  systemd.tmpfiles.rules =
    let
      # "d" = create directory, 1770 = rwxrwx--- + sticky bit
      protect = dir: "d /home/${username}/${dir} 1770 root ${username} -";
      xdgDirs = [
        "Escritorio"
        "Descargas"
        "Documentos"
        "Música"
        "Imágenes"
        "Vídeos"
        "Plantillas"
        "Público"
      ];
    in
      map protect xdgDirs;

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
    path = with pkgs; [ git nix coreutils systemd util-linux libnotify config.system.build.nixos-rebuild bash ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/update.sh";
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

  systemd.services.flatpak-flathub-user = {
    description = "configura Flathub para el usuario con filtro de apps duplicadas";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Environment = "HOME=/home/${username}";
    };
    script = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      ${pkgs.flatpak}/bin/flatpak remote-modify --user --filter=${flathubFilter} flathub
    '';
  };
}
