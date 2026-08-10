# Step 9 — Facebook / X (Read-Only Where Possible)

> These APIs are restricted and change often. Start read-only and expect manual setup.

## Facebook Page

- https://developers.facebook.com → App → Graph API → Page Access Token (`pages_read_engagement` only).
- `.env`: `FB_PAGE_TOKEN=...`
- `config/openclaw.yaml`: `channels.facebook.enabled: true` + `scope: readonly`

## X (Twitter)

- https://developer.twitter.com → Project → Bearer Token (read-only).
- `.env`: `X_BEARER_TOKEN=...`
- `channels.x_twitter.enabled: true`

Both channels are **poll, not push** — agent fetches every 5–15m per allowlist.

If API approval is blocked, skip — document as "not feasible" and use RSS/webhooks instead.

Next: [TradingView & Binance](09-tradingview-binance.md)
