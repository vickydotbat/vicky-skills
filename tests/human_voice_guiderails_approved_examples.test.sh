#!/usr/bin/env bash
# approved-spec: the examples approved on the star "human-voice steers with
# guiderails, never a tell list". Each check is named after its example.
set -u
here="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/human-voice"
lint="$here/scripts/lint-tells.py"
skill="$here/SKILL.md"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# lint <text>: prints the lint's output, then "exit=<code>".
lint() { printf '%s\n' "$1" > "$scratch/draft.md"; python3 "$lint" "$scratch/draft.md" 2>&1; echo "exit=$?"; }

# Every tell the lint has caught by name, as TELLS.md headed them.
names='Puffery|Significance talk|Participle tails|Negative parallelism|Dodging "is"|Vague sourcing|Vague links|Sweep constructions|Worth|Announced importance|Totalizing|Honesty tags|Quietly|Drama words|Consultant talk|Formula openers|Formula endings|Hook lines|Talking about the writing|Placeholders|Tables and emoji|Curly quotes|Hedge stacks|Em dash flood|Bold on key terms|Even rhythm|Horizontal rules|Summary|Signpost'
every=$'Picture this, a robust tool.\n\nIt marks a pivotal moment, highlighting change. It is not just fast but small. It serves as a hub. Studies show it works in relation to speed. Whether it\'s red or blue, it is worth noting. This matters. That\'s the whole game. Honestly, it quietly wrecked us. Let\'s pressure-test it.\n\nFurthermore, here\'s the thing. In this article we will look. [TODO] It may possibly help. She said “hi” \U0001F600.\n\nOne — two — three — four. In summary, done. One of the key aspects is cost. It is imperative that we go.\n\n**a** and **b** and **c** go.\n\n---\n# One\n\n---\n# Two'
every=$(printf '%b' "$every")
out=$(lint "$every")
check "a draft that trips every check the lint has gets no printed line holding the name of a tell" \
  '[ "$(grep -c "^[0-9]*: " <<<"$out")" -ge 20 ] && ! grep -Eiq "$names" <<<"$out"'

check "an agent following human-voice from first step to last never reads a list of tells, and every habit it is given is a move to make" \
  '! grep -q "TELLS.md" "$skill" && ! grep -q "→" "$skill" && ! grep -Eiq "^#+ .*(tell|metaphor)" "$skill" \
   && ! grep -Eiq "^[0-9]+\. \*\*Sweep" "$skill" && ! grep -q "TELLS.md" "$lint"'

out=$(lint 'Honestly, the old build was faster.')
check "a draft saying \"Honestly, the old build was faster.\" gets that line named with the move to make instead" \
  'grep -Eq "^1: Honestly: .{10,}$" <<<"$out" && grep -q "^exit=1$" <<<"$out"'

out=$(lint "I can't be bothered to write these, honestly.")
check "a draft saying \"I can't be bothered to write these, honestly.\" passes quietly" \
  '[ "$out" = "exit=0" ]'

check "an agent drafting a piece that mentions one thing several times is told to vary its words, and nothing it reads tells it to repeat one word" \
  'grep -Eiq "vary (your|the|its) words" "$skill" && ! grep -Eiq "repeat the one right word|repeat one word" "$skill"'

out=$(lint $'In summary, it works.\n\nOne of the key aspects is cost.\n\nIt is imperative that we ship.')
check "a draft with \"In summary,\", \"One of the key aspects\" or \"It is imperative that\" gets each line named with the move to make instead" \
  'grep -Eiq "^1: In summary,?: .{10,}$" <<<"$out" && grep -Eiq "^3: One of the key: .{10,}$" <<<"$out" \
   && grep -Eiq "^5: It is imperative: .{10,}$" <<<"$out" && grep -q "^exit=1$" <<<"$out"'

out=$(lint 'The summary table lists every flag.')
check "a draft saying \"The summary table lists every flag.\" passes quietly" \
  '[ "$out" = "exit=0" ]'
exit $fail
