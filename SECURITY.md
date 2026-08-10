# SECURITY — Locked Down By Default

> OpenClaw can execute commands and interact with connected accounts — start conservative. This document is the law for this repo.

## Threat Model

| Actor | What they can do if we are sloppy |
| :--- | :--- |
| Prompt injection via email/Telegram | Make agent run `rm -rf` or exfiltrate secrets |
| Compromised Discord/Facebook token | DM spam, social impersonation |
| Bad TradingView webhook | Fake signal → Binance trade → loss |
| Leaked `.env` | Full account takeover |

**We design for the worst case:** every external input is untrusted.

## The 5 Laws

1.  **Deny by default.** `security.deny_by_default: true`. No tool runs unless allowlisted.
2.  **Allowlist, never blocklist.** You list the 5 commands you need, not the 500 you don't.
3.  **Read-only first.** Every channel starts `scope: readonly`. Write/trade is a separate PR with review.
4.  **No secrets in git.** `.env` is `age`-encrypted. Example file is `.env.example` only.
5.  **Audit everything.** `jsonl` logs at `/var/log/openclaw/` — who, what, when, prompt.

## Credential Storage (BEST tier)

```bash
# 1. install age
sudo apt install age -y
age-keygen -o ~/.age/openclaw.key
chmod 600 ~/.age/openclaw.key

# 2. encrypt .env
age -r age1... -o config/.env.age config/.env

# 3. decrypt at service start via systemd credentials (never on disk plain)
# see systemd/openclaw-gateway.service — LoadCredentialEncrypted=
```

Fallback (GOOD tier): `chmod 600 config/.env` + `gitignore` — works, but age is better.

## Allowlist — Example

`config/allowlist.yaml`:

```yaml
# Only these are executable. Everything else → "denied by policy"
exec:
  allow:
    - "curl -s https://api.binance.com/*"
    - "python3 /opt/openclaw/scripts/report.py *"
    - "systemctl status openclaw-gateway"
  deny: ["*"]  # explicit

fs:
  read:
    - "/opt/openclaw/config/*"
    - "/var/log/openclaw/*"
  write:
    - "/var/log/openclaw/*"
    - "/tmp/openclaw-*"

channels:
  telegram:
    allowFrom: ["123456789"]  # your TG id only
    allowGroups: []           # no groups until hardened
  gmail:
    scope: "gmail.readonly"
```

## Channel Permissions Ladder

| Level | Gmail | Telegram | Binance | When |
| :--- | :--- | :--- | :--- | :--- |
| 0 | disabled | disabled | disabled | Fresh install |
| 1 | `readonly` label filter | DM only, you | `readonly` key | After step 1 |
| 2 | `send` scoped to you | + allowlisted group | `trade` with daily limit | After audit review |
| 3 | full | full | full | Never — you don't need it |

## Hardening Checklist (run `scripts/harden.sh`)

- [ ] `gateway.bind = 127.0.0.1` (not `0.0.0.0`)
- [ ] UFW: `sudo ufw allow 22/tcp && sudo ufw enable` (no gateway port open)
- [ ] No secrets in `git log` — `git secrets --scan`
- [ ] `age` encrypted `.env.age` present, plain `.env` gitignored
- [ ] `allowlist.yaml` has ≤10 exec entries
- [ ] Binance key is `read-only` (check on binance.com)
- [ ] WhatsApp is dedicated number, not personal
- [ ] `journalctl -u openclaw-gateway` shows no `denied` spam (tune allowlist)

## Incident Response

1. `sudo systemctl stop openclaw-gateway`
2. `sudo journalctl -u openclaw-gateway --since "1 hour ago" | grep -i denied`
3. Rotate token: `age -d config/.env.age | grep TOKEN` → revoke at provider → re-encrypt
4. File an issue with redacted logs.

## What We Never Do

- ❌ `gateway.expose: true` without Tailscale/SSH tunnel
- ❌ `exec: ["*"]`
- ❌ Store `BINANCE_SECRET` in plain `openclaw.yaml`
- ❌ Give agent `gmail.modify` on day one
- ❌ Auto-trade without `require_approval_for: ["trade"]` + daily limit

---

Security is a feature, not a footnote. If a step tells you to `--allow-all`, it's wrong — open an issue.
