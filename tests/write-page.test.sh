#!/usr/bin/env bash
# write-page.py writes question pages and draft files from a spec, in the form
# page.py reads, and refuses a spec it can't write in that form.
set -u
export VISUAL=true EDITOR=true BROWSER=true
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
# The writer opens nothing; a fake desktop still stands first on PATH, as for every page test.
mkdir -p "$dir/desktop"; printf '#!/usr/bin/env bash\necho "BROWSER=true"\n' >"$dir/desktop/systemctl"; chmod +x "$dir/desktop/systemctl"
export PATH="$dir/desktop:$PATH"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
write() { rm -f "$dir/out.md"; printf '%s' "$1" > "$dir/spec.json"; python3 -I "$scripts/write-page.py" "$dir/spec.json" "$dir/out.md"; }
render() { python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import page; print(page.page("x", page.parse(open(sys.argv[2]).read(), sys.argv[3])))' "$scripts" "$dir/out.md" "$dir"; }

write '{"kind": "question", "questions": [{"q": "Which colour?", "options": ["gray", "the phase colour"], "pick": 0, "other": true}]}' >/dev/null
html=$(render)
check "a question page draws each option as a radio, with the pick checked" 'grep -q "value=\"gray\" checked" <<<"$html" && grep -q "value=\"the phase colour\"" <<<"$html"'
check "an open question ends with Other and a notes line" 'grep -qx -- "- ( ) Other" "$dir/out.md" && grep -qx "notes:" "$dir/out.md"'
write '{"kind": "question", "charts": ["course.svg"], "course": [{"key": "T-1", "kind": "Bug", "title": "Fix it", "needs": "nothing"}], "questions": []}' >/dev/null
check "a planning page carries its chart and one ticked box per ticket" 'grep -qx "!\[course\](course.svg)" "$dir/out.md" && grep -qx -- "- \[x\] T-1 Bug: Fix it. Needs: nothing" "$dir/out.md"'
check "a question with one option is refused, and nothing is written" 'out=$(write "{\"kind\": \"question\", \"questions\": [{\"q\": \"x\", \"options\": [\"a\"]}]}"); [ $? = 1 ] && grep -q "two options" <<<"$out" && [ ! -e "$dir/out.md" ]'
check "a pick outside the options is refused" 'out=$(write "{\"kind\": \"question\", \"questions\": [{\"q\": \"x\", \"options\": [\"a\", \"b\"], \"pick\": 2}]}"); [ $? = 1 ] && grep -q "pick" <<<"$out"'

write '{"kind": "drafts", "effort": "colour", "sections": [{"what": "Finish tooltip", "where": "src/Step.cs:41", "text": "Put the colours on your character"}, {"what": "An example", "where": "tests/x_approved_examples.test.sh:new", "text": "Given a doll", "approve": true}]}' >/dev/null
html=$(render)
check "a draft file draws each section's text in its own box" '[ "$(grep -o "name=\"text\." <<<"$html" | wc -l)" = 2 ] && grep -q "Put the colours on your character" <<<"$html"'
check "a section to approve carries its box under its location" 'grep -A1 -x "tests/x_approved_examples.test.sh:new" "$dir/out.md" | grep -qx -- "- \[ \] approve"'
check "the draft file opens with its effort" 'head -1 "$dir/out.md" | grep -qx "# Drafts: colour"'
check "draft text holding a code fence is refused" 'out=$(write "{\"kind\": \"drafts\", \"effort\": \"e\", \"sections\": [{\"what\": \"w\", \"where\": \"a:1\", \"text\": \"a \`\`\` b\"}]}"); [ $? = 1 ] && grep -q "code fence" <<<"$out"'
check "a section with no location is refused" 'out=$(write "{\"kind\": \"drafts\", \"effort\": \"e\", \"sections\": [{\"what\": \"w\", \"text\": \"t\"}]}"); [ $? = 1 ] && grep -q "no where" <<<"$out"'
check "an unknown kind is refused" 'out=$(write "{\"kind\": \"poster\"}"); [ $? = 1 ] && grep -q "kind must be" <<<"$out"'
check "a wrong call exits 2" 'python3 -I "$scripts/write-page.py" 2>/dev/null; [ $? = 2 ]'
# An approved-examples section needs its tick box: the refusal names the section's number.
two='{"kind":"drafts","effort":"x","sections":[{"what":"A","where":"docs/a.md:1","text":"t"},{"what":"B","where":"tests/b_approved_examples.test.sh:new","approve":true,"text":"t"},{"what":"C","where":"tests/c_approved_examples.test.sh:new","text":"t"}]}'
check "only the approved-examples section without a tick is named, by number" 'out=$(write "$two"); [ $? = 1 ] && grep -q "section 3 (C)" <<<"$out" && grep -q "needs approve true" <<<"$out" && grep -q "no tick is recorded" <<<"$out" && ! grep -q "section 2" <<<"$out" && ! grep -q "section 1" <<<"$out"'
one='{"kind":"drafts","effort":"x","sections":[{"what":"A","where":"docs/a.md:1","text":"t"},{"what":"B","where":"tests/b_approved_examples.test.sh:new","approve":true,"text":"t"}]}'
check "an approved-examples section with its tick is written beside a plain one, with one tick box" 'write "$one" >/dev/null && [ "$(grep -c -- "- \[ \] approve" "$dir/out.md")" = 1 ]'
named() { printf '{"kind":"drafts","effort":"x","sections":[{"what":"A","where":"%s","text":"t"}]}' "$1" > "$dir/s.json"; python3 -I "$scripts/write-page.py" "$dir/s.json" "$dir/o.md" >/dev/null; }
check "approved_examples, approved-examples, ApprovedExamples and approvedexamples all name an approved-examples file" '(for w in a_approved_examples.py a-approved-examples.sh AApprovedExamples.cs aapprovedexamples.go; do named "$w"; [ $? = 1 ] || exit 1; done)'
check "a name that only says approved or examples is not an approved-examples file" '(for w in approved.md examples_doc.md approved_notes.md; do named "$w"; [ $? = 0 ] || exit 1; done)'
# A page file goes in the session's scratch folder, never loose in the shared temp folder.
mkdir -p "$dir/tmp/s1"
q='{"kind": "question", "questions": [{"q": "Which one?", "options": ["a", "b"], "pick": 1}]}'
printf '%s' "$q" > "$dir/qspec.json"
scratch() { env -u CLAUDE_CODE_SESSION_ID TMPDIR="$dir/tmp" "$@" python3 -I "$scripts/write-page.py" "$dir/qspec.json" "$f" 2>&1; }
f="$dir/tmp/loose.md"; out=$(scratch CLAUDE_CODE_SESSION_ID=s1)
check "a page loose in the shared temp folder is refused, naming the session folder" '[ $? = 1 ] && grep -q "tmp/s1" <<<"$out" && [ ! -e "$f" ]'
f="$dir/tmp/s1/page.md"; scratch CLAUDE_CODE_SESSION_ID=s1 >/dev/null
check "a page in the session folder is written" '[ -s "$f" ]'
f="$dir/tmp/open.md"; scratch >/dev/null
check "with no session id the shared temp folder is allowed" '[ -s "$f" ]'
f="$dir/elsewhere.md"; scratch CLAUDE_CODE_SESSION_ID=s1 >/dev/null
check "a page outside the temp folder is allowed" '[ -s "$f" ]'
exit $fail
