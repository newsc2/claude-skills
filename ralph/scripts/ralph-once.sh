#!/bin/bash
# Run a single Ralph iteration
# Usage: ralph-once <plan-dir> [model] [mode]
# Uses `claude` CLI directly (Claude Max plan)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$1" ]; then
  echo "Usage: ralph-once <plan-dir> [model] [mode]"
  echo "Example: ralph-once plans/260109-1430-my-feature/"
  echo "         ralph-once plans/260109-feature/ opus prototype"
  echo "Models: haiku, sonnet, opus (default: auto-detect)"
  echo "Modes: prototype (fast), production (quality, default)"
  exit 1
fi

export PLAN_DIR="$1"
MODEL_OVERRIDE="${2:-}"
export RALPH_MODE="${3:-production}"

# Verify plan exists
if [ ! -f "$PLAN_DIR/tasks.md" ]; then
  echo "Error: $PLAN_DIR/tasks.md not found"
  echo "Run: ralph-init <slug> to create a plan"
  exit 1
fi

# Load workflow (detects tasks, model, builds prompt)
source "$SCRIPT_DIR/ralph-workflow.sh"

# Override model if specified
if [ -n "$MODEL_OVERRIDE" ]; then
  MODEL="$MODEL_OVERRIDE"
  CLAUDE_ARGS=$(build_claude_args "$MODEL")
else
  MODEL="$RALPH_MODEL"
fi

# Load shared utilities
source "$SCRIPT_DIR/ralph-utils.sh"

echo "=== Ralph Single Task ==="
echo "Plan: $PLAN_DIR"
echo "Source: $TASK_SOURCE"
echo "Mode: $RALPH_MODE"
echo "Next task: $NEXT_TASK"
echo "Model: $MODEL"
echo "========================="

if [ -z "$NEXT_TASK" ]; then
  echo "No incomplete tasks found in $PLAN_DIR/tasks.md"
  COMPLETED_COUNT=$(grep -c "^\- \[x\]" "$TASKS_FILE" 2>/dev/null || echo "0")
  notify "Ralph" "All $COMPLETED_COUNT tasks already complete!"
  exit 0
fi

# Log task start
log_task_start "$NEXT_TASK" "$MODEL" "$RALPH_MODE" "$PLAN_DIR" "$PLAN_NAME"

# Run with claude CLI
OUTPUT_FILE=$(mktemp)
echo "Running: claude $CLAUDE_ARGS --dangerously-skip-permissions -p ..."
claude $CLAUDE_ARGS --dangerously-skip-permissions -p "$RALPH_WORKFLOW $RALPH_COMPLETE_MSG" > "$OUTPUT_FILE" 2>&1 &
CLAUDE_PID=$!
track_pid "$CLAUDE_PID"
wait $CLAUDE_PID || true
RESULT=$(cat "$OUTPUT_FILE")
rm -f "$OUTPUT_FILE"

# Cleanup
kill_and_cleanup "$CLAUDE_PID"

# Log task completion
if echo "$RESULT" | grep -q "ALL_TASKS_DONE\|TASK_COMPLETE"; then
  log_task_complete "$NEXT_TASK" "completed" "Task completed successfully" "$PLAN_DIR"
elif echo "$RESULT" | grep -q "TASK_BLOCKED\|ERROR\|error"; then
  log_task_complete "$NEXT_TASK" "blocked" "Task encountered issues" "$PLAN_DIR"
else
  log_task_complete "$NEXT_TASK" "completed" "Iteration finished" "$PLAN_DIR"
fi

COMPLETED_COUNT=$(grep -c "^\- \[x\]" "$TASKS_FILE" 2>/dev/null || echo "0")
REMAINING_COUNT=$(grep -c "^\- \[ \]" "$TASKS_FILE" 2>/dev/null || echo "0")
notify "Ralph Task Done" "Completed: ${NEXT_TASK:0:40} | $COMPLETED_COUNT done, $REMAINING_COUNT remaining"
