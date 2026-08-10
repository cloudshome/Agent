#!/usr/bin/env bash
# OpenClaw — Step 3: 24/7 systemd service (BEST)
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "Need sudo: sudo ./scripts/setup-service.sh"; exit 1; fi
if [[ -t 1 ]]; then BOLD='\033[1m'; GRN='\033[0;32m'; YEL='\033[0;33m'; DIM='\033[2m'; RST='\033[0m'; else BOLD=''; GRN=''; YEL=''; DIM=''; RST=''; fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_SRC="$REPO_ROOT/systemd/openclaw-gateway.service"
SERVICE_DST="/etc/systemd/system/openclaw-gateway.service"

echo -e "${BOLD}OpenClaw — 24/7 Service Setup${RST}"

# dedicated user
if ! id -u openclaw >/dev/null 2>&1; then
  useradd -r -m -d /opt/openclaw -s /usr/sbin/nologin openclaw
  echo -e "${GRN}✔ user openclaw created${RST}"
else
  echo -e "${DIM}user openclaw exists${RST}"
fi

mkdir -p /opt/openclaw/{config,data,logs} /var/log/openclaw /etc/openclaw
chown -R openclaw:openclaw /opt/openclaw /var/log/openclaw 2>/dev/null || true
chmod 750 /opt/openclaw/config 2>/dev/null || true

# copy configs if present in repo
for f in config/openclaw.yaml config/allowlist.yaml; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    cp -n "$REPO_ROOT/$f" "/opt/openclaw/$f" 2>/dev/null || true
    chown openclaw:openclaw "/opt/openclaw/$f" 2>/dev/null || true
  fi
done
if [[ -f "$REPO_ROOT/config/.env" ]]; then
  cp -n "$REPO_ROOT/config/.env" "/opt/openclaw/config/.env" 2>/dev/null || true
  chmod 600 /opt/openclaw/config/.env 2>/dev/null || true
  chown openclaw:openclaw /opt/openclaw/config/.env 2>/dev/null || true
fi

# install service
cp "$SERVICE_SRC" "$SERVICE_DST"
systemctl daemon-reload
systemctl enable openclaw-gateway.service
echo -e "${GRN}✔ enabled openclaw-gateway.service${RST}"

# start
if systemctl start openclaw-gateway.service; then
  echo -e "${GRN}✔ started${RST}"
else
  echo -e "${YEL}▲ start failed — check: journalctl -u openclaw-gateway -n 100 --no-pager${RST}"
  journalctl -u openclaw-gateway -n 80 --no-pager || true
  exit 1
fi

sleep 2
systemctl status openclaw-gateway --no-pager -l | head -n 40 || true
echo -e "\n${BOLD}Test reboot recovery:${RST}  ${DIM}sudo reboot  → after boot: systemctl status openclaw-gateway${RST}"
echo -e "${DIM}Logs: journalctl -u openclaw-gateway -f${RST}"
echo -e "${DIM}Health: sudo -u openclaw openclaw health  (or: curl -s http://127.0.0.1:18789/health)${RST}"
