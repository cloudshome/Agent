"""Core AI Agent Loop & Prompt Router."""

import json
import requests
from typing import Dict, Any, Optional
from src.safety import SafetyGate
from src.memory import MemoryEngine
from src.tools import ToolEngine

SYSTEM_PROMPT = """You are an AI Automation Agent. Convert the user's input into a JSON action request.
Respond ONLY with valid JSON in the following format:
{
  "action_type": "read_file" | "write_file" | "run_shell" | "http_get" | "get_status",
  "details": { ... }
}
Do not output markdown code blocks or extra text.
"""

class Agent:
    def __init__(
        self,
        ollama_host: str = "http://localhost:11434",
        model: str = "llama3.2:1b",
        db_path: str = "data/agent_memory.db",
        safety_config: Optional[Dict[str, Any]] = None
    ):
        self.ollama_host = ollama_host
        self.model = model
        self.memory = MemoryEngine(db_path=db_path)
        self.safety = SafetyGate(config=safety_config)
        self.tools = ToolEngine()

    def query_ollama(self, prompt: str) -> str:
        """Sends a query to local Ollama instance."""
        url = f"{self.ollama_host}/api/generate"
        payload = {
            "model": self.model,
            "prompt": f"{SYSTEM_PROMPT}\nUser: {prompt}\nJSON:",
            "stream": False
        }
        try:
            resp = requests.post(url, json=payload, timeout=30)
            if resp.status_code == 200:
                return resp.json().get("response", "")
            return f"Error: Ollama returned status code {resp.status_code}"
        except Exception as e:
            return f"Ollama connection fallback mode: {str(e)}"

    def plan_and_parse_prompt(self, user_prompt: str) -> Dict[str, Any]:
        """Queries local LLM and parses response into structured action and details."""
        raw_response = self.query_ollama(user_prompt)
        try:
            # Strip markdown formatting if model output wraps JSON
            cleaned = raw_response.strip().strip("```json").strip("```").strip()
            data = json.loads(cleaned)
            if "action_type" in data and "details" in data:
                return data
        except Exception:
            pass

        # Fallback heuristic parser if LLM is offline or output isn't JSON
        prompt_lower = user_prompt.lower()
        if "status" in prompt_lower or "health" in prompt_lower:
            return {"action_type": "get_status", "details": {}}
        elif "read" in prompt_lower:
            words = user_prompt.split()
            filepath = words[-1] if len(words) > 1 else "README.md"
            return {"action_type": "read_file", "details": {"filepath": filepath}}
        else:
            return {"action_type": "run_shell", "details": {"command": user_prompt}}

    def process_prompt(self, session_id: str, user_prompt: str) -> Dict[str, Any]:
        """Parses a user prompt via LLM planner and executes it through safety gate."""
        parsed = self.plan_and_parse_prompt(user_prompt)
        return self.process_task(session_id, parsed["action_type"], parsed.get("details", {}))

    def process_task(self, session_id: str, action_type: str, details: Dict[str, Any]) -> Dict[str, Any]:
        """Main agent loop for safety checking, logging, and tool execution."""
        # 1. Log request to short term session memory
        self.memory.add_session_message(session_id, "user", f"Execute {action_type}: {json.dumps(details)}")

        # 2. Safety Gate Evaluation
        eval_result = self.safety.evaluate_authorization(action_type, details)
        risk_level = eval_result["risk_level"]

        if not eval_result["allowed"]:
            msg = f"Action blocked or requires approval. Reason: {eval_result['reason']}"
            self.memory.log_task(action_type, "BLOCKED", msg, risk_level)
            self.memory.add_session_message(session_id, "system", msg)
            return {
                "success": False,
                "status": "BLOCKED",
                "risk_level": risk_level,
                "reason": eval_result["reason"]
            }

        # 3. Execute Tool
        result = self.tools.execute_tool(action_type, details)
        status = "SUCCESS" if result.get("success", False) else "FAILED"

        # 4. Log to Operational & Session Memory
        res_str = json.dumps(result)
        self.memory.log_task(action_type, status, res_str[:500], risk_level)
        self.memory.add_session_message(session_id, "assistant", f"Result: {res_str[:500]}")

        return {
            "success": result.get("success", False),
            "status": status,
            "risk_level": risk_level,
            "output": result
        }
