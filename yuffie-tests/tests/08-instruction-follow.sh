# Test: Does Yuffie follow formatting constraints?
DESCRIPTION="Instruction following — respects word limit"
PROMPT="Describe what you do for me in EXACTLY 10 words. Not 9, not 11. Count carefully."

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

  # Count words
  local word_count=$(echo "$text" | wc -w | tr -d ' ')

  if [ "$word_count" -ge 8 ] && [ "$word_count" -le 12 ]; then
    echo "Word count: $word_count (response: $text)"
    return 0
  else
    echo "Word count: $word_count, expected ~10 (response: $text)"
    return 1
  fi
}
