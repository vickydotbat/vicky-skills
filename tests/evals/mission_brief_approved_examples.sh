#!/usr/bin/env bash
# approved-spec: the examples the user ticked on 2026-11-05 for "Skill evals -
# the first suite": mission-brief's check-first eval case passes only when the
# agent searched the tracker and the codebase before it wrote the ticket, and
# it fails against the skill with its Check first section deleted.
# Each run is a full Claude session on your own credential, so CI never runs
# this file: run it by hand. It caps every run at --max-cost-usd.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
plugin="$root/plugins/vicky-skills"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
eval_case() {
  systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 timeout 900 \
    claude plugin eval "$1" --case check-first --scaffold --trust-plugin --ablation none \
    --runs 1 --max-cost-usd 3 --allow-tools Write Edit --no-publish --json "$dir/$2.json" >"$dir/$2.out" 2>&1
}
score() { jq -r '[.. | objects | select(has("name") and .name == "check-first") | .score? // empty] | first // "none"' "$dir/$1.json" 2>/dev/null || echo none; }

# Given the mission-brief skill and a thin brief that names a feature in one sentence
# When I run claude plugin eval on that case
# Then it passes only if the agent searched the tracker and the codebase before it wrote the spec
if eval_case "$plugin" with; then echo "ok   S1-1 the case passes with the skill"; else
  echo "FAIL S1-1 the case passes with the skill: score $(score with)"; tail -5 "$dir/with.out"; fail=1; fi

# Given that same case with the skill's Check first section deleted
# When I run the eval again
# Then it fails, so the case can go red
cp -r "$plugin" "$dir/cut"
skill="$dir/cut/skills/engineering/mission-brief/SKILL.md"
awk '/^## Check first/{skip=1; next} /^## /{skip=0} !skip' "$skill" > "$skill.tmp" && mv "$skill.tmp" "$skill"
if grep -q '^## Check first' "$skill" || [ ! -d "$dir/cut/evals/mission-brief/check-first" ]; then
  echo "FAIL S1-2 the case goes red without Check first: no case to run, or the section is still there"; fail=1
elif eval_case "$dir/cut" cut; then echo "FAIL S1-2 the case goes red without Check first: it passed"; fail=1; else
  echo "ok   S1-2 the case goes red without Check first (score $(score cut))"; fi

exit $fail
