#!/usr/bin/env bash
# approved-spec: the examples approved on the star "red-pen keeps each edit as
# a sample". Each check is named after its example. The behaviour is the
# agent's, so each check reads the instruction that drives it.
set -u
skills="$(dirname "$0")/../plugins/vicky-skills/skills/productivity"
rp="$skills/red-pen/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
keep=$(grep -A6 '^## Keep a sample' "$rp")
check "after I change a red-pen draft and close the file, red-pen shows my edited text and asks once whether it joins my voice samples" \
  'grep -q "the user changed" <<<"$keep" && grep -q "show their edited text" <<<"$keep" && grep -q "ask once whether it joins their voice samples" <<<"$keep" && grep "Write back" "$rp" | grep -q "Keep a sample"'
check "on my yes, my text joins my own voice samples word for word, with a line saying what it was, and human-voice reads them beside the samples it ships" \
  'grep -q "word for word" <<<"$keep" && grep -q "a line saying what it was" <<<"$keep" && grep -q "the user'"'"'s own samples" "$skills/human-voice/SKILL.md" && grep -q "SAMPLES.md" "$skills/human-voice/SKILL.md"'
check "on my no, or a close with nothing changed, no sample is kept and nothing more is asked" \
  'grep -q "On a no, or a draft closed unchanged, keep nothing and ask nothing more" <<<"$keep"'
exit $fail
