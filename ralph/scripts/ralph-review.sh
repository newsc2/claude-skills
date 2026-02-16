#!/bin/bash
# Pre-flight review: surface unclear requirements before running
# Usage: ralph-review <plan-dir> [model]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$1" ]; then
  echo "Usage: ralph-review <plan-dir> [model]"
  echo "Example: ralph-review plans/260109-my-feature/"
  echo ""
  echo "Reviews your plan for:"
  echo "  - Unclear or ambiguous acceptance criteria"
  echo "  - Missing context (files, patterns)"
  echo "  - Tasks that are too large (should be split)"
  echo "  - Potential blockers or dependencies"
  exit 1
fi

PLAN_DIR="$1"
MODEL="${2:-sonnet}"

# Verify plan exists
if [ ! -f "$PLAN_DIR/tasks.md" ]; then
  echo "Error: $PLAN_DIR/tasks.md not found"
  exit 1
fi

# Build file refs
FILE_REFS=""
[ -f "$PLAN_DIR/context.md" ] && FILE_REFS="$FILE_REFS @$PLAN_DIR/context.md"
[ -f "$PLAN_DIR/plan.md" ] && FILE_REFS="$FILE_REFS @$PLAN_DIR/plan.md"
FILE_REFS="$FILE_REFS @$PLAN_DIR/tasks.md"

echo "=== Ralph Review ==="
echo "Plan: $PLAN_DIR"
echo "Model: $MODEL"
echo "===================="
echo ""

claude --model "$MODEL" -p "$FILE_REFS

Review this plan and surface potential issues. For each task, check:

1. **Unclear AC**: Is the acceptance criteria specific enough to verify?
2. **Too Large**: Should any task be split into smaller ones?
3. **Missing Context**: Are key files/patterns documented in context.md?
4. **Dependencies**: Are tasks in the right order? Any missing prerequisites?
5. **Ambiguity**: Could a task be interpreted multiple ways?

Output format:
## Review Summary
- [count] tasks reviewed
- [count] issues found

## Issues
For each issue:
- **Task:** [task text]
- **Issue:** [what's wrong]
- **Suggestion:** [how to fix]

## Verdict
READY / NEEDS CHANGES

If READY, say so. If NEEDS CHANGES, list exactly what to fix."
