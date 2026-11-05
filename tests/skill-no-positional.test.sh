#!/usr/bin/env bash
# Claude Code replaces $0, $1 and $ARGUMENTS in a SKILL.md body with the
# skill's arguments when it loads, so a shell line holding one reaches the
# agent broken. A skill puts such code in a script under its scripts/ folder.
set -u
cd "$(dirname "$0")/../plugins/vicky-skills"
fail=0
for f in skills/*/*/SKILL.md; do
  hits=$(grep -nE '\$([0-9]|ARGUMENTS)' "$f")
  [ -z "$hits" ] || { echo "FAIL $f holds a token the skill loader replaces:"; echo "$hits" | cut -c1-100 | sed 's/^/     /'; fail=1; }
done
[ $fail -eq 0 ] && echo "ok   no skill holds \$0, \$1 or \$ARGUMENTS for the loader to replace"
exit $fail
