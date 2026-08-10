#!/usr/bin/env bash
# Health check for cron / systemd timer — exits 0 healthy, 1 unhealthy
set -euo pipefail
URL="${OPENCLAW_HEALTH_URL:-http://127.0.0.1:18789/health}"
if curl -fsS --max-time 5 "$URL" >/dev/null 2>&1; then
  echo "$(date -Iseconds) OK $URL"
  exit 0
fi
# fallback: systemd
if systemctl is-active --quiet openclaw-gateway 2>/dev/null; then
  echo "$(date -Iseconds) WARN $URL unreachable but systemd active"
  exit 1
fi
echo "$(date -Iseconds) FAIL gateway down"
exit 1
