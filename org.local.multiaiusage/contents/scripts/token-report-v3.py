#!/usr/bin/env python3
import json
from pathlib import Path
from datetime import datetime, timedelta

FIELDS = (
    "input_tokens",
    "cached_input_tokens",
    "output_tokens",
    "reasoning_output_tokens",
    "cache_write_input_tokens",
    "total_tokens",
)

def report():
    today = datetime.now().astimezone().date()
    days = {
        (today - timedelta(days=i)).isoformat():
        {key: 0 for key in FIELDS}
        for i in range(29, -1, -1)
    }

    folder = Path.home() / ".codex/sessions"
    sessions = 0

    if not folder.exists():
        return {
            "available": False,
            "sessions": 0,
            "days": []
        }

    for path in folder.rglob("*.jsonl"):
        previous = None
        counted = False

        try:
            with path.open(errors="replace") as stream:
                for line in stream:
                    try:
                        obj = json.loads(line)
                        payload = obj.get("payload")

                        if not isinstance(payload, dict):
                            continue

                        if payload.get("type") != "token_count":
                            continue

                        info = payload.get("info")

                        if not isinstance(info, dict):
                            continue

                        current_raw = info.get("total_token_usage")

                        if not isinstance(current_raw, dict):
                            continue

                        timestamp = obj.get("timestamp")

                        if not isinstance(timestamp, str):
                            continue

                        moment = datetime.fromisoformat(
                            timestamp.replace("Z", "+00:00")
                        )

                        if moment.tzinfo is None:
                            moment = moment.astimezone()

                        day = moment.astimezone().date().isoformat()

                        current = {
                            key: max(0, int(current_raw.get(key) or 0))
                            for key in FIELDS
                        }

                        if previous is None:
                            delta = current

                        elif current["total_tokens"] < previous["total_tokens"]:
                            delta = current

                        else:
                            delta = {
                                key: max(0, current[key] - previous[key])
                                for key in FIELDS
                            }

                        previous = current
                        counted = True

                        if day in days:
                            for key in FIELDS:
                                days[day][key] += delta[key]

                    except (ValueError, TypeError, OverflowError):
                        continue

        except OSError:
            continue

        if counted:
            sessions += 1

    return {
        "available": sessions > 0,
        "sessions": sessions,
        "days": [
            {"date": day, **values}
            for day, values in sorted(days.items())
        ]
    }

try:
    print(json.dumps(report()))
except Exception:
    print(json.dumps({
        "available": False,
        "sessions": 0,
        "days": [],
        "error": "Token report unavailable"
    }))
