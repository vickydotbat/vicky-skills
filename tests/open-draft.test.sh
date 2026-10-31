#!/usr/bin/env bash
# open-draft.sh's grants the approved examples leave out: an editor that saves
# a blank line under each heading, and a ticked approve box.
set -u
# No test may reach the user's own editor.
export VISUAL=true EDITOR=true
root="$(cd "$(dirname "$0")/.." && pwd)"
open="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts/open-draft.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
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
expect "an approved-examples section whose location is not path:line never opens" "$(opens "${c_ok/c_approved_examples.test.sh:new/c_approved_examples.test.sh, the Then line}")" "refused 2"
exit $fail
