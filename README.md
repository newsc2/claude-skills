# Claude Code Skills

Personal Claude Code skills shared across machines via git.

## Setup

Clone to `~/.claude/skills/` on each machine:

```bash
git clone https://github.com/newsc2/claude-skills.git ~/.claude/skills
```

Add aliases to `~/.zshrc`:

```bash
# Ralph - Autonomous AI Coding Loop
export RALPH_DIR="$HOME/.claude/skills/ralph"
alias ralph-init="$RALPH_DIR/scripts/ralph-init.sh"
alias ralph-review="$RALPH_DIR/scripts/ralph-review.sh"
alias ralph-once="$RALPH_DIR/scripts/ralph-once.sh"
alias ralph-afk="$RALPH_DIR/scripts/ralph-afk.sh"
alias ralph-kill="$RALPH_DIR/scripts/ralph-kill.sh"
```

## Skills

### ralph/
Autonomous AI coding loop. Runs Claude on a task list, one task per iteration, with progress tracking, model auto-selection, and checkpoint support.

See [ralph/SKILL.md](ralph/SKILL.md) for full docs.
