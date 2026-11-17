#!/usr/bin/env bash
# ready-resume-hint.sh tells the agent to carry make-it-so on once the user's
# `!` command marked a pull request ready, read from the prompt or from the
# bash inputs since the agent's last reply. It stays silent for a draft mark,
# an older command, the setting off, and without jq.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/ready-resume-hint.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
run() { CLAUDE_PLUGIN_OPTION_READY_RESUME_HINT="${opt-}" bash "$hook" <<<"$1" 2>&1; }
has() { if grep -qF -- "$2" <<<"$3"; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
none() { if [ -z "$2" ] && [ "${code:-0}" = 0 ]; then echo "ok   $1"; else echo "FAIL $1: got '$2'"; fail=1; fi; }
p() { jq -nc --arg p "$1" --arg t "${2:-}" '{hook_event_name:"UserPromptSubmit",prompt:$p,transcript_path:$t}'; }
b() { printf '<bash-input>%s</bash-input>' "$1"; }
u() { jq -nc --arg c "$1" '{type:"user",message:{role:"user",content:$c}}'; }
a() { jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:"Type the command."}]}}'; }

out=$(run "$(p "$(b 'gh pr ready 12')")")
has "gh pr ready in the prompt resumes make-it-so" "make-it-so goes on" "$out"
has "the hint names the command" 'gh pr ready 12' "$out"
has "the hint names the run check" "close and reopen the pull request" "$out"
has "the hint names the CI watch" "watch every required check" "$out"
has "the hint names the settling" "settle the tickets and the body" "$out"
has "the hint answers as UserPromptSubmit" '"hookEventName":"UserPromptSubmit"' "$out"
has "a Gitea title edit without WIP: resumes it" "make-it-so goes on" "$(run "$(p "$(b 'tea pr edit 1614 -t "Add the forge"')")")"
has "a Gitea --title= edit resumes it" "make-it-so goes on" "$(run "$(p "$(b 'tea pulls edit 3 --title="Fix it"')")")"
has "tea pr edit --ready resumes it" "make-it-so goes on" "$(run "$(p "$(b 'tea pr edit 7 --ready')")")"
none "gh pr ready --undo is a draft mark" "$(run "$(p "$(b 'gh pr ready 12 --undo')")")"
none "a title that keeps WIP: is a draft mark" "$(run "$(p "$(b 'tea pr edit 4 -t "WIP: Add it"')")")"
none "a title edit with --draft is a draft mark" "$(run "$(p "$(b 'tea pr edit 4 -t "Add it" --draft')")")"
none "a tea edit with no title is no ready mark" "$(run "$(p "$(b 'tea pr edit 4 --description x')")")"
none "a prompt that only talks about gh pr ready is skipped" "$(run "$(p 'what does gh pr ready do')")"
none "another command is skipped" "$(run "$(p "$(b 'gh pr view 12')")")"
none "a word ending in gh is not gh" "$(run "$(p "$(b 'xgh pr ready 1')")")"

t="$dir/t.jsonl"
{ a; u "$(b 'gh pr ready 9')"; } >"$t"
has "a ready mark since the last reply resumes it" "gh pr ready 9" "$(run "$(p 'done' "$t")")"
{ u "$(b 'gh pr ready 9')"; a; } >"$t"
none "a ready mark before the last reply is old" "$(run "$(p 'done' "$t")")"
{ u "$(b 'gh pr ready 9')"; } >"$t"
has "a transcript with no reply yet is read whole" "gh pr ready 9" "$(run "$(p 'done' "$t")")"
{ a; jq -nc '{type:"user",message:{role:"user",content:[{type:"tool_result",content:"<bash-input>gh pr ready 9</bash-input>"}]}}'; } >"$t"
none "a tool result is not the user's command" "$(run "$(p 'done' "$t")")"
none "a missing transcript reads the prompt alone" "$(run "$(p 'done' "$dir/none.jsonl")")"
none "bad input is skipped" "$(run 'not json')"

opt=false; out=$(run "$(p "$(b 'gh pr ready 1')")"); code=$?; none "the setting off skips it" "$out"; code=0
opt=0; none "the setting 0 skips it" "$(run "$(p "$(b 'gh pr ready 1')")")"
opt=true; has "the setting on runs it" "make-it-so goes on" "$(run "$(p "$(b 'gh pr ready 1')")")"
unset opt
mkdir -p "$dir/nobin"; for t in bash cat sed grep tail; do ln -s "$(command -v "$t")" "$dir/nobin/$t"; done
none "without jq it stays silent" "$(PATH="$dir/nobin" run "$(p "$(b 'gh pr ready 1')")")"

step=$(sed -n '/^5\. /p' "$root/plugins/vicky-skills/skills/engineering/make-it-so/SKILL.md")
has "make-it-so step 5 watches for the user's ready mark" "isDraft" "$step"
has "make-it-so step 5 names this hook" "ready-resume-hint" "$step"
exit $fail
