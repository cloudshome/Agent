# Technical Architecture: Home AI Agent

This document details the software architecture, safety engine design, memory models, LLM routing, task queue scheduling, and system watchdog mechanisms for running a 24/7 personal AI agent on consumer Ubuntu hardware.

---

## 1. Safety Gate & Action Authorization Policy

Running an autonomous agent 24/7 requires strict safety controls so that unintended tool invocations cannot compromise system stability or delete user data.

### Risk Classifications

Actions requested by the LLM Planner are passed to `src/safety.py` and classified into 5 risk levels:

| Level | Classification | Examples | Default Action |
| :--- | :--- | :--- | :--- |
| **0** | `SAFE` / `READ` | Read file, list directory, HTTP GET request, query memory | Auto-Approve |
| **1** | `LOW` / `WRITE` | Create file, append log, update SQLite table | Auto-Approve + Log |
| **2** | `MEDIUM` / `RUN` | Execute safe shell command (`uptime`, `ls`), run local python script | Auto-Approve + Log |
| **3** | `HIGH` / `DELETE` | Delete file, modify configuration, `git push`, service restart | Request User Approval (Telegram/CLI) |
| **4** | `CRITICAL` | Wipe disk (`rm -rf /`), modify `/etc/`, financial transactions | Blocked / Strict Approval |

### Policy Configuration

Security rules are defined in `config/config.yaml`:

```yaml
security:
  strict_mode: true
  auto_approve_risk_max: 2  # Risk levels <= 2 run automatically
  require_telegram_confirmation_risk: 3
  blocked_commands:
    - "rm -rf /"
    - "mkfs"
    - "dd"
    - "shutdown"
    - "reboot"
```

---

## 2. 3-Tier Memory System (SQLite & Flat Files)

To avoid high memory overhead from dedicated vector databases like Chroma or Pinecone on an 8GB RAM machine, Home AI Agent uses SQLite (`src/memory.py`).

```text
┌────────────────────────────────────────────────────────┐
│                   3-TIER MEMORY ENGINE                 │
├──────────────────┬──────────────────┬──────────────────┤
│ Short-Term       │ Operational      │ Long-Term        │
│ Session Memory   │ Task Memory      │ Knowledge        │
├──────────────────┼──────────────────┼──────────────────┤
│ • Current prompt │ • Executed jobs  │ • Saved notes    │
│ • Tool call chain│ • Error logs     │ • Web summaries  │
│ • RAM / In-Mem   │ • System metrics │ • User context   │
│   SQLite         │ • `tasks` table  │ • `knowledge`    │
└──────────────────┴──────────────────┴──────────────────┘
```

### Schema Overview

1. `sessions`: Stores ongoing prompt context and short-term dialogue.
2. `task_logs`: Stores history of automated tasks, tool calls, return codes, and execution timestamps.
3. `knowledge`: Key-value and document store for long-term facts, web summaries, and persistent instructions.

---

## 3. Hybrid LLM Routing Architecture

Local inference via Ollama handles standard operations without incurring API fees.

```text
                          Incoming Task Request
                                    │
                                    ▼
                         ┌────────────────────┐
                         │   Hybrid Router    │
                         └─────────┬──────────┘
                                   │
               ┌───────────────────┴───────────────────┐
               ▼                                       ▼
    Simple Task / Parsing                    Complex Reasoning
  (Summary, Classification,                     (Architecture,
     Tool Dispatching)                          Advanced Code)
               │                                       │
               ▼                                       ▼
     Ollama (Local LLM)                     Optional Cloud API
(`llama3.2:1b`, `qwen2.5:3b`)            (OpenAI / Anthropic / DeepSeek)
```

---

## 4. Task Scheduler & Watchdog

1. **Task Scheduler (`src/scheduler.py`)**: Runs interval and cron-like jobs (e.g. checking websites every 30 minutes, auditing logs daily at 8:00 AM).
2. **Watchdog (`systemd`)**: Monitors the Python scheduler process. If memory consumption exceeds safety thresholds or if the service crashes, `systemd` auto-restarts the process.

```text
[Unit]
Description=Home AI Agent Watchdog Service
After=network.target ollama.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/home-ai-agent
ExecStart=/usr/bin/python3 src/scheduler.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```
