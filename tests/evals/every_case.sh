#!/usr/bin/env bash
# Runs every eval case that names a cut (a cut.txt beside its prompt): once
# against today's plugin, where it must pass, and once against a copy with
# that section of its skill deleted, where its graders must score it below 1.
# cut.txt holds the exact heading line to delete, such as "## Steps"; the
# section runs to the next heading of the same or a higher level.
# Each run is a full Claude session on your own credential, so CI never runs
# this file: run it by hand.
# Usage: every_case.sh [skill ...]   (no skill: every case with a cut.txt)
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
copy "$evals_out/now-plugin"; copy "$evals_out/cut-plugin"
for c in "${cuts[@]}"; do
  rel=${c#"$evals_plugin/evals/"}; skill=${rel%%/*}
  file=$(ls "$evals_out/cut-plugin"/skills/*/"$skill"/SKILL.md)
  heading=$(head -1 "$c")
  grep -qxF -- "$heading" "$file" || { echo "every-case: $rel: $skill has no line \"$heading\""; exit 1; }
  level=${heading%%[^#]*}
  awk -v h="$heading" -v lv="${#level}" '
    $0 == h {skip=1; next}
    skip && match($0, /^#+ /) && RLENGTH - 1 <= lv {skip=0}
    !skip' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
done
# Every run shares one 8 GB ceiling, however many runners go at once.
systemctl --user set-property --runtime evals.slice MemoryMax=8G MemorySwapMax=0 2>/dev/null
run_all() { # run_all <plugin dir> <out name>
  systemd-run --user --scope -q --slice=evals.slice -p MemoryMax=4G -p MemorySwapMax=0 timeout 3600 \
    claude plugin eval "$1" --scaffold --trust-plugin --keep-temp --ablation none -j "$jobs" \
    --runs 1 --max-cost-usd 40 --allow-tools Write Edit Bash --no-publish --json "$evals_out/$2.json" >"$evals_out/$2.out" 2>&1
}
run_all "$evals_out/now-plugin" now
run_all "$evals_out/cut-plugin" cut
fail=0
score() { jq -r --arg n "$2" '.cases[] | select(.name == $n) | .aggregates.score // "none"' "$evals_out/$1.json" 2>/dev/null; }
failed() { jq -r --arg n "$2" '[.cases[] | select(.name == $n) | .arms.with[]?.graders[]? | select(.passed == false) | .name] | unique | join(", ")' "$evals_out/$1.json" 2>/dev/null; }
for c in "${cuts[@]}"; do
  name=$(basename "$(dirname "$c")")
  now=$(score now "$name"); cut=$(score cut "$name")
  graded=$(jq -r --arg n "$name" '[.cases[] | select(.name == $n) | .arms.with[]?.graders[]?] | length' "$evals_out/cut.json" 2>/dev/null)
  if [ "$now" = 1 ] && [ "${graded:-0}" -gt 0 ] && [ "$cut" != 1 ] && [ -n "$cut" ] && [ "$cut" != none ]; then
    echo "ok   $name: 1 now, $cut with its section cut"
  else
    echo "FAIL $name: ${now:-none} now (failed: $(failed now "$name")), ${cut:-none} with its section cut"; fail=1
    echo "     traces: $(jq -r --arg n "$name" '[.cases[] | select(.name == $n) | .arms.with[]?.tracePath] | join(" ")' "$evals_out/now.json" "$evals_out/cut.json" 2>/dev/null | tr '\n' ' ')"
  fi
done
echo "cost: \$$(jq -r '.costUsd' "$evals_out/now.json" 2>/dev/null) now, \$$(jq -r '.costUsd' "$evals_out/cut.json" 2>/dev/null) cut"
exit $fail
