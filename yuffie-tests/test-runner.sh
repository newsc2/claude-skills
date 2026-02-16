#!/bin/bash
# Yuffie Test Runner — lightweight agent task reliability tests
# Usage: yuffie-test [test-name|all] [--agent main|opus-briefing] [--dry-run]
#
# Tests send a task to Yuffie via `openclaw agent`, capture output,
# and check for expected markers. Results logged to results/.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
TESTS_DIR="$SCRIPT_DIR/tests"
TIMESTAMP=$(date '+%y%m%d-%H%M')
RUN_DIR="$RESULTS_DIR/$TIMESTAMP"

AGENT="main"
DRY_RUN=false
TEST_FILTER="all"
TIMEOUT=120

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) TEST_FILTER="$1"; shift ;;
  esac
done

mkdir -p "$RUN_DIR"

# ─── Test Discovery ───────────────────────────────────────────────

discover_tests() {
  if [ "$TEST_FILTER" = "all" ]; then
    ls "$TESTS_DIR"/*.sh 2>/dev/null | sort
  else
    ls "$TESTS_DIR"/${TEST_FILTER}*.sh 2>/dev/null | sort
  fi
}

# ─── Run a Single Test ────────────────────────────────────────────

run_test() {
  local test_file="$1"
  local test_name=$(basename "$test_file" .sh)
  local output_file="$RUN_DIR/${test_name}.out"
  local result_file="$RUN_DIR/${test_name}.result"

  # Source the test to get PROMPT, CHECK_FN, and optional SETUP_FN/TEARDOWN_FN
  unset PROMPT CHECK_FN DESCRIPTION EXPECTED_TOOLS SETUP_FN TEARDOWN_FN
  source "$test_file"

  # Run setup if defined
  if type SETUP_FN &>/dev/null; then
    SETUP_FN
  fi

  echo -n "  $test_name: $DESCRIPTION ... "

  if [ "$DRY_RUN" = true ]; then
    echo "SKIP (dry-run)"
    echo "skip" > "$result_file"
    return 0
  fi

  # Send to Yuffie via openclaw agent
  local start_time=$(date +%s)
  openclaw agent \
    --agent "$AGENT" \
    --message "$PROMPT" \
    --timeout "$TIMEOUT" \
    --json \
    --session-id "yuffie-test-${test_name}-${TIMESTAMP}" \
    > "$output_file" 2>&1 || true
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Run the check function
  local output=$(cat "$output_file")
  local check_result
  check_result=$(CHECK_FN "$output" 2>&1)
  local check_exit=$?

  # Run teardown if defined
  if type TEARDOWN_FN &>/dev/null; then
    TEARDOWN_FN
  fi

  if [ $check_exit -eq 0 ]; then
    echo "PASS (${duration}s)"
    echo "pass|${duration}s|$check_result" > "$result_file"
    return 0
  else
    echo "FAIL (${duration}s) — $check_result"
    echo "fail|${duration}s|$check_result" > "$result_file"
    return 1
  fi
}

# ─── Main ─────────────────────────────────────────────────────────

echo "=== Yuffie Test Run ==="
echo "Time: $TIMESTAMP"
echo "Agent: $AGENT"
echo "Filter: $TEST_FILTER"
echo "Timeout: ${TIMEOUT}s"
echo "Results: $RUN_DIR/"
echo "========================"
echo ""

TESTS=$(discover_tests)
if [ -z "$TESTS" ]; then
  echo "No tests found matching '$TEST_FILTER' in $TESTS_DIR/"
  exit 1
fi

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

for test_file in $TESTS; do
  TOTAL=$((TOTAL + 1))
  run_test "$test_file" && rc=0 || rc=$?
  result=$(cat "$RUN_DIR/$(basename "$test_file" .sh).result" 2>/dev/null)
  if [[ "$result" == skip* ]]; then
    SKIPPED=$((SKIPPED + 1))
  elif [ $rc -eq 0 ]; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=== Results ==="
echo "Total: $TOTAL | Pass: $PASSED | Fail: $FAILED | Skip: $SKIPPED"
PASS_RATE=0
if [ $((TOTAL - SKIPPED)) -gt 0 ]; then
  PASS_RATE=$(( (PASSED * 100) / (TOTAL - SKIPPED) ))
fi
echo "Pass rate: ${PASS_RATE}%"
echo ""

# Write summary
cat > "$RUN_DIR/summary.md" << EOF
# Yuffie Test Run — $TIMESTAMP

| Metric | Value |
|--------|-------|
| Agent | $AGENT |
| Total | $TOTAL |
| Pass | $PASSED |
| Fail | $FAILED |
| Skip | $SKIPPED |
| Pass Rate | ${PASS_RATE}% |

## Results
EOF

for result_file in "$RUN_DIR"/*.result; do
  test_name=$(basename "$result_file" .result)
  result=$(cat "$result_file")
  status=$(echo "$result" | cut -d'|' -f1)
  duration=$(echo "$result" | cut -d'|' -f2)
  detail=$(echo "$result" | cut -d'|' -f3-)
  echo "- **$test_name**: $status ($duration) $detail" >> "$RUN_DIR/summary.md"
done

echo "Summary: $RUN_DIR/summary.md"
