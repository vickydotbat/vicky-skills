#!/usr/bin/env bash
# sentinels-first-guard refuses a mutation-tool command until the session has
# started sentinels, and lets other commands, a started sentinels, quoted
# mentions, a missing transcript, bad input and the setting off through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/sentinels-first-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
: > "$dir/none.jsonl"
sk() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
sk vicky-skills:sentinels > "$dir/sent.jsonl"
sk sentinels > "$dir/bare.jsonl"
sk vicky-skills:do > "$dir/do.jsonl"
jq -nc '{type:"user",message:{content:"<command-name>/vicky-skills:sentinels</command-name>"}}' > "$dir/typed.jsonl"
fail=0
run() {
  local out code
  out=$(jq -n --arg c "$1" --arg t "$2" '{tool_name:"Bash",tool_input:{command:$c},transcript_path:$t}' |
    CLAUDE_PLUGIN_OPTION_GUARD_SENTINELS_FIRST=${3:-true} bash "$hook"); code=$?
  [ "$code" = 0 ] || { echo "exit $code"; return; }
  jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out"
}
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
for c in "dotnet stryker --since main" "cd server; scripts/mutate.sh --base origin/main" "./mutate.sh" \
  "mutmut run" "cargo mutants --in-diff x" "cargo-mutants" "mvn org.pitest:pitest-maven:mutationCoverage" \
  "gradle pitest" "tests/mutate-hooks.sh git-guard.sh" "npx stryker run" "timeout 300 bash tests/mutate-hooks.sh" \
  "systemd-run --user --scope -p MemoryMax=4G timeout 300 dotnet-stryker"; do
  check "no sentinels refuses: $c" deny "$(run "$c" "$dir/none.jsonl")"
done
for c in "python3 tests/mutate-hooks.py --all" "bash -c 'mutmut run'" "sh -c \"dotnet stryker\""; do
  check "no sentinels refuses: $c" deny "$(run "$c" "$dir/none.jsonl")"
done
check "another skill is no sentinels" deny "$(run "mutmut run" "$dir/do.jsonl")"
check "a started sentinels lets it through" "" "$(run "dotnet stryker" "$dir/sent.jsonl")"
check "a bare skill name counts" "" "$(run "mutmut run" "$dir/bare.jsonl")"
check "a typed /sentinels counts" "" "$(run "cargo mutants" "$dir/typed.jsonl")"
check "a plain command passes" "" "$(run "dotnet test" "$dir/none.jsonl")"
check "a quoted mention passes" "" "$(run "git commit -m 'stryker config tidied'" "$dir/none.jsonl")"
check "a double-quoted mention passes" "" "$(run "grep -n \"mutate.sh\" README.md" "$dir/none.jsonl")"
check "a word holding the name passes" "" "$(run "cat strykerish.txt" "$dir/none.jsonl")"
check "the refusal names the sentinels skill" 1 "$(jq -n --arg t "$dir/none.jsonl" '{tool_name:"Bash",tool_input:{command:"mutmut run"},transcript_path:$t}' | CLAUDE_PLUGIN_OPTION_GUARD_SENTINELS_FIRST=true bash "$hook" | grep -c 'start the sentinels skill')"
check "a missing transcript is refused too" deny "$(run "mutmut run" "$dir/gone.jsonl")"
check "the setting off passes" "" "$(run "mutmut run" "$dir/none.jsonl" false)"
check "the setting unset stays on" deny "$(jq -n --arg t "$dir/none.jsonl" '{tool_name:"Bash",tool_input:{command:"mutmut run"},transcript_path:$t}' | env -u CLAUDE_PLUGIN_OPTION_GUARD_SENTINELS_FIRST bash "$hook" | jq -r '.hookSpecificOutput.permissionDecision')"
check "bad input passes" "" "$(echo 'not json' | CLAUDE_PLUGIN_OPTION_GUARD_SENTINELS_FIRST=true bash "$hook" 2>/dev/null)"
check "no command passes" "" "$(jq -n '{tool_name:"Bash",tool_input:{}}' | CLAUDE_PLUGIN_OPTION_GUARD_SENTINELS_FIRST=true bash "$hook")"
# A mutation script the agent wrote itself, named for mutation, counts like a tool.
for c in "python3 -I /scratch/mutate_loop.py" "bash scratch/run-mutants.sh" "sh ./mutation.sh" "zsh x/mutate.sh" \
  "node mutants.js" "deno run mutate.ts" "bun mutate.ts" "ruby mutate.rb" "perl -w mutate.pl" "./mutate_loop.sh" \
  "/scratch/mutate_loop.py" "cd s && python3 mutate.py" "python3 mutate.py | tail"; do
  check "no sentinels refuses a script of its own: $c" deny "$(run "$c" "$dir/none.jsonl")"
done
check "a started sentinels lets a script of its own through" "" "$(run "python3 mutate_loop.py" "$dir/sent.jsonl")"
check "a script not named for mutation passes" "" "$(run "python3 summarise.py" "$dir/none.jsonl")"
check "a script named for mutation, quoted, passes" "" "$(run "cat 'mutate_loop.py'" "$dir/none.jsonl")"
check "a mutation word with no script extension passes" "" "$(run "python3 mutate_notes.txt" "$dir/none.jsonl")"
# A hand mutation: an in-place edit run with the tests, or a backup copy taken before breaking a file.
for c in "sed -i 's/a/b/' lib/x.js && npm test" "sed -i.tmp 's/a/b/' x.sh; bash tests/x.test.sh" "perl -pi -e 's/a/b/' x.py && pytest" \
  "sed -i 's/>/>=/' src/a.go && go test ./..." "sed -E -i 's/a/b/' x.sh && tests/run-all.sh" "cp lib/wiki-links.js lib/wiki-links.js.bak" \
  "cp -p x.sh /tmp/s/x.sh.orig" "mv src/a.rs src/a.rs.backup" "sed -i 's/a/b/' x && cargo test" "sed -i 's/a/b/' x && dotnet test" \
  "sed -i 's/a/b/' x && npx vitest" "sed -i 's/a/b/' x && just test" "sed -i 's/a/b/' x && mvn test" "sed -i 's/a/b/' x && bats t" \
  "sed -i 's/a/b/' x && pnpm run test" "sed -i 's/a/b/' x && jest"; do
  check "no sentinels refuses a hand mutation: $c" deny "$(run "$c" "$dir/none.jsonl")"
done
check "a started sentinels lets a hand mutation through" "" "$(run "cp x.js x.js.bak" "$dir/sent.jsonl")"
check "a restore from the backup passes" "" "$(run "cp lib/x.js.bak lib/x.js" "$dir/none.jsonl")"
check "an in-place edit with no test passes" "" "$(run "sed -i 's/a/b/' x.js" "$dir/none.jsonl")"
check "a test with no in-place edit passes" "" "$(run "sed 's/a/b/' x.js && npm test" "$dir/none.jsonl")"
check "a plain copy passes" "" "$(run "cp a.js b.js" "$dir/none.jsonl")"
check "a backup name inside quotes passes" "" "$(run "echo 'cp a a.bak'" "$dir/none.jsonl")"
check "a .bak word that is no copy passes" "" "$(run "cat a.bak" "$dir/none.jsonl")"
exit $fail
