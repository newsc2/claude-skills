#!/usr/bin/env bash
# sync-personal.sh — keep the laptop copy of ~/Projects/personal in step with the Mac Mini, which is canonical.
#
#   sync-personal.sh            # same as "sync"
#   sync-personal.sh status     # show what would move, both ways; changes nothing
#   sync-personal.sh sync       # push laptop files changed since the last sync, then pull everything from the Mini
#   sync-personal.sh push       # push only; never deletes on the Mini
#   sync-personal.sh pull       # pull only; refuses if the laptop has unpushed changes
#
# Rules: the Mini is the source of truth. Delete or rename on the Mini, then pull; the laptop follows.
# Laptop edits are pushed per file, newest wins. Laptop files deleted on the Mini are deleted on pull,
# capped at MAX_DELETE per run as a guard against a wiped or wrong remote path.
set -euo pipefail
HOST="${PERSONAL_SYNC_HOST:-macmini}"
REMOTE="/Users/newsc2/Projects/personal/"
LOCAL="$HOME/Projects/personal/"
STAMP="$HOME/.claude/.personal-sync-stamp"
MAX_DELETE="${PERSONAL_SYNC_MAX_DELETE:-25}"
EXCL=(--exclude '.DS_Store' --exclude '.claude/' --exclude '.omc/' --exclude '__pycache__/' --exclude '.venv/')
RS=(rsync -rltp --itemize-changes "${EXCL[@]}" -e "ssh -o ConnectTimeout=10")

[ -d "$LOCAL" ] || { echo "no laptop copy at $LOCAL" >&2; exit 2; }
ssh -o ConnectTimeout=10 "$HOST" true 2>/dev/null || { echo "Mac Mini ($HOST) unreachable; check Tailscale" >&2; exit 3; }

changed_since_stamp() {
  # Laptop files created or modified since the last sync. ctime, not mtime, so files copied in with
  # preserved timestamps (rsync -t, exports) still count as new.
  [ -f "$STAMP" ] || { echo "no sync stamp at $STAMP; run 'push' once to create it" >&2; return 1; }
  (cd "$LOCAL" && find . -type f -cnewer "$STAMP" ! -name .DS_Store ! -path './.claude/*' ! -path '*/.omc/*' \
      ! -path '*/__pycache__/*' ! -path '*/.venv/*' | sed 's#^\./##' | sort)
}

do_push() {
  local list
  if [ -f "$STAMP" ]; then list=$(changed_since_stamp); else list=$(cd "$LOCAL" && find . -type f ! -name .DS_Store ! -path './.claude/*' ! -path '*/.omc/*' | sed 's#^\./##' | sort); fi
  if [ -z "$list" ]; then echo "push: nothing changed on the laptop since the last sync"; touch "$STAMP"; return 0; fi
  echo "push: $(printf '%s\n' "$list" | wc -l | tr -d ' ') laptop file(s) changed since the last sync"
  printf '%s\n' "$list" | "${RS[@]}" --update --files-from=- "$LOCAL" "$HOST:$REMOTE" | grep -v '^\.d' | sed 's/^/  /' || true
  touch "$STAMP"
}

do_pull() {  # $1 = "checked" to refuse on unpushed laptop changes
  if [ "${1:-}" = "checked" ]; then
    local pending; pending=$(changed_since_stamp)
    if [ -n "$pending" ]; then
      echo "pull: laptop has unpushed changes; run 'push' or 'sync' first:" >&2
      printf '%s\n' "$pending" | sed 's/^/  /' >&2; exit 5
    fi
  fi
  local dry ndel
  dry=$("${RS[@]}" --delete --dry-run "$HOST:$REMOTE" "$LOCAL" | grep -v '^\.d' || true)
  ndel=$(printf '%s\n' "$dry" | grep -c '^\*deleting' || true)
  if [ "$ndel" -gt "$MAX_DELETE" ]; then
    echo "pull: would delete $ndel laptop file(s), over the cap of $MAX_DELETE. Check the Mini copy; to proceed: PERSONAL_SYNC_MAX_DELETE=$ndel $0 pull" >&2
    printf '%s\n' "$dry" | grep '^\*deleting' | head -20 | sed 's/^/  /' >&2; exit 6
  fi
  "${RS[@]}" --delete "$HOST:$REMOTE" "$LOCAL" | grep -v '^\.d' | sed 's/^/  /' || true
  touch "$STAMP"
  echo "pull: laptop mirror matches the Mini ($ndel deleted here)"
}

do_status() {
  echo "== laptop files changed since the last sync (a push would send these):"
  if [ -f "$STAMP" ]; then changed_since_stamp | sed 's/^/  /'; echo "  (last sync: $(date -r "$STAMP" '+%Y-%m-%d %H:%M'))"; else echo "  (no stamp yet)"; fi
  echo "== Mini → laptop (a pull would do these; *deleting = removed here):"
  "${RS[@]}" --delete --dry-run "$HOST:$REMOTE" "$LOCAL" | grep -v '^\.d' | sed 's/^/  /' || true
}

case "${1:-sync}" in
  status) do_status ;;
  push)   do_push ;;
  pull)   do_pull checked ;;
  sync)   do_push; do_pull ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
