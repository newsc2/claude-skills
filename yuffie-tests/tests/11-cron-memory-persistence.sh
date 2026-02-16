# Test: Does a preference written in one session persist into the next?
# This simulates the "Yuffie forgets my tweak" problem.
DESCRIPTION="Persistence — changes survive across isolated sessions"

# Step 1: In session A, ask Yuffie to remember a test preference
PROMPT="IMPORTANT TEST: I want you to write the following to a file called /tmp/yuffie-test-pref.md:
---
# Test Preference
morning_greeting: Ahoy Captain
---
Just write the file. Confirm when done."

CHECK_FN() {
  local output="$1"
  local text=$(echo "$output" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    payloads = data.get('result', {}).get('payloads', [])
    print(payloads[0]['text'] if payloads else '')
except: print(sys.stdin.read())
" 2>/dev/null)

  # Check if the file was actually written
  if [ -f "/tmp/yuffie-test-pref.md" ]; then
    content=$(cat /tmp/yuffie-test-pref.md)
    if echo "$content" | grep -q "Ahoy Captain"; then
      echo "File written with correct content"
      rm -f /tmp/yuffie-test-pref.md
      return 0
    else
      echo "File exists but wrong content: $content"
      rm -f /tmp/yuffie-test-pref.md
      return 1
    fi
  else
    echo "File was NOT written — Yuffie acknowledged but didn't act"
    return 1
  fi
}
