#!/bin/bash
# Shared workflow for Ralph automation
# Used by: ralph-once.sh, ralph-afk.sh
# Adapted for Claude Max plan (uses `claude` directly, no ccs)

# Require PLAN_DIR to be set
if [ -z "$PLAN_DIR" ]; then
  echo "Error: PLAN_DIR not set"
  exit 1
fi

# Quality mode: prototype (fast) or production (full quality)
RALPH_MODE="${RALPH_MODE:-production}"

# File paths
PLAN_FILE="$PLAN_DIR/plan.md"
CONTEXT_FILE="$PLAN_DIR/context.md"
PROGRESS_FILE="$PLAN_DIR/progress.md"
TASKS_FILE="$PLAN_DIR/tasks.md"
ERRORS_LOG="$PLAN_DIR/errors.log"
ACTIVITY_LOG="$PLAN_DIR/activity.log"

# Global log file (for watching all plans)
GLOBAL_LOG="plans/ralph-log.md"

# Extract plan name from path (e.g., "260109-1500-my-feature")
PLAN_NAME=$(basename "$PLAN_DIR")

# Ralph skill directory
RALPH_SKILL_DIR="${RALPH_SKILL_DIR:-$HOME/.claude/skills/ralph}"

# Global guardrails file (append-only failure log)
GUARDRAILS_FILE="$RALPH_SKILL_DIR/guardrails.md"

# ─── Model Selection ───────────────────────────────────────────────

# Auto-select model based on task keywords
# Strategy: Opus for complex reasoning, Sonnet for everything else
detect_model() {
  local task="$1"

  # Check for explicit model tag: [OPUS], [SONNET], [HAIKU]
  if echo "$task" | grep -qiE "\[OPUS\]"; then
    echo "opus"
    return
  elif echo "$task" | grep -qiE "\[HAIKU\]"; then
    echo "haiku"
    return
  elif echo "$task" | grep -qiE "\[SONNET\]"; then
    echo "sonnet"
    return
  fi

  # Auto-detect based on keywords
  # PLANNING/COMPLEX → Opus
  if echo "$task" | grep -qiE "plan|architect|design|debug|restructure|refactor.*complex|multi-file|analyze"; then
    echo "opus"
  # Everything else → Sonnet (fast, capable enough)
  else
    echo "sonnet"
  fi
}

# Build claude CLI args from model
build_claude_args() {
  local model="$1"
  echo "--model $model"
}

# ─── Task Detection ────────────────────────────────────────────────

# Detect task source: tasks.md OR phase files
detect_task_source() {
  if [ -f "$TASKS_FILE" ]; then
    echo "tasks"
  elif [ -n "$(get_phase_files)" ]; then
    echo "phases"
  else
    echo "none"
  fi
}

# Get phase files sorted
get_phase_files() {
  ls "$PLAN_DIR"/phase-*.md 2>/dev/null | sort
}

# Get next incomplete task from tasks.md
get_next_task_from_tasks() {
  grep -m1 "^\- \[ \]" "$TASKS_FILE" 2>/dev/null | sed 's/- \[ \] //' || echo ""
}

# Get next incomplete task from phase files
get_next_task_from_phases() {
  for phase in $(get_phase_files); do
    task=$(grep -m1 "^\- \[ \]" "$phase" 2>/dev/null | sed 's/- \[ \] //')
    if [ -n "$task" ]; then
      echo "$task"
      return
    fi
  done
  echo ""
}

# Get next task based on source
get_next_task() {
  local source=$(detect_task_source)
  if [ "$source" = "tasks" ]; then
    get_next_task_from_tasks
  elif [ "$source" = "phases" ]; then
    get_next_task_from_phases
  else
    echo ""
  fi
}

# ─── Session Naming ────────────────────────────────────────────────

build_session_name() {
  local completed_count
  completed_count=$(grep -c "^\- \[x\]" "$TASKS_FILE" 2>/dev/null) || completed_count=0
  local task_num=$((completed_count + 1))
  local task_preview="${NEXT_TASK:0:40}"
  echo "[Ralph] $PLAN_NAME: T$task_num - $task_preview"
}

# ─── Checkpoint Detection ──────────────────────────────────────────

is_checkpoint() {
  local task="$1"
  echo "$task" | grep -qE "^\s*CHECKPOINT|PAUSE:|manual.*(verify|test|check)"
}

# ─── File References ───────────────────────────────────────────────

build_file_refs() {
  local refs=""

  # Include Ralph design philosophy
  [ -f "$RALPH_SKILL_DIR/CLAUDE.md" ] && refs="@$RALPH_SKILL_DIR/CLAUDE.md"

  # Include global guardrails (failures to avoid)
  [ -f "$GUARDRAILS_FILE" ] && refs="$refs @$GUARDRAILS_FILE"

  # Always include progress if exists
  [ -f "$PROGRESS_FILE" ] && refs="$refs @$PROGRESS_FILE"

  # Include context if exists (key files to focus on)
  [ -f "$CONTEXT_FILE" ] && refs="$refs @$CONTEXT_FILE"

  # Include plan overview
  [ -f "$PLAN_FILE" ] && refs="$refs @$PLAN_FILE"

  # Include task source
  local source=$(detect_task_source)
  if [ "$source" = "tasks" ]; then
    refs="$refs @$TASKS_FILE"
  elif [ "$source" = "phases" ]; then
    for phase in $(get_phase_files); do
      refs="$refs @$phase"
    done
  fi

  echo "$refs"
}

# ─── Export Variables ──────────────────────────────────────────────

TASK_SOURCE=$(detect_task_source)
NEXT_TASK=$(get_next_task)
RALPH_MODEL=$(detect_model "$NEXT_TASK")
CLAUDE_ARGS=$(build_claude_args "$RALPH_MODEL")
FILE_REFS=$(build_file_refs)
SESSION_NAME=$(build_session_name)
IS_CHECKPOINT=$(is_checkpoint "$NEXT_TASK" && echo "yes" || echo "no")
export TASK_SOURCE NEXT_TASK RALPH_MODEL CLAUDE_ARGS PLAN_DIR PROGRESS_FILE TASKS_FILE RALPH_MODE GLOBAL_LOG PLAN_NAME IS_CHECKPOINT SESSION_NAME GUARDRAILS_FILE ERRORS_LOG ACTIVITY_LOG

# ─── Build Prompt ──────────────────────────────────────────────────

# Context instructions (if context.md exists)
CONTEXT_INSTRUCTIONS=""
if [ -f "$CONTEXT_FILE" ]; then
  CONTEXT_INSTRUCTIONS="IMPORTANT: Read context.md FIRST for key files to focus on. This saves exploration time. \\"
fi

# Quality mode instructions
MODE_INSTRUCTIONS=""
if [ "$RALPH_MODE" = "prototype" ]; then
  MODE_INSTRUCTIONS="MODE: PROTOTYPE - Make it work first. \\
   CRITICAL: Do NOT write unit tests. Do NOT write e2e tests. Do NOT run lint. \\
   Just implement core functionality and verify it works. \\"
else
  MODE_INSTRUCTIONS="MODE: PRODUCTION - Quality code required. Full tests, handle edge cases, maintainable code. \\"
fi

# Build quality-specific steps
if [ "$RALPH_MODE" = "prototype" ]; then
  QUALITY_STEPS="6. DO NOT run tests or lint. Just verify core functionality works. \\"
else
  QUALITY_STEPS="6. Run linting if available (skip if no lint script). \\
7. Run tests if available (must pass before completing). \\
   If tests fail, append to errors.log and fix before continuing. \\"
fi

# Main workflow prompt
RALPH_WORKFLOW="$SESSION_NAME

$FILE_REFS \\
$MODE_INSTRUCTIONS
$CONTEXT_INSTRUCTIONS
1. Read the plan files to understand the current state. \\
2. Find the next incomplete task (unchecked checkbox [ ]). \\
   - If using tasks.md: Look in tasks.md \\
   - If using phases: Look in phase-XX-*.md files in order \\
3. BEFORE starting, append to BOTH progress.md AND $GLOBAL_LOG (create if not exists): \\
   --- \\
   ## [$PLAN_NAME] Task N: [task description] \\
   **Status:** In Progress | **Time:** [YYYY-MM-DD HH:MM] | **Model:** $RALPH_MODEL | **Mode:** $RALPH_MODE \\
   ### Plan \\
   - [step 1] \\
   - [step 2] \\
4. Implement the task. \\
   - PROTOTYPE: Get it working, skip edge cases, minimal error handling. \\
   - PRODUCTION: Write tests, handle edge cases, maintainable code. \\
5. LOGGING (append-only): \\
   a) progress.md - Task status only: \\
      - [HH:MM] Started: [task description] \\
      - [HH:MM] Completed: [result summary] \\
   b) activity.log - Tool usage (create if not exists): \\
      [HH:MM] READ: [file] \\
      [HH:MM] EDIT: [file] - [what changed] \\
      [HH:MM] BASH: [command] \\
   c) errors.log - When things fail (create if not exists): \\
      [HH:MM] ERROR: [what failed] \\
      [HH:MM] CAUSE: [why it failed] \\
      [HH:MM] FIX: [how you fixed it] \\
$QUALITY_STEPS
8. When done, append to progress.md: \\
   ### Result \\
   **Status:** Completed | **Completed:** [HH:MM] \\
   [what was achieved] \\
9. Mark the task as complete by changing [ ] to [x] in the source file. \\
10. Commit all changes with a descriptive message. \\
ONLY WORK ON A SINGLE TASK."

# Completion signal for loop detection
RALPH_COMPLETE_MSG='If all tasks are complete (no unchecked boxes remain in any file), output exactly: ALL_TASKS_DONE'

export RALPH_WORKFLOW RALPH_COMPLETE_MSG
