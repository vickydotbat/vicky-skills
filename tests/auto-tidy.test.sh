#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# shellcheck disable=SC2329 # helpers are called inside check()'s eval
# auto-tidy's switches and triggers: which settings turn it off, which tool
# calls start it, and that it stays silent where it has nothing to do.
set -u
# shellcheck source=lib/auto-tidy-fixture.sh
. "$(dirname "$0")/lib/auto-tidy-fixture.sh"
merged_repo() { setup; branch feat; merge feat; on_main; }
after() { jq -nc --arg c "$1" --arg d "$dir/repo" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}, cwd: $d}'; }

for v in false 0; do
  merged_repo; out=$(OPT=$v run)
  check "auto_tidy=$v leaves the branch and says nothing" 'has_local feat && [ -z "$out" ]'
done
for v in true 1 ""; do
  merged_repo; OPT=$v run >/dev/null
  check "auto_tidy='$v' tidies" '! has_local feat'
done

for c in 'gh pr merge 1 --squash' 'cd sub && tea pr merge 2' 'tea pulls merge 3'; do
  merged_repo; run "$dir/repo" "$(after "$c")" >/dev/null
  check "after '$c' it tidies" '! has_local feat'
done
for c in 'git status' 'gh pr view 1' 'echo gh pr merged' 'ghx pr merge 1'; do
  merged_repo; out=$(run "$dir/repo" "$(after "$c")")
  check "after '$c' it does nothing" 'has_local feat && [ -z "$out" ]'
done

mkdir -p "$dir/plain"
out=$(run "$dir/plain"); check "outside a repo it says nothing" '[ -z "$out" ]'
out=$(run "$dir/gone"); check "in a folder that is gone it says nothing" '[ -z "$out" ]'

# A report that holds a quote or a backslash still reaches you as JSON.
setup; branch 'q"b'; merge 'q"b'; on_main; echo x > "$dir/repo/back\\slash.txt"
git -C "$dir/repo" switch -q -c sticky origin/main; echo "sticky MERGED $(git -C "$dir/repo" rev-parse sticky)" >> "$dir/prs"
out=$(run); check "a quote and a backslash in the report stay valid JSON" 'jq -e . <<<"$out" >/dev/null && seen "$out" | grep -qF "q\"b" && seen "$out" | grep -qF "slash.txt"'

# Without jq the forge goes unread, and a gone upstream whose work landed still counts.
mkdir -p "$dir/nojq"; for t in git bash timeout grep awk sed cut tr cat dirname sort readlink mktemp sleep; do ln -sf "$(command -v "$t")" "$dir/nojq/$t"; done
setup; branch feat; merge feat; on_main
out=$(PATH="$dir/nojq" CLAUDE_PROJECT_DIR="$dir/repo" "$dir/nojq/bash" "$hook" <<<'{"hook_event_name": "SessionStart"}')
check "without jq a landed branch still goes, and the agent hears nothing" '! has_local feat && agent_silent "$out"'

# Exit status 0 on every quiet path, so Claude Code never reports a hook error.
st() { "$@" >/dev/null; echo $?; }
merged_repo
check "switched off, the hook exits 0" '[ "$(OPT=false st run)" = 0 ]'
check "after a command that merged nothing, the hook exits 0" '[ "$(st run "$dir/repo" "$(after "git status")")" = 0 ]'
check "with nothing to tidy, the hook exits 0" '[ "$(st run)" = 0 ] && [ "$(st run)" = 0 ]'

# Only the forge knows: main moved before a two-commit squash, so no tree or patch matches.
for forge in gh tea; do
  FORGE=$forge; setup; branch feat; second feat; main_moves; merge feat keep; on_main
  out=$(run)
  check "with $forge, a branch only the forge knows merged goes, and you see it named" '! has_local feat && ! has_remote feat && seen "$out" | grep -q "Gone: feat, origin/feat"'
  setup; branch feat; second feat; main_moves; merge feat; on_main
  run >/dev/null
  check "with $forge, a branch only the forge knows merged goes after the forge deleted its remote" '! has_local feat'
  setup; branch feat; echo "feat OPEN $(git -C "$dir/repo" rev-parse feat)" > "$dir/prs"
  git clone -q "$dir/origin.git" "$dir/other" 2>/dev/null; git -C "$dir/other" cherry-pick -x origin/feat >/dev/null; git -C "$dir/other" push -q origin main 2>/dev/null; rm -rf "$dir/other"; on_main
  run >/dev/null
  check "with $forge, an open pull request's branch stays, even when main holds its work" 'has_local feat'
done
FORGE=gh

# With no forge, a squash whose upstream is gone still counts once main holds its last tree.
setup; branch feat; second feat; merge feat; rm -f "$dir/prs"; on_main
run >/dev/null
check "without a forge, a landed two-commit squash goes" '! has_local feat'
setup; branch feat; second feat; merge feat keep; rm -f "$dir/prs"; on_main; git -C "$dir/repo" branch -q -D feat
out=$(run)
check "without a pull request, your landed remote branch goes" '! has_remote feat && seen "$out" | grep -q "origin/feat"'

setup; branch feat; rm -f "$dir/prs"; on_main; git -C "$dir/repo" branch -q -D feat
run >/dev/null
check "without a pull request, your remote branch whose work never landed stays" 'has_remote feat'

setup; branch feat; merge feat keep; git -C "$dir/repo" switch -q feat; echo late > "$dir/repo/late.txt"; git -C "$dir/repo" add late.txt; git -C "$dir/repo" commit -q -m late
git -C "$dir/repo" push -q origin feat 2>/dev/null; on_main; git -C "$dir/repo" branch -q -D feat
run >/dev/null
check "a remote branch pushed to after its merge stays" 'has_remote feat'

setup; branch feat; merge feat; git -C "$dir/repo" switch -q feat; echo more > "$dir/repo/more.txt"; git -C "$dir/repo" add more.txt; git -C "$dir/repo" commit -q -m more; on_main
out=$(run)
check "a merged branch with later commits is named as kept" 'has_local feat && seen "$out" | grep -q "feat (commits made after the merge)"'

setup; branch feat; worktree feat; merge feat; on_main; git -C "$dir/repo" worktree lock "$dir/wt-feat"
out=$(run)
check "a locked worktree stays, and you see why" '[ -d "$dir/wt-feat" ] && seen "$out" | grep -q "locked worktree"'

setup; branch feat; worktree feat; merge feat; on_main
mkdir -p "$dir/repo/docs/agents" "$dir/repo/scripts"; printf 'Drop worktree: scripts/drop.sh\n' > "$dir/repo/docs/agents/testing.md"
printf '#!/usr/bin/env bash\nexit 1\n' > "$dir/repo/scripts/drop.sh"; chmod +x "$dir/repo/scripts/drop.sh"
out=$(run)
check "a worktree the removal script leaves keeps its branch" '[ -d "$dir/wt-feat" ] && has_local feat && seen "$out" | grep -q "would not come off"'

setup; git -C "$dir/repo" worktree add -q -b side "$dir/wt-side" origin/main 2>/dev/null; main_moves; on_main; git -C "$dir/repo" fetch -q origin; before=$(git -C "$dir/wt-side" rev-parse HEAD)
run >/dev/null
check "a worktree on another branch is never fast-forwarded" '[ "$(git -C "$dir/wt-side" rev-parse HEAD)" = "$before" ]'

setup; on_main; main_moves
out=$(run)
check "a caught-up main is named" 'seen "$out" | grep -q "caught up with origin/main"'

setup; branch feat; merge feat; git -C "$dir/repo" fetch -q origin; git -C "$dir/repo" branch -q -f main origin/main~1; git -C "$dir/repo" switch -q feat
run >/dev/null
check "a clone handed back to a stale local main stands on origin's main" '[ "$(git -C "$dir/repo" symbolic-ref --short HEAD)" = main ] && [ "$(git -C "$dir/repo" rev-parse main)" = "$(git -C "$dir/repo" rev-parse origin/main)" ]'

# The tidy line names a detached worktree and a leftover folder it removed.
gdoc() { mkdir -p "$dir/repo/docs/agents" "$dir/repo/scripts"; printf 'Drop worktree: scripts/drop.sh\n' > "$dir/repo/docs/agents/testing.md"; printf '#!/usr/bin/env bash\ngit worktree remove --force "$1" 2>/dev/null || rm -rf "$1"\n' > "$dir/repo/scripts/drop.sh"; chmod +x "$dir/repo/scripts/drop.sh"; }
setup; on_main; git -C "$dir/repo" worktree add -q --detach "$dir/wt-d" origin/main 2>/dev/null; main_moves
out=$(run)
check "a removed detached worktree is named" 'seen "$out" | grep -q "detached worktree wt-d"'
setup; on_main; gdoc; mkdir -p "$dir/repo/.claude/worktrees/old"
out=$(run)
check "a removed leftover folder is named" 'seen "$out" | grep -q "leftover folder old"'
setup; on_main; gdoc; mkdir -p "$dir/repo/.claude/worktrees"
out=$(run)
check "an empty worktrees folder says nothing" '[ -z "$out" ]'
# A removal script that forces would take a dirty detached worktree, so the tidy checks first.
setup; on_main; gdoc; git -C "$dir/repo" worktree add -q --detach "$dir/wt-d" origin/main 2>/dev/null; main_moves; echo half > "$dir/wt-d/notes.txt"
run >/dev/null
check "a forcing removal script never gets a dirty detached worktree" '[ -f "$dir/wt-d/notes.txt" ]'
# The clone itself, detached on a commit main holds, is never handed to the removal script.
setup; gdoc; git -C "$dir/repo" switch -q --detach origin/main; main_moves
run >/dev/null
check "a detached clone stays" '[ -d "$dir/repo/.git" ]'

exit "$fail"
