#!/bin/bash
# Dump Tony's native Apple Notes (iCloud "Notes" journal + Google "Notes" phone-era) to a text file.
# Usage: export-notes.sh OUT.txt [FOLDER ...]
#   Default folders: "iCloud:Notes" "Google:Notes". Pass "iCloud:AI" etc. to add others.
# Each note: =====NOTE===== / ACCOUNT / TITLE / CREATED / MODIFIED / ---- / plaintext
set -euo pipefail
out="${1:?usage: export-notes.sh OUT.txt [ACCOUNT:FOLDER ...]}"; shift || true
targets=("$@"); [ ${#targets[@]} -eq 0 ] && targets=("iCloud:Notes" "Google:Notes")
list=""
for t in "${targets[@]}"; do list="$list{\"${t%%:*}\", \"${t#*:}\"}, "; done
list="{${list%, }}"
osascript > "$out" <<EOF
tell application "Notes"
  set out to ""
  repeat with t in $list
    set f to folder (item 2 of t) of account (item 1 of t)
    repeat with n in notes of f
      set out to out & "=====NOTE=====" & linefeed & "ACCOUNT: " & (item 1 of t) & linefeed & "TITLE: " & (name of n) & linefeed & "CREATED: " & ((creation date of n) as «class isot» as string) & linefeed & "MODIFIED: " & ((modification date of n) as «class isot» as string) & linefeed & "----" & linefeed & (plaintext of n as text) & linefeed
    end repeat
  end repeat
  return out
end tell
EOF
echo "exported $(grep -c '=====NOTE=====' "$out") notes to $out"
