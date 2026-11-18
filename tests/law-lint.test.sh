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
mkdir -p tests; printf '#!/usr/bin/env bash\nsleep 30\n' > tests/slow.test.sh; chmod +x tests/slow.test.sh
printf -- '- Slow.\n  Proven by: tests/slow.test.sh\n' > AGENTS.md; git add -A; git commit -qm base; base=$(git rev-parse HEAD)
echo "# x" >> tests/slow.test.sh; git commit -qam touch
start=$SECONDS; out=$(LAW_LINT_TIMEOUT=1 "$lint" prove "$base" 2>&1); rc=$?
check "a proof that outlives LAW_LINT_TIMEOUT counts as failed, and prove stops waiting" \
  '[ $rc = 1 ] && grep -q "Slow. (tests/slow.test.sh: failed)" <<<"$out" && [ $((SECONDS - start)) -lt 10 ]'
exit $fail
