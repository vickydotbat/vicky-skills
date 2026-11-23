# shellcheck shell=bash
# Shared by the eval runners in this folder. Each run is a full Claude session
# on your own credential, capped by memory, time and --max-cost-usd.
# eval_case <plugin dir> <case> <out name> [extra --allow-tools entries...]
#   exits as `claude plugin eval` does: 0 when the case passes.
# plugin_before <commit> <dir>: the plugin as it stood just before <commit>,
#   with today's eval cases copied in, so a case can run against old skill text.
[ "${EVAL_SPEND:-}" = yes ] || {
  echo "evals: every run here is a paid Claude session on your own credential. Read this runner's header for what it runs, then start it again with EVAL_SPEND=yes." >&2
  exit 2
}
# The model each run uses, pinned so a pass can record what it passed on.
[ -n "${EVAL_MODEL:-}" ] || {
  echo "evals: set EVAL_MODEL to the model under test, such as EVAL_MODEL=claude-opus-5-5. Each passing case records it with the date in its passed file." >&2
  exit 2
}
evals_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
evals_plugin="$evals_root/plugins/vicky-skills"
# The eval sandbox denies shell writes under /tmp and /var/tmp, and that deny
# beats its allow on the run's own folder, so a run under /tmp leaves the
# agent's shell read-only. Every run and copy goes under the runtime dir instead.
evals_tmp="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/vicky-skills-evals"
mkdir -p "$evals_tmp" || { echo "evals: cannot make $evals_tmp, and a run under /tmp gets a read-only shell. Set XDG_RUNTIME_DIR to a writable folder outside /tmp." >&2; exit 2; }
export TMPDIR="$evals_tmp"
evals_out=$(mktemp -d) # kept after the run, so each result can be read back
echo "eval results: $evals_out" >&2
# The one grant every runner passes; a case that lists no Bash in its
# allowed_tools still gets none.
evals_tools=(Write Edit Bash)
eval_case() {
  local plugin=$1 name=$2 out=$3; shift 3
  timeout 900 \
    claude plugin eval "$plugin" --case "$name" --scaffold --trust-plugin --keep-temp --ablation none \
    --runs 1 --max-cost-usd 3 --model "$EVAL_MODEL" --allow-tools "${evals_tools[@]}" "$@" --no-publish --json "$evals_out/$out.json" >"$evals_out/$out.out" 2>&1 || return
  record_pass "$plugin" "$name"
}
# record_pass <plugin dir> <case>: write "<model> <date>" to the case's passed
# file, which law-lint.sh reads to show what an eval proof passed on. Only the
# real plugin's case counts: a copy is thrown away, and a name two skills share
# names no one case.
record_pass() {
  [ "$1" = "$evals_plugin" ] || return 0
  local dirs=("$1"/evals/*/"$2")
  [ ${#dirs[@]} = 1 ] && [ -d "${dirs[0]}" ] && echo "$EVAL_MODEL $(date +%F)" > "${dirs[0]}/passed"
  return 0
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
# run <skill>/<case> <code> <what the example says>: report one example, set fail=1 on a miss.
# shellcheck disable=SC2034 # fail is read by the runner that sources this file
run() {
  if ! case_exists "$1"; then echo "FAIL $2 no eval case at evals/$1"; fail=1
  elif eval_case "$evals_plugin" "$(basename "$1")" "$2"; then echo "ok   $2 $3"
  else echo "FAIL $2 $3 (failed: $(failed_graders "$2"))"; fail=1; fi
}
