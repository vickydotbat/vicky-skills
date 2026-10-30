#!/usr/bin/env bash
# An agent runs a skill's steps in order and moves on when one looks done.
# Every numbered step under a "Steps" heading says when it is done, and every
# skill opens with a title, so a step never ends on a feeling.
set -u
cd "$(dirname "$0")/../plugins/vicky-skills"
fail=0
for f in skills/*/*/SKILL.md; do
  grep -q '^# ' "$f" || { echo "FAIL $f has no title"; fail=1; }
  missing=$(awk '
    function check() { gsub(/[ \t]+/, " ", text); if (step != "" && text !~ /Done when/) print step; step = text = "" }
    /^## / { check(); in_steps = ($0 ~ /^## .*Steps/); next }
    in_steps && /^[0-9]+\. / { check(); step = $0 }
    in_steps { text = text " " $0 }
    END { check() }
  ' "$f")
  [ -z "$missing" ] || { echo "FAIL $f has a step with no Done when:"; echo "$missing" | cut -c1-80 | sed 's/^/     /'; fail=1; }
done
[ $fail -eq 0 ] && echo "ok   every skill has a title, and every numbered step says when it is done"
exit $fail
