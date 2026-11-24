#!/usr/bin/env bash
# Runs every eval case that names a cut (a cut.txt beside its prompt): once
# against today's plugin, where it must pass, and once against a copy with
# that part of its skill deleted, where its graders must score it below 1.
# cut.txt's first line names the part, as cut.sh reads it: a heading line,
# such as "## Steps", or the start of a step or table row, such as
# "**Pick the kind**". Cases that name the same cut of the same skill share
# one cut copy; every other cut gets its own, so one case's cut never reaches
# another case's run.
# Each run is a full Claude session on your own credential, so CI never runs
# this file: run it by hand.
# Usage: EVAL_SPEND=yes EVAL_MODEL=<model> every_case.sh [skill ...]   (no skill: every case with a cut.txt)
# EVAL_JOBS sets how many runs go at once, 4 by default.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
jobs=${EVAL_JOBS:-4}
mapfile -t cuts < <(find "$evals_plugin/evals" -name cut.txt -not -path '*/results/*' | sort)
if [ $# -gt 0 ]; then
  keep=(); for c in "${cuts[@]}"; do rel=${c#"$evals_plugin/evals/"}; for s in "$@"; do [ "${rel%%/*}" = "$s" ] && keep+=("$c"); done; done
  cuts=("${keep[@]}")
fi
[ ${#cuts[@]} -gt 0 ] || { echo "every-case: no case names a cut"; exit 1; }
# Both arms run on copies outside the home folder, holding only the chosen cases.
copy() {
  cp -r "$evals_plugin" "$1"; rm -rf "$1/evals"; mkdir -p "$1/evals"
  for c in "${cuts[@]}"; do d=$(dirname "$c"); rel=${d#"$evals_plugin/evals/"}; mkdir -p "$1/evals/$(dirname "$rel")"; cp -r "$d" "$1/evals/$rel"; done
}
copy "$evals_out/now-plugin"
run_all() { # run_all <plugin dir> <out name> <parallel runs>
  timeout 3600 \
    claude plugin eval "$1" --scaffold --trust-plugin --keep-temp --ablation none -j "$3" \
    --runs 1 --max-cost-usd 40 --model "$EVAL_MODEL" --allow-tools "${evals_tools[@]}" --no-publish --json "$evals_out/$2.json" >"$evals_out/$2.out" 2>&1
}
# Group the cases by skill and cut. Each group's copy holds only its own cases,
# with only its own cut made.
declare -A group_of # case dir -> group number
groups=()           # group number -> "skill<TAB>cut line"
for c in "${cuts[@]}"; do
  rel=${c#"$evals_plugin/evals/"}; key="${rel%%/*}"$'\t'"$(head -1 "$c")"
  n=-1; for i in "${!groups[@]}"; do [ "${groups[$i]}" = "$key" ] && n=$i; done
  [ "$n" = -1 ] && { n=${#groups[@]}; groups+=("$key"); }
  group_of["$c"]=$n
done
for n in "${!groups[@]}"; do
  skill=${groups[$n]%%$'\t'*}; line=${groups[$n]#*$'\t'}; dir="$evals_out/cut-plugin-$n"
  cp -r "$evals_plugin" "$dir"; rm -rf "$dir/evals"; mkdir -p "$dir/evals"
  for c in "${cuts[@]}"; do [ "${group_of["$c"]}" = "$n" ] || continue
    d=$(dirname "$c"); rel=${d#"$evals_plugin/evals/"}; mkdir -p "$dir/evals/$(dirname "$rel")"; cp -r "$d" "$dir/evals/$rel"; done
  "$(dirname "$0")/cut.sh" "$(ls "$dir"/skills/*/"$skill"/SKILL.md)" "$line" || { echo "every-case: $skill has no part \"$line\""; exit 1; }
done
run_all "$evals_out/now-plugin" now "$jobs"
# The cut arms run side by side, at most $jobs at once, one run each at a time.
for n in "${!groups[@]}"; do
  while [ "$(jobs -rp | wc -l)" -ge "$jobs" ]; do wait -n; done
  run_all "$evals_out/cut-plugin-$n" "cut-$n" 1 &
done
wait
fail=0
score() { jq -r --arg n "$2" '.cases[] | select(.name == $n) | .aggregates.score // "none"' "$evals_out/$1.json" 2>/dev/null; }
failed() { jq -r --arg n "$2" '[.cases[] | select(.name == $n) | .arms.with[]?.graders[]? | select(.passed == false) | .name] | unique | join(", ")' "$evals_out/$1.json" 2>/dev/null; }
for c in "${cuts[@]}"; do
  name=$(basename "$(dirname "$c")")
  cutrun="cut-${group_of["$c"]}"
  now=$(score now "$name"); cut=$(score "$cutrun" "$name")
  graded=$(jq -r --arg n "$name" '[.cases[] | select(.name == $n) | .arms.with[]?.graders[]?] | length' "$evals_out/$cutrun.json" 2>/dev/null)
  if [ "$now" = 1 ] && [ "${graded:-0}" -gt 0 ] && [ "$cut" != 1 ] && [ -n "$cut" ] && [ "$cut" != none ]; then
    echo "ok   $name: 1 now, $cut with its section cut"; record_pass "$evals_plugin" "$name"
  else
    echo "FAIL $name: ${now:-none} now (failed: $(failed now "$name")), ${cut:-none} with its section cut"; fail=1
    echo "     traces: $(jq -r --arg n "$name" '[.cases[] | select(.name == $n) | .arms.with[]?.tracePath] | join(" ")' "$evals_out/now.json" "$evals_out/$cutrun.json" 2>/dev/null | tr '\n' ' ')"
  fi
done
echo "cost: \$$(jq -r '.costUsd' "$evals_out/now.json" 2>/dev/null) now, \$$(cat "$evals_out"/cut-*.json 2>/dev/null | jq -s 'map(.costUsd // 0) | add // 0') cut"
exit $fail
