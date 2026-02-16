# Test: Can Yuffie do a web search and return results?
DESCRIPTION="Tool use — web search with result synthesis"
PROMPT="Search the web for 'S&P 500 today' and tell me the current level in one sentence. No extra commentary."

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

  # Should contain a number that looks like an index level (handles commas: 6,836)
  if echo "$text" | grep -qE "[0-9],?[0-9]{3}"; then
    echo "Returned market data with numeric value"
    return 0
  elif echo "$text" | grep -qi "rate.limit\|429\|error"; then
    echo "Search rate-limited or errored"
    return 1
  else
    echo "No numeric market data found in response"
    return 1
  fi
}
