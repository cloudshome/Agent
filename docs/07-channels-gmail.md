# Step 8 — Gmail (Read-Only First)

> Start `readonly` — escalate to `send` only after you trust the allowlist.

## OAuth

1. https://console.cloud.google.com → New project → Enable Gmail API → Credentials → OAuth 2.0 Client ID (Desktop) → Download JSON.
2. Save as `data/gmail/credentials.json` (`chmod 600`).
3. `config/openclaw.yaml`:

```yaml
channels:
  gmail:
    enabled: true
    scope: readonly
    label_filter: "label:openclaw-test"
```

4. First auth:

```bash
openclaw channels gmail auth
# opens browser → consent → token saved to data/gmail/token.json
openclaw channels gmail list --label openclaw-test --limit 3
```

## Hardening

- Filter narrow (`label:openclaw-test`) — not `INBOX`.
- `scope: readonly` — no `gmail.send` until Step 13 audit.
- `data/gmail/token.json` chmod 600, never committed.

Next: [Facebook / X](08-channels-social.md)
