{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, wrapGAppsHook3
, xdg-utils, alsa-lib, atk, at-spi2-atk, at-spi2-core, cairo, cups, dbus, expat
, fontconfig, freetype, ffmpeg, gdk-pixbuf, glib, glib-networking
, gsettings-desktop-schemas, gtk3, libdrm, libnotify, libsecret, libuuid
, mesa, nspr, nss, pango, systemd, udev, libx11, libxcomposite, libxdamage
, libxext, libxfixes, libxrandr, libxrender, libxscrnsaver, libxtst
, libxcb, libxshmfence, libxkbcommon }:

stdenv.mkDerivation (finalAttrs: {
  pname = "learningml-desktop";
  version = "1.4.3";

  dontWrapGApps = true;

  src = fetchurl {
    url = "https://github.com/LearningML-Education/learningml-desktop-releases/releases/download/${finalAttrs.version}/learningml-desktop_${finalAttrs.version}_amd64.deb";
    hash = "sha256-xxz+bryh9UhXtaHdQTpKY7dSNNzYddVwH9YarFqhJSM=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    glib-networking
    gsettings-desktop-schemas
    gtk3
    libdrm
    libnotify
    libsecret
    libuuid
    mesa
    nspr
    nss
    pango
    systemd
    udev
    xdg-utils
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxrender
    libxscrnsaver
    libxtst
    libxcb
    libxshmfence
    libxkbcommon
  ];

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack
    ar x "$src"
    tar xf data.tar.xz
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/learningml-desktop $out/share

    cp -r opt/LearningMLDesktop/* $out/libexec/learningml-desktop/
    cp -r usr/share/icons $out/share/

    install -Dm644 \
      usr/share/applications/learningml-desktop.desktop \
      $out/share/applications/learningml-desktop.desktop

    makeWrapper \
      $out/libexec/learningml-desktop/learningml-desktop \
      $out/bin/learningml-desktop \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--no-sandbox" \
      --add-flags "--disable-gpu-sandbox" \
      --add-flags "--disable-gpu" \
      --add-flags "--disable-software-rasterizer"

    substituteInPlace $out/share/applications/learningml-desktop.desktop \
      --replace-fail "/opt/LearningMLDesktop/learningml-desktop" "$out/bin/learningml-desktop"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Desktop version of LearningML";
    homepage = "https://github.com/LearningML-Education/learningml-desktop-releases";
    license = licenses.cc0;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "learningml-desktop";
  };
})
