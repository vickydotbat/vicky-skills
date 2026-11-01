#!/usr/bin/env bash
# SessionStart and PostToolUse (Bash) hook: rebuilds the marked springboard
# block in the repo's .todo, at most five actions only the user can take,
# each with its link: a draft page open in their browser, a ready pull
# request with green checks to merge, and a pull request whose `Waits on:`
# line names them. Lines outside the block are the user's and stay as they
# are. At session start it tells the agent to open on N1 alone, and to say
# what changed in the tracker since the user's last session in this repo.
# After a Bash call it rebuilds only on a push, a merge or a page that closed.
# It touches only a repo whose .gitignore ignores .todo, so it never leaves
# an untracked file in a repo that didn't ask for one.
# shortcut: reads pull requests from GitHub only; add tea when a Gitea repo wants the block.
set -u
input=$(cat)
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0 # mutant-ok: the project folder exists whenever Claude Code starts a session in it
grep -qs '^Todo file: off' docs/agents/*.md && exit 0
git check-ignore -q .todo 2>/dev/null || exit 0
gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0 # mutant-ok: git check-ignore above already proved this is a repository
event=$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null)
case "$event" in SessionStart|PostToolUse) ;; *) exit 0 ;; esac
if [ "$event" = PostToolUse ]; then
  cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)
  grep -qE '(^|[;&|[:space:]])(git push|gh pr merge|tea (pr|pulls) merge)([[:space:]]|$)|open-(page|draft)\.sh' <<<"$cmd" || exit 0
fi

actions() {
  if [ -f "$gitdir/red-pen-open" ]; then
    echo "press Done on the draft page for $(sed -n 2p "$gitdir/red-pen-open")"
  fi
  gh pr list --state open --json number,title,url,isDraft,body,statusCheckRollup 2>/dev/null | jq -r '
    def green: (.statusCheckRollup // []) | length > 0 and all(.[]; (.conclusion // "") | test("^(SUCCESS|SKIPPED|NEUTRAL)$"));
    def waits_on_you: (.body // "") | split("\n") | map(select(test("^`?Waits on:`? *(you|the user)\\b"; "i"))) | first;
    .[] |
    if (.isDraft | not) and green then "merge #\(.number) \(.title) \(.url)"
    elif waits_on_you then "#\(.number) waits on you: \(waits_on_you | sub("^`?Waits on:`? *"; "")) \(.url)"
    else empty end'
}

lines=$(actions | head -5 | awk '{print "N" NR " " $0}')
[ -n "$lines" ] || lines="nothing waits on you"
new=$(printf '# springboard start: actions only you can take, rebuilt by the vicky-skills plugin\n%s\n# springboard end\n' "$lines")
if [ -f .todo ] && grep -q '^# springboard start' .todo; then
  awk -v block="$new" '/^# springboard start/{print block; skip=1; next} /^# springboard end/{skip=0; next} !skip' .todo > .todo.tmp && mv .todo.tmp .todo
else
  printf '%s\n' "$new" >> .todo
fi

[ "$event" = SessionStart ] || exit 0
first=$(grep -m1 '^N1 ' <<<"$lines")
[ -n "$first" ] && echo "Open your first reply with this line alone, and give the rest of the .todo springboard block only when the user asks: next: $first"
stamp="$gitdir/springboard-last-session"
if [ -f "$stamp" ]; then
  echo "Run the tracker's \"List items created or changed since <time>\" operation from docs/agents/issue-tracker.md for the items since $(cat "$stamp"), when the user's last session in this repo started, and add one line: Since then: <n> new, <m> edited. Say \`since\` for the list."
fi
date -Iseconds > "$stamp"
