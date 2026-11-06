#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for the hook audit, E9.
# A stale mutation proof fails the suite and CI, never the commit.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a stale mutation-proof.tsv
# When the agent commits
# Then the commit goes through
check "E9 no hook refuses a commit over the proof" \
  '! grep -q "mutation-proof-guard" "$root/plugins/vicky-skills/hooks/hooks.json" && [ ! -e "$root/plugins/vicky-skills/scripts/mutation-proof-guard.sh" ]'

# Given the same stale proof
# When tests/run-all.sh or CI runs
# Then it fails, naming the stale scripts
check "E9 run-all.sh and CI run the proof check" \
  'grep -q "mutate-hooks.py --check" "$root/tests/run-all.sh" && grep -q "mutate-hooks.py --check" "$root/.github/workflows/ci.yml"'
exit $fail
