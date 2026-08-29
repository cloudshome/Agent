"""Safety Gate and Policy Authorization Engine."""

from enum import IntEnum
import re
from typing import Dict, Any, List

class RiskLevel(IntEnum):
    SAFE = 0
    LOW = 1
    MEDIUM = 2
    HIGH = 3
    CRITICAL = 4

class SafetyGate:
    def __init__(self, config: Dict[str, Any] = None):
        config = config or {}
        self.auto_approve_max_risk = config.get("auto_approve_max_risk", RiskLevel.MEDIUM)
        self.blocked_patterns = config.get("blocked_patterns", [
            r"rm\s+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-f\s+-r|-r\s+-f)\s+/(?:\s+.*)?$",
            r"\bmkfs\b",
            r"\bdd\b",
            r":\(\)\{\s*:\|:&\s*\};:"
        ])

    def classify_action(self, action_type: str, details: Dict[str, Any]) -> RiskLevel:
        """Categorizes an action into a risk tier."""
        action_type = action_type.lower()
        command = details.get("command", "").strip()

        # Check for critical regex pattern matches
        for pattern in self.blocked_patterns:
            if re.search(pattern, command, re.IGNORECASE):
                return RiskLevel.CRITICAL

        if action_type in ["read_file", "http_get", "get_status", "query_memory"]:
            return RiskLevel.SAFE
        elif action_type in ["write_file", "save_memory", "append_log"]:
            return RiskLevel.LOW
        elif action_type in ["run_shell", "execute_script"]:
            if re.search(r"\b(rm|sudo|chmod|chown)\b", command, re.IGNORECASE):
                return RiskLevel.HIGH
            return RiskLevel.MEDIUM
        elif action_type in ["delete_file", "git_push", "restart_service"]:
            return RiskLevel.HIGH
        elif action_type in ["format_disk", "system_wipe"]:
            return RiskLevel.CRITICAL

        return RiskLevel.MEDIUM

    def evaluate_authorization(self, action_type: str, details: Dict[str, Any]) -> Dict[str, Any]:
        """Evaluates whether an action is allowed, requires user approval, or is blocked."""
        risk = self.classify_action(action_type, details)

        if risk == RiskLevel.CRITICAL:
            return {
                "allowed": False,
                "risk_level": risk.name,
                "requires_approval": False,
                "reason": "Command or action is explicitly blocked due to CRITICAL safety policy."
            }
        elif risk <= self.auto_approve_max_risk:
            return {
                "allowed": True,
                "risk_level": risk.name,
                "requires_approval": False,
                "reason": "Action risk is within auto-approval limits."
            }
        else:
            return {
                "allowed": False,
                "risk_level": risk.name,
                "requires_approval": True,
                "reason": "Action exceeds auto-approval limits and requires user authorization."
            }
