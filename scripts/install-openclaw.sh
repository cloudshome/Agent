#!/usr/bin/env bash
# OpenClaw — Step 2: Install Gateway (idempotent, locked-down defaults)
set -euo pipefail
if [[ -t 1 ]]; then BOLD='\033[1m'; GRN='\033[0;32m'; YEL='\033[0;33m'; RED='\033[0;31m'; DIM='\033[2m'; RST='\033[0m'; else BOLD=''; GRN=''; YEL=''; RED=''; DIM=''; RST=''; fi

echo -e "${BOLD}OpenClaw — Install Gateway${RST}  ${DIM}(Step 2)${RST}"
echo -e "${DIM}Runs: Node check → install gateway → verify → no channels enabled${RST}\n"

if ! command -v node >/dev/null; then echo -e "${RED}✘ Node not found. Run Step 1 first: ./scripts/step1-system-check.sh${RST}"; exit 2; fi
NODE_MAJOR="$(node --version | sed 's/v//' | cut -d. -f1)"
if [[ "$NODE_MAJOR" -lt 18 ]]; then echo -e "${RED}✘ Node $(node --version) < 18. Upgrade first.${RST}"; exit 2; fi
echo -e "${GRN}✔ Node $(node --version) ok${RST}"

# Detect install method — prefer official docs
# OpenClaw gateway is distributed via npm / openclaw-cli. We probe both.
set +e
if npm view openclaw 2>/dev/null | grep -q "openclaw"; then PKG="openclaw"; 
elif npm view @openclaw/gateway 2>/dev/null | grep -q "gateway"; then PKG="@openclaw/gateway"; 
else PKG="openclaw"; fi
set -e

echo -e "\n${BOLD}Installing ${PKG} (global)...${RST}  ${DIM}sudo may be needed${RST}"
if npm list -g "$PKG" >/dev/null 2>&1; then
  echo -e "${DIM}Already installed — updating...${RST}"
  npm update -g "$PKG" 2>&1 | tail -n 20 || sudo npm update -g "$PKG" 2>&1 | tail -n 20 || true
else
  npm install -g "$PKG" 2>&1 | tail -n 30 || sudo npm install -g "$PKG" 2>&1 | tail -n 30 || {
    echo -e "${YEL}▲ npm global install needed sudo or failed.\n  Try: sudo npm install -g $PKG${RST}"
    exit 1
  }
fi

echo -e "\n${BOLD}Preparing directories (no secrets yet)...${RST}"
sudo mkdir -p /opt/openclaw/{config,data/{whatsapp,gmail},logs} /var/log/openclaw
sudo chown -R "$USER":"$USER" /opt/openclaw 2>/dev/null || true
sudo chown -R "$USER":"$USER" /var/log/openclaw 2>/dev/null || true

# Copy example configs if not present (never overwrite)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
for f in config/openclaw.yaml.example config/allowlist.example.yaml; do
  dest="/opt/openclaw/$f"; src="$REPO_ROOT/$f"
  # also support repo-local config
  if [[ ! -f "./config/openclaw.yaml" && -f "$src" ]]; then
    mkdir -p "./config"
    if [[ "$f" == *openclaw.yaml* ]]; then cp -n "$src" "./config/openclaw.yaml" 2>/dev/null || true
    else cp -n "$src" "./config/allowlist.yaml" 2>/dev/null || true; fi
  fi
done
if [[ ! -f "./config/openclaw.yaml" && -f "$REPO_ROOT/config/openclaw.yaml.example" ]]; then
  cp -n "$REPO_ROOT/config/openclaw.yaml.example" "./config/openclaw.yaml"
  echo -e "${DIM}Created ./config/openclaw.yaml (all channels disabled)${RST}"
fi
if [[ ! -f "./config/allowlist.yaml" && -f "$REPO_ROOT/config/allowlist.example.yaml" ]]; then
  cp -n "$REPO_ROOT/config/allowlist.example.yaml" "./config/allowlist.yaml"
  echo -e "${DIM}Created ./config/allowlist.yaml (deny-by-default)${RST}"
fi

echo -e "\n${BOLD}Verify...${RST}"
if command -v openclaw >/dev/null; then
  openclaw --version 2>&1 | head -n 5 || true
  openclaw health 2>&1 | head -n 30 || echo -e "${YEL}▲ 'openclaw health' not yet — gateway may need 'openclaw init' (see docs/02-install.md)${RST}"
else
  echo -e "${YEL}▲ 'openclaw' not on PATH. Try: hash -r; openclaw --version${RST}"
  echo -e "${DIM}  npm bin -g: $(npm bin -g 2>/dev/null || echo unknown) — add to PATH if needed${RST}"
fi

cat <<NEXT

${GRN}${BOLD}✔ Install step done.${RST}
  Next:
    1. Edit config:  \$EDITOR ./config/openclaw.yaml   (keep all enabled: false)
    2. Make it 24/7: sudo ./scripts/setup-service.sh
    3. Check:        openclaw health  &&  systemctl status openclaw-gateway

  Docs: docs/02-install.md  •  docs/03-service-24-7.md
  Security: channels are DISABLED by default — enable one at a time after QR/OAuth.
NEXT
