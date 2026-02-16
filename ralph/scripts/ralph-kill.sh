#!/bin/bash
# Kill all running Ralph processes
# Usage: ralph-kill

PID_FILE="$HOME/.ralph-pids"

if [ ! -f "$PID_FILE" ] || [ ! -s "$PID_FILE" ]; then
  echo "No tracked Ralph processes found."
  # Also check for orphaned claude processes
  ORPHANS=$(pgrep -f "claude.*dangerously-skip-permissions" 2>/dev/null || true)
  if [ -n "$ORPHANS" ]; then
    echo "Found orphaned claude processes: $ORPHANS"
    echo "Kill them? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
      echo "$ORPHANS" | xargs kill 2>/dev/null || true
      echo "Killed orphaned processes."
    fi
  fi
  exit 0
fi

echo "Killing tracked Ralph processes..."
while IFS= read -r pid; do
  if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
    echo "  Killing PID $pid"
    kill "$pid" 2>/dev/null || true
    sleep 0.3
    if ps -p "$pid" > /dev/null 2>&1; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  else
    echo "  PID $pid already stopped"
  fi
done < "$PID_FILE"

# Clear PID file
> "$PID_FILE"
echo "All Ralph processes stopped."
