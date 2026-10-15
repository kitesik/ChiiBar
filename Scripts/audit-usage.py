#!/usr/bin/env python3
"""Independent read-only audit. Emits daily numeric totals, never log text.

Usage: python3 Scripts/audit-usage.py /path/to/ChiiBar
Today's moving total is reported separately; completed days must match exactly.
"""
import datetime as dt
import json
import pathlib
import re
import subprocess
import sys
from collections import defaultdict


def count():
    totals = defaultdict(lambda: [0, 0])
    seen = set()
    home = pathlib.Path.home()
    for source, root in enumerate([home / ".claude/projects", home / ".codex/sessions"]):
        for path in sorted(root.rglob("*.jsonl")):
            previous = [0, 0, 0]
            # Bound the read to this file's size at open, without copying any text.
            with path.open("rb") as handle:
                remaining = path.stat().st_size
                while remaining:
                    line = handle.readline(remaining)
                    remaining -= len(line)
                    if not line or not line.endswith(b"\n"):
                        break
                    if (b'"usage"' if source == 0 else b'token_count') not in line:
                        continue
                    try:
                        r = json.loads(line)
                        if source == 0:
                            if r.get("type") != "assistant":
                                continue
                            message = r.get("message") or {}
                            usage = message.get("usage")
                            if usage is None:
                                continue
                            key = (message.get("id"), r.get("requestId"))
                            if any(key):
                                if key in seen:
                                    continue
                                seen.add(key)
                            values = [max(0, int(usage.get(k) or 0)) for k in
                                      ["input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]]
                            value = sum(values[:3]) + values[3] // 10
                        else:
                            p = r.get("payload") or {}
                            if r.get("type") != "event_msg" or p.get("type") != "token_count":
                                continue
                            usage = (p.get("info") or {}).get("total_token_usage")
                            if usage is None:
                                continue
                            current = [int(usage.get(k) or 0) for k in ["input_tokens", "cached_input_tokens", "output_tokens"]]
                            base = previous if all(a >= b for a, b in zip(current, previous)) else [0, 0, 0]
                            uncached, cached, output = [a - b for a, b in zip(current, base)]
                            previous = current
                            value = max(0, uncached - cached) + max(0, cached) // 10 + max(0, output)
                        date = dt.datetime.fromisoformat(r["timestamp"].replace("Z", "+00:00")).astimezone().date()
                        totals[str(date)][source] += value
                    except (ValueError, KeyError, TypeError, OverflowError):
                        continue
    return totals


if __name__ == "__main__":
    reference = count()
    output = subprocess.check_output([sys.argv[1], "--stats"], text=True)
    today = str(dt.datetime.now().astimezone().date())
    matches = 0
    for day, claude, codex, total in re.findall(r"^(\d{4}-\d{2}-\d{2})\s+(\d+)\s+(\d+)\s+(\d+)$", output, re.M):
        actual = [int(claude), int(codex)]
        expected = reference[day]
        if day == today:
            print(day, "live Python/Swift totals:", sum(expected), int(total))
            continue
        if actual != expected:
            raise SystemExit("MISMATCH " + day + " numeric totals: " + str(expected) + " / " + str(actual))
        matches += 1
        print(day, "MATCH", *actual, int(total))
    if matches != 13:
        raise SystemExit("Expected 13 completed days, got " + str(matches))
    print("PASS: 13 completed days match exactly")
