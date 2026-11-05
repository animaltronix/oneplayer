#!/bin/zsh
# Double-click to serve Ice Player locally and open it in Chrome.
cd "$(dirname "$0")"
PORT=8080
# Reuse a server that's already running on the port
if ! curl -s -o /dev/null "http://localhost:$PORT/"; then
  python3 serve.py $PORT >/dev/null 2>&1 &
  sleep 1
fi
open -a "Google Chrome" "http://localhost:$PORT/" 2>/dev/null || open "http://localhost:$PORT/"
echo "Ice Player is running at http://localhost:$PORT  (close this window to stop it)"
wait
