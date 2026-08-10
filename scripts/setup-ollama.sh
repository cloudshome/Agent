#!/usr/bin/env bash
# OpenClaw — Step 4: Local Model (Ollama) — BEST tier
# Installs Ollama, picks model by RAM (from Step 1 logic), pulls, verifies.
# Idempotent, safe to rerun. Respects existing install.
set -uo pipefail
# keep -e off for retry logic, handle manually
if [[ -t 1 ]]; then BOLD='\033[1m'; GRN='\033[0;32m'; YEL='\033[0;33m'; RED='\033[0;31m'; DIM='\033[2m'; RST='\033[0m'; else BOLD=''; GRN=''; YEL=''; RED=''; DIM=''; RST=''; fi

MODEL_OVERRIDE="${1:-}"
DO_PULL=1
[[ "${2:-}" == "--no-pull" ]] && DO_PULL=0

echo -e "${BOLD}OpenClaw — Step 4: Local Model (Ollama)${RST}  ${DIM}[BEST]${RST}"
echo -e "${DIM}Fits your RAM — no API bill — offline inference on 127.0.0.1:11434${RST}\n"

# ── detect RAM ────────────────────────────────────────────────────────────
MEM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
MEM_GB=$(awk "BEGIN{printf \"%.1f\", $MEM_KB/1024/1024}")
MEM_INT=${MEM_GB%.*}; [[ -z "$MEM_INT" ]] && MEM_INT=0
if [[ -n "$MODEL_OVERRIDE" ]]; then
  MODEL="$MODEL_OVERRIDE"
  REASON="override: $MODEL_OVERRIDE"
elif [[ "$MEM_INT" -ge 32 ]]; then
  MODEL="llama3.1:8b"  # default safe for 32GB; 70b is heavy even on 32GB for this gateway use-case
  # For 32GB+ power users: uncomment next line to use 70b-q4
  # MODEL="llama3.1:70b"
  REASON="RAM ${MEM_GB}GB ≥32 → $MODEL (70b-q4 available if you want: ollama pull llama3.1:70b)"
elif [[ "$MEM_INT" -ge 16 ]]; then
  MODEL="llama3.1:8b"
  REASON="RAM ${MEM_GB}GB 16–31 → $MODEL (BEST for this tier)"
elif [[ "$MEM_INT" -ge 8 ]]; then
  MODEL="llama3.2:3b"
  REASON="RAM ${MEM_GB}GB 8–15 → $MODEL (fits 8GB)"
elif [[ "$MEM_INT" -ge 4 ]]; then
  MODEL="qwen2:1.5b"
  REASON="RAM ${MEM_GB}GB 4–7 → $MODEL (tight, but works)"
else
  MODEL="qwen2:0.5b"
  REASON="RAM ${MEM_GB}GB <4 → $MODEL (tiny) — consider cloud fallback"
fi

echo -e "  Detected RAM: ${BOLD}${MEM_GB} GB${RST}  →  ${GRN}${MODEL}${RST}"
echo -e "  ${DIM}${REASON}${RST}"
echo -e "  ${DIM}Guide: 0.5–1.5B≈4GB  •  3B≈8GB  •  8B≈16GB  •  70B≈32GB Q4${RST}\n"

# ── install Ollama if missing ─────────────────────────────────────────────
if command -v ollama >/dev/null 2>&1; then
  echo -e "${GRN}✔ Ollama already installed:${RST} $(ollama --version 2>&1 | head -n1)"
else
  echo -e "${YEL}→ Installing Ollama (official install.sh)…${RST}  ${DIM}needs sudo for /usr/local/bin${RST}"
  if curl -fsSL https://ollama.com/install.sh | sh; then
    echo -e "${GRN}✔ Ollama installed${RST}: $(ollama --version 2>&1 | head -n1)"
  else
    echo -e "${RED}✘ Ollama install failed${RST} — try manually: curl -fsSL https://ollama.com/install.sh | sh"
    exit 1
  fi
fi

# ensure service
if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet ollama 2>/dev/null; then
    echo -e "${GRN}✔ ollama.service active${RST}"
  else
    echo -e "${DIM}  starting ollama.service…${RST}"
    sudo systemctl enable --now ollama 2>/dev/null || sudo service ollama start 2>/dev/null || (ollama serve >/tmp/ollama.log 2>&1 & echo $! > /tmp/ollama.pid; sleep 3)
    if systemctl is-active --quiet ollama 2>/dev/null || pgrep -x ollama >/dev/null 2>&1; then
      echo -e "${GRN}✔ ollama running${RST}"
    else
      echo -e "${YEL}▲ ollama not as systemd — running as background process (ok for test)${RST}"
    fi
  fi
fi

# wait for API
echo -e "${DIM}  waiting for http://127.0.0.1:11434 …${RST}"
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then echo -e "${GRN}✔ Ollama API ready${RST}"; break; fi
  sleep 1
  if [[ $i -eq 10 ]]; then echo -e "${YEL}▲ API not ready after 10s — check: journalctl -u ollama -n 50${RST}"; fi
done

# ── pull model ────────────────────────────────────────────────────────────
if [[ $DO_PULL -eq 0 ]]; then
  echo -e "${DIM}Skipping pull (--no-pull) — chosen model: $MODEL${RST}"
else
  echo -e "\n${BOLD}Pulling $MODEL …${RST}  ${DIM}(first pull is large: 0.5B≈400MB, 3B≈2GB, 8B≈4.7GB, 70B≈40GB)${RST}"
  if ollama pull "$MODEL" 2>&1 | tail -n 20; then
    echo -e "${GRN}✔ pulled $MODEL${RST}"
  else
    echo -e "${RED}✘ pull failed — check disk: df -h / and try ollama pull $MODEL manually${RST}"
    exit 1
  fi
fi

# ── verify ────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}Verify…${RST}"
ollama list 2>&1 | head -n 20 || true
echo ""
# quick inference (tiny, 5 sec timeout)
echo -e "${DIM}Test inference: ollama run $MODEL \"Hello from OpenClaw (reply in 5 words)\"${RST}"
if timeout 30 ollama run "$MODEL" "Hello from OpenClaw. Reply in 5 words." 2>&1 | head -n 10; then
  echo -e "${GRN}✔ inference OK${RST}"
else
  echo -e "${YEL}▲ inference timed out or slow — model is installed but may need more RAM${RST}"
fi

# ── wire hint ─────────────────────────────────────────────────────────────
echo ""
cat <<WIRE
${BOLD}Wire to OpenClaw — add to config/openclaw.yaml:${RST}
${DIM}─────────────────────────────${RST}
models:
  default: local
  local:
    provider: ollama
    host: http://127.0.0.1:11434
    model: $MODEL     # ← chosen for your ${MEM_GB}GB
    keep_alive: "30m"
  cloud_fallback:
    enabled: false   # keep false — local first
${DIM}─────────────────────────────${RST}
Then:
  sudo systemctl restart openclaw-gateway
  journalctl -u openclaw-gateway -n 50 | grep -i -E "ollama|model"
  curl -s http://127.0.0.1:11434/api/tags | python3 -m json.tool | head -n 30

Tip: dashboard will show this model in the next visual update.
WIRE
echo -e "\n${GRN}✔ Step 4 done — $MODEL ready for loopback gateway.${RST}"
echo -e "${DIM}Next: Step 5 WhatsApp QR (reports-only) → docs/05-channels-whatsapp.md${RST}"
