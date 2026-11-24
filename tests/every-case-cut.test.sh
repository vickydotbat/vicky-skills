#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its test later, so the quotes keep it unexpanded
# shellcheck disable=SC2034 # out, before and status are read inside the eval'd tests
# tests/evals/cut.sh, the cut arm's editor for every_case.sh: a heading cut,
# a step cut, a table-row cut, and a cut line that matches nothing.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
cut="$root/tests/evals/cut.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
skill() {
  cat > "$dir/SKILL.md" <<'EOF'
# Lantern

| Kind | Use |
| --- | --- |
| warm | dusk |
| cold | dawn |

## Steps

1. **Light it**: strike the match.

   | Fuel | Burns |
   | --- | --- |
   | oil | long |
   Proven by: evals/light
2. **Trim it**: cut the wick.
   Proven by: evals/trim
3. **Hang it** on the hook.

Charter: C1.

## Notes

Keep it dry.
EOF
}
skill; "$cut" "$dir/SKILL.md" "## Steps"; out=$(cat "$dir/SKILL.md")
check "a heading cut deletes its section up to the next heading" '[[ $out != *"Light it"* && $out != *Charter* && $out == *"## Notes"* && $out == *"Keep it dry"* && $out == *"| warm |"* ]]'
skill; "$cut" "$dir/SKILL.md" "**Light it**"; out=$(cat "$dir/SKILL.md")
check "a step cut deletes the step with its indented table and proof" '[[ $out != *"Light it"* && $out != *"| oil |"* && $out != *"evals/light"* ]]'
check "a step cut keeps the next step" '[[ $out == *"2. **Trim it**"* && $out == *"evals/trim"* && $out == *"## Steps"* ]]'
skill; "$cut" "$dir/SKILL.md" "**Hang it**"; out=$(cat "$dir/SKILL.md")
check "the last step's cut stops at the line after it" '[[ $out != *"Hang it"* && $out == *"Charter: C1."* && $out == *"Trim it"* ]]'
skill; "$cut" "$dir/SKILL.md" "| warm |"; out=$(cat "$dir/SKILL.md")
check "a table-row cut deletes that row only" '[[ $out != *"| warm |"* && $out == *"| cold | dawn |"* && $out == *"| Kind | Use |"* ]]'
skill; before=$(cat "$dir/SKILL.md")
"$cut" "$dir/SKILL.md" "**Douse it**" 2>/dev/null; status=$?
check "a cut that matches nothing exits 1 and leaves the file whole" '[ $status = 1 ] && [ "$(cat "$dir/SKILL.md")" = "$before" ]'
"$cut" "$dir/SKILL.md" "## Light" 2>/dev/null; status=$?
check "a heading cut matches the whole line, not its start" '[ $status = 1 ]'
check "a failed cut leaves no temporary file" '[ "$(ls "$dir")" = SKILL.md ]'
# Found by the deathmatch: a fence inside a cut part, whose lines start at the margin or with #.
printf '# T\n\n## A\ntext\n```bash\n# comment\nunindented\n```\nafter\n\n## B\nkeep\n' > "$dir/SKILL.md"
"$cut" "$dir/SKILL.md" "## A"
check "a heading cut skips a fence that holds a # line" '[ "$(cat "$dir/SKILL.md")" = "$(printf "# T\n\n## B\nkeep")" ]'
printf '1. **Do** it\n```bash\nls\n```\n   Done when x.\n2. **Next** one\n' > "$dir/SKILL.md"
"$cut" "$dir/SKILL.md" "**Do**"
check "a step cut skips a fence at the left margin" '[ "$(cat "$dir/SKILL.md")" = "2. **Next** one" ]'
exit $fail
