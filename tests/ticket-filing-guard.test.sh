#!/usr/bin/env bash
# The ticket-filing guard: a command that files a ticket (plane file, tea issues
# create, gh issue create) is refused until the session has started
# mission-brief. Every other command, a quoted mention, the setting off, a
# missing transcript and bad input pass.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/ticket-filing-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
started vicky-skills:do > "$dir/none.jsonl"
{ started vicky-skills:do; started vicky-skills:mission-brief; } > "$dir/briefed.jsonl"
{ started vicky-skills:do; started vicky-skills:groundhog-day; } > "$dir/bugged.jsonl"
{ started vicky-skills:do; started vicky-skills:away-team; } > "$dir/away.jsonl"
has() { # name word...: ok when the last refusal holds every word
  local name=$1 word; shift
  for word in "$@"; do grep -q -- "$word" "$dir/err" || { echo "FAIL $name"; fail=1; return; }; done
  echo "ok   $name"
}
expect() { # name want transcript command [env...]
  local name=$1 want=$2 transcript=$3 cmd=$4; shift 4
  jq -nc --arg c "$cmd" --arg t "$transcript" --arg a "${AGENT:-}" '{tool_input:{command:$c},transcript_path:$t} + (if $a == "" then {} else {agent_id:$a} end)' |
    env CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING=true "$@" "$guard" >"$dir/out" 2>"$dir/err"; got=$?
  if [ "$got" = "$want" ]; then echo "ok   $name"; else echo "FAIL $name: exit $got, want $want"; fail=1; fi
}
expect "plane file with no mission-brief is refused" 2 "$dir/none.jsonl" 'bin/plane file GAME "A title" --body-file b.md'
expect "tea issues create with no mission-brief is refused" 2 "$dir/none.jsonl" 'tea issues create --title T </dev/null'
expect "tea issue create is refused too" 2 "$dir/none.jsonl" 'tea issue create --title T </dev/null'
expect "gh issue create is refused" 2 "$dir/none.jsonl" 'gh issue create --title T --body b'
expect "a filing command after cd and && is refused" 2 "$dir/none.jsonl" 'cd repo && bin/plane file GAME T'
expect "the refusal names mission-brief and its three checks" 2 "$dir/none.jsonl" 'bin/plane file GAME T'
has "the steer names the three checks" mission-brief codebase tracker
expect "gh issue create after groundhog-day started runs" 0 "$dir/bugged.jsonl" 'gh issue create --title T --body b'
expect "gh issue create with neither filing skill is refused" 2 "$dir/none.jsonl" 'gh issue create --title T'
has "the steer names groundhog-day for a bug report" groundhog-day
expect "a Research ticket after away-team started runs" 0 "$dir/away.jsonl" 'bin/plane file GAME "Research: does save trim the name?" --body-file b.md'
expect "any other ticket after away-team is refused" 2 "$dir/away.jsonl" 'bin/plane file GAME "Fix the save button" --body-file b.md'
has "the steer names away-team for a research note" away-team
expect "a ticket with Research: only in its body after away-team is refused" 2 "$dir/away.jsonl" 'bin/plane file APP "Fix the save button" --body "Research: see notes"'
expect "a ticket with Research: only in a shell comment after away-team is refused" 2 "$dir/away.jsonl" 'bin/plane file APP "Fix bug" # Research:'
expect "a second filing chained on a Research ticket after away-team is refused" 2 "$dir/away.jsonl" 'bin/plane file APP "Research: x"; bin/plane file APP "Add feature"'
expect "a -t Research: title inside a shell comment after away-team is refused" 2 "$dir/away.jsonl" 'bin/plane file APP "Fix the button" # -t "Research: x"'
expect "a -t Research: inside a quoted body after away-team is refused" 2 "$dir/away.jsonl" "bin/plane file APP \"Fix it\" --body \"see -t 'Research: x'\""
expect "a plane file with no project before its Research title is refused" 2 "$dir/away.jsonl" 'bin/plane file "Research: x"'
expect "a filing nested in a quoted \$(...) after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body "$(gh issue create --title Fix --body b)"'
expect "a filing nested in quoted backticks after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body "`gh issue create --title Fix`"'
expect "a -t Research: in a later command after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title Fix --body b; echo -t "Research: x"'
expect "a quoted plane word in a later command after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title Fix; echo "plane" file X "Research: y"'
expect "two titles after away-team are refused" 2 "$dir/away.jsonl" 'gh issue create --title Fix --title "Research: x"'
expect "a Research ticket after another command after away-team is refused" 2 "$dir/away.jsonl" 'cd repo && gh issue create --title "Research: x" --body b'
expect "a Research ticket with a command chained after it after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body b && echo done'
expect "a gh --title=Research: after away-team runs" 0 "$dir/away.jsonl" 'gh issue create --title="Research: x" --body-file b.md'
expect "a gh Research title after away-team runs" 0 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body-file b.md'
expect "a Research ticket with a body file before a second title after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body "#1" --title "Fix"'
expect "a Research ticket with an inline body after away-team is refused, so the body comes from a file" 2 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body "# Heading"'
expect "a Research ticket followed by a second line after away-team is refused" 2 "$dir/away.jsonl" "$(printf 'gh issue create --title "Research: x" --body-file b.md\nrm -rf zz')"
expect "a Research title holding a command substitution after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: $(touch zz)" --body-file b.md'
expect "a Research body file outside the repo after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body-file ../../.env'
expect "a Research body file at an absolute path after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body-file /etc/passwd'
expect "a Research body read from stdin after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: x" -F -'
expect "a Research body file in a hidden folder after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body-file .secrets/b.md'
expect "a Research body file in scratch after away-team runs" 0 "$dir/away.jsonl" 'gh issue create --title "Research: x" --body-file /tmp/s1/b.md'
expect "a Research body file in a repo folder through -F after away-team runs" 0 "$dir/away.jsonl" 'gh issue create -t "Research: x" -F notes/b.md'
expect "a flag in plane's project slot after away-team is refused" 2 "$dir/away.jsonl" 'bin/plane file -- "Research: x"'
expect "plane with two spaces and no project after away-team is refused" 2 "$dir/away.jsonl" 'bin/plane file  "Research: x"'
expect "./bin/plane with a Research title after away-team runs" 0 "$dir/away.jsonl" './bin/plane file APP "Research: x"'
expect "a Research title holding backticks after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Research: `id`" --body-file b.md'
expect "a Research ticket with leading spaces after away-team runs" 0 "$dir/away.jsonl" '  gh issue create --title "Research: x" --body-file b.md'
expect "a Research body file in TMPDIR after away-team runs" 0 "$dir/away.jsonl" 'bin/plane file APP "Research: x" --body-file "$TMPDIR/body.md"'
expect "a Research body file climbing out of TMPDIR after away-team is refused" 2 "$dir/away.jsonl" 'bin/plane file APP "Research: x" --body-file $TMPDIR/../.env'
expect "a Research body file named by another variable after away-team is refused" 2 "$dir/away.jsonl" 'bin/plane file APP "Research: x" --body-file "$f"'
expect "a tea Research title after away-team runs" 0 "$dir/away.jsonl" "tea issues create -t 'Research: x' </dev/null"
expect "a gh ticket with Research: only in its body after away-team is refused" 2 "$dir/away.jsonl" 'gh issue create --title "Fix it" --body "Research: x"'
expect "a Research ticket with no filing skill is refused" 2 "$dir/none.jsonl" 'gh issue create --title "Research: x" --body b'
expect "plane file after mission-brief started runs" 0 "$dir/briefed.jsonl" 'bin/plane file GAME T'
expect "tea issues create after mission-brief started runs" 0 "$dir/briefed.jsonl" 'tea issues create --title T </dev/null'
jq -nc '{type:"user",message:{content:"<command-message>mission-brief</command-message>\n<command-name>/vicky-skills:mission-brief</command-name>"}}' > "$dir/slash.jsonl"
jq -nc '{type:"user",message:{content:"<command-name>/vicky-skills:do</command-name>"}}' > "$dir/slash-other.jsonl"
expect "plane file after the mission-brief slash command runs" 0 "$dir/slash.jsonl" 'bin/plane file GAME T'
expect "plane file after a different slash command is refused" 2 "$dir/slash-other.jsonl" 'bin/plane file GAME T'
expect "a familiar debt note filed on a tracker is refused, even after mission-brief" 2 "$dir/briefed.jsonl" 'bin/plane file GAME "Familiar debt: sow-codebase session 8624" --body-file d.md'
has "the debt steer names the local note" local
# Regression, ticked as E3 on the reader-cost page: a familiar debt note is
# refused before any skill is read, so groundhog-day opens no way round it.
expect "a familiar debt note is refused after groundhog-day too" 2 "$dir/bugged.jsonl" 'gh issue create --title "Familiar debt: session 12" --body b'
has "the debt steer after groundhog-day names the local note" local
expect "a debt note filed through gh is refused" 2 "$dir/briefed.jsonl" 'gh issue create --title "familiar DEBT - e9" --body b'
expect "a debt note filed through tea is refused" 2 "$dir/briefed.jsonl" "tea issues create --title 'Familiar debt: 62' </dev/null"
expect "a debt note with the guard off lets it through" 0 "$dir/none.jsonl" 'bin/plane file GAME "Familiar debt: x"' CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING=false
expect "a comment that names a familiar debt note is no filing" 0 "$dir/none.jsonl" 'bin/plane comment GAME-12 "Familiar debt: moved"'
expect "plane file --help is no filing" 0 "$dir/none.jsonl" 'bin/plane file --help'
expect "tea issues create --help is no filing" 0 "$dir/none.jsonl" 'tea issues create --help </dev/null'
expect "plane file with a title that is not --help is refused" 2 "$dir/none.jsonl" 'bin/plane file GAME T --body-file h.md'
expect "plane comment is no filing" 0 "$dir/none.jsonl" 'bin/plane comment GAME-12 "text"'
expect "gh issue list is no filing" 0 "$dir/none.jsonl" 'gh issue list'
expect "tea issues list is no filing" 0 "$dir/none.jsonl" 'tea issues list </dev/null'
expect "a quoted mention is no filing" 0 "$dir/none.jsonl" 'grep "plane file" notes.md'
expect "a heredoc body that names it is no filing" 0 "$dir/none.jsonl" "cat > n.md <<'EOF'
bin/plane file GAME T
EOF"
expect "the setting off lets it through" 0 "$dir/none.jsonl" 'bin/plane file GAME T' CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING=false
# Inside a subagent the payload names the parent's transcript; the subagent's
# own Skill calls sit in <session>/subagents/agent-<id>.jsonl.
mkdir -p "$dir/none/subagents"
started vicky-skills:mission-brief > "$dir/none/subagents/agent-a1b2.jsonl"
started vicky-skills:do > "$dir/none/subagents/agent-c3d4.jsonl"
AGENT=a1b2 expect "a subagent that started mission-brief files" 0 "$dir/none.jsonl" 'gh issue create --title T --body b'
AGENT=c3d4 expect "a subagent that did not start mission-brief is refused" 2 "$dir/none.jsonl" 'gh issue create --title T --body b'
AGENT=zz99 expect "a subagent with no transcript of its own is refused" 2 "$dir/none.jsonl" 'gh issue create --title T --body b'
AGENT=c3d4 expect "a subagent of a session that started mission-brief files" 0 "$dir/briefed.jsonl" 'gh issue create --title T --body b'
AGENT=../none/subagents/agent-a1b2 expect "an agent_id holding a path is ignored" 2 "$dir/none.jsonl" 'gh issue create --title T --body b'
jq -nc '{type:"user",message:{content:"<command-name>/vicky-skills:mission-brief</command-name>"}}' > "$dir/none/subagents/agent-e5f6.jsonl"
AGENT=e5f6 expect "a parent's prompt that quotes the typed marker does not count in a subagent" 2 "$dir/none.jsonl" 'gh issue create --title T --body b'
mkdir -p "$dir/torn/subagents"; printf '{bad\n' > "$dir/torn.jsonl"
started vicky-skills:mission-brief > "$dir/torn/subagents/agent-a1b2.jsonl"
AGENT=a1b2 expect "a torn line in the parent transcript does not hide the subagent's call" 0 "$dir/torn.jsonl" 'gh issue create --title T --body b'
expect "the main session does not count a subagent's mission-brief" 2 "$dir/none.jsonl" 'gh issue create --title T --body b'
expect "a missing transcript lets it through" 0 "$dir/missing.jsonl" 'bin/plane file GAME T'
if echo '' | CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING=true "$guard" >/dev/null 2>&1; then echo "ok   an empty payload passes"; else echo "FAIL an empty payload passes"; fail=1; fi
exit $fail
