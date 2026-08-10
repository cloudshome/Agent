# Step 14 — Reboot & Auto-Recovery

> The "pull the plug" test — if this fails, 24/7 is a lie.

## Test

```bash
sudo reboot
# wait 60s, ssh back
systemctl status openclaw-gateway --no-pager
journalctl -u openclaw-gateway --since "5 min ago" --no-pager | tail -n 80
openclaw health
curl -fsS http://127.0.0.1:18789/health || echo "health endpoint down"
# channels
openclaw channels whatsapp status
openclaw channels telegram status
```

Expected: `active (running)` within 10s of boot, health OK, no `FAIL`.

## If it fails

```bash
systemctl is-enabled openclaw-gateway  # should be enabled
sudo systemctl enable openclaw-gateway
journalctl -u openclaw-gateway -b --no-pager | grep -i "error\|fail"
# common: bad yaml, missing .env, ollama not ready (gateway retries — increase RestartSec)
sudo systemd-analyze blame | head
```

## Health timer (BEST)

```bash
# cron every 5m
crontab -e
# */5 * * * * /opt/openclaw/scripts/healthcheck.sh >> /var/log/openclaw/health.log 2>&1 || systemctl restart openclaw-gateway
```

Or systemd timer — see `systemd/openclaw-health.timer` (create if needed).

You are done — BEST tier achieved. Keep `scripts/harden.sh` in CI / weekly cron.
