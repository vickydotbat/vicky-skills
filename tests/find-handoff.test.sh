#!/usr/bin/env bash
# find-handoff.sh finds the newest **Handoff** comment on the branch's open
# pull request, on the tickets it names, or in an earlier session that names
# the branch, and lists where it looked when it finds none. gh and tea are
# stubs on PATH, so no test reaches a real tracker.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
finder="$root/plugins/vicky-skills/skills/productivity/sup/scripts/find-handoff.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if grep -qF -- "$2" <<<"$3"; then echo "ok   $1"; else echo "FAIL $1: want '$2' in: $3"; fail=1; fi; }
lacks() { if grep -qF -- "$2" <<<"$3"; then echo "FAIL $1: '$2' in: $3"; fail=1; else echo "ok   $1"; fi; }
mkdir -p "$dir/bin" "$dir/projects"
repo() { # repo <name> <remote>: a checkout on branch feat-ABC-7 with a tracker doc
  local r="$dir/$1"; git init -q -b main "$r"; git -C "$r" remote add origin "$2"
  git -C "$r" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init; git -C "$r" switch -q -c feat-ABC-7
  mkdir -p "$r/docs/agents"; echo "| Read, whole | \`cat $dir/ticket-<key>\` |" > "$r/docs/agents/issue-tracker.md"; echo "$r"
}
cat > "$dir/bin/tea" <<EOF
#!/usr/bin/env bash
case "\$1" in
  pr) cat "$dir/tea-prs" ;;
  api) echo "\$2" >> "$dir/tea-calls"; cat "$dir/tea-comments" ;;
esac
EOF
cat > "$dir/bin/gh" <<EOF
#!/usr/bin/env bash
cat "$dir/gh-pr"
EOF
chmod +x "$dir/bin/"*
run() { (cd "$1" && shift && PATH="$dir/bin:$PATH" FIND_HANDOFF_PROJECTS_DIR="$dir/projects" CLAUDE_CODE_SESSION_ID=now bash "$finder" "$@" 2>&1); }

tea_repo=$(repo tea git@forge.example:o/r.git)
echo '[{"index":"5","head":"feat-ABC-7","url":"https://forge.example/o/r/pulls/5","title":"t","body":"Closes XYZ-9"},{"index":"6","head":"other","url":"u6","title":"","body":""}]' > "$dir/tea-prs"
echo '[{"body":"**Handoff** old","html_url":"c1"},{"body":"**Handoff** new","html_url":"c2"},{"body":"not a **Handoff**","html_url":"c3"}]' > "$dir/tea-comments"
out=$(run "$tea_repo")
check "tea: the newest handoff comment on the branch's pull request" "found: pull request comment: c2" "$out"
check "tea: it reads that pull request's comments" "issues/5/comments" "$(cat "$dir/tea-calls")"
check "tea: it names the pull request it searched" "searched: pull request https://forge.example/o/r/pulls/5" "$out"
check "a key in the branch name is read as a ticket" "ticket ABC-7" "$out"
check "a key in the pull request body is read as a ticket" "ticket XYZ-9" "$out"

echo '[{"body":"no","html_url":"c1"}]' > "$dir/tea-comments"
echo '- 2026-01-01: **Handoff** pick up the parser' > "$dir/ticket-XYZ-9"
out=$(run "$tea_repo")
check "a handoff on a linked ticket is found" "found: ticket XYZ-9: - 2026-01-01: **Handoff** pick up the parser" "$out"
rm "$dir/ticket-XYZ-9"

echo '[]' > "$dir/tea-prs"
out=$(run "$tea_repo")
check "no open pull request is named as not read" "not read: pull request, no open one for feat-ABC-7" "$out"
check "with no hit it lists where it looked" "none found in:" "$out"

prefix=$(cd "$tea_repo" && dirname "$(git rev-parse --path-format=absolute --git-common-dir)" | sed 's#[/.]#-#g')
mkdir -p "$dir/projects/$prefix" "$dir/projects/$prefix--claude-worktrees-x"
echo '{"text":"unrelated, **Handoff** at https://forge.example/wrong"}' > "$dir/projects/$prefix/newer.jsonl"
echo '{"text":"feat-ABC-7 done. **Handoff** https://forge.example/o/r/pulls/5#c9"}' > "$dir/projects/$prefix--claude-worktrees-x/old.jsonl"
echo '{"text":"feat-ABC-7 **Handoff** https://forge.example/self"}' > "$dir/projects/$prefix/now.jsonl"
touch -d '1 hour ago' "$dir/projects/$prefix--claude-worktrees-x/old.jsonl"
out=$(run "$tea_repo")
check "an earlier worktree session naming the branch links the handoff" "found: earlier session old: https://forge.example/o/r/pulls/5#c9" "$out"
lacks "a session that never names the branch or a key is skipped" "forge.example/wrong" "$out"
lacks "the current session is skipped" "forge.example/self" "$out"
rm -rf "$dir/projects/"*

gh_repo=$(repo gh https://github.com/o/r.git)
echo '{"state":"OPEN","url":"https://github.com/o/r/pull/3","title":"t","body":"","comments":[{"body":"**Handoff** go","url":"g1"}]}' > "$dir/gh-pr"
check "gh: the handoff comment on a GitHub pull request" "found: pull request comment: g1" "$(run "$gh_repo")"
echo '{"state":"MERGED","url":"x","title":"","body":"","comments":[{"body":"**Handoff** go","url":"g1"}]}' > "$dir/gh-pr"
out=$(run "$gh_repo")
check "gh: a merged pull request is not the branch's open one" "not read: pull request, no open one for feat-ABC-7" "$out"
lacks "gh: a merged pull request's handoff is not reported" "g1" "$out"

git -C "$tea_repo" switch -q --detach
check "a detached HEAD names the pull request as not read" "not read: pull request, HEAD is detached" "$(run "$tea_repo")"
check "an extra argument is read as a ticket key" "ticket QQ-1" "$(run "$tea_repo" QQ-1)"

bare=$(repo bare git@forge.example:o/s.git)
mkdir -p "$dir/nobin"; for t in bash git jq sed grep awk sort dirname basename timeout ls cat; do ln -s "$(command -v "$t")" "$dir/nobin/$t"; done
out=$(cd "$bare" && PATH="$dir/nobin" FIND_HANDOFF_PROJECTS_DIR="$dir/projects" bash "$finder" 2>&1)
check "with neither gh nor tea it names the pull request as not read" "not read: pull request, neither gh nor tea is installed" "$out"
skill=$(cat "$root/plugins/vicky-skills/skills/productivity/sup/SKILL.md")
check "sup step 1 runs the finder" "scripts/find-handoff.sh" "$skill"
check "sup quotes where it looked when no handoff is found" "quotes the script's \`none found in:\` and \`not read:\` lines" "$skill"
check "conn names /sup as the one resume command" "Name \`/sup\` as the only command that resumes the work" "$(cat "$root/plugins/vicky-skills/skills/productivity/conn/SKILL.md")"
exit $fail
