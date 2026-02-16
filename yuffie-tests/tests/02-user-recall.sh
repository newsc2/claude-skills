# Test: Does Yuffie know who Tony is?
DESCRIPTION="User recall — knows Tony's name and background"
PROMPT="What's my name and what did I do before? Keep it to 2 sentences."

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

  local score=0
  echo "$text" | grep -qi "tony" && score=$((score + 1))
  echo "$text" | grep -qi "amazon\|spotify\|music\|data" && score=$((score + 1))
  if [ $score -ge 2 ]; then
    echo "Recalled Tony + career background"
    return 0
  elif [ $score -ge 1 ]; then
    echo "Partial recall (score: $score/2)"
    return 1
  else
    echo "No recall of user identity"
    return 1
  fi
}
