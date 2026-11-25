#!/usr/bin/env bash
# Prints the UDID of an available iPhone simulator (newest runtime first).
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
runtimes = sorted((r for r in data if "iOS" in r), reverse=True)
for r in runtimes:
    for d in data[r]:
        if d.get("isAvailable") and d["name"].startswith("iPhone"):
            print(d["udid"]); sys.exit(0)
sys.exit("No available iPhone simulator found")
'
