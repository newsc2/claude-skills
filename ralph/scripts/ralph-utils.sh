#!/bin/bash
# Shared utilities for Ralph scripts
# Provides: notifications, logging, PID tracking

# ─── Notifications ─────────────────────────────────────────────────

# Send macOS notification (works on both Mac Mini and MBP)
notify() {
  local title="$1"
  local message="$2"
  osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
}

# ─── PID Tracking ──────────────────────────────────────────────────

PID_FILE="$HOME/.ralph-pids"

track_pid() {
  echo "$1" >> "$PID_FILE"
}

untrack_pid() {
  if [ -f "$PID_FILE" ]; then
    sed -i '' "/$1/d" "$PID_FILE" 2>/dev/null || true
  fi
}

# Kill and cleanup a Claude process
kill_and_cleanup() {
  local pid="$1"
  if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
    kill "$pid" 2>/dev/null || true
    sleep 0.5
    if ps -p "$pid" > /dev/null 2>&1; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  untrack_pid "$pid"
}

# ─── Logging ───────────────────────────────────────────────────────

# Log task start to progress.md and global log
log_task_start() {
  local task="$1"
  local model="$2"
  local mode="$3"
  local plan_dir="$4"
  local plan_name="$5"
  local timestamp=$(date '+%Y-%m-%d %H:%M')
  local progress_file="$plan_dir/progress.md"
  local global_log="plans/ralph-log.md"

  # Count completed tasks for task number
  local completed_count
  completed_count=$(grep -c "^\- \[x\]" "$plan_dir/tasks.md" 2>/dev/null) || completed_count=0
  local task_num=$((completed_count + 1))

  local entry="
---
## [$plan_name] Task $task_num: ${task:0:60}
**Status:** In Progress | **Time:** $timestamp | **Model:** $model | **Mode:** $mode"

  echo "$entry" >> "$progress_file"

  # Also append to global log if plans/ dir exists
  if [ -d "plans" ]; then
    echo "$entry" >> "$global_log"
  fi
}

# Log task completion
log_task_complete() {
  local task="$1"
  local status="$2"
  local summary="$3"
  local plan_dir="$4"
  local timestamp=$(date '+%H:%M')
  local progress_file="$plan_dir/progress.md"

  local entry="
### Result
**Status:** $(echo "$status" | sed 's/./\U&/') | **Completed:** $timestamp
$summary"

  echo "$entry" >> "$progress_file"
}

# Log iteration info (for AFK mode)
log_iteration() {
  local iteration="$1"
  local total="$2"
  local task="$3"
  local plan_dir="$4"
  local timestamp=$(date '+%H:%M')
  local activity_log="$plan_dir/activity.log"

  echo "[$timestamp] ITERATION $iteration/$total: ${task:0:60}" >> "$activity_log"
}
