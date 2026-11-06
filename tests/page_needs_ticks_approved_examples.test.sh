#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for "an examples draft
# page always has its approve ticks" (R1 to R4). Each check is named after its
# example. write-page.py writes the page, or refuses and writes nothing.
set -u
export VISUAL=true EDITOR=true BROWSER=true
writer="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/interactive-page/scripts/write-page.py"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
# The writer opens nothing; a fake desktop still stands first on PATH, as for every page test.
mkdir -p "$dir/desktop"; printf '#!/usr/bin/env bash\necho "BROWSER=true"\n' >"$dir/desktop/systemctl"; chmod +x "$dir/desktop/systemctl"
export PATH="$dir/desktop:$PATH"
export CLAUDE_CODE_SESSION_ID=pt-test
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# Runs write-page on one section: $1 its location, $2 its approve value as JSON (or "none").
# Prints the writer's output and leaves the page at $dir/out.md, or no file.
write() {
  rm -f "$dir/out.md"
  local approve=""
  [ "$2" = none ] || approve=",\"approve\":$2"
  printf '{"kind":"drafts","effort":"x","sections":[{"what":"E1 a thing","where":"%s","text":"Given a\\nWhen b\\nThen c"%s}]}' "$1" "$approve" > "$dir/spec.json"
  python3 "$writer" "$dir/spec.json" "$dir/out.md"
}

# Given a drafts spec with a section whose location names an approved-examples test file
# When the section has no approve flag, or approve is false, and write-page runs
# Then it exits 1 with a line naming that section and saying it needs an approve tick, and writes no file
check "R1 a section for an approved-examples test with no approve flag, or false, is refused with a line naming it, and no file is written" \
  'out=$(write tests/foo_approved_examples.test.sh:new none); [ $? = 1 ] && grep -q "E1 a thing" <<<"$out" && grep -qi "approve" <<<"$out" && [ ! -e "$dir/out.md" ] &&
   out=$(write tests/foo_approved_examples.test.sh:new false); [ $? = 1 ] && [ ! -e "$dir/out.md" ]'

# Given the same section with approve true
# When write-page runs
# Then it writes the page, with a "- [ ] approve" line under that section's location
check "R2 with approve true the page is written with a tick box under the location" \
  'write tests/foo_approved_examples.test.sh:new true >/dev/null && grep -qxF -- "- [ ] approve" "$dir/out.md"'

# Given a drafts spec whose sections have locations that are not approved-examples test files, such as release notes or UI text
# When no section has an approve flag
# Then write-page writes the page, with no approve lines
check "R3 a section whose location is not an approved-examples file is written with no approve line" \
  'write docs/release-notes.md:12 none >/dev/null && [ -s "$dir/out.md" ] && ! grep -q "approve" "$dir/out.md"'

# Given locations named charm_approved_examples.py, CharmApprovedExamples.cs and charm-approved-examples.test.sh
# When each section has no approve flag
# Then write-page refuses each one
check "R4 every spelling of an approved-examples file counts" \
  '(for f in charm_approved_examples.py:new CharmApprovedExamples.cs:7 charm-approved-examples.test.sh:new; do write "$f" none >/dev/null; [ $? = 1 ] || exit 1; done)'
exit $fail
