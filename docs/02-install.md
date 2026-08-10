# Step 2 — Install OpenClaw Gateway

> After Step 1 is green.

Official docs: https://docs.openclaw.ai/

## Install (automated)

```bash
./scripts/install-openclaw.sh
```

What it does:

1. Checks Node ≥18
2. `npm install -g openclaw` (or `@openclaw/gateway` — probes)
3. Creates `/opt/openclaw` + `config/openclaw.yaml` (all channels `enabled: false`)
4. Leaves secrets empty — you fill them per channel later

Idempotent — safe to rerun.

## Manual (if script fails)

```bash
# Node 22
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs
node --version  # v22.x

# Gateway
sudo npm install -g openclaw
openclaw --version
openclaw init --help  # or openclaw gateway --help — follow official output
openclaw health
```

If `openclaw` not on PATH:

```bash
echo 'export PATH=$(npm bin -g):$PATH' >> ~/.bashrc && source ~/.bashrc
hash -r
which openclaw
```

## Verify

```bash
openclaw health
# expected: gateway: ok  config: ok  channels: 0 enabled (locked down)

# config is deny-by-default?
grep -q 'deny_by_default: true' config/openclaw.yaml && echo "✔ locked down"
```

## Next

Do **not** enable channels yet. Next is 24/7 service:

→ [Step 3 — 24/7 Service](03-service-24-7.md)
