#!/usr/bin/env bash
# approved-spec: the examples approved for "A lint lists laws with no proof".
# Each check is named after its example and runs the lint on a scratch repo.
set -u
lint="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/law-lint.sh"
fc="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/commands/first-contact/domain.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
repo() { rm -rf "$t/r"; mkdir -p "$t/r/tests" && cd "$t/r" && git init -q && git config user.email t@t && git config user.name t; }
law() { printf -- '- %s\n  Proven by: tests/a.test.sh\n' "$1"; }

repo; : > tests/a.test.sh
{ echo "# Rules"; for i in 1 2 3 4 5 6 7 8; do law "Rule $i holds."; done; echo "- Rule nine has no proof."; echo "- Rule ten has no proof."; } > AGENTS.md
out=$("$lint" 2>&1); rc=$?
check "given a repo with ten law lines, two naming no proof, when the law lint runs, then it lists the two, each with its file and line, and exits non-zero" \
  '[ $rc -ne 0 ] && [ "$(grep -c "^unproven " <<<"$out")" = 2 ] && grep -q "AGENTS.md:18: Rule nine" <<<"$out" && grep -q "AGENTS.md:19: Rule ten" <<<"$out"'

repo; printf -- '- Rule gone.\n  Proven by: tests/gone.test.sh\n' > AGENTS.md
out=$("$lint" 2>&1)
check "given a law whose named proof no longer exists, when the law lint runs, then it lists that law as a broken proof, naming the missing check" \
  'grep -q "^broken AGENTS.md:1: .*tests/gone.test.sh" <<<"$out"'

repo; cat > AGENTS.md <<'MD'
# Rules
- A real rule.
1. A real step.
A plain note sentence.
```
- fenced line
```
- See [other](other.md)
## Examples
- an example line
## Pointers
- a pointer line
## Comments
- a comment
## Notes
- a note
MD
out=$("$lint" 2>&1)
check "given a scanned file, when the law lint runs, then a law line is a top-level bullet or numbered step, and lines in code fences, under an Examples, Pointers, Comments or Notes heading, or that only link are never laws" \
  '[ "$(grep -c "^unproven " <<<"$out")" = 2 ] && grep -q "A real rule" <<<"$out" && grep -q "A real step" <<<"$out"'

repo; mkdir -p docs/agents skills/x node_modules/m vendor/v
for f in AGENTS.md CLAUDE.md docs/agents/a.md skills/x/SKILL.md README.md CHANGELOG.md node_modules/m/SKILL.md vendor/v/AGENTS.md; do echo "- Rule in $f." > "$f"; done
mkdir -p .git/x; echo "- Rule in git." > .git/x/AGENTS.md; git add -A
out=$("$lint" 2>&1)
check "given a repo with AGENTS.md, CLAUDE.md, agent docs, SKILL.md files, a README and a CHANGELOG, when the law lint runs, then it reads the agent files and every SKILL.md, and skips README, CHANGELOG, node_modules, vendor and .git" \
  '[ "$(grep -c "^unproven " <<<"$out")" = 4 ] && ! grep -qE "README|CHANGELOG|node_modules|vendor" <<<"$out"'

repo; printf -- '- Old one.\n- Old two.\n- Old three.\n' > AGENTS.md; git add -A; git commit -qm base; base=$(git rev-parse HEAD)
git switch -qc b; echo "x" > other.txt; git add -A; git commit -qm none
out=$("$lint" --since "$base" 2>&1); rc=$?
printf -- '- New four.\n' >> AGENTS.md; git commit -qam four
out2=$("$lint" --since "$base" 2>&1); rc2=$?
check "given three old unproven laws and a branch that adds none, when the law lint runs since the base, then it lists the three as backlog and exits 0, and when the branch adds a fourth it exits non-zero naming only the new one" \
  '[ $rc = 0 ] && [ "$(grep -c "^backlog " <<<"$out")" = 3 ] && [ $rc2 -ne 0 ] && [ "$(grep -c "^unproven " <<<"$out2")" = 1 ] && grep -q "^unproven .*New four" <<<"$out2"'

repo; mkdir -p docs/agents; echo "Law proofs: off" > docs/agents/domain.md; echo "- Unproven." > AGENTS.md
out=$("$lint" 2>&1); rc=$?
repo; printf -- '- Empty.\n  Proven by:\n' > AGENTS.md
out2=$("$lint" 2>&1)
check "given the agent docs say Law proofs: off, when the law lint runs, then it says the check is off and exits 0, first-contact writes Law proofs: on, and an empty Proven by counts as unproven" \
  '[ $rc = 0 ] && grep -qi "law proofs: off" <<<"$out" && ! grep -q "^unproven" <<<"$out" && grep -q "Law proofs: on" "$fc" && grep -q "^unproven AGENTS.md:1: Empty" <<<"$out2"'
exit $fail
