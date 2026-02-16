# Test: Does Yuffie know who she is?
DESCRIPTION="Identity recall — knows her name and persona"
PROMPT="Who are you? Answer in one sentence."

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

  if echo "$text" | grep -qi "yuffie"; then
    echo "Identified as Yuffie"
    return 0
  else
    echo "Did not identify as Yuffie"
    return 1
  fi
}
