#!/usr/bin/env bash
# Every hook exits 0 and prints nothing to stdout when it has nothing to say:
# with its setting off, with jq, git or gawk missing, on input it doesn't
# handle, and outside a repository. Claude Code shows a non-zero exit as a
# hook error, so a quiet hook must also exit 0.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q -b main "$dir/repo"
mkdir -p "$dir/plain" "$dir/data" "$dir/bare"
# A PATH with the basic tools and none of jq, git or gawk.
for tool in bash sh cat grep sed awk tr head tail cut date mkdir mv rm dirname basename wc printf env id sort uniq timeout ls touch; do
  path=$(command -v "$tool") && ln -s "$path" "$dir/bare/$tool"
done
[ -e "$dir/bare/awk" ] && [ "$(readlink -f "$dir/bare/awk")" = "$(readlink -f "$(command -v gawk 2>/dev/null)")" ] && rm "$dir/bare/awk"
fail=0
# Every setting on, so each hook gets past its first gate.
on=(CLAUDE_PLUGIN_OPTION_GUARD_PR=true CLAUDE_PLUGIN_OPTION_GUARD_ISSUE_THREADS=true CLAUDE_PLUGIN_OPTION_GUARD_TEA_STDIN=true
  CLAUDE_PLUGIN_OPTION_GUARD_LOCAL_PATHS=true CLAUDE_PLUGIN_OPTION_GUARD_PUSH_BEHIND=true CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true
  CLAUDE_PLUGIN_OPTION_GUARD_RED_FIRST=true CLAUDE_PLUGIN_OPTION_GUARD_DRAFT_LOCK=true CLAUDE_PLUGIN_OPTION_SKILL_LEDGER=true
  CLAUDE_PLUGIN_OPTION_AUTO_TIDY=true CLAUDE_PLUGIN_OPTION_GATE_NOTIFY=true CLAUDE_PLUGIN_OPTION_STEP_GUARD=true
  CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=true CLAUDE_PLUGIN_OPTION_GUARD_MUTATION_PROOF=true CLAUDE_PLUGIN_OPTION_GUARD_PLANE_BLOCK=true CLAUDE_PLUGIN_DATA="$dir/data" HOME="$dir")
# quiet <name> <script> <stdin> [env...]: the hook exits 0 and stdout stays empty.
quiet() {
  local name=$1 script=$2 input=$3; shift 3
  out=$(cd "$dir/plain" && env "$@" bash "$scripts/$script" <<<"$input" 2>/dev/null); code=$?
  if [ $code = 0 ] && [ -z "$out" ]; then echo "ok   $script: $name"; else echo "FAIL $script: $name: exit $code, stdout '$out'"; fail=1; fi
}
bash_in() { jq -n --arg c "$1" --arg d "${2:-$dir/repo}" '{session_id: "s1", hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}, cwd: $d}'; }
edit_in() { jq -n --arg f "$1" --arg d "$dir/repo" '{session_id: "s1", hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $f}, cwd: $d}'; }

for script in $(cd "$scripts" && ls *.sh); do
  [ "$script" = git-hook-lib.sh ] || [ "$script" = red-first-check.sh ] || [ "$script" = watch.sh ] || [ "$script" = lesson-ledger.sh ] && continue
  quiet "setting off, unknown input" "$script" '{}'
  quiet "jq, git and gawk missing" "$script" "$(bash_in 'git push origin x; tea pr list')" "${on[@]}" PATH="$dir/bare"
  quiet "a command it doesn't handle" "$script" "$(bash_in 'ls -la')" "${on[@]}"
  quiet "a git command outside a repository" "$script" "$(bash_in 'git status' "$dir/plain")" "${on[@]}"
  quiet "an edit to a plain file" "$script" "$(edit_in "$dir/repo/notes.txt")" "${on[@]}"
  quiet "input that isn't JSON" "$script" 'not json' "${on[@]}"
done
for script in gamma-shift.sh spark-joy.sh ticket-drift.sh auto-tidy.sh; do
  quiet "a session start with nothing due" "$script" '{"hook_event_name": "SessionStart"}' "${on[@]}" CLAUDE_PROJECT_DIR="$dir/plain" \
    CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT=off CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS=0 CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS=0
done
for days in '' x -1 0; do
  quiet "days set to '$days'" spark-joy.sh '{}' CLAUDE_PLUGIN_OPTION_DEEPEN_EVERY_DAYS="$days" CLAUDE_PROJECT_DIR="$dir/repo"
  quiet "days set to '$days'" ticket-drift.sh '{}' CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS="$days" CLAUDE_PROJECT_DIR="$dir/repo"
done
quiet "a session end" checkout-guard.sh '{"session_id": "s1", "hook_event_name": "SessionEnd"}' "${on[@]}"
quiet "a git command after it ran" checkout-guard.sh "$(bash_in 'git status' | jq '.hook_event_name = "PostToolUse"')" "${on[@]}"
quiet "no session id" checkout-guard.sh "$(bash_in 'git switch x' | jq 'del(.session_id)')" "${on[@]}"
quiet "no data folder" checkout-guard.sh "$(bash_in 'git switch x')" "${on[@]}" CLAUDE_PLUGIN_DATA=
quiet "a cwd that is gone" draft-lock.sh "$(bash_in 'echo x > f' "$dir/gone")" "${on[@]}"
quiet "a stale lock" draft-lock.sh "$(edit_in "$dir/repo/f")" "${on[@]}" \
  && { printf '999999\nd.md\n' > "$dir/repo/.git/red-pen-open"; quiet "a lock whose editor exited" draft-lock.sh "$(edit_in "$dir/repo/f")" "${on[@]}"; \
       printf 'x\nd.md\n' > "$dir/repo/.git/red-pen-open"; quiet "a lock with no process id" draft-lock.sh "$(edit_in "$dir/repo/f")" "${on[@]}"; rm -f "$dir/repo/.git/red-pen-open"; }

# speaks <name> <script> <stdin> [env...]: a hook with something to say still exits 0.
speaks() {
  local name=$1 script=$2 input=$3; shift 3
  out=$(cd "$dir/plain" && env "$@" bash "$scripts/$script" <<<"$input" 2>&1); code=$?
  if [ $code = 0 ] && [ -n "$out" ]; then echo "ok   $script: $name"; else echo "FAIL $script: $name: exit $code, output '$out'"; fail=1; fi
}
for hook in spark-joy:DEEPEN ticket-drift:DRIFT; do
  script=${hook%%:*}.sh; var=CLAUDE_PLUGIN_OPTION_${hook#*:}_EVERY_DAYS
  quiet "a project folder that is gone" "$script" '{}' "$var=3" CLAUDE_PROJECT_DIR="$dir/gone"
  quiet "a project folder outside a repository" "$script" '{}' "$var=3" CLAUDE_PROJECT_DIR="$dir/plain"
  rm -f "$dir/repo/.git/"*-last
  speaks "a run that is due" "$script" '{}' "$var=3" CLAUDE_PROJECT_DIR="$dir/repo"
  quiet "a run that just happened" "$script" '{}' "$var=3" CLAUDE_PROJECT_DIR="$dir/repo"
done
mkdir -p "$dir/repo/docs/agents"; printf 'Ticket drift: off\n' > "$dir/repo/docs/agents/issue-tracker.md"; rm -f "$dir/repo/.git/"*-last
quiet "a repo that turned it off" ticket-drift.sh '{}' CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS=3 CLAUDE_PROJECT_DIR="$dir/repo"
rm -rf "$dir/repo/docs"

quiet "a project folder that is gone" auto-tidy.sh '{}' CLAUDE_PLUGIN_OPTION_AUTO_TIDY=true CLAUDE_PROJECT_DIR="$dir/gone"
quiet "a repo with nothing gone" auto-tidy.sh '{}' CLAUDE_PLUGIN_OPTION_AUTO_TIDY=true CLAUDE_PROJECT_DIR="$dir/repo"
git init -q --bare "$dir/remote.git"; git clone -q "$dir/remote.git" "$dir/clone" 2>/dev/null
git -C "$dir/clone" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
git -C "$dir/clone" push -q -u origin HEAD:merged 2>/dev/null; git -C "$dir/clone" branch -q --set-upstream-to=origin/merged
git -C "$dir/remote.git" branch -q -D merged
speaks "a branch whose upstream is gone" auto-tidy.sh '{}' CLAUDE_PLUGIN_OPTION_AUTO_TIDY=true CLAUDE_PROJECT_DIR="$dir/clone"

mkdir -p "$dir/plain/tests"; printf 'x\n' > "$dir/plain/tests/a_approved_examples.test.sh"
head -c 1100000 /dev/zero | tr '\0' 'x' > "$dir/plain/big.py"; printf '\nopen("tests/a_approved_examples.test.sh", "w")\n' >> "$dir/plain/big.py"
quiet "reading an approved test" approved-spec-guard.sh "$(bash_in 'cat tests/a_approved_examples.test.sh' "$dir/plain")"
quiet "a script over 1 MB is not read" approved-spec-guard.sh "$(bash_in 'python3 big.py' "$dir/plain")"
quiet "a copy, with a target variable in the environment" approved-spec-guard.sh "$(bash_in 'cp a b' "$dir/plain")" target=tests/a_approved_examples.test.sh
out=$(edit_in "$dir/plain/tests/a_approved_examples.test.sh" | bash "$scripts/approved-spec-guard.sh"); code=$?
if [ $code = 0 ] && [ "$(jq -s length <<<"$out")" = 1 ]; then echo "ok   approved-spec-guard.sh: an ask exits 0 with one answer"; else echo "FAIL approved-spec-guard.sh: an ask: exit $code, '$out'"; fail=1; fi
quiet "a write outside any repository" draft-lock.sh "$(bash_in 'echo x > f' "$dir/plain")" "${on[@]}"
out=$(bash_in "sed -i s/x/y/ tests/a_approved_examples.test.sh; python3 -c pass" "$dir/plain" | bash "$scripts/approved-spec-guard.sh"); code=$?
if [ $code = 0 ] && [ "$(jq -s length <<<"$out")" = 1 ]; then echo "ok   approved-spec-guard.sh: a shell write it asks about gets one answer"; else echo "FAIL approved-spec-guard.sh: a shell ask: exit $code, '$out'"; fail=1; fi
# jq on the PATH, with git or gawk missing.
mkdir -p "$dir/jq-only"; cp -P "$dir/bare/"* "$dir/jq-only/"; ln -s "$(command -v jq)" "$dir/jq-only/jq"
for script in draft-lock.sh tea-stdin.sh local-path-guard.sh checkout-guard.sh; do
  quiet "jq here, git and gawk missing" "$script" "$(bash_in 'git push origin x > f; tea pr list')" "${on[@]}" PATH="$dir/jq-only"
done
for script in local-path-guard.sh push-behind-guard.sh red-first-guard.sh checkout-guard.sh; do
  quiet "a cwd that is gone" "$script" "$(bash_in 'git commit -m x; git push' "$dir/gone")" "${on[@]}"
  quiet "a cd to a folder that is gone" "$script" "$(bash_in "cd $dir/gone && git push origin x")" "${on[@]}"
  quiet "a git command that changes nothing" "$script" "$(bash_in 'git status')" "${on[@]}"
done
out=$(bash_in 'git push' "$dir/clone" | env "${on[@]}" bash "$scripts/push-behind-guard.sh" 2>&1); code=$?
if [ $code = 0 ] && [ -z "$out" ]; then echo "ok   push-behind-guard.sh: a repo with no origin says nothing"; else echo "FAIL push-behind-guard.sh: no origin: exit $code, '$out'"; fail=1; fi
printf 'see %s/notes\n' "$dir" > "$dir/repo/leak.txt"; git -C "$dir/repo" add leak.txt
quiet "a git command that is no commit, with a local path staged" local-path-guard.sh "$(bash_in 'git status')" "${on[@]}"
git -C "$dir/repo" rm -q --cached leak.txt; rm "$dir/repo/leak.txt"
exit $fail
