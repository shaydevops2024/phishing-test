#!/bin/bash
#
# Deploy the phishing-test app on a fresh Ubuntu server.
# Installs Docker + Compose (if missing), then builds and starts the stack.
#
# Usage:  copy this whole project to the server, then run:
#   cd phishing-test
#   ./deploy.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Phishing-test deploy starting in: $SCRIPT_DIR"

# --- sudo helper (works whether or not you're already root) ----------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

# --- 1. Ensure .env exists -------------------------------------------------
if [ ! -f .env ]; then
  echo "==> No .env found; creating one from .env.example"
  cp .env.example .env
  echo "    !! Edit .env to set a strong POSTGRES_PASSWORD, then re-run ./deploy.sh"
  exit 1
fi

# --- 2. Install Docker if missing ------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "==> Docker not found; installing Docker Engine + Compose plugin"
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -y
  $SUDO apt-get install -y ca-certificates curl gnupg

  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  $SUDO systemctl enable --now docker
  $SUDO usermod -aG docker "$USER" || true
  echo "==> Docker installed."
else
  echo "==> Docker already present: $(docker --version)"
fi

# --- 3. Pick the compose command -------------------------------------------
# 'docker compose' (v2 plugin) is preferred; fall back to legacy 'docker-compose'.
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "ERROR: no docker compose available." >&2
  exit 1
fi

# If the current user isn't in the docker group yet (first install), use sudo.
if ! docker info >/dev/null 2>&1; then
  COMPOSE="$SUDO $COMPOSE"
fi

# --- 4. Build and start ----------------------------------------------------
echo "==> Building and starting containers"
$COMPOSE up -d --build

echo "==> Waiting for the web app to respond..."
for i in $(seq 1 30); do
  if curl -fs http://localhost/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo
echo "============================================================"
echo " Deploy complete."
$COMPOSE ps
PUBLIC_IP="$(curl -s https://checkip.amazonaws.com 2>/dev/null || echo "<server-ip>")"
echo
echo " App URL:  http://${PUBLIC_IP}/"
echo
echo " View captured data:"
echo "   $COMPOSE exec db psql -U \$POSTGRES_USER -d \$POSTGRES_DB \\"
echo "     -c \"SELECT full_name, work_email, public_ip, captured_at FROM captures ORDER BY captured_at DESC;\""
echo "============================================================"
