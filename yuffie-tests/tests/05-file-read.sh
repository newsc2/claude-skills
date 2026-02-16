# Test: Can Yuffie read a workspace file?
DESCRIPTION="File access — read and summarize a workspace file"
PROMPT="Read your SOUL.md file and tell me your creature type in exactly 3 words."

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

  # SOUL.md says "Digital Ninja / Materia Hunter"
  if echo "$text" | grep -qi "ninja\|materia\|hunter\|digital"; then
    echo "Correctly read SOUL.md content"
    return 0
  else
    echo "Did not reference SOUL.md content"
    return 1
  fi
}
