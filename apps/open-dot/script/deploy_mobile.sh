#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale
[ -x "$ts" ] || { echo 'Tailscale is required on the Mac mini.' >&2; exit 1; }
[ -f dist/ios-device/Dot.ipa ] || { echo 'Run ./script/build_ios.sh first.' >&2; exit 1; }
bun_bin="$(command -v bun)"
codex_bin="$(command -v codex)"
ts_status="$(TAILSCALE_BE_CLI=1 "$ts" status --json)"
login="$(printf '%s' "$ts_status" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["BackendState"]=="Running"; print(d["User"][str(d["Self"]["UserID"])]["LoginName"])')"
dns="$(printf '%s' "$ts_status" | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"
label=com.pedroavj.opendot.harness
agent="$HOME/Library/LaunchAgents/$label.plist"
log_dir="$HOME/Library/Logs/OpenDot"
state_dir="$HOME/Library/Application Support/OpenDot"
mkdir -p "$HOME/Library/LaunchAgents" "$log_dir" "$state_dir"
chmod 700 "$state_dir" "$log_dir"

serve_status="$(TAILSCALE_BE_CLI=1 "$ts" serve status --json)"
printf '%s' "$serve_status" | python3 -c '
import json,sys
d=json.load(sys.stdin)
port=d.get("Web",{}).get(sys.argv[1]+":9453",{}).get("Handlers",{})
if port and port != {"/":{"Proxy":"http://127.0.0.1:19453"}}:
    sys.exit("Tailscale port 9453 is used by another service.")
' "$dns"
if lsof -nP -iTCP:19453 -sTCP:LISTEN >/dev/null 2>&1 &&
   ! launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
  echo 'Local port 19453 is used by another service.' >&2
  exit 1
fi
DOT_REPO="$project_root" DOT_BUN="$bun_bin" DOT_CODEX="$codex_bin" \
DOT_LOGIN="$login" DOT_DNS="$dns" DOT_AGENT="$agent" DOT_LOGS="$log_dir" \
python3 - <<'PY'
import os, plistlib
from pathlib import Path
config = {
    "Label": "com.pedroavj.opendot.harness",
    "ProgramArguments": [os.environ["DOT_BUN"], str(Path(os.environ["DOT_REPO"]) / "harness/server.ts")],
    "WorkingDirectory": os.environ["DOT_REPO"],
    "EnvironmentVariables": {
        "DOT_ALLOWED_TAILSCALE_LOGIN": os.environ["DOT_LOGIN"],
        "DOT_PUBLIC_HOST": os.environ["DOT_DNS"] + ":9453",
        "DOT_CODEX_BIN": os.environ["DOT_CODEX"],
        "DOT_PORT": "19453",
        "PATH": str(Path.home()/".local/bin") + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
    },
    "RunAtLoad": True,
    "KeepAlive": True,
    "StandardOutPath": str(Path(os.environ["DOT_LOGS"])/"harness.log"),
    "StandardErrorPath": str(Path(os.environ["DOT_LOGS"])/"harness-error.log"),
}
with open(os.environ["DOT_AGENT"],"wb") as output:
    plistlib.dump(config, output)
PY
if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)/$label"
fi
for attempt in $(seq 1 20); do
  if ! lsof -nP -iTCP:19453 -sTCP:LISTEN >/dev/null 2>&1; then break; fi
  sleep 0.25
done
if lsof -nP -iTCP:19453 -sTCP:LISTEN >/dev/null 2>&1; then
  echo 'Local port 19453 is still occupied. No harness or Tailscale service was started.' >&2
  exit 1
fi
launchctl bootstrap "gui/$(id -u)" "$agent"
TAILSCALE_BE_CLI=1 "$ts" serve --bg --https=9453 http://127.0.0.1:19453
url="https://$dns:9453"
ready=false
for attempt in $(seq 1 20); do
  if health="$(curl -fsS --max-time 2 "$url/health" 2>/dev/null)" &&
    printf '%s' "$health" | python3 -c 'import json,sys; assert json.load(sys.stdin)["status"]=="ok"' 2>/dev/null; then
    ready=true
    break
  fi
  sleep 1
done
if ! $ready; then echo "Dot did not become healthy at $url. Inspect $log_dir/harness-error.log." >&2; exit 1; fi
echo "Dot is available privately at $url"
