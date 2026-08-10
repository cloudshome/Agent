# Step 13 — Lock Down

Run the audit:

```bash
./scripts/harden.sh
# fix what it complains about
./scripts/harden.sh --fix
./scripts/harden.sh  # should be all PASS
```

Checklist:

- [ ] `gateway.bind = 127.0.0.1` (no `0.0.0.0`)
- [ ] UFW on, only 22 open
- [ ] `.env` is 600 and gitignored, `.env.age` exists
- [ ] `allowlist.yaml` ≤10 entries, no `*`
- [ ] Binance key is read-only (verify on binance.com)
- [ ] WhatsApp is dedicated number
- [ ] `journalctl -u openclaw-gateway | grep DENIED` — tune allowlist, not open it

Backup encrypted secrets:

```bash
age -r age1... -o config/.env.age config/.env
cp config/.env.age /mnt/backup/openclaw-$(date +%F).age
```

Next: [Reboot Test](12-recovery.md)
