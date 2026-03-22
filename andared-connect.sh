#!/usr/bin/env bash

set -euo pipefail

connection_id="Andared_Corporativo"
eap_method="${1:-auto}"

if ! command -v nmcli >/dev/null 2>&1; then
  echo "nmcli no esta disponible en este sistema." >&2
  exit 1
fi

ensure_profile() {
  if nmcli -t -f NAME connection show | grep -Fxq "$connection_id"; then
    return
  fi

  nmcli connection add \
    type wifi \
    con-name "$connection_id" \
    ifname "*" \
    ssid "$connection_id" \
    wifi-sec.key-mgmt wpa-eap \
    802-1x.phase2-auth gtc \
    802-1x.password-flags 2 \
    802-1x.system-ca-certs no \
    ipv4.method auto \
    ipv6.method auto >/dev/null
}

connect_once() {
  local method="$1"

  nmcli connection modify "$connection_id" \
    802-1x.eap "$method" \
    802-1x.phase2-auth gtc \
    802-1x.password-flags 2 \
    802-1x.system-ca-certs no

  nmcli --ask connection up "$connection_id"
}

ensure_profile

case "$eap_method" in
  auto)
    if connect_once ttls; then
      exit 0
    fi

    echo "TTLS ha fallado; probando PEAP..." >&2
    connect_once peap
    ;;
  ttls|peap)
    connect_once "$eap_method"
    ;;
  *)
    echo "Uso: andared-connect [auto|ttls|peap]" >&2
    exit 1
    ;;
esac
