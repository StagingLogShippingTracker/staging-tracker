#!/usr/bin/env bash
# Optional: connect Swift FortiGate SSL-VPN from WSL using openfortivpn.
# Install: sudo apt-get install -y openfortivpn
# Config: copy .env.vpn.example to .env.vpn and fill VPN password (not committed).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${HERE}/.env.vpn"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy .env.vpn.example and set VPN_USER / VPN_PASSWORD."
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${VPN_HOST:=edmonton.swiftsupply.ca}"
: "${VPN_PORT:=10443}"
: "${VPN_USER:?Set VPN_USER in .env.vpn}"
: "${VPN_PASSWORD:?Set VPN_PASSWORD in .env.vpn}"
echo "Connecting SSL-VPN to ${VPN_HOST}:${VPN_PORT} as ${VPN_USER} ..."
sudo openfortivpn "${VPN_HOST}:${VPN_PORT}" -u "${VPN_USER}" --trusted-cert=pin-sha256:auto
