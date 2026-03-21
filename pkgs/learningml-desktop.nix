# this file has been ai generated

{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, xdg-utils, alsa-lib
, atk, at-spi2-atk, cairo, cups, dbus, expat, fontconfig, freetype
, gdk-pixbuf, glib, gtk3, libdrm, libnotify, libsecret, libuuid, mesa, nspr
, nss, pango, systemd, xorg }:

stdenv.mkDerivation (finalAttrs: {
  pname = "learningml-desktop";
  version = "1.4.3";

  src = fetchurl {
    url = "https://github.com/LearningML-Education/learningml-desktop-releases/releases/download/${finalAttrs.version}/learningml-desktop_${finalAttrs.version}_amd64.deb";
    hash = "sha256-08r5l5daq6nn3xqdaxfqvhs55dv398x43pd1nmblixd1pipgw767";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
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
    xdg-utils
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXrender
    xorg.libXScrnSaver
    xorg.libXtst
    xorg.libxcb
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
      --add-flags "--no-sandbox"

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
