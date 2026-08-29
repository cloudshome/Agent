"""Deterministic Execution Tools Engine."""

import os
import subprocess
import urllib.request
import urllib.parse
from typing import Dict, Any

class ToolEngine:
    def __init__(self, workspace_dir: str = "."):
        self.workspace_dir = os.path.abspath(workspace_dir)

    def _is_safe_path(self, target_path: str) -> bool:
        """Ensures target path is safely inside workspace_dir using commonpath."""
        abs_target = os.path.abspath(target_path)
        try:
            return os.path.commonpath([self.workspace_dir, abs_target]) == self.workspace_dir
        except ValueError:
            return False

    def execute_tool(self, action_type: str, details: Dict[str, Any]) -> Dict[str, Any]:
        """Dispatches an action request to the appropriate tool runner."""
        action_type = action_type.lower()

        try:
            if action_type == "read_file":
                return self.read_file(details.get("filepath", ""))
            elif action_type == "write_file":
                return self.write_file(details.get("filepath", ""), details.get("content", ""))
            elif action_type == "run_shell":
                return self.run_shell(details.get("command", ""))
            elif action_type == "http_get":
                return self.http_get(details.get("url", ""))
            elif action_type == "get_status":
                return self.get_status()
            else:
                return {"success": False, "error": f"Unknown action type: {action_type}"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def read_file(self, filepath: str) -> Dict[str, Any]:
        full_path = os.path.abspath(os.path.join(self.workspace_dir, filepath))
        if not self._is_safe_path(full_path):
            return {"success": False, "error": "Access denied: Path outside workspace."}

        if not os.path.exists(full_path):
            return {"success": False, "error": f"File not found: {filepath}"}

        with open(full_path, "r", encoding="utf-8") as f:
            content = f.read()
        return {"success": True, "content": content}

    def write_file(self, filepath: str, content: str) -> Dict[str, Any]:
        full_path = os.path.abspath(os.path.join(self.workspace_dir, filepath))
        if not self._is_safe_path(full_path):
            return {"success": False, "error": "Access denied: Path outside workspace."}

        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, "w", encoding="utf-8") as f:
            f.write(content)
        return {"success": True, "filepath": filepath, "bytes_written": len(content)}

    def run_shell(self, command: str) -> Dict[str, Any]:
        if not command:
            return {"success": False, "error": "No command provided."}

        res = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=self.workspace_dir
        )
        return {
            "success": res.returncode == 0,
            "stdout": res.stdout,
            "stderr": res.stderr,
            "returncode": res.returncode
        }

    def http_get(self, url: str) -> Dict[str, Any]:
        if not url:
            return {"success": False, "error": "No URL provided."}

        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Home-AI-Agent/1.0"}
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read().decode("utf-8", errors="ignore")
        return {"success": True, "url": url, "content": content[:5000]}

    def get_status(self) -> Dict[str, Any]:
        return {
            "success": True,
            "status": "online",
            "os": os.name,
            "cpu_count": os.cpu_count()
        }
