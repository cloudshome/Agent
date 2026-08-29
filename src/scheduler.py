"""Task Scheduler & Watchdog Runner."""

import time
import logging
from typing import List, Dict, Any
from src.agent import Agent

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

class TaskScheduler:
    def __init__(self, agent: Agent = None, check_interval: int = 5):
        self.agent = agent or Agent()
        self.check_interval = check_interval
        self.tasks: List[Dict[str, Any]] = []
        self.running = False

    def add_task(self, name: str, interval_seconds: int, action_type: str, details: Dict[str, Any]):
        """Adds a scheduled task to the queue."""
        self.tasks.append({
            "name": name,
            "interval_seconds": interval_seconds,
            "action_type": action_type,
            "details": details,
            "last_run": 0
        })

    def run_pending(self):
        """Runs any task whose scheduled interval has elapsed."""
        now = time.time()
        for task in self.tasks:
            if now - task["last_run"] >= task["interval_seconds"]:
                logging.info(f"Executing scheduled task: {task['name']}")
                task["last_run"] = now
                res = self.agent.process_task(
                    session_id=f"scheduler_{task['name']}",
                    action_type=task["action_type"],
                    details=task["details"]
                )
                logging.info(f"Task '{task['name']}' status: {res.get('status')} (Risk: {res.get('risk_level')})")

    def start_loop(self, max_iterations: int = None):
        """Starts the scheduler loop."""
        self.running = True
        iterations = 0
        logging.info("Starting Task Scheduler Loop...")
        try:
            while self.running:
                self.run_pending()
                iterations += 1
                if max_iterations and iterations >= max_iterations:
                    break
                time.sleep(self.check_interval)
        except KeyboardInterrupt:
            logging.info("Scheduler stopped by user.")

if __name__ == "__main__":
    scheduler = TaskScheduler()
    scheduler.add_task("heartbeat", interval_seconds=10, action_type="get_status", details={})
    scheduler.start_loop(max_iterations=1)
