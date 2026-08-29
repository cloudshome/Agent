"""3-Tier SQLite Memory Engine."""

import sqlite3
import json
import os
from typing import List, Dict, Any, Optional
from datetime import datetime

class MemoryEngine:
    def __init__(self, db_path: str = "data/agent_memory.db"):
        self.db_path = db_path
        os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)
        self._init_db()

    def _get_connection(self):
        return sqlite3.connect(self.db_path)

    def _init_db(self):
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # Short-Term Session Memory
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    content TEXT NOT NULL,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Operational Task Logs
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS task_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    task_name TEXT NOT NULL,
                    status TEXT NOT NULL,
                    result TEXT,
                    risk_level TEXT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Long-Term Knowledge Base
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS knowledge (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    key TEXT UNIQUE NOT NULL,
                    value TEXT NOT NULL,
                    category TEXT DEFAULT 'general',
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.commit()

    # --- Short-Term Memory Methods ---
    def add_session_message(self, session_id: str, role: str, content: str):
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO sessions (session_id, role, content) VALUES (?, ?, ?)",
                (session_id, role, content)
            )
            conn.commit()

    def get_session_history(self, session_id: str, limit: int = 10) -> List[Dict[str, str]]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT role, content FROM sessions WHERE session_id = ? ORDER BY id DESC LIMIT ?",
                (session_id, limit)
            )
            rows = cursor.fetchall()
            return [{"role": r[0], "content": r[1]} for r in reversed(rows)]

    # --- Operational Memory Methods ---
    def log_task(self, task_name: str, status: str, result: str = "", risk_level: str = "SAFE"):
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO task_logs (task_name, status, result, risk_level) VALUES (?, ?, ?, ?)",
                (task_name, status, result, risk_level)
            )
            conn.commit()

    def get_task_logs(self, limit: int = 20) -> List[Dict[str, Any]]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT task_name, status, result, risk_level, timestamp FROM task_logs ORDER BY id DESC LIMIT ?",
                (limit,)
            )
            rows = cursor.fetchall()
            return [
                {
                    "task_name": r[0],
                    "status": r[1],
                    "result": r[2],
                    "risk_level": r[3],
                    "timestamp": r[4]
                }
                for r in rows
            ]

    # --- Long-Term Knowledge Base ---
    def set_knowledge(self, key: str, value: str, category: str = "general"):
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO knowledge (key, value, category, updated_at)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(key) DO UPDATE SET
                    value=excluded.value,
                    category=excluded.category,
                    updated_at=CURRENT_TIMESTAMP
                """,
                (key, value, category)
            )
            conn.commit()

    def get_knowledge(self, key: str) -> Optional[str]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT value FROM knowledge WHERE key = ?", (key,))
            row = cursor.fetchone()
            return row[0] if row else None
