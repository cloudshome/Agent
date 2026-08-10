# Step 4 — Local AI Model (Ollama) — No API bill, loopback only

> OpenClaw is free — the model doesn't have to be. We run **local, offline inference** on `127.0.0.1:11434` so the gateway never needs the internet to think.

You already saw your RAM in `~/openclaw-system-report.json` — this step picks the model that actually fits.

## Option A — One command (recommended, picks by RAM)

```bash
./scripts/setup-ollama.sh
# or pick explicitly:
./scripts/setup-ollama.sh llama3.1:8b
./scripts/setup-ollama.sh qwen2:0.5b --no-pull   # just choose + wire hint, no download
```

What it does (idempotent, safe to rerun):

1. Installs Ollama if missing (`https://ollama.com/install.sh`)
2. Detects RAM → chooses: `3.8GB→qwen2:0.5b`, `8GB→llama3.2:3b`, `16GB→llama3.1:8b`, `32GB+→llama3.1:8b` (70b optional)
3. `ollama pull <model>` + `ollama list` + `ollama run <model> "Hello"` test
4. Prints the exact `config/openclaw.yaml` snippet to wire

## Option B — Manual

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama --version
sudo systemctl enable --now ollama  # if not auto

# Pick model by RAM (from Step 1 report)
# 32GB+ → llama3.1:70b  | 16GB → llama3.1:8b  | 8GB → llama3.2:3b  | 4GB → qwen2:1.5b  | <4GB → qwen2:0.5b
ollama pull llama3.1:8b
ollama run llama3.1:8b "Hello from OpenClaw"
# Ctrl+D to exit
ollama list
```

## Wire to OpenClaw (same for both options)

In `config/openclaw.yaml` (or `config/openclaw.yaml.example` → copy first):

```yaml
models:
  default: local
  local:
    provider: ollama
    host: http://127.0.0.1:11434
    model: llama3.1:8b   # ← use what setup-ollama.sh suggested for your RAM
    keep_alive: "30m"
  cloud_fallback:
    enabled: false       # keep false — local first
```

Restart & verify:

```bash
sudo systemctl restart openclaw-gateway
journalctl -u openclaw-gateway -n 50 | grep -i -E "ollama|model"
curl -s http://127.0.0.1:11434/api/tags | python3 -m json.tool | head -n 30
openclaw health  # should show model:ok
```

Cloud fallback stays `enabled: false` — turn on **per task only** if you want a cloud model for a specific channel.

## Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| `ollama: command not found` after install | `hash -r` + reopen terminal; check `/usr/local/bin` on PATH |
| `pull` fails `no space` | `df -h /` need ~1× model size free; `ollama rm` old models |
| Inference hangs | RAM too small for model — use smaller (`qwen2:0.5b`) |
| `curl 11434` refused | `sudo systemctl status ollama --no-pager` + `journalctl -u ollama` |

Visual: dashboard now has a **Local Brain** card (see `dashboard/index.html`).

Next: [Step 5 — WhatsApp](05-channels-whatsapp.md)
