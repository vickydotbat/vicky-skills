# shellcheck shell=bash
# Sourced by the auto-tidy tests: a repo with an origin, a fake gh and a fake
# tea that answer from one pull request list, and helpers to merge, branch
# and check. A test stops only the processes busy() started.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/auto-tidy.sh"
manifest="$root/plugins/vicky-skills/.claude-plugin/plugin.json"
skills="$root/plugins/vicky-skills/skills"
dir=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "$dir"; }
trap cleanup EXIT
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
mkdir "$dir/gh" "$dir/tea"
# $dir/prs holds one pull request per line: <branch> <OPEN|MERGED> <head sha>.
cat > "$dir/gh/gh" <<EOF
#!/usr/bin/env bash
[ -f "$dir/prs" ] || exit 1
case "\$1 \$2" in
  "pr list") jq -Rn '[inputs | split(" ") | {headRefName: .[0], state: .[1], headRefOid: .[2]}]' "$dir/prs" ;;
  *) exit 1 ;;
esac
EOF
cat > "$dir/tea/tea" <<EOF
#!/usr/bin/env bash
[ "\$1" = api ] && [ -f "$dir/prs" ] || exit 1
jq -Rn '[inputs | split(" ") | {head: {ref: .[0], sha: .[2]}, merged: (.[1] == "MERGED"), state: (if .[1] == "OPEN" then "open" else "closed" end)}]' "$dir/prs"
EOF
chmod +x "$dir/gh/gh" "$dir/tea/tea"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
FORGE=gh
start_in() { jq -nc --arg d "$1" '{hook_event_name: "SessionStart", source: "startup", cwd: $d}'; }
# run [project dir] [stdin]: the hook as Claude Code starts it.
run() {
  local d=${1:-$dir/repo} opt=()
  [ -n "${OPT+x}" ] && opt=(CLAUDE_PLUGIN_OPTION_AUTO_TIDY="$OPT")
  env PATH="$dir/$FORGE:$PATH" CLAUDE_PROJECT_DIR="$d" "${opt[@]}" bash "$hook" <<<"${2:-$(start_in "$d")}"
}
# The agent hears nothing: no output at all, or JSON whose only field is systemMessage.
agent_silent() { [ -z "$1" ] || jq -e 'keys == ["systemMessage"]' <<<"$1" >/dev/null 2>&1; }
seen() { jq -r '.systemMessage // empty' <<<"$1" 2>/dev/null; }
has_local() { git -C "$dir/repo" rev-parse -q --verify "refs/heads/$1" >/dev/null; }
has_remote() { git -C "$dir/origin.git" rev-parse -q --verify "refs/heads/$1" >/dev/null; }
setup() {
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; pids=()
  rm -rf "$dir/origin.git" "$dir/repo" "$dir/prs" "$dir"/wt-* "$dir/other"
  git init -q --bare -b main "$dir/origin.git"
  git clone -q "$dir/origin.git" "$dir/repo" 2>/dev/null
  git -C "$dir/repo" config user.email t@example.invalid
  git -C "$dir/repo" commit -q --allow-empty -m base
  git -C "$dir/repo" push -q origin HEAD:main 2>/dev/null
}
# branch <name>: a pushed branch with one commit, made from main.
branch() {
  git -C "$dir/repo" switch -q -c "$1" origin/main
  echo "$1" > "$dir/repo/$1.txt"; git -C "$dir/repo" add "$1.txt"; git -C "$dir/repo" commit -q -m "$1"
  git -C "$dir/repo" push -q -u origin "$1" 2>/dev/null
  git -C "$dir/repo" switch -q --detach origin/main
}
# merge <name> [keep]: squash-merge the branch on origin's main and record its
# pull request merged. The forge deletes the branch unless "keep" is given.
merge() {
  local sha; sha=$(git -C "$dir/origin.git" rev-parse "$1")
  git clone -q "$dir/origin.git" "$dir/merger" 2>/dev/null
  git -C "$dir/merger" merge -q --squash "origin/$1" >/dev/null 2>&1; git -C "$dir/merger" commit -q -m "$1 (#1)"
  git -C "$dir/merger" push -q origin main 2>/dev/null; rm -rf "$dir/merger"
  echo "$1 MERGED $sha" >> "$dir/prs"
  [ "${2:-}" = keep ] || git -C "$dir/origin.git" branch -q -D "$1"
}
# worktree <branch>: check the branch out in its own worktree.
worktree() { git -C "$dir/repo" worktree add -q "$dir/wt-$1" "$1" 2>/dev/null; }
# busy <path>: another session stands in that folder until the test ends.
busy() {
  local i
  (cd "$1" && exec sleep 300) & pids+=($!)
  for i in $(seq 50); do [ "$(readlink "/proc/$!/cwd" 2>/dev/null)" = "$1" ] && return; sleep 0.1; done
}
on_main() { git -C "$dir/repo" switch -q main 2>/dev/null || git -C "$dir/repo" switch -q -c main origin/main; }

