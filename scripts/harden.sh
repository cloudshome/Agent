#!/usr/bin/env bash
# OpenClaw — Hardening audit (Step 13). Read-only checks, no changes unless --fix
set -euo pipefail
FIX=0; [[ "${1:-}" == "--fix" ]] && FIX=1
RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[0;33m'; BOLD='\033[1m'; DIM='\033[2m'; RST='\033[0m'
pass=0; warn=0; fail=0
check() {
  local status="$1" title="$2" advice="$3"
  case "$status" in PASS) echo -e "  ${GRN}✔ PASS${RST} $title"; pass=$((pass+1));;
                  WARN) echo -e "  ${YEL}▲ WARN${RST} $title ${DIM}→ $advice${RST}"; warn=$((warn+1));;
                  FAIL) echo -e "  ${RED}✘ FAIL${RST} $title ${DIM}→ $advice${RST}"; fail=$((fail+1));;
  esac
}
echo -e "${BOLD}OpenClaw — Hardening Audit${RST}  ${DIM}$(date -u +%Y-%m-%dT%H:%M:%SZ)${RST}\n"

# 1. gateway bind (checks live config, falls back to .example for repo audit)
if grep -q 'bind: "127.0.0.1"' /opt/openclaw/config/openclaw.yaml 2>/dev/null \
   || grep -q 'bind: "127.0.0.1"' ./config/openclaw.yaml 2>/dev/null \
   || grep -q 'bind: "127.0.0.1"' ./config/openclaw.yaml.example 2>/dev/null; then
  check PASS "Gateway binds 127.0.0.1 (not 0.0.0.0)" ""
else
  check FAIL "Gateway bind not 127.0.0.1" "Set gateway.bind: \"127.0.0.1\" in openclaw.yaml"
fi

# 1b. trusted_proxies explicit (fixes audit warning)
if grep -q 'trusted_proxies:' /opt/openclaw/config/openclaw.yaml 2>/dev/null \
   || grep -q 'trusted_proxies:' ./config/openclaw.yaml 2>/dev/null \
   || grep -q 'trusted_proxies:' ./config/openclaw.yaml.example 2>/dev/null; then
  check PASS "trusted_proxies declared (audit warning cleared)" ""
else
  check WARN "trusted_proxies missing" "Add gateway.trusted_proxies: [] for loopback (or [\"127.0.0.1\",\"::1\"] behind proxy) — see config/openclaw.yaml.example"
fi

# 2. .env not in git
if git -C . check-ignore -q config/.env 2>/dev/null || grep -q "config/.env" .gitignore 2>/dev/null; then
  check PASS ".env is gitignored" ""
else
  check WARN ".env may not be gitignored" "Add config/.env to .gitignore"
  [[ $FIX -eq 1 ]] && echo "config/.env" >> .gitignore && echo "  → fixed .gitignore"
fi

# 3. .env perms
if [[ -f ./config/.env ]]; then
  perms=$(stat -c %a ./config/.env 2>/dev/null || stat -f %p ./config/.env 2>/dev/null || echo 644)
  if [[ "$perms" == "600" || "$perms" == "400" ]]; then check PASS ".env is 600" ""; else check WARN ".env is $perms (want 600)" "chmod 600 config/.env"; [[ $FIX -eq 1 ]] && chmod 600 ./config/.env; fi
else
  check WARN "config/.env not found (using .env.age?)" "That's fine if you use age"
fi

# 4. .env.age exists (BEST)
if [[ -f ./config/.env.age || -f /opt/openclaw/config/.env.age ]]; then
  check PASS ".env.age (age-encrypted) present — BEST" ""
else
  check WARN "No .env.age — plain .env on disk" "Encrypt: age -r <pubkey> -o config/.env.age config/.env"
fi

# 5. allowlist (live or example) — count only exec.allow entries
for p in ./config/allowlist.yaml /opt/openclaw/config/allowlist.yaml ./config/allowlist.example.yaml; do
  if [[ -f "$p" ]]; then
    exec_count=$(sed -n '/^exec:/,/^fs:/p' "$p" 2>/dev/null | sed -n '/allow:/,/deny:/p' 2>/dev/null | grep -c -- '- "' 2>/dev/null || echo 0)
    # fallback if no exec block
    if [[ "$exec_count" -eq 0 ]]; then exec_count=$(grep -c -- '- "' "$p" 2>/dev/null || echo 0); fi
    if [[ "$exec_count" -le 10 ]]; then check PASS "Allowlist exec short ($exec_count) — least privilege ($p)" "";
    elif [[ "$exec_count" -le 15 ]]; then check WARN "Allowlist exec $exec_count — okay, trim to ≤10 if possible" "Review exec.allow";
    else check WARN "Allowlist exec long ($exec_count)" "Shrink to ≤10 — least privilege"; fi
    break
  fi
done

# 6. UFW
if command -v ufw >/dev/null 2>&1; then
  if ufw status 2>&1 | grep -qi "active"; then check PASS "UFW active" ""; else check WARN "UFW not active" "sudo ufw allow 22/tcp && sudo ufw enable"; fi
else
  check WARN "UFW not installed" "sudo apt install ufw -y"
fi

# 7. systemd hardening
if systemctl cat openclaw-gateway 2>/dev/null | grep -q "NoNewPrivileges=yes"; then
  check PASS "systemd hardening present" ""
else
  check WARN "systemd hardening not detected" "Reinstall service: sudo ./scripts/setup-service.sh"
fi

# 8. Binance read-only (live or example)
if grep -q "canTrade: false" ./config/openclaw.yaml 2>/dev/null \
   || grep -q "canTrade: false" /opt/openclaw/config/openclaw.yaml 2>/dev/null \
   || grep -q "canTrade: false" ./config/openclaw.yaml.example 2>/dev/null; then
  check PASS "Binance canTrade: false (read-only)" ""
else
  check WARN "Binance canTrade not false" "Keep read-only until audited"
fi

# 9. No secrets in git log
if git log --all -p 2>/dev/null | grep -qiE "BINANCE_SECRET|OPENAI_API_KEY.*sk-" | head -n1; then
  check FAIL "Potential secret in git history" "Rotate keys immediately, purge history"
else
  check PASS "No obvious secrets in git log" ""
fi

echo -e "\n${BOLD}Result: $pass pass  $warn warn  $fail fail${RST}"
if [[ $fail -gt 0 ]]; then echo -e "${RED}✘ Fix FAIL items before going live.${RST}"; exit 2
elif [[ $warn -gt 0 ]]; then echo -e "${YEL}▲ Hardened with warnings — review above.${RST}"; exit 1
else echo -e "${GRN}✔ Hardened — BEST tier.${RST}"; exit 0; fi
