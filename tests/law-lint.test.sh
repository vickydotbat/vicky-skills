#!/usr/bin/env bash
# law-lint.sh beyond its approved examples: a user's diff settings never
# change which laws count as added, and a bad call says what it needs.
set -u
lint="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/law-lint.sh"
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
exit $fail
