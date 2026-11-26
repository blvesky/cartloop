#!/usr/bin/env bash
set -euo pipefail
export NO_PROXY="localhost,127.0.0.1"
export no_proxy="localhost,127.0.0.1"
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

for dependency in python3 kane-cli; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'Required command missing: %s\n' "$dependency" >&2
    exit 2
  fi
done

url=http://127.0.0.1:8080
mkdir -p .testmuai/cartloop
logs=$(mktemp -d .testmuai/cartloop/run.XXXXXX)
PYTHONUNBUFFERED=1 python3 -m http.server 8080 --bind 127.0.0.1 >"$logs/server.log" 2>&1 &
server_pid=$!
cleanup() {
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if ! python3 - "$server_pid" "$logs/server.log" <<'PY'
import os
import sys
import time
import urllib.request
from pathlib import Path

pid = int(sys.argv[1])
server_log = Path(sys.argv[2])
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
for _ in range(50):
    try:
        os.kill(pid, 0)
        if b"Serving HTTP on" in server_log.read_bytes():
            with opener.open("http://127.0.0.1:8080/", timeout=0.5) as response:
                if b"<title>CartLoop</title>" in response.read():
                    break
    except ProcessLookupError:
        sys.exit(1)
    except OSError:
        pass
    time.sleep(0.1)
else:
    sys.exit(1)
PY
then
  cat "$logs/server.log" >&2
  printf 'CartLoop could not start on %s.\n' "$url" >&2
  exit 2
fi

run_flow() {
  local flow=$1 name stdout stderr cli_exit=0
  name=${flow##*/}
  stdout="$logs/${name%.txt}.ndjson"
  stderr="$logs/${name%.txt}.stderr"
  printf 'Running %s\n' "$flow"
  kane-cli run --agent --headless --target desktop --url "$url" --timeout 180 "$(< "$flow")" \
    </dev/null >"$stdout" 2>"$stderr" || cli_exit=$?

  python3 - "$stdout" "$stderr" "$cli_exit" <<'PY'
import json
import sys

stdout, stderr, exit_code = sys.argv[1:]
last_event = None
with open(stdout, encoding="utf-8") as stream:
    for line in stream:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict) and event.get("type") == "run_end":
            last_event = (line.rstrip(), event.get("status"))

if last_event:
    print(last_event[0])
else:
    print(f"No Kane run_end event (CLI exit {exit_code}).", file=sys.stderr)

if exit_code != "0" or not last_event or last_event[1] != "passed":
    print(f"CLI exit {exit_code}. See {stdout} and {stderr}.", file=sys.stderr)
    sys.exit(1)
PY
}

result=0
run_flow kane/flow-checkout.txt || result=1
run_flow kane/flow-discount-error.txt || result=1
run_flow kane/flow-cart-validation.txt || result=1
printf 'Verification logs: %s\n' "$logs"
exit "$result"
