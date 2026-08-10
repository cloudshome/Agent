#!/usr/bin/env bash
# =============================================================================
# OpenClaw — STEP 1 System Check (BEST edition)
# -----------------------------------------------------------------------------
# Runs the 7 commands from docs/01-system-check.md, plus extras:
#  - Ubuntu version, arch, kernel, node, npm, RAM, CPU, disk, GPU, systemd
#  - Produces: human report (stdout) + JSON + Markdown in ~/openclaw-system-report.*
#  - Exit 0 = overall PASS, 1 = warnings, 2 = fail (blocking)
#  - Idempotent, no sudo required (except optional probes), no network writes.
#
# Usage:
#   ./scripts/step1-system-check.sh
#   ./scripts/step1-system-check.sh --json-only
#   curl -fsSL https://raw.githubusercontent.com/cloudshome/Agent/main/scripts/step1-system-check.sh | bash
# =============================================================================
set -uo pipefail
# (no -e — we handle PASS/WARN/FAIL ourselves; -e would abort on expected sort -V mismatches)

VERSION="1.0.0"
JSON_ONLY=0
REPORT_JSON="$HOME/openclaw-system-report.json"
REPORT_MD="$HOME/openclaw-system-report.md"

if [[ "${1:-}" == "--json-only" ]]; then JSON_ONLY=1; fi

# ── colors (disable if not tty or NO_COLOR) ─────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[0;33m'; BLU='\033[0;34m'
  BOLD='\033[1m'; DIM='\033[2m'; RST='\033[0m'
else
  RED=''; GRN=''; YEL=''; BLU=''; BOLD=''; DIM=''; RST=''
fi

pass=0; warn=0; fail=0
checks=()

# helpers
has_cmd() { command -v "$1" >/dev/null 2>&1; }
ver_ge() {
  # $1 >= $2 ?  1.2.3 vs 1.10
  printf '%s\n%s\n' "$2" "$1" | sort -V -C 2>/dev/null && return 0
  # fallback manual
  local IFS=.; local i a=($1) b=($2)
  for i in "${!a[@]}"; do [[ "${a[i]:-0}" -gt "${b[i]:-0}" ]] && return 0; [[ "${a[i]:-0}" -lt "${b[i]:-0}" ]] && return 1; done
  return 0
}
json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$(sed 's/"/\\"/g' <<<"$1")"; }

record() {
  # $1 id $2 status(PASS|WARN|FAIL) $3 title $4 detail $5 advice
  local id="$1" status="$2" title="$3" detail="$4" advice="$5"
  checks+=("$(printf '{"id":%s,"status":%s,"title":%s,"detail":%s,"advice":%s}' \
    "$(printf '%s' "$id" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$id")" \
    "$(printf '%s' "$status" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$status")" \
    "$(printf '%s' "$title" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$title")" \
    "$(printf '%s' "$detail" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$detail")" \
    "$(printf '%s' "$advice" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$advice")")")
  case "$status" in
    PASS) pass=$((pass+1));;
    WARN) warn=$((warn+1));;
    FAIL) fail=$((fail+1));;
  esac
  if [[ $JSON_ONLY -eq 0 ]]; then
    local icon color
    case "$status" in
      PASS) icon="✔"; color="$GRN";;
      WARN) icon="▲"; color="$YEL";;
      FAIL) icon="✘"; color="$RED";;
    esac
    printf "  ${color}${BOLD}%s %-6s${RST} ${BOLD}%s${RST}\n" "$icon" "$status" "$title"
    [[ -n "$detail" ]] && printf "           ${DIM}%s${RST}\n" "$detail"
    [[ -n "$advice" && "$status" != "PASS" ]] && printf "           → %s\n" "$advice"
  fi
}

header() {
  if [[ $JSON_ONLY -eq 1 ]]; then return; fi
  printf "\n${BOLD}${BLU}%s${RST}\n" "$1"
  printf "${DIM}%s${RST}\n" "$(printf '─%.0s' {1..62})"
}

# ── banner ──────────────────────────────────────────────────────────────────
if [[ $JSON_ONLY -eq 0 ]]; then
  cat <<'BANNER'
   ____                   __________
  / __ \____  ___  ____  / ____/ /___ __      __
 / / / / __ \/ _ \/ __ \/ /   / / __ `/ | /| / /
/ /_/ / /_/ /  __/ / / / /___/ / /_/ /| |/ |/ /
\____/ .___/\___/_/ /_/\____/_/\__,_/ |__/|__/
    /_/   STEP 1 — System Check  v1.0.0  (locked-down edition)

BANNER
  printf "${DIM}Report → %s  •  %s${RST}\n\n" "$REPORT_JSON" "$REPORT_MD"
fi

# ── probe values ────────────────────────────────────────────────────────────
LSB_OUT="$(lsb_release -a 2>&1 || cat /etc/os-release 2>&1 || echo 'lsb_release not found')"
UBUNTU_CODENAME="$(lsb_release -cs 2>/dev/null || grep -oP 'VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null || echo unknown)"
UBUNTU_VER="$(lsb_release -rs 2>/dev/null || grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release 2>/dev/null || echo unknown)"
ARCH="$(uname -m 2>&1)"
KERNEL="$(uname -r 2>&1)"
NODE_VER_RAW="$(node --version 2>&1 || echo 'not found')"
NPM_VER_RAW="$(npm --version 2>&1 || echo 'not found')"
NODE_VER="${NODE_VER_RAW#v}"
NPM_VER="$NPM_VER_RAW"
FREE_H="$(free -h 2>&1 || echo 'free not found')"
MEM_TOTAL_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
MEM_GB="$(awk "BEGIN {printf \"%.1f\", $MEM_TOTAL_KB/1024/1024}")"
CPU_MODEL="$(lscpu 2>&1 | grep -m1 'Model name' | sed 's/.*: *//' | xargs || echo unknown)"
CPU_COUNT="$(nproc 2>/dev/null || lscpu 2>&1 | grep -m1 '^CPU(s):' | awk '{print $2}' || echo unknown)"
DF_OUT="$(df -h / 2>&1 || df -h 2>&1 | head -n 20)"
DF_AVAIL="$(df -BG / 2>&1 | awk 'NR==2{print $4}' | tr -d 'G' || echo 0)"
HAS_SYSTEMD="$(ps -p 1 -o comm= 2>&1 | tr -d ' ' || echo unknown)"
GPU_INFO="$(lspci 2>&1 | grep -i -E 'vga|3d|display' | head -n 3 || echo 'no lspci / no GPU detected')"
HAS_NVIDIA="$(command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>&1 | head -n 2 || echo 'none')"
HAS_DOCKER="$(command -v docker >/dev/null 2>&1 && echo yes || echo no)"

# ── checks ──────────────────────────────────────────────────────────────────
header "1/7  OS — Ubuntu"

OS_DETAIL="$(echo "$LSB_OUT" | head -n 3 | tr '\n' ' ' | cut -c1-120)"
if echo "$LSB_OUT" | grep -qi "ubuntu"; then
  if ver_ge "$UBUNTU_VER" "22.04" 2>/dev/null; then
    record "os" "PASS" "Ubuntu $UBUNTU_VER ($UBUNTU_CODENAME)" "$OS_DETAIL" ""
  elif ver_ge "$UBUNTU_VER" "20.04" 2>/dev/null; then
    record "os" "WARN" "Ubuntu $UBUNTU_VER ($UBUNTU_CODENAME) — works, but upgrade recommended" "$OS_DETAIL" "Upgrade to 22.04 LTS or 24.04 LTS for 5-year support: sudo do-release-upgrade"
  else
    record "os" "FAIL" "Ubuntu $UBUNTU_VER — too old" "$OS_DETAIL" "Fresh install 24.04 LTS recommended"
  fi
else
  if echo "$LSB_OUT" | grep -qi "debian"; then
    record "os" "WARN" "Debian detected ($UBUNTU_VER) — should work, not primary target" "$OS_DETAIL" "Ubuntu 22.04/24.04 is the tested path"
  else
    record "os" "WARN" "Not Ubuntu — $UBUNTU_VER ($UBUNTU_CODENAME)" "$OS_DETAIL" "Ubuntu 22.04+ recommended; other distros need manual tweaks"
  fi
fi
if [[ $JSON_ONLY -eq 0 ]]; then printf "       ${DIM}kernel %s  •  detail: lsb_release -a${RST}\n" "$KERNEL"; fi

header "2/7  Architecture"

if [[ "$ARCH" == "x86_64" ]]; then
  record "arch" "PASS" "x86_64 (amd64) — fully supported" "uname -m → $ARCH" ""
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  record "arch" "PASS" "ARM64 ($ARCH) — supported (Ollama, Node fine)" "uname -m → $ARCH" ""
else
  record "arch" "WARN" "Arch $ARCH — likely works, less tested" "uname -m → $ARCH" "Prefer x86_64 or aarch64"
fi

header "3/7  Node.js"

if has_cmd node; then
  # normalize
  NODE_MAJOR="$(printf '%s' "$NODE_VER" | cut -d. -f1 | tr -cd '0-9')"
  if [[ -z "$NODE_MAJOR" ]]; then NODE_MAJOR=0; fi
  if [[ "$NODE_MAJOR" -ge 22 ]]; then
    record "node" "PASS" "Node $NODE_VER_RAW — BEST (22 LTS)" "node --version → $NODE_VER_RAW" ""
  elif [[ "$NODE_MAJOR" -ge 20 ]]; then
    record "node" "PASS" "Node $NODE_VER_RAW — BETTER (20 LTS recommended)" "node --version → $NODE_VER_RAW" ""
  elif [[ "$NODE_MAJOR" -ge 18 ]]; then
    record "node" "WARN" "Node $NODE_VER_RAW — GOOD, but upgrade to 20/22 LTS" "node --version → $NODE_VER_RAW" "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs"
  else
    record "node" "FAIL" "Node $NODE_VER_RAW — too old (need ≥18)" "node --version → $NODE_VER_RAW" "Upgrade: https://nodejs.org or use nvm"
  fi
else
  record "node" "FAIL" "Node not found" "node --version → not found" "Install: curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs  (or nvm)"
fi

header "4/7  npm"

if has_cmd npm; then
  NPM_MAJOR="$(printf '%s' "$NPM_VER" | cut -d. -f1 | tr -cd '0-9')"
  if [[ -z "$NPM_MAJOR" ]]; then NPM_MAJOR=0; fi
  if [[ "$NPM_MAJOR" -ge 10 ]]; then
    record "npm" "PASS" "npm $NPM_VER — BEST" "npm --version → $NPM_VER" ""
  elif [[ "$NPM_MAJOR" -ge 9 ]]; then
    record "npm" "PASS" "npm $NPM_VER — GOOD" "npm --version → $NPM_VER" ""
  else
    record "npm" "WARN" "npm $NPM_VER — old, update recommended" "npm --version → $NPM_VER" "npm i -g npm@latest  or reinstall Node 20/22"
  fi
else
  record "npm" "FAIL" "npm not found" "npm --version → not found" "Reinstall Node.js (npm ships with it)"
fi

header "5/7  Memory (RAM)"

if [[ $JSON_ONLY -eq 0 ]]; then printf "${DIM}%s${RST}\n" "$FREE_H"; fi
# MEM_GB is float, compare integer part
MEM_INT="${MEM_GB%.*}"; [[ -z "$MEM_INT" ]] && MEM_INT=0
if [[ "$MEM_INT" -ge 32 ]]; then
  record "ram" "PASS" "RAM ${MEM_GB} GB — BEST (70B quantized possible)" "free -h → ${MEM_GB} GB" ""
elif [[ "$MEM_INT" -ge 16 ]]; then
  record "ram" "PASS" "RAM ${MEM_GB} GB — BETTER (7B–13B models OK)" "free -h → ${MEM_GB} GB" ""
elif [[ "$MEM_INT" -ge 8 ]]; then
  record "ram" "WARN" "RAM ${MEM_GB} GB — GOOD (3B models, or 7B quantized)" "free -h → ${MEM_GB} GB" "Use qwen2:1.5b / llama3.2:3b or add swap"
elif [[ "$MEM_INT" -ge 4 ]]; then
  record "ram" "WARN" "RAM ${MEM_GB} GB — tight for local LLM" "free -h → ${MEM_GB} GB" "Use tiny models (qwen2:0.5b) or cloud fallback; consider +8GB"
else
  record "ram" "FAIL" "RAM ${MEM_GB} GB — too low for local inference" "free -h → ${MEM_GB} GB" "Upgrade to ≥8GB or use cloud model (opt-in)"
fi
if [[ $JSON_ONLY -eq 0 ]]; then
  printf "       → Model guide:  0.5–3B ≈ 4GB  •  7B ≈ 8–16GB  •  13B ≈ 16GB  •  70B ≈ 32–48GB (Q4)\n"
fi

header "6/7  CPU"

if [[ $JSON_ONLY -eq 0 ]]; then printf "       ${DIM}%s${RST}\n" "$CPU_MODEL"; printf "       ${DIM}CPUs: %s  •  lscpu | grep -E 'Model name|CPU\\(s\\)'${RST}\n" "$CPU_COUNT"; fi
CPU_INT="$(printf '%s' "$CPU_COUNT" | tr -cd '0-9')"; [[ -z "$CPU_INT" ]] && CPU_INT=0
if [[ "$CPU_INT" -ge 8 ]]; then
  record "cpu" "PASS" "CPU $CPU_MODEL — BEST ($CPU_COUNT threads)" "lscpu → $CPU_MODEL / $CPU_COUNT" ""
elif [[ "$CPU_INT" -ge 4 ]]; then
  record "cpu" "PASS" "CPU $CPU_MODEL — BETTER ($CPU_COUNT threads)" "lscpu → $CPU_MODEL / $CPU_COUNT" ""
elif [[ "$CPU_INT" -ge 2 ]]; then
  record "cpu" "WARN" "CPU $CPU_MODEL — GOOD ($CPU_COUNT threads, a bit slow)" "lscpu → $CPU_MODEL / $CPU_COUNT" "LLM will be slower; consider quantized models"
else
  record "cpu" "WARN" "CPU $CPU_MODEL — minimal ($CPU_COUNT thread)" "lscpu → $CPU_MODEL / $CPU_COUNT" "Will work, but inference is slow"
fi

header "7/7  Disk"

if [[ $JSON_ONLY -eq 0 ]]; then printf "${DIM}%s${RST}\n" "$(echo "$DF_OUT" | head -n 5)"; fi
DF_INT="$(printf '%s' "$DF_AVAIL" | tr -cd '0-9')"; [[ -z "$DF_INT" ]] && DF_INT=0
if [[ "$DF_INT" -ge 100 ]]; then
  record "disk" "PASS" "Disk ${DF_AVAIL} GB free — BEST (NVMe+)" "df -h / → ${DF_AVAIL} GB avail" ""
elif [[ "$DF_INT" -ge 50 ]]; then
  record "disk" "PASS" "Disk ${DF_AVAIL} GB free — BETTER" "df -h / → ${DF_AVAIL} GB avail" ""
elif [[ "$DF_INT" -ge 20 ]]; then
  record "disk" "WARN" "Disk ${DF_AVAIL} GB free — GOOD, tight for models" "df -h / → ${DF_AVAIL} GB avail" "Need ~6GB per 7B model; clean: sudo apt autoremove --purge"
elif [[ "$DF_INT" -ge 10 ]]; then
  record "disk" "WARN" "Disk ${DF_AVAIL} GB free — low" "df -h / → ${DF_AVAIL} GB avail" "Free space: sudo journalctl --vacuum-time=7d; docker prune if used"
else
  record "disk" "FAIL" "Disk ${DF_AVAIL} GB free — too low" "df -h / → ${DF_AVAIL} GB avail" "Free ≥20GB before installing models"
fi

# ── extras (not blocking but useful) ────────────────────────────────────────
header "Extras — GPU / systemd / docker"

if echo "$HAS_NVIDIA" | grep -qi "none"; then
  record "gpu" "WARN" "No NVIDIA GPU detected — CPU inference (fine)" "$GPU_INFO" "Optional: NVIDIA GPU speeds Ollama 10×; not required"
else
  VRAM="$(echo "$HAS_NVIDIA" | head -n1)"
  record "gpu" "PASS" "NVIDIA GPU: $VRAM" "$HAS_NVIDIA" ""
fi

if [[ "$HAS_SYSTEMD" == "systemd" ]]; then
  record "systemd" "PASS" "systemd is PID 1 — 24/7 service supported" "ps -p 1 → $HAS_SYSTEMD" ""
else
  record "systemd" "WARN" "PID 1 is $HAS_SYSTEMD — not systemd" "ps -p 1 → $HAS_SYSTEMD" "24/7 service needs systemd; WSL needs special setup"
fi

if [[ "$HAS_DOCKER" == "yes" ]]; then
  record "docker" "PASS" "Docker available — optional container path" "docker --version → $(docker --version 2>&1 | head -n1)" ""
else
  record "docker" "WARN" "Docker not installed — optional, not required" "docker → not found" "Optional: for containerized Ollama"
fi

# ── summary ─────────────────────────────────────────────────────────────────
TOTAL=$((pass+warn+fail))
if [[ $JSON_ONLY -eq 0 ]]; then
  printf "\n${BOLD}Summary${RST}  ${GRN}%d pass${RST}  ${YEL}%d warn${RST}  ${RED}%d fail${RST}  (of %d)\n" "$pass" "$warn" "$fail" "$TOTAL"
  if [[ $fail -gt 0 ]]; then
    printf "${RED}${BOLD}✘  BLOCKED — fix FAIL items before Step 2.${RST}\n"
  elif [[ $warn -gt 0 ]]; then
    printf "${YEL}${BOLD}▲  READY WITH WARNINGS — you can proceed, but read advice above.${RST}\n"
  else
    printf "${GRN}${BOLD}✔  READY — all checks green. Proceed to Step 2 (install).${RST}\n"
  fi
  cat <<'NEXT'

Next:
  1. Save this report:  cat ~/openclaw-system-report.json
  2. If FAIL: fix items above, rerun:  ./scripts/step1-system-check.sh
  3. If PASS/WARN: continue to docs/02-install.md

Tip: paste the JSON into a GitHub Issue for help — it has no secrets.
NEXT
fi

# ── write reports ────────────────────────────────────────────────────────────
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
HOSTNAME="$(hostname 2>/dev/null || echo unknown)"

# Build JSON
CHECKS_JSON="$(printf '%s\n' "${checks[@]}" | paste -sd, - 2>/dev/null || printf '%s' "${checks[*]}")"
# fallback if paste missing
if [[ -z "$CHECKS_JSON" ]]; then CHECKS_JSON="$(IFS=,; echo "${checks[*]}")"; fi

cat > "$REPORT_JSON" <<JSON
{
  "version": "$VERSION",
  "timestamp": "$TIMESTAMP",
  "hostname": "$HOSTNAME",
  "summary": { "pass": $pass, "warn": $warn, "fail": $fail, "total": $TOTAL },
  "raw": {
    "os": $(printf '%s' "$LSB_OUT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$LSB_OUT"),
    "ubuntu_version": $(printf '%s' "$UBUNTU_VER" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$UBUNTU_VER"),
    "codename": $(printf '%s' "$UBUNTU_CODENAME" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$UBUNTU_CODENAME"),
    "arch": $(printf '%s' "$ARCH" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$ARCH"),
    "kernel": $(printf '%s' "$KERNEL" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$KERNEL"),
    "node": $(printf '%s' "$NODE_VER_RAW" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$NODE_VER_RAW"),
    "npm": $(printf '%s' "$NPM_VER_RAW" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$NPM_VER_RAW"),
    "mem_gb": "$MEM_GB",
    "cpu_model": $(printf '%s' "$CPU_MODEL" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$CPU_MODEL"),
    "cpu_count": "$CPU_COUNT",
    "disk_avail_gb": "$DF_AVAIL",
    "gpu": $(printf '%s' "$HAS_NVIDIA" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$HAS_NVIDIA"),
    "free_h": $(printf '%s' "$FREE_H" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$FREE_H"),
    "df_h": $(printf '%s' "$DF_OUT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$DF_OUT")
  },
  "checks": [${CHECKS_JSON}],
  "recommendation": {
    "local_model": "$( if [[ "$MEM_INT" -ge 32 ]]; then echo "llama3.1:70b-q4 or qwen2.5:32b"; elif [[ "$MEM_INT" -ge 16 ]]; then echo "llama3.1:8b or qwen2.5:14b"; elif [[ "$MEM_INT" -ge 8 ]]; then echo "llama3.2:3b or qwen2:1.5b"; else echo "qwen2:0.5b or cloud fallback"; fi )",
    "tier": "$( if [[ $fail -gt 0 ]]; then echo "BLOCKED"; elif [[ $warn -gt 0 ]]; then echo "READY_WITH_WARNINGS"; else echo "READY"; fi )"
  }
}
JSON

# Markdown report
cat > "$REPORT_MD" <<MD
# OpenClaw System Report — $TIMESTAMP

Host: \`$HOSTNAME\` — Ubuntu $UBUNTU_VER ($UBUNTU_CODENAME) — $ARCH — kernel $KERNEL

**Summary:** $pass PASS · $warn WARN · $fail FAIL

## Raw outputs

\`\`\`
# lsb_release -a
$LSB_OUT

# uname -m
$ARCH

# node --version
$NODE_VER_RAW

# npm --version
$NPM_VER_RAW

# free -h
$FREE_H

# lscpu | grep -E 'Model name|CPU(s)'
$CPU_MODEL / $CPU_COUNT

# df -h /
$DF_OUT
\`\`\`

## Checks

| Status | Check | Advice |
|--------|-------|--------|
MD
# append checks to MD
python3 <<PY 2>/dev/null || true
import json, pathlib
j=json.loads(pathlib.Path("$REPORT_JSON").read_text())
with open("$REPORT_MD","a") as f:
    for c in j["checks"]:
        f.write(f"| {c['status']} | {c['title']} | {c['advice']} |\n")
    f.write(f"\n**Recommended local model:** {j['recommendation']['local_model']}\n")
    f.write(f"**Tier:** {j['recommendation']['tier']}\n")
PY

if [[ $JSON_ONLY -eq 0 ]]; then
  printf "${DIM}Wrote %s and %s${RST}\n" "$REPORT_JSON" "$REPORT_MD"
fi

# exit code
if [[ $fail -gt 0 ]]; then exit 2
elif [[ $warn -gt 0 ]]; then exit 1
else exit 0
fi
