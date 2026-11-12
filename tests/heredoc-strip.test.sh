#!/usr/bin/env bash
# heredoc-strip.awk drops heredoc bodies, which are text. With -v code=1 it
# keeps a body fed to a shell, since that body runs as code; without it, every
# body goes.
set -u
awkf="$(dirname "$0")/../plugins/vicky-skills/scripts/heredoc-strip.awk"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
fed=$'bash <<EOF\nrm -rf x\nEOF\necho after'
text=$'cat > f <<EOF\nrm -rf x\nEOF\necho after'
check "without code, a body fed to a shell is dropped" '! grep -q "rm -rf" <<<"$(awk -f "$awkf" <<<"$fed")" && grep -q "echo after" <<<"$(awk -f "$awkf" <<<"$fed")"'
check "with code=1, a body fed to a shell stays" 'grep -q "rm -rf" <<<"$(awk -v code=1 -f "$awkf" <<<"$fed")"'
check "with code=1, a body fed to a file is dropped" '! grep -q "rm -rf" <<<"$(awk -v code=1 -f "$awkf" <<<"$text")"'
exit $fail
