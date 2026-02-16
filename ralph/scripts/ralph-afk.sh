#!/bin/bash
# Run Ralph in AFK loop mode
# Usage: ralph-afk <plan-dir> <iterations> [model] [mode]
# Uses `claude` CLI directly (Claude Max plan)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ralph-afk <plan-dir> <iterations> [model] [mode]"
  echo "Example: ralph-afk plans/260109-1430-my-feature/ 5"
  echo "         ralph-afk plans/260109-feature/ 10 auto prototype"
  echo "Models: haiku, sonnet, opus, auto (default)"
  echo "Modes: prototype (fast), production (quality, default)"
  exit 1
fi

export PLAN_DIR="$1"
ITERATIONS="$2"
MODEL_OVERRIDE="${3:-auto}"
export RALPH_MODE="${4:-production}"

# Verify plan exists
if [ ! -f "$PLAN_DIR/tasks.md" ] && [ ! -f "$PLAN_DIR/plan.md" ]; then
  echo "Error: No tasks.md or plan.md found in $PLAN_DIR"
  echo "Run: ralph-init <slug> to create a plan"
  exit 1
fi

# Load shared utilities
source "$SCRIPT_DIR/ralph-utils.sh"

echo "=== Ralph AFK Mode ==="
echo "Plan: $PLAN_DIR"
echo "Iterations: $ITERATIONS"
echo "Model: $MODEL_OVERRIDE"
echo "Mode: $RALPH_MODE"
echo "======================"

for ((i=1; i<=$ITERATIONS; i++)); do
  # Re-source to get fresh task detection each iteration
  source "$SCRIPT_DIR/ralph-workflow.sh"

  if [ "$MODEL_OVERRIDE" = "auto" ]; then
    MODEL="$RALPH_MODEL"
    CLAUDE_ARGS_ITER="$CLAUDE_ARGS"
  else
    MODEL="$MODEL_OVERRIDE"
    CLAUDE_ARGS_ITER=$(build_claude_args "$MODEL")
  fi

  echo ""
  echo "=== Iteration $i of $ITERATIONS ==="
  echo "Task: $NEXT_TASK"
  echo "Model: $MODEL"
  echo "Mode: $RALPH_MODE"
  echo "Checkpoint: $IS_CHECKPOINT"
  echo "=================================="

  if [ -z "$NEXT_TASK" ]; then
    echo "No more tasks found."
    COMPLETED_COUNT=$(grep -c "^\- \[x\]" "$TASKS_FILE" 2>/dev/null || echo "0")
    log_task_complete "All tasks" "completed" "All $COMPLETED_COUNT tasks done" "$PLAN_DIR"
    notify "Ralph Complete" "All $COMPLETED_COUNT tasks done!"
    exit 0
  fi

  # Log iteration start
  log_task_start "$NEXT_TASK" "$MODEL" "$RALPH_MODE" "$PLAN_DIR" "$PLAN_NAME"
  log_iteration "$i" "$ITERATIONS" "$NEXT_TASK" "$PLAN_DIR"

  # CHECKPOINT DETECTION - pause for manual verification
  if [ "$IS_CHECKPOINT" = "yes" ]; then
    echo ""
    echo "CHECKPOINT DETECTED: $NEXT_TASK"
    echo "This task requires manual verification before continuing."
    echo ""

    # Extract AC from the task
    AC_LINE=$(grep -A2 "CHECKPOINT" "$TASKS_FILE" 2>/dev/null | grep -i "AC:" | head -1 | sed 's/.*AC://' | xargs)

    # Mark checkpoint as complete
    claude --model sonnet --dangerously-skip-permissions -p "@$PROGRESS_FILE @$TASKS_FILE
    This is a CHECKPOINT task. Do the following:
    1. Append to progress.md:
       ---
       ## CHECKPOINT: Manual Verification
       **Time:** $(date +'%Y-%m-%d %H:%M')
       **Status:** Paused for manual testing
       Please verify Phase 1 works correctly before running Phase 2.
    2. Mark the checkpoint task as [x] complete in tasks.md
    3. Output: CHECKPOINT_COMPLETE" &
    CHECKPOINT_PID=$!
    track_pid "$CHECKPOINT_PID"
    wait $CHECKPOINT_PID || true
    kill_and_cleanup "$CHECKPOINT_PID"

    # Log checkpoint pause
    log_task_complete "$NEXT_TASK" "blocked" "CHECKPOINT: Paused for manual verification" "$PLAN_DIR"

    # Send notification
    notify "Ralph Checkpoint" "Manual verification required for: $PLAN_NAME"

    # Show macOS dialog if available
    osascript -e "display dialog \"CHECKPOINT - Manual Verification Required

What to verify:
${AC_LINE:-Test the prototype works correctly}

If working:
  ralph-afk $PLAN_DIR $((ITERATIONS-i)) $MODEL_OVERRIDE production

If broken:
  Fix issues, then re-run\" with title \"Ralph Checkpoint\" buttons {\"OK\"} default button \"OK\"" 2>/dev/null &

    echo ""
    echo "Ralph paused at checkpoint."
    echo ""
    echo "VERIFICATION: ${AC_LINE:-Test the prototype works correctly}"
    echo ""
    echo "NEXT STEPS:"
    echo "  If working: ralph-afk $PLAN_DIR $((ITERATIONS-i)) $MODEL_OVERRIDE production"
    echo "  If broken:  Fix issues, then re-run prototype phase"
    exit 0
  fi

  # Run with claude CLI
  OUTPUT_FILE=$(mktemp)
  echo "Running: claude $CLAUDE_ARGS_ITER --dangerously-skip-permissions -p ..."
  claude $CLAUDE_ARGS_ITER --dangerously-skip-permissions -p "$RALPH_WORKFLOW $RALPH_COMPLETE_MSG" > "$OUTPUT_FILE" 2>&1 &
  CLAUDE_PID=$!
  track_pid "$CLAUDE_PID"
  wait $CLAUDE_PID || true
  result=$(cat "$OUTPUT_FILE")
  rm -f "$OUTPUT_FILE"

  # Cleanup
  kill_and_cleanup "$CLAUDE_PID"

  echo "$result"

  # Log task completion
  if echo "$result" | grep -q "TASK_BLOCKED\|ERROR\|error"; then
    log_task_complete "$NEXT_TASK" "blocked" "Task encountered issues" "$PLAN_DIR"
  else
    log_task_complete "$NEXT_TASK" "completed" "Iteration $i completed" "$PLAN_DIR"
  fi

  # Check for all-done signal
  if [[ "$result" == *"ALL_TASKS_DONE"* ]]; then
    echo ""
    echo "All tasks complete after $i iterations."
    COMPLETED_COUNT=$(grep -c "^\- \[x\]" "$TASKS_FILE" 2>/dev/null || echo "0")
    log_task_complete "All tasks" "completed" "All $COMPLETED_COUNT tasks completed in $i iterations" "$PLAN_DIR"
    notify "Ralph Complete" "$COMPLETED_COUNT tasks done in $i iterations!"
    exit 0
  fi
done

echo ""
echo "Reached iteration limit ($ITERATIONS). Check progress.md for status."
COMPLETED_COUNT=$(grep -c "^\- \[x\]" "$TASKS_FILE" 2>/dev/null || echo "0")
REMAINING_COUNT=$(grep -c "^\- \[ \]" "$TASKS_FILE" 2>/dev/null || echo "0")

log_task_complete "Session" "blocked" "Iteration limit ($ITERATIONS) reached. $COMPLETED_COUNT done, $REMAINING_COUNT remaining" "$PLAN_DIR"
notify "Ralph Paused" "$COMPLETED_COUNT done, $REMAINING_COUNT remaining (limit: $ITERATIONS)"
