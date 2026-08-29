"""Unit tests for MemoryEngine module."""

import os
import tempfile
import pytest
from src.memory import MemoryEngine

@pytest.fixture
def temp_memory():
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_memory.db")
        engine = MemoryEngine(db_path=db_path)
        yield engine

def test_session_memory(temp_memory):
    temp_memory.add_session_message("session_1", "user", "Hello agent")
    temp_memory.add_session_message("session_1", "assistant", "Hello user")

    history = temp_memory.get_session_history("session_1")
    assert len(history) == 2
    assert history[0]["role"] == "user"
    assert history[1]["role"] == "assistant"

def test_operational_task_logging(temp_memory):
    temp_memory.log_task("check_disk", "SUCCESS", "Disk space 50%", "SAFE")
    logs = temp_memory.get_task_logs()
    assert len(logs) == 1
    assert logs[0]["task_name"] == "check_disk"
    assert logs[0]["status"] == "SUCCESS"

def test_long_term_knowledge(temp_memory):
    temp_memory.set_knowledge("user_name", "Alice")
    val = temp_memory.get_knowledge("user_name")
    assert val == "Alice"

    # Test update
    temp_memory.set_knowledge("user_name", "Bob")
    val_updated = temp_memory.get_knowledge("user_name")
    assert val_updated == "Bob"
