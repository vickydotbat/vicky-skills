#!/usr/bin/env bash
# The lint's moves: each check gives its own move, and a matched sentence
# with a colon still prints as three fields.
set -u
lint="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/human-voice/scripts/lint-tells.py"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

moves=$(python3 -I - "$lint" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("lint", sys.argv[1])
lint = importlib.util.module_from_spec(spec); spec.loader.exec_module(lint)
moves = [move for move, _ in lint.WORDS] + [lint.HEDGE_MOVE, lint.DASH_MOVE, lint.BOLD_MOVE, lint.RHYTHM_MOVE, lint.RULE_MOVE]
print(len(moves), len(set(moves)), min(len(m) for m in moves))
PY
)
read -r total distinct shortest <<<"$moves"
check "every check gives a move of its own" '[ "$total" -gt 20 ] && [ "$total" = "$distinct" ] && [ "$shortest" -ge 10 ]'

printf '%s\n' 'Note: it may possibly help.' > "$scratch/draft.md"
out=$(python3 "$lint" "$scratch/draft.md")
check "a hedged sentence with a colon prints as line, match and move" \
  '[ "$(awk -F": " "{print NF}" <<<"$out")" = 3 ] && grep -q "Keep one qualifier" <<<"$out"'

printf '%s\n' 'That clause is load-bearing.' > "$scratch/draft.md"
out=$(python3 "$lint" "$scratch/draft.md")
check "a stock metaphor gets the literal-word move" 'grep -q "^1: load-bearing: Write the literal word" <<<"$out"'

printf '%s\n' 'We utilize it in order to ship.' > "$scratch/draft.md"
out=$(python3 "$lint" "$scratch/draft.md")
check "a fancy verb or filler phrase gets the plain-word move" \
  'grep -q "^1: utilize: Use the plain word" <<<"$out" && grep -q "^1: in order to: Use the plain word" <<<"$out"'

printf '%s\n' 'The interplay is our bedrock.' > "$scratch/draft.md"
out=$(python3 "$lint" "$scratch/draft.md")
check "an abstract noun gets the concrete-thing move" \
  'grep -q "^1: interplay: Name the concrete thing" <<<"$out" && grep -q "^1: bedrock: Name the concrete thing" <<<"$out"'

for word in utilize utilizes utilized utilizing utilization facilitate facilitates facilitated facilitating "in order to" "due to the fact that" "in the event that" interplay flywheel bedrock; do
  printf '%s\n' "Then $word it." > "$scratch/draft.md"
  out=$(python3 "$lint" "$scratch/draft.md")
  check "\"$word\" gets a plain-word or concrete-thing move" 'grep -Eiq "^1: $word: (Use the plain word|Name the concrete thing)" <<<"$out"'
done
run() { printf '%s\n' "$1" > "$scratch/d.md"; python3 -I "$lint" "$scratch/d.md"; }
check "a fence line's own text is skipped, and so is the block" '[ -z "$(run "$(printf '"'"'```robust\nrobust\n```\nPlain words.'"'"')")" ]'
check "a line after a closed block is read again" 'run "$(printf '"'"'```\ncode\n```\nIt is robust.'"'"')" | grep -q "^4: robust:"'
check "three bold spans in a paragraph are a hit" 'run "The **a** and **b** and **c** parts." | grep -q "^1: 3 bold spans: "'
check "three bold spans in a list are not" '[ -z "$(run "- The **a** and **b** and **c** parts.")" ]'
check "three paragraphs of the same length are a hit" 'run "$(printf '"'"'One. Two.\n\nThree. Four.\n\nFive. Six.'"'"')" | grep -q "^1: every paragraph has 2 sentences: "'
check "paragraphs of mixed length are not" '[ -z "$(run "$(printf '"'"'One. Two.\n\nThree.\n\nFive. Six.'"'"')")" ]'
check "headings, lists and numbered steps don't count toward the rhythm" '[ -z "$(run "$(printf '"'"'One. Two.\n\n# Head. Er.\n\n1. Step two.\n\nFive. Six.'"'"')")" ]'
check "two rules before headings are a hit" 'run "$(printf -- '"'"'---\n# A\nText here.\n---\n# B\nMore text.'"'"')" | grep -q "^1: 2 rules before headings: "'
check "one rule before a heading is not" '[ -z "$(run "$(printf -- '"'"'---\n# A\nText here.\n---\nMore text.'"'"')")" ]'
check "the wrong number of arguments prints the usage" '[ "$(python3 -I "$lint" 2>&1)" = "Usage: lint-tells.py <draft>" ]'
check "a fence line ends a paragraph" 'run "$(printf '"'"'One. Two.\n```\n```\nThree. Four.\n\nFive. Six.'"'"')" | grep -q "every paragraph has 2 sentences"'
check "a closing fence line's own text is skipped" '[ -z "$(run "$(printf '"'"'```\ncode\n``` robust\nPlain words.'"'"')")" ]'
exit $fail
