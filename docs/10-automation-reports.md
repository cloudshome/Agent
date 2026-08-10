# Step 12 — Schedulers & Reports

## Daily WhatsApp Digest (09:00)

`config/openclaw.yaml`:

```yaml
automation:
  schedulers:
    - id: daily-report
      enabled: true
      cron: "0 9 * * *"
      actions:
        - report --to whatsapp --template daily
        - report --to telegram
    - id: hourly-health
      enabled: true
      cron: "0 * * * *"
      actions:
        - healthcheck --to telegram --on-fail-only
```

Templates live in `scripts/report.py` (you create it) — pulls Gmail unread, Binance balance (readonly), TradingView last signal.

## Real-time Monitors

```yaml
  monitors:
    - id: gmail-urgent
      enabled: true
      source: gmail
      filter: "is:unread label:urgent"
      action: "notify --to telegram --priority high"
    - id: tv-signal
      enabled: true
      source: tradingview
      action: "notify --to telegram --template signal"
```

Restart after edits: `sudo systemctl restart openclaw-gateway`.

Logs: `journalctl -u openclaw-gateway | grep -E "scheduler|monitor|report"`

Next: [Hardening](11-hardening.md)
