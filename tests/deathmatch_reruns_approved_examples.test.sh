#!/usr/bin/env bash
# approved-spec: the Deathmatch reruns chart, DR-1 to DR-8, ticked on the
# examples page on 2026-11-25. Each block is one approved example, run against
# the hook or script it names. The skill-text halves of DR-4 to DR-8 are proven
# by their eval cases.
# shellcheck disable=SC2016,SC2034,SC2329 # check evals its condition strings, which read these variables and call these functions
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
s="$root/plugins/vicky-skills/scripts"
dm="$root/plugins/vicky-skills/skills/shipping/deathmatch/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
# A home and git config of its own, so no setting on the machine reaches a repo here.
export HOME="$t/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export CLAUDE_PLUGIN_DATA="$t/data" TMPDIR="$t/tmp"; mkdir -p "$HOME" "$TMPDIR" "$t/bin"
unset CLAUDE_CODE_SESSION_ID # verdict.sh record checks it, and CI never sets it
# A gh stub, so no guard here ever reaches a real forge.
printf '#!/bin/sh\nexit 0\n' > "$t/bin/gh"; chmod +x "$t/bin/gh"; export PATH="$t/bin:$PATH"
skill() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
repo() { # repo <dir>: a git repo with one commit on main
  mkdir -p "$1" && git -C "$1" init -qb main && git -C "$1" config user.email t@t && git -C "$1" config user.name t
  printf 'a\n' > "$1/a.sh" && git -C "$1" add -A && git -C "$1" commit -qm base
}
verdict_body() { printf '## Proof\n\nDeathmatch verdict for %s: 0 proven findings\n' "$1"; }
# guard <script> <transcript> <command> [cwd]: the hook's exit for a Bash call.
guard() { jq -nc --arg c "$3" --arg t "$2" --arg d "${4:-}" '{tool_input:{command:$c},transcript_path:$t,cwd:$d}' |
  bash "$s/$1" >/dev/null 2>&1; echo $?; }

# DR-1
# Given a transcript whose line 1823 is NUL bytes, and a mission-brief Skill call after it
# When ticket-filing-guard judges a gh issue create
# Then the command runs, and draft-guard and rebase-guard read the same later call
torn() { for _ in $(seq 1822); do skill vicky-skills:do; done; printf '\0\0\0\0\n'; }
{ torn; skill vicky-skills:mission-brief; skill vicky-skills:make-it-so; skill vicky-skills:history-monks; } > "$t/torn.jsonl"
torn > "$t/torn-only.jsonl"
# A branch behind a moved origin main, so rebase-guard has a rebase to judge.
repo "$t/o1"; git clone -q "$t/o1" "$t/c1"; git -C "$t/c1" switch -qc feature
printf 'm\n' > "$t/o1/m.sh"; git -C "$t/o1" add -A; git -C "$t/o1" commit -qm moved; git -C "$t/c1" fetch -q
file="gh issue create --title T --body-file b.md"
check "DR-1 a torn line hides no later Skill call from ticket-filing-guard, draft-guard or rebase-guard" \
  '[ "$(guard ticket-filing-guard.sh "$t/torn.jsonl" "$file")" = 0 ] &&
   [ "$(guard draft-guard.sh "$t/torn.jsonl" "gh pr ready 1")" = 0 ] &&
   [ "$(guard rebase-guard.sh "$t/torn.jsonl" "git rebase origin/main" "$t/c1")" = 0 ] &&
   [ "$(guard ticket-filing-guard.sh "$t/torn-only.jsonl" "$file")" = 2 ] &&
   [ "$(guard draft-guard.sh "$t/torn-only.jsonl" "gh pr ready 1")" = 2 ] &&
   [ "$(guard rebase-guard.sh "$t/torn-only.jsonl" "git rebase origin/main" "$t/c1")" = 2 ]'

# DR-2
# Given a command that runs $GH issue create, or a full path ending in /gh, with no filing skill started
# When ticket-filing-guard judges it
# Then it is refused, as plain gh issue create is
skill vicky-skills:do > "$t/none.jsonl"
filing() { guard ticket-filing-guard.sh "$t/none.jsonl" "$1"; }
check "DR-2 a forge CLI behind a variable or a full path is refused as gh is" \
  '[ "$(filing "gh issue create --title T")" = 2 ] && [ "$(filing "\$GH issue create --title T")" = 2 ] &&
   [ "$(filing "\"\$GH\" issue create --title T")" = 2 ] && [ "$(filing "\${GH} issue create --title T")" = 2 ] &&
   [ "$(filing "/usr/local/bin/gh issue create --title T")" = 2 ]'

# DR-3
# Given batch.sh printed at once: 1 and no opponent fights
# When the first opponent launch reaches opponent-batch-guard with its own tool_use already in the transcript
# Then it starts on the first try
launch() { jq -nc --arg i "$1" '{type:"assistant",message:{content:[{type:"tool_use",id:$i,name:"Agent",input:{subagent_type:"vicky-skills:intent-opponent",prompt:"p"}}]}}'; }
batch() { # batch <session> <transcript>: the guard's exit for launch own1
  jq -nc --arg t "$2" --arg sid "$1" '{session_id:$sid,tool_use_id:"own1",transcript_path:$t,tool_input:{subagent_type:"vicky-skills:intent-opponent",prompt:"p"}}' |
    bash "$s/opponent-batch-guard.sh" >/dev/null 2>&1; echo $?; }
once=$(jq -nc '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"b",content:"at once: 1\nmemory cap: 2.0G"}]}}')
{ echo "$once"; launch own1; } > "$t/batch.jsonl"
{ echo "$once"; launch other; launch own1; } > "$t/batch-other.jsonl"
check "DR-3 a launch never counts itself, and another fighter still fills the one slot" \
  '[ "$(batch dr3 "$t/batch.jsonl")" = 0 ] && [ "$(batch dr3b "$t/batch-other.jsonl")" = 2 ]'

# DR-4
# Given a sealed-copy root setting that names a folder outside the temp folder, and a dev shell that sets core.hooksPath and installs hooks in each clone
# When deathmatch makes, checks and resets the copies
# Then copy and reset work there, and check reports only git state added after the warm build
repo "$t/w"; c4="$t/root/c"; mkdir -p "$t/root"; git clone -q "$t/w" "$c4"; pin=$(git -C "$c4" rev-parse HEAD)
hook() { printf '#!/bin/sh\n' > "$c4/.git/hooks/$1"; chmod +x "$c4/.git/hooks/$1"; }
git -C "$c4" config core.hooksPath .githooks; hook pre-commit
export CLAUDE_PLUGIN_OPTION_SEALED_COPY_ROOT="$t/root"
base="$t/git.baseline"; bash "$dm/sealed-check.sh" baseline "$c4" > "$base" 2>/dev/null
export SEALED_GIT_BASELINE="$base"
cp4=$(bash "$dm/sealed-check.sh" copy "$c4" holds 2>/dev/null); rc=$?
clean=$(bash "$dm/sealed-check.sh" check "$c4" "$pin" 2>&1); rk=$?
hook post-checkout
added=$(bash "$dm/sealed-check.sh" check "$c4" "$pin" 2>&1); ra=$?
printf 'x\n' >> "$c4/a.sh"; bash "$dm/sealed-check.sh" reset "$c4" "$pin" >/dev/null 2>&1; rr=$?
check "DR-4 copy and reset work under the root setting, and check reports only git state added after the baseline" \
  '[ $rc = 0 ] && [ -d "$cp4" ] && [ $rk = 0 ] && [ $ra = 1 ] && grep -q "hook post-checkout" <<<"$added" &&
   ! grep -qi "hookspath\|hook pre-commit" <<<"$added" && [ $rr = 0 ] && [ -z "$(git -C "$c4" status --porcelain)" ]'
unset CLAUDE_PLUGIN_OPTION_SEALED_COPY_ROOT SEALED_GIT_BASELINE

# DR-5: make-it-so's order is skill text, proven by evals/make-it-so/rules-before-deathmatch.

# DR-6
# Given a pull request body with a verdict for an ancestor of HEAD, and three commits since
# When deathmatch runs
# Then its fixed point is that verdict's commit, and every brief names that range
repo "$t/g6"; printf 'b\n' > "$t/g6/b.sh"; git -C "$t/g6" add -A; git -C "$t/g6" commit -qm one; v6=$(git -C "$t/g6" rev-parse HEAD)
for i in 1 2 3; do printf '%s\n' "$i" >> "$t/g6/b.sh"; git -C "$t/g6" commit -qam "c$i"; done
verdict_body "$v6" > "$t/body6.md"
since=$(cd "$t/g6" && bash "$dm/verdict.sh" since "$t/body6.md" 2>/dev/null)
check "DR-6 the fixed point is the last verdict's commit when it is an ancestor of HEAD" '[ "$since" = "$v6" ]'

# DR-7
# Given a verdict for the old head, a rebase onto an unrelated main commit, and the repo's checks green on the new head
# When make-it-so asks verdict.sh whether deathmatch is due
# Then it is not due, the body gains a verdict line for the new head, and pr-guard lets it go ready
#
# Given the same rebase plus a one-line content change
# When verdict.sh is asked
# Then deathmatch is due
g7="$t/g7"; repo "$g7"; git -C "$g7" switch -qc feature; printf 'f\n' > "$g7/f.sh"; git -C "$g7" add -A; git -C "$g7" commit -qm feat
old=$(git -C "$g7" rev-parse HEAD)
git -C "$g7" switch -q main; printf 'm\n' > "$g7/m.sh"; git -C "$g7" add -A; git -C "$g7" commit -qm unrelated
git -C "$g7" switch -q feature; git -C "$g7" rebase -q main; new=$(git -C "$g7" rev-parse HEAD)
verdict_body "$old" > "$t/body7.md"
(cd "$g7" && bash "$dm/verdict.sh" due "$t/body7.md" "$new" main s7 >/dev/null 2>&1); rd=$?
ready=$(cd "$g7" && jq -nc '{session_id:"s7",tool_name:"Bash",hook_event_name:"PreToolUse",tool_input:{command:"gh pr ready 7"}}' |
  CLAUDE_PLUGIN_OPTION_GUARD_PR=true bash "$s/pr-guard.sh" >/dev/null 2>&1; echo $?)
printf 'g\n' >> "$g7/f.sh"; git -C "$g7" commit -qam more; new2=$(git -C "$g7" rev-parse HEAD)
(cd "$g7" && bash "$dm/verdict.sh" due "$t/body7.md" "$new2" main s7 >/dev/null 2>&1); rd2=$?
check "DR-7 a rebase with no content change carries the verdict and pr-guard lets it go ready, and a content change is due" \
  '[ $rd = 1 ] && grep -q "Deathmatch verdict for $new" "$t/body7.md" && [ "$ready" = 0 ] &&
   [ $rd2 = 0 ] && ! grep -q "Deathmatch verdict for $new2" "$t/body7.md"'

# DR-8
# Given an earlier verdict, and new commits that change only Markdown
# When deathmatch runs again
# Then only Intent and Claims fight, and the report names each opponent left out and why
g8="$t/g8"; repo "$g8"; v8=$(git -C "$g8" rev-parse HEAD); printf '# n\n' > "$g8/n.md"; git -C "$g8" add -A; git -C "$g8" commit -qm notes
verdict_body "$v8" > "$t/body8.md"
tr8=$(cd "$g8" && bash "$dm/triggers.sh" --rerun "$v8" "$t/body8.md" 2>&1)
fights=$(grep '^fight: ' <<<"$tr8" | sed 's/^fight: //' | sort | tr '\n' ' ')
check "DR-8 a Markdown-only rerun sends only Intent and Claims, and names why each other is out" \
  '[ "$fights" = "claims intent " ] && [ "$(grep -c "^out of reach: [a-z]* (.\+)" <<<"$tr8")" = 4 ]'

exit "$fail"
