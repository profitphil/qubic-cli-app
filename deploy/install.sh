#!/usr/bin/env bash
# One-shot VPS installer. Run as root on a fresh Ubuntu 24.04.
#
#   curl -fsSL https://YOUR-REPO/install.sh | sudo bash -s -- DOMAIN
#
# Or copy this file to the server and run:
#   sudo DOMAIN=api.example.com bash install.sh
#
# If you don't have a domain, pass DOMAIN=_ to listen on :8787 directly
# (you'll need to accept an untrusted cert, or tunnel via Tailscale).
set -euo pipefail

DOMAIN="${DOMAIN:-${1:-_}}"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merr:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root"

log "installing deps"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  build-essential cmake git ca-certificates curl ufw \
  debian-keyring debian-archive-keyring apt-transport-https golang-go

# ---- build qubic-cli -------------------------------------------------------
if [[ ! -x /usr/local/bin/qubic-cli ]]; then
  log "building qubic-cli"
  tmp=$(mktemp -d)
  git clone --depth 1 https://github.com/qubic/qubic-cli.git "$tmp/src"
  # qubic-cli's .gitmodules uses git@github.com URLs; rewrite to https
  git -C "$tmp/src" config --file=.gitmodules --get-regexp 'submodule\..*\.url' \
    | awk '{print $1, $2}' \
    | while read key url; do
        https=${url/git@github.com:/https:\/\/github.com\/}
        git -C "$tmp/src" config --file=.gitmodules "$key" "$https"
      done
  git -C "$tmp/src" submodule sync
  git -C "$tmp/src" submodule update --init --recursive --depth 1
  cmake -S "$tmp/src" -B "$tmp/build" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$tmp/build" -j"$(nproc)"
  install -m 0755 "$tmp/build/qubic-cli" /usr/local/bin/qubic-cli
  rm -rf "$tmp"
fi
/usr/local/bin/qubic-cli -help >/dev/null 2>&1 || true
log "qubic-cli installed: $(/usr/local/bin/qubic-cli -help 2>&1 | head -1 || echo ok)"

# ---- system user & dirs ----------------------------------------------------
id qubic &>/dev/null || useradd --system --home /var/lib/qubic-api --shell /usr/sbin/nologin qubic
install -d -o qubic -g qubic -m 0700 /var/lib/qubic-api

# ---- api binary ------------------------------------------------------------
log "building api"
srcdir=$(cd "$(dirname "$0")/../backend" && pwd)
pushd "$srcdir" >/dev/null
CGO_ENABLED=0 go build -ldflags '-s -w' -o /usr/local/bin/qubic-api .
popd >/dev/null
chmod 0755 /usr/local/bin/qubic-api

# ---- env file with random token -------------------------------------------
if [[ ! -f /etc/qubic-api.env ]]; then
  TOKEN=$(head -c 48 /dev/urandom | base64 | tr -d '=+/' | cut -c1-48)
  cat >/etc/qubic-api.env <<EOF
API_TOKEN=${TOKEN}
QUBIC_CLI=/usr/local/bin/qubic-cli
QUBIC_WORKDIR=/var/lib/qubic-api
LISTEN=127.0.0.1:8787
EOF
  chmod 0640 /etc/qubic-api.env
  chown root:qubic /etc/qubic-api.env
  log "GENERATED API TOKEN (save this, you'll paste it into the iOS app):"
  printf '\n    %s\n\n' "${TOKEN}"
fi

# ---- systemd ---------------------------------------------------------------
install -m 0644 "$(dirname "$0")/qubic-api.service" /etc/systemd/system/qubic-api.service
systemctl daemon-reload
systemctl enable --now qubic-api
sleep 1
systemctl status qubic-api --no-pager | head -10

# ---- caddy for HTTPS -------------------------------------------------------
if [[ "$DOMAIN" != "_" ]]; then
  if ! command -v caddy >/dev/null; then
    log "installing caddy"
    curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
      | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
      > /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -y
    apt-get install -y caddy
  fi
  sed "s/^DOMAIN/${DOMAIN}/" "$(dirname "$0")/Caddyfile" > /etc/caddy/Caddyfile
  systemctl reload caddy
  log "caddy configured for ${DOMAIN} — point DNS here"
  ufw allow 80/tcp  || true
  ufw allow 443/tcp || true
else
  log "no DOMAIN provided — api is on 127.0.0.1:8787 only"
  log "use ssh tunnel or tailscale to reach it from your phone"
fi

ufw allow 22/tcp || true
yes | ufw enable || true

log "done. token is in /etc/qubic-api.env (API_TOKEN=...)"
log "test:  curl -s http://127.0.0.1:8787/healthz"
