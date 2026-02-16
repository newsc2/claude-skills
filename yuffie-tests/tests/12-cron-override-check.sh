# Test: Does an isolated session honor a preference from a file
# when given a rigid, prescriptive prompt?
#
# This simulates the real problem:
# - Tony tells Yuffie "change X" → gets written to a pref file
# - Next cron run has a rigid prompt → does the pref bleed through?
DESCRIPTION="Cron override — rigid prompt vs file-based preference"

SETUP_FN() {
  # Write a test preference file that the agent should find
  cat > /tmp/yuffie-cron-test-pref.md << 'EOF'
# Briefing Overrides
morning_greeting: Ahoy Captain
EOF
}

TEARDOWN_FN() {
  rm -f /tmp/yuffie-cron-test-pref.md
}

# Simulate a cron-like prescriptive prompt that ALSO tells the agent
# to check for overrides — this tests what happens when we add the
# preamble fix
PROMPT="BEFORE EXECUTING: Check /tmp/yuffie-cron-test-pref.md for any overrides to this routine.

Now execute this routine:
1. Start with a greeting. Default greeting is 'Good morning'.
2. Tell me today's date.
3. Say goodbye.

Keep it to 3 lines max."

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

  # The agent should have read the override and used "Ahoy Captain"
  # instead of the default "Good morning"
  if echo "$text" | grep -qi "ahoy\|captain"; then
    echo "Override applied — used 'Ahoy Captain' instead of default"
    return 0
  elif echo "$text" | grep -qi "good morning"; then
    echo "OVERRIDE IGNORED — used default 'Good morning' despite file override"
    return 1
  else
    echo "Unclear — response: $text"
    return 1
  fi
}
