"""Unit tests for Agent module."""

import os
import tempfile
import pytest
from src.agent import Agent

@pytest.fixture
def temp_agent():
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_agent_memory.db")
        agent = Agent(db_path=db_path)
        yield agent

def test_agent_safe_execution(temp_agent):
    res = temp_agent.process_task("test_sess", "get_status", {})
    assert res["success"] is True
    assert res["status"] == "SUCCESS"
    assert res["risk_level"] == "SAFE"

def test_agent_blocked_execution(temp_agent):
    res = temp_agent.process_task("test_sess", "run_shell", {"command": "rm -rf /"})
    assert res["success"] is False
    assert res["status"] == "BLOCKED"
    assert res["risk_level"] == "CRITICAL"

def test_process_prompt_fallback(temp_agent):
    res = temp_agent.process_prompt("test_sess", "check system status")
    assert res["success"] is True
    assert res["risk_level"] == "SAFE"
