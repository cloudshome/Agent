# Step 5 — WhatsApp (Reports)

> **Dedicated number recommended.** Self-chat works but burns your personal session.

OpenClaw uses **WhatsApp Web / Baileys + QR pairing** ([docs](https://docs.openclaw.ai/channels/whatsapp)).

## Setup

1. Get a dedicated number (or use personal — not recommended for 24/7).
2. In `config/openclaw.yaml`:

```yaml
channels:
  whatsapp:
    enabled: true
    mode: report-only   # start report-only
    allowFrom: ["+33612345678"]  # your E.164
```

3. Restart and pair:

```bash
sudo systemctl restart openclaw-gateway
journalctl -u openclaw-gateway -f  # shows QR
# or
openclaw channels whatsapp qr
```

Scan QR with WhatsApp → Linked Devices → Link a device.

Test:

```bash
openclaw channels whatsapp send --to +33612345678 --text "OpenClaw WhatsApp OK"
```

## Daily report (after Step 12)

```yaml
automation:
  schedulers:
    - id: daily-report
      cron: "0 9 * * *"
      actions: [ "report --to whatsapp --template daily" ]
```

Next: [Telegram & Discord](06-channels-telegram-discord.md)
