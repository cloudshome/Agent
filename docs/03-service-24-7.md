# Step 3 — 24/7 Systemd Service

> Makes gateway survive reboot, crash, and log out. Based on [OpenClaw Gateway docs](https://docs.openclaw.ai/).

## One command

```bash
sudo ./scripts/setup-service.sh
```

It:

- Creates `openclaw` system user (no login)
- Installs `systemd/openclaw-gateway.service` → `/etc/systemd/system/`
- Enables at boot, starts now

## Manual

```bash
sudo cp systemd/openclaw-gateway.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw-gateway
systemctl status openclaw-gateway --no-pager
journalctl -u openclaw-gateway -f
```

## Verify reboot (BEST)

```bash
sudo reboot
# after reboot
systemctl status openclaw-gateway --no-pager
openclaw health
```

If `systemctl` not PID 1 (WSL), use `pm2` or `wsl --install` systemd — not recommended for prod.

## Hardening in service file

`NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`, `MemoryMax=2G`, etc. See the file.

Next: [Step 4 — Local Model](04-local-model.md)
