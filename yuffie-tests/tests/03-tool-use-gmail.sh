# Test: Can Yuffie use gog to scan Gmail?
DESCRIPTION="Tool use — Gmail search via gog CLI"
PROMPT="Check my Gmail primary inbox for unread emails. Just tell me the count — nothing else. Use: gog gmail search \"is:unread category:primary\" --max 5 --json --account newsc2@gmail.com"

CHECK_FN() {
  local output="$1"
  # Extract text from OpenClaw JSON response
  local text=$(echo "$output" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    payloads = data.get('result', {}).get('payloads', [])
    print(payloads[0]['text'] if payloads else '')
except: print(sys.stdin.read())
" 2>/dev/null)

  # Should contain a number — even "0" means the tool ran
  if echo "$text" | grep -qE "^[0-9]+$|[0-9]+ (unread|email|message)|no (unread|new)|inbox.*(empty|clear)|found [0-9]"; then
    echo "Gmail tool executed, returned: $text"
    return 0
  elif echo "$text" | grep -qi "error\|fail\|couldn't\|unable"; then
    echo "Tool execution failed: $text"
    return 1
  else
    echo "Unclear result: $text"
    return 1
  fi
}
