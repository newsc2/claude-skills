---
name: ralph
description: Autonomous AI coding loop. Use when user wants to run tasks from a plan autonomously, go AFK while coding, or automate repetitive development work. Triggers on "ralph", "afk coding", "autonomous loop", "run tasks automatically".
---

# Ralph - Autonomous AI Coding Loop

Run AI coding in a loop, letting it work autonomously on a list of tasks from a plans directory.

## Modes

| Mode | Script | Use Case |
|------|--------|----------|
| Review | `ralph-review` | Pre-flight check, surface unclear requirements |
| HITL (human-in-the-loop) | `ralph-once` | Learning, prompt refinement, risky tasks |
| AFK (away from keyboard) | `ralph-afk` | Bulk work, low-risk tasks, overnight runs |

## Quality Modes

| Mode | Flag | Behavior |
|------|------|----------|
| Prototype | `prototype` | Speed over perfection. No tests, no lint, just make it work |
| Production | `production` | Full quality. Tests, edge cases, maintainable code |

## Plan Structure

Ralph works with your existing plans directory:

```
plans/{date}-{slug}/
├── tasks.md      # Task file with checkboxes [ ] and [x]
├── context.md    # Key files to focus on (optional, saves tokens)
└── progress.md   # Auto-generated progress log
```

### context.md (Optional - Saves Exploration Tokens)

Create this file to tell Ralph which files are relevant, avoiding re-discovery each task:

```markdown
# Context

## Key Files
- src/components/Calculator.jsx   # Main component to modify
- src/utils/parser.js             # Parser logic

## Patterns
- Components use useReducer for state
- Tests located in __tests__/ directories
```

Ralph reads context.md FIRST before starting any task, saving exploration time.

## Usage

### Initialize Ralph in a project
```bash
ralph-init "my-feature"
# Creates: plans/YYMMDD-HHMM-my-feature/tasks.md
```

### Run single iteration (HITL)
```bash
ralph-once plans/260109-my-feature/
# Or with model override:
ralph-once plans/260109-my-feature/ opus
```

### Run AFK loop
```bash
ralph-afk plans/260109-my-feature/ 5
# Runs 5 iterations with auto model selection
# Or with model and mode override:
ralph-afk plans/260109-my-feature/ 10 sonnet prototype
```

## Model Selection

Ralph auto-selects the Claude model based on task keywords:

| Keywords | Model | Reasoning |
|----------|-------|-----------|
| plan, architect, design, debug, analyze | opus | Complex reasoning |
| implement, create, add, build, fix, test, lint, docs | sonnet | Fast execution |
| (default) | sonnet | Safe middle ground |

### Explicit Model Tags

Force a specific model by adding tags to task descriptions:

```markdown
- [ ] [OPUS] Debug the authentication flow
- [ ] [SONNET] Implement the login form
- [ ] [HAIKU] Write documentation
```

### Override via CLI

```bash
ralph-once <plan> sonnet           # Force Sonnet for all
ralph-once <plan> opus             # Force Opus
ralph-afk <plan> 5 auto            # Auto-select per task (default)
```

## Task File Format (tasks.md)

```markdown
# Feature Name

## Tasks

- [ ] First task description
  - **AC:** Acceptance criteria
- [ ] Second task
  - **AC:** What done looks like
- [x] Completed task
```

## Progress Tracking

Ralph appends to `progress.md` (never overwrites):

```markdown
---
## Task N: [description]
**Status:** In Progress | **Time:** YYYY-MM-DD HH:MM | **Model:** sonnet

### Plan
- Step 1
- Step 2

### Actions
- [HH:MM] Action taken
- [HH:MM] ERROR: What failed (if any)
- [HH:MM] FIX: What was tried

### Result
**Status:** Completed | **Completed:** HH:MM
```

## Feedback Loops

Ralph runs these checks before marking complete:
1. `npm run lint -- --fix` / `ruff check --fix` (if available)
2. `npm test` / `pytest` (must pass)
3. Commits changes with descriptive message

## Recommended Workflow (Validate First)

```
1. ralph-init my-feature     # Creates plan with prototype-first structure
2. Edit tasks.md             # Add your tasks
3. ralph-review <plan>       # Pre-flight: surface unclear requirements
4. ralph-afk <plan> 5 auto prototype  # Phase 1: Make it work (no tests)
   → Ralph auto-pauses at CHECKPOINT
5. Manual test               # Verify it actually works!
6. ralph-afk <plan> 5 auto production # Phase 2: Add quality (tests, lint)
```

## Checkpoints

Add `CHECKPOINT:` to any task to force Ralph to pause:

```markdown
- [ ] CHECKPOINT: Manual verification
  - **AC:** Manually test the feature works
  - **PAUSE:** Stop here, verify before Phase 2
```

Ralph will:
1. Detect checkpoint task
2. Log pause to progress.md
3. Mark checkpoint complete
4. Exit with instructions for next steps

## Best Practices

1. **Prototype first** - Get it working before adding tests
2. **Use checkpoints** - Pause between prototype and quality phases
3. **Review first** - Run `ralph-review` to catch unclear requirements
4. **Small tasks** - One feature per checkbox, not epics
5. **Cap iterations** - Always limit AFK runs (5-10 small, 30-50 large)

## Installation

Add to your shell profile (~/.zshrc or ~/.bashrc):

```bash
# Ralph aliases
export RALPH_DIR="$HOME/.claude/skills/ralph"
alias ralph-init="$RALPH_DIR/scripts/ralph-init.sh"
alias ralph-review="$RALPH_DIR/scripts/ralph-review.sh"
alias ralph-once="$RALPH_DIR/scripts/ralph-once.sh"
alias ralph-afk="$RALPH_DIR/scripts/ralph-afk.sh"
```
