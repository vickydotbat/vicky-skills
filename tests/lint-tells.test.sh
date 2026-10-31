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
exit $fail
