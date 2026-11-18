#!/usr/bin/env bash
# law-lint.sh beyond its approved examples: a user's diff settings never
# change which laws count as added, and a bad call says what it needs.
set -u
lint="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/shipping/engrave/scripts/law-lint.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
cd "$t" && git init -q && git config user.email t@t && git config user.name t
printf -- '- Old.\n' > AGENTS.md; git add -A; git commit -qm base; base=$(git rev-parse HEAD)
printf -- '- New.\n' >> AGENTS.md; git commit -qam new

for opt in diff.mnemonicPrefix diff.noprefix; do
  out=$(GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0="$opt" GIT_CONFIG_VALUE_0=true GIT_CONFIG_KEY_1=color.ui GIT_CONFIG_VALUE_1=always "$lint" --since "$base" 2>&1); rc=$?
  check "with $opt set, a law the branch added still fails as unproven" \
    '[ $rc = 1 ] && grep -q "^unproven AGENTS.md:2: New" <<<"$out"'
done
git config diff.mnemonicPrefix true
out=$("$lint" --since "$base" 2>&1); rc=$?
check "with diff.mnemonicPrefix in the repo config, a law the branch added still fails as unproven" \
  '[ $rc = 1 ] && grep -q "^unproven AGENTS.md:2: New" <<<"$out"'

for mode in --since reach prove; do
  out=$("$lint" $mode 2>&1); rc=$?
  check "$mode with no base ref says it needs one and fails" '[ $rc -ne 0 ] && grep -q "needs a base ref" <<<"$out"'
done
cd "$t" && rm -rf r && mkdir r && cd r && git init -q
printf -- '- After a heading.\n# Next\n  Proven by: AGENTS.md\n- After a note.\nA note.\n  Proven by: AGENTS.md\n' > AGENTS.md
out=$("$lint" 2>&1)
check "a Proven by line after a heading or a plain line belongs to no law above it" \
  'grep -q "^unproven AGENTS.md:1: After a heading" <<<"$out" && grep -q "^unproven AGENTS.md:4: After a note" <<<"$out"'

git config user.email t@t && git config user.name t
# The proof hangs for 30 s; LAW_LINT_TIMEOUT=1 below kills it after one second.
mkdir -p tests; printf '#!/usr/bin/env bash\nsleep 30\n' > tests/slow.test.sh; chmod +x tests/slow.test.sh
printf -- '- Slow.\n  Proven by: tests/slow.test.sh\n' > AGENTS.md; git add -A; git commit -qm base; base=$(git rev-parse HEAD)
echo "# x" >> tests/slow.test.sh; git commit -qam touch
start=$SECONDS; out=$(LAW_LINT_TIMEOUT=1 "$lint" prove "$base" 2>&1); rc=$?
check "a proof that outlives LAW_LINT_TIMEOUT counts as failed, and prove stops waiting" \
  '[ $rc = 1 ] && grep -q "Slow. (tests/slow.test.sh: failed)" <<<"$out" && [ $((SECONDS - start)) -lt 10 ]'
cd "$t" && rm -rf r && mkdir r && cd r && git init -q && git config user.email t@t && git config user.name t
mkdir -p tests; printf '#!/usr/bin/env bash\n' > tests/a.test.sh; chmod +x tests/a.test.sh
long=$(printf 'word%.0s ' $(seq 60))
printf -- '- Long law %s\n  Proven by: tests/a.test.sh\n' "$long" > AGENTS.md; git add -A; git commit -qm base; base=$(git rev-parse HEAD)
echo "# x" >> tests/a.test.sh; git commit -qam touch
out=$("$lint" prove "$base" 2>&1)
check "a Laws line names each law by its file and line and a short start, never its whole text" \
  'line=$(grep "^Laws:" <<<"$out") && grep -q "AGENTS.md:1 " <<<"$line" && [ ${#line} -lt 160 ] && grep -q "tests/a.test.sh: passed" <<<"$line"'

# approved-spec: the examples the user ticked on 2026-11-18 for "Date each proof".
cd "$t" && rm -rf r && mkdir r && cd r && git init -q && git config user.email t@t && git config user.name t
mkdir -p evals/s/old evals/s/new evals/s/bare evals/s/other
echo "model-a 2026-10-01" > evals/s/old/passed
echo "model-b 2026-11-18" > evals/s/new/passed
echo "model-a 2026-10-02" > evals/s/other/passed
printf -- '- Old law.\n  Proven by: evals/s/old\n- New law.\n  Proven by: evals/s/new\n- Bare law.\n  Proven by: evals/s/bare\n- Other law.\n  Proven by: evals/s/other\n- Test law.\n  Proven by: AGENTS.md\n' > AGENTS.md
git add -A; git commit -qm base; base=$(git rev-parse HEAD)
touch evals/s/old/prompt.md evals/s/bare/prompt.md; echo 'A plain line.' >> AGENTS.md; git add -A; git commit -qm touch

# Given a law whose proof is an eval case folder
# When law-lint prove reaches it
# Then the Laws line reads not run, passed on <model> <date> when the folder holds a passed file
# And reads not run, never recorded when it holds none
out=$("$lint" prove "$base" 2>&1)
check "T1-3 the Laws line shows the model and date an eval proof passed on, or that none was recorded" \
  'line=$(grep "^Laws:" <<<"$out") && grep -qF "(evals/s/old: not run, passed on model-a 2026-10-01)" <<<"$line" && grep -qF "(evals/s/bare: not run, never recorded)" <<<"$line"'
check "a proof that is a plain file, neither a command nor an eval case, reads not run" \
  'grep -qF "(AGENTS.md: not run)" <<<"$(grep "^Laws:" <<<"$out")"'

# Given laws proven by eval cases, some passed on model A, one passed on model B and one never recorded
# When law-lint stale B runs
# Then it lists each law whose case passed on another model or was never recorded, with the model and date it has
# And lists none that passed on B
out=$("$lint" stale model-b 2>&1); rc=$?
check "T1-4 stale lists each law whose case passed on another model or was never recorded, and none on that model" \
  '[ $rc = 0 ] && grep -qF "AGENTS.md:1 Old law. (evals/s/old: passed on model-a 2026-10-01)" <<<"$out" && grep -qF "AGENTS.md:7 Other law. (evals/s/other: passed on model-a 2026-10-02)" <<<"$out" && grep -qF "AGENTS.md:5 Bare law. (evals/s/bare: never recorded)" <<<"$out" && ! grep -qF "New law" <<<"$out" && ! grep -qF "Test law" <<<"$out"'
out=$("$lint" stale 2>&1); rc=$?
check "stale with no model says it needs one and fails" '[ $rc -ne 0 ] && grep -q "needs a model" <<<"$out"'
exit $fail
