# Step 4 — Local AI Model (Ollama)

> OpenClaw is free — the model doesn't have to be. We run **local, offline inference** so no API bill.

## Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama --version
sudo systemctl enable --now ollama  # if not auto
```

## Pick model by RAM (from Step 1 report)

| RAM | Model | Pull |
| :--- | :--- | :--- |
| 32 GB+ | `llama3.1:70b-q4` | `ollama pull llama3.1:70b` |
| 16 GB | `llama3.1:8b` | `ollama pull llama3.1:8b` |
| 8 GB | `llama3.2:3b` | `ollama pull llama3.2:3b` |
| 4 GB | `qwen2:1.5b` | `ollama pull qwen2:1.5b` |

```bash
ollama pull llama3.1:8b
ollama run llama3.1:8b "Hello from OpenClaw"
# Ctrl+D to exit
ollama list
```

## Wire to OpenClaw

In `config/openclaw.yaml`:

```yaml
models:
  default: local
  local:
    provider: ollama
    host: http://127.0.0.1:11434
    model: llama3.1:8b
```

Restart: `sudo systemctl restart openclaw-gateway && journalctl -u openclaw-gateway -n 50`

Cloud fallback is `enabled: false` — turn on per task only.

Next: [Step 5 — WhatsApp](05-channels-whatsapp.md)
