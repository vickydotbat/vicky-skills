#!/usr/bin/env bash
# open-draft.sh writes "page" on the lock's third line when open-page.sh opened
# the draft in the browser, and leaves it blank for an editor, so draft-lock
# can say where the draft is open.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
open="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts/open-draft.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"
# The stand-in editor copies the lock while it is open, then exits.
printf '#!/usr/bin/env bash\ncp "%s/repo/.git/red-pen-open" "%s/seen"\n' "$dir" "$dir" > "$dir/editor"; chmod +x "$dir/editor"
printf '# Drafts\n' > "$dir/draft.md"
fail=0
expect() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
seen() { rm -f "$dir/seen"; (cd "$dir/repo" && env "$@" VISUAL="$dir/editor" bash "$open" "$dir/draft.md" >/dev/null 2>&1); sed -n 3p "$dir/seen" 2>/dev/null; }
expect "a page writes page" "$(seen DRAFT_PAGE=1)" page
expect "an editor writes nothing there" "$(seen DRAFT_PAGE=)" ""
exit $fail
