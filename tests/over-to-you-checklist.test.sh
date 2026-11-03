#!/usr/bin/env bash
# checklist.py writes the over-to-you checklist from a spec in the one form the
# page reads, and refuses a spec it can't write without breaking that form.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root/plugins/vicky-skills/skills/productivity/over-to-you/scripts"
page="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
item='{"do": "Open the pack", "see": "the slots show", "person": "look"}'
spec() { # items json -> spec file
  jq -n --argjson items "$1" '{name: "Bob", brief: ["One sitting for the pack."], open: "Open the client on the branch.",
    signed_off: "nothing yet", proven_by: "`health.sh` answers ok", sections: [{title: "Pack", items: $items}]}' > "$dir/spec.json"
}
write() { rm -f "$dir/out.md"; python3 -I "$skill/checklist.py" "$dir/spec.json" "$dir/out.md"; }

spec "[$item, {\"do\": \"Spawn the paper\", \"see\": \"the sheet shows\", \"person\": \"real client\", \"kit\": \"\`/runscript paper\`\"}]"
check "a good spec writes the checklist and exits 0" 'write >/dev/null && [ -s "$dir/out.md" ]'
check "the written checklist passes the lint" '[ -z "$(python3 -I "$skill/lint-checklist.py" "$dir/out.md")" ]'
check "the legend line is the page's own" 'grep -qxF "Mark each item: [x] completed as expected, [~] completed with changes, [-] failed to complete, [ ] not tested at all." "$dir/out.md"'
html=$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import page; print(page.page("x", page.parse(open(sys.argv[2]).read(), "/")))' "$page" "$dir/out.md")
check "the page draws both items as cards with every mark labelled" '[ "$(grep -o "<div class=card>" <<<"$html" | wc -l)" = 2 ] && [ "$(grep -o "failed to complete</label>" <<<"$html" | wc -l)" = 2 ]'
check "every section and Extra tests carry the quick-note tags" '[ "$(grep -c "^- QUESTION:" "$dir/out.md")" = 2 ]'

spec "[$item,$item,$item,$item,$item,$item,$item,$item]"
check "eight items are refused and nothing is written" 'out=$(write); [ $? = 1 ] && grep -q "7 at most" <<<"$out" && [ ! -e "$dir/out.md" ]'
spec '[{"do": "Open the pack", "see": "the slots show"}]'
check "an item with no person is refused" 'out=$(write); [ $? = 1 ] && grep -q "item 1 has no person" <<<"$out"'
spec '[{"do": "Spawn the paper", "see": "the sheet shows", "person": "look"}]'
check "an item that reaches a thing with no kit is refused by the lint" 'out=$(write); [ $? = 1 ] && grep -q "kit" <<<"$out" && [ ! -e "$dir/out.md" ]'
jq -n --argjson i "[$item]" '{name: "Bob", open: "x", signed_off: "nothing yet", sections: [{title: "P", items: $i}]}' > "$dir/spec.json"
check "a spec with no proven by is refused" 'out=$(write); [ $? = 1 ] && grep -q "missing proven_by" <<<"$out"'
jq -n --argjson i "[$item]" '{name: "Bob", open: "x", signed_off: "n", proven_by: "p", sitting: [2, 3], sections: [{title: "P", items: $i}]}' > "$dir/spec.json"
check "a numbered sitting says which one it is" 'write >/dev/null && grep -qx "Sitting 2 of 3." "$dir/out.md"'
check "a wrong call prints its usage and exits 2" 'python3 -I "$skill/checklist.py" 2>/dev/null; [ $? = 2 ]'
exit $fail
