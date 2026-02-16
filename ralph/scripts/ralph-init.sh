#!/bin/bash
# Initialize a Ralph plan directory
# Usage: ralph-init <slug> [plan-dir]

set -e

if [ -z "$1" ]; then
  echo "Usage: ralph-init <slug> [plan-dir]"
  echo "Example: ralph-init my-feature"
  echo "         ralph-init my-feature plans/"
  echo ""
  echo "Creates: plans/YYMMDD-HHMM-<slug>/tasks.md"
  exit 1
fi

SLUG="$1"
PLAN_BASE="${2:-plans}"
DATE_PREFIX=$(date '+%y%m%d-%H%M')
PLAN_DIR="$PLAN_BASE/${DATE_PREFIX}-${SLUG}"

mkdir -p "$PLAN_DIR"

# Create tasks.md template
cat > "$PLAN_DIR/tasks.md" << 'TEMPLATE'
# Feature Name

## Tasks

### Phase 1: Prototype (make it work)
- [ ] First task description
  - **AC:** Acceptance criteria — what "done" looks like
- [ ] Second task
  - **AC:** What done looks like
- [ ] CHECKPOINT: Manual verification
  - **AC:** Manually test the prototype works
  - **PAUSE:** Stop here, verify before Phase 2

### Phase 2: Quality (make it right)
- [ ] Add tests for feature
  - **AC:** All tests pass, covers happy path + edge cases
- [ ] Lint and type-check cleanup
  - **AC:** No lint errors, type-checks pass
TEMPLATE

# Create empty progress.md
cat > "$PLAN_DIR/progress.md" << EOF
# Progress: $SLUG

Started: $(date '+%Y-%m-%d %H:%M')
EOF

echo "Created plan: $PLAN_DIR/"
echo ""
echo "Files:"
echo "  $PLAN_DIR/tasks.md      ← Edit this with your tasks"
echo "  $PLAN_DIR/progress.md   ← Auto-updated by Ralph"
echo ""
echo "Optional: Create $PLAN_DIR/context.md to list key files"
echo ""
echo "Next steps:"
echo "  1. Edit tasks.md with your actual tasks"
echo "  2. ralph-review $PLAN_DIR     # Pre-flight check"
echo "  3. ralph-afk $PLAN_DIR 5 auto prototype  # Phase 1"
