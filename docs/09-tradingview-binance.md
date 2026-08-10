# Step 10–11 — TradingView & Binance

> **Both are money-adjacent. Both stay read-only until hardening passes.** Webhook secret is mandatory.

## TradingView Webhook

1. `config/.env`: `TV_WEBHOOK_SECRET=$(openssl rand -hex 16)`
2. `config/openclaw.yaml`:

```yaml
channels:
  tradingview:
    enabled: true
    webhook_secret: ${TV_WEBHOOK_SECRET}
    listen_path: /hooks/tradingview
```

3. Expose **only via tunnel** (Tailscale Funnel or `ssh -R` or Cloudflare Tunnel) — never open firewall.
4. In TradingView alert: Webhook URL `https://your-tunnel/hooks/tradingview`, body:

```json
{"secret":"<TV_WEBHOOK_SECRET>","symbol":"{{ticker}}","price":"{{close}}","note":"{{strategy.order.comment}}"}
```

Test: `curl -H "Authorization: Bearer $TV_WEBHOOK_SECRET" http://127.0.0.1:18789/hooks/tradingview -d '{"test":1}'`

→ Should notify Telegram (read-only, no trade).

## Binance (Read-Only)

1. https://www.binance.com → API Management → Create **Read-Only** key (disable Trading, disable Withdraw, enable IP allowlist → your PC's IP).
2. `.env`:

```
BINANCE_API_KEY=...
BINANCE_API_SECRET=...
BINANCE_TESTNET=true
```

3. `config/openclaw.yaml`:

```yaml
channels:
  binance:
    enabled: true
    scope: readonly
    canTrade: false
    testnet: true
    daily_trade_limit_usd: 0
```

4. Verify:

```bash
openclaw channels binance balance --testnet
# should list balances, should FAIL on trade:
openclaw channels binance trade --symbol BTCUSDT --side buy --dry-run
```

### Escalation (BEST only, after `scripts/harden.sh` PASS)

- New key with `Spot Trading` enabled, IP-locked, `daily_trade_limit_usd: 100`, `require_approval_for: ["trade"]`.
- Never enable `Withdraw`.

Next: [Automation & Reports](10-automation-reports.md)
