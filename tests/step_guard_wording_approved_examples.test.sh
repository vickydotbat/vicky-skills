#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for the hook audit, E3
# and E4. Approved wording is judged once, when the pull request is marked
# ready, from the branch's diff, and a do build's body names its examples.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/step-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
: > "$dir/none.jsonl"
{ started vicky-skills:do; started vicky-skills:sentinels; started vicky-skills:review; } > "$dir/do.jsonl"
mkdir "$dir/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$BODY"\n' > "$dir/bin/gh"; chmod +x "$dir/bin/gh"
git init -q -b main "$dir/origin"; git -C "$dir/origin" config user.email t@t; git -C "$dir/origin" config user.name t
mkdir -p "$dir/origin/tests"; printf '# Given a thing\n# When it runs\n# Then it works\ncheck x\n' > "$dir/origin/tests/x_approved_examples.test.sh"
git -C "$dir/origin" add -A; git -C "$dir/origin" commit -qm base
fresh() { rm -rf "$dir/w"; git clone -q "$dir/origin" "$dir/w"; git -C "$dir/w" config user.email t@t; git -C "$dir/w" config user.name t; git -C "$dir/w" switch -qc feat; }
edit() { sed -i "$1" "$dir/w/tests/x_approved_examples.test.sh"; git -C "$dir/w" commit -qam change; }
run() { jq -nc --arg t "$dir/$1" --arg d "$dir/w" '{tool_input:{command:"gh pr ready 5"},transcript_path:$t,cwd:$d}' |
  env PATH="$dir/bin:$PATH" BODY="$2" CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$guard" 2>"$dir/err" >/dev/null; echo $?; }

# Given a branch that changed a Then line in an approved examples file, with no ticked page for it
# When the agent marks the pull request ready
# Then it is refused, naming the file
fresh; edit 's/# Then it works/# Then it works well/'
check "E3 changed Then wording with no ticked page is refused" \
  '[ "$(run none.jsonl "")" = 2 ] && grep -q "x_approved_examples.test.sh" "$dir/err"'

# Given the same change, with the file ticked on a red-pen page
# When the agent marks the pull request ready
# Then it goes through
echo tests/x_approved_examples.test.sh >> "$(git -C "$dir/w" rev-parse --path-format=absolute --git-common-dir)/approved-spec-grants"
check "E3 the same change ticked on a page goes through" '[ "$(run none.jsonl "")" = 0 ]'

# Given a branch that changed only harness lines in an approved file
# When the agent marks the pull request ready
# Then it goes through
fresh; edit 's/^check x$/check y/'
check "E3 a harness-only change goes through" '[ "$(run none.jsonl "")" = 0 ]'

# Given a session that ran do and a pull request body with no Examples line
# When the agent marks it ready
# Then it is refused and told to add Examples: approved on <ticket> or Examples: none, because <reason>
check "E4 a do build with no Examples line is refused" \
  '[ "$(run do.jsonl "Plan check: none found")" = 2 ] && grep -q "Examples: none, because" "$dir/err"'
check "E4 a do build with an Examples line goes through" \
  '[ "$(run do.jsonl "Plan check: none found
Examples: approved on T-1")" = 0 ]'
exit $fail
