#!/usr/bin/env bash
#
# smoke_test.sh — repeatable integration smoke test for the currency-insurance
# exam app. Run from anywhere; it resolves the repo root itself.
#
# Stages:
#   1. flutter test               (Dart/Flutter widget + unit test suite)
#   2. python3 -m pytest -v       (content-extraction pipeline test suite)
#   3. flutter build web          (confirms the web bundle actually builds)
#
# Exits non-zero (and prints a clear FAIL banner) on the first stage that
# fails. Intended to be run by a human before merging/deploying, or wired
# into CI.

set -uo pipefail

# Resolve repo root as the directory this script lives in, one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED_STAGES=()

run_stage() {
  local name="$1"
  shift
  echo ""
  echo -e "${YELLOW}==>${NC} Running: ${name}"
  echo "----------------------------------------------------------------------"
  if "$@"; then
    echo "----------------------------------------------------------------------"
    echo -e "${GREEN}PASS${NC}: ${name}"
    return 0
  else
    local status=$?
    echo "----------------------------------------------------------------------"
    echo -e "${RED}FAIL${NC}: ${name} (exit ${status})"
    FAILED_STAGES+=("$name")
    return 1
  fi
}

echo "========================================================================"
echo " Currency Insurance Exam — Integration Smoke Test"
echo " Repo root: ${REPO_ROOT}"
echo "========================================================================"

run_stage "Flutter test suite (flutter test)" \
  flutter test

run_stage "Python content-pipeline test suite (pytest)" \
  bash -c "cd '${REPO_ROOT}/scripts/extract' && python3 -m pytest -v"

run_stage "Flutter web build (flutter build web)" \
  flutter build web

echo ""
echo "========================================================================"
if [ ${#FAILED_STAGES[@]} -eq 0 ]; then
  echo -e " ${GREEN}ALL STAGES PASSED${NC}"
  echo "========================================================================"
  exit 0
else
  echo -e " ${RED}SMOKE TEST FAILED${NC} — ${#FAILED_STAGES[@]} stage(s) failed:"
  for s in "${FAILED_STAGES[@]}"; do
    echo -e "   - ${RED}${s}${NC}"
  done
  echo "========================================================================"
  exit 1
fi
