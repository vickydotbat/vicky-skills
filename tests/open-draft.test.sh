#!/usr/bin/env bash
# open-draft.sh's grants the approved examples leave out: an editor that saves
# a blank line under each heading, and a ticked approve box.
set -u
# No test may reach the user's own editor.
export VISUAL=true EDITOR=true BROWSER=true
root="$(cd "$(dirname "$0")/.." && pwd)"
open="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts/open-draft.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
# A fake desktop, so no run can reach the user's session through systemctl.
mkdir -p "$dir/desktop"; printf '#!/usr/bin/env bash\necho "BROWSER=true"\n' >"$dir/desktop/systemctl"; chmod +x "$dir/desktop/systemctl"
export PATH="$dir/desktop:$PATH"
git init -q "$dir/repo"
grants="$dir/repo/.git/approved-spec-grants"
fail=0
expect() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
draft() { # $1 draft text before, $2 text the "editor" leaves
  rm -f "$grants"; printf '%s' "$1" > "$dir/draft.md"
  printf '#!/usr/bin/env bash\nprintf %%s %q > "$1"\n' "$2" > "$dir/editor"; chmod +x "$dir/editor"
  (cd "$dir/repo" && VISUAL="$dir/editor" bash "$open" "$dir/draft.md" >/dev/null 2>&1)
  cat "$grants" 2>/dev/null
}
a='## A
tests/a_approved_examples.test.sh:12

- [ ] approve

```text
Then a
```
'
b='## B
tests/b_approved_examples.test.sh:new

```text
Then b
```
'
spaced=$(sed 's/^\(## .*\)$/\1\n/' <<<"$a$b")
expect "an unchanged close grants nothing" "$(draft "$a$b" "$a$b")" ""
expect "a ticked approve box grants its section's test" "$(draft "$a$b" "${a/- \[ \]/- [x]}$b")" "tests/a_approved_examples.test.sh"
expect "an editor's blank line under each heading still finds the test" "$(draft "$a$b" "${spaced/Then b/Then bee}")" "tests/b_approved_examples.test.sh"
expect "a blank line under each heading alone grants nothing" "$(draft "$a$b" "$spaced")" ""
expect "the page's closing comment grants nothing" "$(draft "$a$b" "$a$b
## Anything else
Comment: tests/a_approved_examples.test.sh:1 looks fine
")" ""
printf '#!/usr/bin/env bash\nexit 2\n' > "$dir/editor"; chmod +x "$dir/editor"
(cd "$dir" && VISUAL="$dir/editor" bash "$open" "$dir/draft.md" >/dev/null 2>&1); code=$?
expect "outside a git checkout, an editor that ends without an answer passes its exit back" "$code" "2"

# A section for a file that holds approved examples reaches the editor only in the form a tick can grant.
mkdir -p "$dir/repo/tests"; echo '# approved-spec: c' > "$dir/repo/tests/c_approved_examples.test.sh"
opens() { # $1 draft text; prints "opened" when the editor ran, else the refusal's exit
  rm -f "$dir/ran"; printf '%s' "$1" > "$dir/draft.md"
  printf '#!/usr/bin/env bash\ntouch %q\n' "$dir/ran" > "$dir/editor"; chmod +x "$dir/editor"
  (cd "$dir/repo" && VISUAL="$dir/editor" bash "$open" "$dir/draft.md" >/dev/null 2>&1); code=$?
  [ -f "$dir/ran" ] && echo opened || echo "refused $code"
}
c_ok='## C
tests/c_approved_examples.test.sh:new
- [ ] approve

```text
Then c
```
'
expect "an approved-examples section with its path:line and approve box opens" "$(opens "$c_ok")" "opened"
expect "an approved-examples section with no approve box opens with one added" "$(opens "${c_ok/- \[ \] approve
/}"; grep -c '^- \[ \] approve' "$dir/draft.md")" "opened
1"
echo '# approved-spec: d' > "$dir/repo/tests/d_approved_examples.test.sh"
two='## C
tests/c_approved_examples.test.sh:new

```text
Then c
```
## D
tests/d_approved_examples.test.sh:new

```text
Then d
```
'
opens "$two" >/dev/null
expect "two approved sections with no box each get one, under their location" "$(grep -A1 '_approved_examples.test.sh:new$' "$dir/draft.md" | grep -c '^- \[ \] approve$')" "2"
code() { (cd "${2:-$dir/repo}" && VISUAL="$1" EDITOR= bash "$open" "${@:3}" >/dev/null 2>&1); echo $?; }
expect "no draft named is a usage error" "$(code true "$dir/repo")" "2"
expect "no editor set is an error" "$(code "" "$dir/repo" "$dir/draft.md")" "2"
printf '#!/usr/bin/env bash\nexit 3\n' > "$dir/editor3"; chmod +x "$dir/editor3"
expect "in a checkout, the editor's exit is passed back" "$(code "$dir/editor3" "$dir/repo" "$dir/draft.md")" "3"
expect "the lock is gone after the close" "$([ -e "$dir/repo/.git/red-pen-open" ] && echo kept || echo gone)" "gone"
rm -f "$dir/approved-spec-grants"; code "$dir/editor3" "$dir" "$dir/draft.md" >/dev/null
expect "outside a checkout, no grants file is written" "$([ -e "$dir/approved-spec-grants" ] && echo written || echo none)" "none"
expect "an approved-examples section whose location is not path:line never opens" "$(opens "${c_ok/c_approved_examples.test.sh:new/c_approved_examples.test.sh, the Then line}")" "refused 2"
# The close marker: an absolute path printed before the editor opens, holding
# the exit status once it closes, so a watch from any folder, started late, reads it.
printf '#!/usr/bin/env bash\n[ -e "%s/repo/.git/red-pen-closed" ] && echo early > "%s/early"\nexit 3\n' "$dir" "$dir" > "$dir/editor4"; chmod +x "$dir/editor4"
rm -f "$dir/early"; echo 0 > "$dir/repo/.git/red-pen-closed"; printf 'x\n' > "$dir/plain.md"
line=$(cd "$dir/repo" && VISUAL="$dir/editor4" bash "$open" "$dir/plain.md" 2>&1 >/dev/null | grep '^draft: wait')
expect "a marker from an earlier close is gone before the editor opens" "$([ -e "$dir/early" ] && echo kept || echo gone)" "gone"
check=$(sed -n "s/^draft: wait with watch.sh '\(.*\)'$/\1/p" <<<"$line")
expect "in a checkout, the printed check passes from another folder after the close" "$(cd / && [ -n "$check" ] && bash -c "$check" && echo pass)" "pass"
expect "the marker holds the exit status" "$(cat "$dir/repo/.git/red-pen-closed")" "3"
mkdir -p "$dir/loose"; printf 'x\n' > "$dir/loose/d.md"
line=$(cd "$dir/loose" && GIT_CEILING_DIRECTORIES="$dir" VISUAL=true bash "$open" "$dir/loose/d.md" 2>&1 >/dev/null | grep '^draft: wait')
expect "outside a checkout, the marker sits beside the draft" "$line" "draft: wait with watch.sh 'test -f \"$dir/loose/.d.md.closed\"'"
expect "outside a checkout, the marker holds the exit status" "$(cat "$dir/loose/.d.md.closed" 2>/dev/null)" "0"
# open-page.sh hands its page to open-draft.sh as the editor, and marks the lock as a page's.
mkdir -p "$dir/op"; cp "$(dirname "$open")/open-page.sh" "$dir/op/"
printf '#!/usr/bin/env bash\necho "$DRAFT_PAGE|$VISUAL"\n' > "$dir/op/open-draft.sh"
got=$(DISPLAY=:9 DRAFT_PAGE= VISUAL=true bash "$dir/op/open-page.sh" x.md)
expect "with a display, open-page sets the page as the editor and marks it" "$got" "1|python3 -I $dir/op/page.py"
got=$(DISPLAY= WAYLAND_DISPLAY= DRAFT_PAGE= VISUAL=true bash "$dir/op/open-page.sh" x.md)
expect "with no display, the editor stays and no page is marked" "$got" "|true"
exit $fail
