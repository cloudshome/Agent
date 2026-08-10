# Architecture — Detailed

See README for Mermaid overview. This doc explains data flow and why each hop is locked.

## Flow

```
WhatsApp/Telegram/Discord  ─┐
Gmail ──────────────────────┤
Facebook/X ─────────────────┤→  OpenClaw Gateway (127.0.0.1:18789)  →  Ollama (127.0.0.1:11434)
TradingView webhook ────────┤         │ audit.jsonl + allowlist
Binance API ────────────────┘         └→  Your reports (WhatsApp/Telegram)
```

- Every inbound webhook/channels message → `audit.jsonl` (who, payload hash, decision).
- Tool calls → `allowlist.yaml` check → `DENIED` if not listed.
- Binance trade → `require_approval_for: ["trade"]` + `daily_trade_limit_usd` + human confirm.

## Ports

- `18789` gateway — local only
- `11434` Ollama — local only
- No inbound internet — tunnels only (Tailscale, Cloudflare)

## Files

- `/opt/openclaw/config/openclaw.yaml` — gateway config (no secrets)
- `/opt/openclaw/config/.env` — 600, or `.env.age`
- `/opt/openclaw/data/*` — channel sessions (whatsapp baileys, gmail token)
- `/var/log/openclaw/*.jsonl` — audit + gateway log
