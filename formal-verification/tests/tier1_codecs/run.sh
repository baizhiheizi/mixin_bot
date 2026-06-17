#!/usr/bin/env bash
# 🔬 Lean Squad — executable correspondence harness for Tier 1 codecs.
#
# Runs the Ruby side of the harness (regenerates fixtures.json from the
# live Ruby implementation) and the Lean side (`lake build`, which
# executes the #guard statements in FVSquad/Correspondence.lean against
# the Lean model). Both must succeed for the harness to pass.
#
# Usage: bash formal-verification/tests/tier1_codecs/run.sh
#
# Exit code: 0 = both sides passed; 1 = at least one side failed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TEST_DIR="${REPO_ROOT}/formal-verification/tests/tier1_codecs"
LEAN_DIR="${REPO_ROOT}/formal-verification/lean"

echo "============================================================"
echo "Lean Squad — Tier 1 Codecs Correspondence Harness"
echo "============================================================"
echo "Repo root:    ${REPO_ROOT}"
echo "Test dir:     ${TEST_DIR}"
echo "Lean dir:     ${LEAN_DIR}"
echo ""

# ----------------------------------------------------------------------
# Step 1: Ruby side — regenerate the expected byte values.
# ----------------------------------------------------------------------

echo "[1/2] Ruby side: regenerating fixtures.json from live Ruby"
echo "------------------------------------------------------------"
if ! command -v ruby >/dev/null 2>&1; then
  echo "ERROR: ruby not found on PATH" >&2
  exit 1
fi

ruby "${TEST_DIR}/ruby_harness.rb" > "${TEST_DIR}/fixtures.json"

# Spot-check the fixture has the expected top-level keys
for key in varint uint16 uint32 uint64; do
  if ! ruby -rjson -e "exit(JSON.parse(STDIN.read)['${key}'] ? 0 : 1)" < "${TEST_DIR}/fixtures.json"; then
    echo "ERROR: fixtures.json missing top-level key '${key}'" >&2
    exit 1
  fi
done

echo "  ✓ fixtures.json regenerated ($(wc -c < "${TEST_DIR}/fixtures.json") bytes)"
echo ""

# ----------------------------------------------------------------------
# Step 2: Lean side — run `lake build` to execute the #guard checks.
# ----------------------------------------------------------------------

echo "[2/2] Lean side: running lake build (executes #guard checks)"
echo "------------------------------------------------------------"
if ! command -v lean >/dev/null 2>&1; then
  if [ -f "${HOME}/.elan/bin/lean" ]; then
    export PATH="${HOME}/.elan/bin:${PATH}"
  else
    echo "ERROR: lean not found on PATH" >&2
    echo "       Install via: curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y" >&2
    exit 1
  fi
fi

cd "${LEAN_DIR}"
LEAN_BUILD_LOG="${TEST_DIR}/lake_build.log"

if ! lake build 2>&1 | tee "${LEAN_BUILD_LOG}"; then
  echo ""
  echo "✗ Lean build FAILED — see ${LEAN_BUILD_LOG}" >&2
  exit 1
fi

# Count #guard statements as a coverage proxy
GUARD_COUNT=$(grep -cE '^#guard ' "${LEAN_DIR}/FVSquad/Correspondence.lean" || true)

echo ""
echo "============================================================"
echo "✓ Correspondence harness PASSED"
echo "  - Ruby:  fixtures.json regenerated with $(ruby -rjson -e 'puts JSON.parse(STDIN.read).values.map { |v| v.is_a?(Hash) ? v.keys.size : 0 }.sum' < "${TEST_DIR}/fixtures.json") input/output pairs"
echo "  - Lean:  ${GUARD_COUNT} #guard statements in FVSquad/Correspondence.lean all hold"
echo "============================================================"
