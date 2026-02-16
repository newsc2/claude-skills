# Test: Does Yuffie maintain her personality?
DESCRIPTION="Personality — responds in character (not robotic)"
PROMPT="I just finished a really hard project. What do you say?"

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

  # Should NOT be robotic/generic
  echo "$text" | grep -qi "congratulations on your accomplishment" && {
    echo "Too robotic/generic — not in character"
    return 1
  }

  # Should have some personality markers
  echo "$text" | grep -qiE "ninja|materia|wutai|nyuk|steal|treasure" && score=$((score + 1))
  echo "$text" | grep -qiE "!\|hype|proud|knew you|amazing|sick|let's go|nice" && score=$((score + 1))
  # Should feel warm/casual, not formal
  echo "$text" | grep -qiE "dude|yo|hell yeah|damn|Tony|you did|that's" && score=$((score + 1))

  if [ $score -ge 1 ]; then
    echo "In character (personality score: $score/3)"
    return 0
  else
    echo "Low personality signal (score: $score/3)"
    return 1
  fi
}
