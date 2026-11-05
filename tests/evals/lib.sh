# shellcheck shell=bash
# Shared by the eval runners in this folder. Each run is a full Claude session
# on your own credential, capped by memory, time and --max-cost-usd.
# eval_case <plugin dir> <case> <out name> [extra --allow-tools entries...]
#   exits as `claude plugin eval` does: 0 when the case passes.
# plugin_before <commit> <dir>: the plugin as it stood just before <commit>,
#   with today's eval cases copied in, so a case can run against old skill text.
evals_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
evals_plugin="$evals_root/plugins/vicky-skills"
evals_out=$(mktemp -d) # kept after the run, so each result can be read back
eval_case() {
  local plugin=$1 name=$2 out=$3; shift 3
  systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 timeout 900 \
    claude plugin eval "$plugin" --case "$name" --scaffold --trust-plugin --ablation none \
    --runs 1 --max-cost-usd 3 --allow-tools Write Edit "$@" --no-publish --json "$evals_out/$out.json" >"$evals_out/$out.out" 2>&1
}
plugin_before() {
  mkdir -p "$2"
  git -C "$evals_root" archive "$1^" plugins/vicky-skills | tar -x -C "$2" --strip-components=2
  rm -rf "$2/evals"; cp -r "$evals_plugin/evals" "$2/evals" 2>/dev/null
}
case_exists() { [ -d "$evals_plugin/evals/$1" ]; }
# A run's case score, the graders that failed, and whether it was graded below 1
# (red) rather than broken before grading, such as a crash or a load error.
case_score() { jq -r '.cases[0].aggregates.score // "none"' "$evals_out/$1.json" 2>/dev/null || echo none; }
failed_graders() { jq -r '[.cases[0].arms.with[]?.graders[]? | select(.passed == false) | .name] | unique | join(", ")' "$evals_out/$1.json" 2>/dev/null; }
graded_red() { jq -e '.cases[0].arms.with[0].graders | length > 0' "$evals_out/$1.json" >/dev/null 2>&1 && [ "$(case_score "$1")" != 1 ]; }
