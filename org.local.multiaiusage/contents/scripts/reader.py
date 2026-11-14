#!/usr/bin/env python3
import subprocess
import json
import select
import shutil
import time
from pathlib import Path

def codex_path():
    desktop = Path("/usr/lib/chatgpt/resources/codex")
    if desktop.is_file():
        return str(desktop)

    local = Path.home() / ".local/npm/node_modules/.bin/codex"
    if local.is_file():
        return str(local)

    return shutil.which("codex")

def logged_in(executable):
    try:
        result = subprocess.run([executable, "login", "status"],
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL,
                                timeout=4, check=False)
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False

def query(executable):
    p = subprocess.Popen(
        [executable, "app-server"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1
    )

    try:
        def send(data):
            p.stdin.write(json.dumps(data) + "\n")
            p.stdin.flush()

        def receive(req_id):
            deadline = time.monotonic() + 15

            while time.monotonic() < deadline:
                ready, _, _ = select.select(
                    [p.stdout], [], [], 0.5
                )
                if not ready:
                    continue

                line = p.stdout.readline()
                if not line:
                    break

                msg = json.loads(line)
                if msg.get("id") == req_id:
                    if "error" in msg:
                        raise RuntimeError(
                            msg["error"].get("message", "API error")
                        )
                    return msg["result"]

            raise TimeoutError("Codex API timeout")

        send({
            "id": 1,
            "method": "initialize",
            "params": {
                "clientInfo": {
                    "name": "kde-codex-monitor",
                    "version": "1.0"
                },
                "capabilities": {}
            }
        })
        receive(1)

        send({
            "method": "initialized",
            "params": {}
        })

        send({
            "id": 2,
            "method": "account/rateLimits/read",
            "params": {}
        })

        result = receive(2)
        limits = result.get("rateLimits") or {}

        if not limits.get("primary"):
            limits = (
                result.get("rateLimitsByLimitId", {})
                .get("codex", {})
            )

        windows = [
            limits.get("primary"),
            limits.get("secondary")
        ]

        def window(minutes):
            for item in windows:
                if (item and
                    item.get("windowDurationMins") == minutes):
                    return item
            return None

        credits = result.get("rateLimitResetCredits") or {}

        return {
            "connected": True,
            "five": window(300),
            "weekly": window(10080),
            "resets": credits.get("availableCount"),
            "error": None,
            "message": "Existing Codex login detected"
        }
    finally:
        if p.poll() is None:
            p.terminate()
            try:
                p.wait(timeout=2)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait()

def main():
    executable = codex_path()
    if not executable:
        result = {"connected": False, "five": None, "weekly": None,
                  "resets": None, "error": "Codex CLI not found",
                  "message": "Codex CLI not found"}
    else:
        try:
            result = query(executable)
        except Exception as error:
            authenticated = logged_in(executable)
            message = ("Codex usage unavailable: " + str(error) if authenticated
                       else "Codex login or usage unavailable: " + str(error))
            result = {"connected": authenticated, "five": None,
                      "weekly": None, "resets": None,
                      "error": str(error), "message": message}
    print(json.dumps(result))

if __name__ == "__main__":
    main()
