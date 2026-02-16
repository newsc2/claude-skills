# Test: Can Yuffie handle a 2-step task?
DESCRIPTION="Multi-step — read file then answer question about it"
PROMPT="Read your HEARTBEAT.md file. How many bullet points are in it? Just give me the number."

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

  # HEARTBEAT.md has ~3-4 bullet points depending on how you count
  if echo "$text" | grep -qE "[2-6]"; then
    echo "Counted bullet points from HEARTBEAT.md"
    return 0
  else
    echo "Did not return a reasonable count"
    return 1
  fi
}
