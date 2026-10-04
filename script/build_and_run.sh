#!/usr/bin/env bash
set -euo pipefail

mode="${1:-run}"
case "$mode" in run|--verify|--logs|--debug) ;; *) echo "usage: $0 [--verify|--logs|--debug]" >&2; exit 2 ;; esac
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
bun ../f/bend2/main.ts system build
bun ../f/bend2/main.ts system deploy
app_bundle="$HOME/Applications/Dot.app"
app_pid="$(lsappinfo info -only pid com.pedro.open-dot.mac 2>/dev/null | sed -n 's/.*"pid"=\([0-9][0-9]*\).*/\1/p')"
if [ -n "$app_pid" ]; then
  kill -TERM "$app_pid"
  for attempt in {1..50}; do
    if ! kill -0 "$app_pid" 2>/dev/null; then break; fi
    sleep 0.1
  done
  if kill -0 "$app_pid" 2>/dev/null; then echo "Dot did not quit." >&2; exit 1; fi
fi
case "$mode" in
  --debug) exec lldb -- "$app_bundle/Contents/MacOS/Dot" ;;
  --logs) open -n "$app_bundle"; exec /usr/bin/log stream --info --style compact --predicate 'process == "Dot"' ;;
  *) open -n "$app_bundle" ;;
esac
if [ "$mode" = --verify ]; then
  for attempt in {1..20}; do
    if lsappinfo info -only pid com.pedro.open-dot.mac 2>/dev/null | rg -q '"pid"=[0-9]'; then
      codesign --verify --strict "$app_bundle"
      echo "Dot built, installed and running."
      exit 0
    fi
    sleep 0.25
  done
  echo "Dot did not start." >&2
  exit 1
fi
