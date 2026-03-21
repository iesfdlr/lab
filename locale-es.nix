{ lib, username, ... }:

let
  homeDir = "/home/${username}";
  locale = "es_ES.UTF-8";
in
{
  services.xserver.xkb.layout = "es";
  console.useXkbConfig = true;

  i18n.defaultLocale = locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = locale;
    LC_IDENTIFICATION = locale;
    LC_MEASUREMENT = locale;
    LC_MESSAGES = locale;
    LC_MONETARY = locale;
    LC_NAME = locale;
    LC_NUMERIC = locale;
    LC_PAPER = locale;
    LC_TELEPHONE = locale;
    LC_TIME = locale;
  };

  # plasma per user override with system locale
  system.activationScripts.plasmaSpanishLocale = lib.stringAfter [ "users" ] ''
    if [ -d "${homeDir}" ]; then
      install -d -m 700 -o ${username} -g users "${homeDir}/.config"
      cat > "${homeDir}/.config/plasma-localerc" <<'EOF'
[Formats]
LANG=es_ES.UTF-8
LC_ADDRESS=es_ES.UTF-8
LC_IDENTIFICATION=es_ES.UTF-8
LC_MEASUREMENT=es_ES.UTF-8
LC_MESSAGES=es_ES.UTF-8
LC_MONETARY=es_ES.UTF-8
LC_NAME=es_ES.UTF-8
LC_NUMERIC=es_ES.UTF-8
LC_PAPER=es_ES.UTF-8
LC_TELEPHONE=es_ES.UTF-8
LC_TIME=es_ES.UTF-8

[Translations]
LANGUAGE=es
EOF
      chown ${username}:users "${homeDir}/.config/plasma-localerc"
      chmod 600 "${homeDir}/.config/plasma-localerc"
    fi
  '';
}
