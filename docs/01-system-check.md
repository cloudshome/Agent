# Step 1 — System Check (Do Only This Now)

> **Goal:** Prove your Ubuntu box can run OpenClaw + a local model *before* you install anything.  
> **Time:** 2 minutes. **Risk:** zero — read-only checks.

## Why locked-down order?

OpenClaw needs Node ≥18 and a bit of RAM/disk for models. If you install first and hardware is too small, you wasted time and opened attack surface for nothing. Check → then install.

## Option A — One-liner (best)

```bash
# from anywhere, no clone needed
curl -fsSL https://raw.githubusercontent.com/cloudshome/Agent/main/scripts/step1-system-check.sh | bash

# or if you already cloned
git clone https://github.com/cloudshome/Agent.git && cd Agent
chmod +x scripts/step1-system-check.sh
./scripts/step1-system-check.sh
```

It prints a colored report and writes two files:

- `~/openclaw-system-report.json` — machine-readable (paste into an Issue for help)
- `~/openclaw-system-report.md`  — human-readable

Exit codes: `0` = ready, `1` = warn (you can proceed), `2` = fail (fix first).

## Option B — Manual (7 commands, one at a time)

Open **Terminal** (`Ctrl+Alt+T`) and run each line, wait for output, then next:

### 1. OS
```bash
lsb_release -a
```
Expected: `Description: Ubuntu 22.04.x LTS` or `24.04.x LTS` — BEST. `20.04` still works (WARN).

### 2. Arch
```bash
uname -m
```
Expected: `x86_64` (BEST) or `aarch64` (OK). Anything else → WARN.

### 3. Node
```bash
node --version
```
Need `v18+`. Want `v20+` (BETTER) or `v22+` (BEST). If `command not found`, see fix below.

### 4. npm
```bash
npm --version
```
Need `9+`, want `10+`.

### 5. RAM
```bash
free -h
```
| RAM | Verdict | What local model fits |
| :--- | :--- | :--- |
| 32 GB+ | BEST | 70B Q4, 32B |
| 16 GB | BETTER | 7B–13B (`llama3.1:8b`) |
| 8 GB | GOOD | 3B (`llama3.2:3b`) |
| 4 GB | WARN | 0.5–1.5B (`qwen2:0.5b`) or cloud fallback |
| <4 GB | FAIL | Cloud fallback, or add RAM |

### 6. CPU
```bash
lscpu | grep -E 'Model name|CPU\(s\)'
```
4+ cores = BETTER. 2 cores = works but slow.

### 7. Disk
```bash
df -h /
```
Need `20 GB` free (GOOD), want `50 GB` (BETTER). Each 7B model ≈ 4–6 GB.

## Screenshots

```
✔ PASS  Ubuntu 24.04.1 LTS
✔ PASS  x86_64
✔ PASS  Node v22.11.0 — BEST
✔ PASS  npm 10.9.0 — BEST
✔ PASS  RAM 15.6 GB — BETTER (7B–13B OK)
✔ PASS  CPU Intel i5 — BETTER (4 threads)
✔ PASS  Disk 87 GB free — BEST
✔ PASS  systemd is PID 1

Summary  9 pass  2 warn  0 fail
✔ READY — all green. Proceed to Step 2.
```

## Troubleshooting

### `lsb_release: command not found`
```bash
sudo apt update && sudo apt install lsb-release -y
```

### `node: command not found` or too old
```bash
# Option 1 — NodeSource (system-wide, recommended for gateway)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node --version  # should be v22.x

# Option 2 — nvm (user-only, no sudo)
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
# reopen terminal
nvm install 22
nvm use 22
nvm alias default 22
```

### `npm` old
```bash
npm i -g npm@latest
# or reinstall Node 22 (ships npm 10)
```

### RAM low — add swap (temporary relief, not a real upgrade)
```bash
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h
```

### Disk full
```bash
sudo apt autoremove --purge -y
sudo journalctl --vacuum-time=7d
sudo apt clean
docker system prune -af 2>/dev/null || true
df -h /
```

### `uname -m` shows `aarch64` — is that ok?
Yes. Ollama + Node both support ARM64 (Apple Silicon, Pi 5, ARM VPS). Some quantized models are x86-optimized but will still run.

## What to share for help

Paste the *JSON* (it has no secrets) or screenshot the colored report:

```bash
cat ~/openclaw-system-report.json | pbcopy   # mac
cat ~/openclaw-system-report.json            # then copy
# or
cat ~/openclaw-system-report.md
```

## Gate

- `0 fails` → ✅ Go to `docs/02-install.md`
- `≥1 fail` → 🛑 Fix FAIL lines, rerun `./scripts/step1-system-check.sh` until `0 fail`

**Do not run `install-openclaw.sh` until this gate is green.** That's the discipline that keeps the agent locked down.

---

Next: [Step 2 — Install OpenClaw Gateway →](02-install.md)
