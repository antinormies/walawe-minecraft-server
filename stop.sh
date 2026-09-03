#!/usr/bin/env bash
# Gracefully stop the Minecraft server.
#
# Works when the server was started with:
#   tmux new -s mc ./start.sh
#
# It sends the in-game "stop" command to the console, which makes vanilla
# save the world and exit cleanly. If you run the server with systemd
# (minecraft.service) instead, just use:  sudo systemctl stop minecraft
set -euo pipefail

if tmux has-session -t mc 2>/dev/null; then
  echo "Sending 'stop' to the server console (tmux session 'mc')..."
  tmux send-keys -t mc "stop" Enter
  echo "Waiting for the process to exit..."
  for _ in $(seq 1 60); do
    if ! pgrep -f "server.jar" > /dev/null; then
      echo "Server stopped."
      exit 0
    fi
    sleep 1
  done
  echo "Still running after 60s - check the console (tmux attach -t mc)." >&2
  exit 1
else
  echo "No tmux session 'mc' found." >&2
  echo "If the server runs under systemd:  sudo systemctl stop minecraft" >&2
  exit 1
fi
