"""Unit tests for SafetyGate module."""

import pytest
from src.safety import SafetyGate, RiskLevel

def test_risk_classification():
    gate = SafetyGate()

    assert gate.classify_action("read_file", {}) == RiskLevel.SAFE
    assert gate.classify_action("http_get", {}) == RiskLevel.SAFE
    assert gate.classify_action("write_file", {}) == RiskLevel.LOW
    assert gate.classify_action("run_shell", {"command": "ls -l"}) == RiskLevel.MEDIUM
    assert gate.classify_action("run_shell", {"command": "rm -rf /tmp/foo"}) == RiskLevel.HIGH
    assert gate.classify_action("run_shell", {"command": "rm -rf /"}) == RiskLevel.CRITICAL

def test_authorization_evaluation():
    gate = SafetyGate(config={"auto_approve_max_risk": RiskLevel.MEDIUM})

    # Safe read file
    eval_safe = gate.evaluate_authorization("read_file", {})
    assert eval_safe["allowed"] is True
    assert eval_safe["requires_approval"] is False

    # High risk action requires approval
    eval_high = gate.evaluate_authorization("delete_file", {})
    assert eval_high["allowed"] is False
    assert eval_high["requires_approval"] is True

    # Critical action blocked
    eval_critical = gate.evaluate_authorization("run_shell", {"command": "rm -rf /"})
    assert eval_critical["allowed"] is False
    assert eval_critical["requires_approval"] is False
