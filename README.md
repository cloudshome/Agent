# Home AI Agent: 24/7 Personal AI Automation Server

Welcome to the **Home AI Agent** project. This repository transforms your local Ubuntu PC into an always-on, privacy-focused, autonomous AI automation server without relying on expensive monthly cloud APIs.

---

## 💡 Honest Assessment & Honest Feedback

Your overall vision of turning an Ubuntu machine into a 24/7 personal AI worker is **100% sound, realistic, and highly practical**. However, to make it work reliably on consumer hardware, critical architectural adjustments are necessary.

### 1. Hardware Reality Check (8 GB RAM + GT 710 GPU)
* **The Constraint**: A NVIDIA GT 710 has only 1GB-2GB of VRAM (Kepler architecture) and lacks modern CUDA/Tensor Core compute capabilities. Modern LLMs cannot be offloaded to this GPU efficiently. Furthermore, with **8 GB of system RAM**, running Linux OS + Docker + PostgreSQL + n8n + OpenHands + Playwright + Ollama simultaneously will cause heavy RAM swapping and system freezing.
* **The Solution**:
  * **Quantized Models**: Stick to 1B to 3.8B parameter models quantized to 4-bit (e.g., `llama3.2:1b`, `phi3:mini`, `qwen2.5:1.5b` or `qwen2.5:3b`).
  * **Lightweight Native Architecture**: Avoid running heavy Docker multi-container setups (like OpenHands or n8n container clusters) on an 8GB machine. Instead, use a lightweight, modular Python native engine with SQLite for memory and deterministic script execution.
  * **Hybrid AI Router**: Use lightweight local LLMs for parsing, classification, and routine task routing. For heavy reasoning or complex coding tasks, allow an optional API fallback (OpenAI/Anthropic/DeepSeek) while keeping routine 24/7 operations 100% local and free.

### 2. Architectural Recommendation: Modular & Tool-Driven
* **LLM ≠ Whole System**: As emphasized in your architecture, the LLM is just the **brain/planner**. Execution must be delegated to deterministic, high-speed Python tools (shell commands, web fetchers, SQLite queries, Playwright scripts).
* **Security Gate is Non-Negotiable**: An unattended 24/7 autonomous agent running system scripts must operate under strict safety policies. Commands are categorized into risk tiers (`SAFE`, `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`), requiring interactive user authorization (via Telegram or Web UI) for destructive operations (e.g., file deletion, database modification, external code execution).

---

## 🏗 System Architecture

```text
                                YOU (User Interface)
                                  │ (Telegram / CLI)
                                  ▼
                      ┌──────────────────────┐
                      │    SECURITY GATE     │ ◄── Policy Rules (yaml)
                      └──────────┬───────────┘
                                 │ Approved
                                 ▼
                      ┌──────────────────────┐
                      │    HOME AGENT LOOP   │
                      └─────┬──────────┬─────┘
                            │          │
        ┌───────────────────┘          └───────────────────┐
        ▼                                                  ▼
┌──────────────┐                                    ┌──────────────┐
│  LOCAL LLM   │ (Ollama)                           │  MEMORY DB   │ (SQLite 3-Tier)
└──────────────┘                                    └──────────────┘
        │                                                  │
        └───────────────────┬──────────────────────────────┘
                            ▼
                      ┌──────────────┐
                      │  TOOL ENGINE │
                      └──────┬───────┘
                             │
     ┌───────────────────────┼───────────────────────┐
     ▼                       ▼                       ▼
┌──────────┐           ┌──────────┐            ┌──────────┐
│ Shell &  │           │  Web &   │            │ Task     │
│ System   │           │ Browser  │            │ Scheduler│
└──────────┘           └──────────┘            └──────────┘
```

---

## 🛠 Recommended Technology Stack

| Component | Recommended Tool | Purpose |
| :--- | :--- | :--- |
| **Operating System** | Ubuntu Server / Desktop | 24/7 Always-On Host |
| **Local LLM Engine** | **Ollama** (`llama3.2:1b`, `qwen2.5:3b`) | Local inference server |
| **Agent Orchestrator** | Custom Python Engine (`src/agent.py`) | Low-footprint reasoning & tool execution |
| **Memory Database** | **SQLite3** (`src/memory.py`) | Short-term state, operational logs, long-term memory |
| **Safety & Policy Gate**| Risk Evaluator (`src/safety.py`) | Action security classification & approval gate |
| **Browser Automation** | **Playwright / Requests** | Headless web navigation & extraction |
| **Scheduler & Watchdog**| Python `cron` runner + `systemd` | Task scheduling & automatic service recovery |
| **Remote Interface** | **Telegram Bot API** | Command agent remotely from smartphone |

---

## 🚀 Step-by-Step Implementation Roadmap

### Phase 1: Base Setup & Ollama
1. Install Ubuntu & Docker (optional for isolated execution).
2. Install Ollama: `curl -fsSL https://ollama.com/install.sh | sh`
3. Pull lightweight model: `ollama pull llama3.2:1b` or `ollama pull qwen2.5:1.5b`

### Phase 2: Core Agent Framework
1. Clone this repository & install dependencies: `pip install -r requirements.txt`
2. Configure settings: Copy `config/config.example.yaml` to `config/config.yaml`.
3. Run the core agent loop and safety verification tests: `pytest`

### Phase 3: Workflows & Automation
1. Define scheduled tasks in `config/config.yaml`.
2. Enable Playwright for headless web scraping.
3. Configure Telegram Bot tokens for remote notifications and interactive approval gates.

### Phase 4: 24/7 Watchdog & Systemd Integration
1. Configure systemd service for `src/scheduler.py` to auto-start on boot.
2. Setup log rotation and automatic recovery on failure.

---

## 🔒 Security Tiers

* **SAFE / READ**: Web fetching, reading local files, status checks (Executed automatically).
* **LOW / WRITE**: Saving notes, writing log files, updating local SQLite (Executed automatically).
* **MEDIUM / RUN**: Running safe shell commands, executing python scripts (Logged & optional notify).
* **HIGH / DELETE**: File deletion, code modification, git push, network config (Requires Telegram/CLI Approval).
* **CRITICAL**: Financial API calls, system wipe, password modification (Strictly blocked / Interactive confirmation).
