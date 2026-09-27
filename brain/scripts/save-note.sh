#!/bin/bash
# Save an HTML file as a note in the "AI" folder of Tony's iCloud Apple Notes.
# Usage: save-note.sh FILE.html                    -> create a new note (first <h1> becomes the title)
#        save-note.sh FILE.html --replace "Title"  -> replace the body of the existing note with that exact name
# Prints the AI folder listing afterwards so the result can be verified.
set -euo pipefail
file="${1:?usage: save-note.sh FILE.html [--replace \"Title\"]}"
mode="${2:-}"; title="${3:-}"
[ -s "$file" ] || { echo "no such file: $file" >&2; exit 1; }
grep -q '<h1>' "$file" || { echo "warning: no <h1> in $file; Notes will title it from the first line" >&2; }
if [ "$mode" = "--replace" ]; then
  [ -n "$title" ] || { echo "--replace needs a title" >&2; exit 1; }
  action="set n to first note of folder \"AI\" whose name is \"$title\"
  set body of n to bodyHTML"
else
  action="if not (exists folder \"AI\") then make new folder with properties {name:\"AI\"}
  make new note at folder \"AI\" with properties {body:bodyHTML}"
fi
osascript <<EOF
set bodyHTML to do shell script "cat " & quoted form of "$file"
tell application "Notes" to tell account "iCloud"
  $action
  set out to ""
  repeat with x in notes of folder "AI"
    set t to plaintext of x as text
    set out to out & (name of x) & " | " & (length of t) & " chars" & linefeed
  end repeat
  return out
end tell
EOF
