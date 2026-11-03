#!/usr/bin/env bash
# approved-spec: the pull request body examples Vicky approved on 2026-11-03:
# a body that opens or replaces a pull request holds ship-it's sections. Each
# check runs pr-guard the way Claude Code does, with stand-in forges that list
# no open pull request.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pr-guard.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin" "$scratch/data"
printf '#!/usr/bin/env bash\n[ "$1 $2" = "pr list" ] && echo "[]"\n' >"$scratch/bin/gh"
printf '#!/usr/bin/env bash\ncase "$1 $2" in "api user") echo %s ;; "pulls list") echo "[]" ;; *) exit 1 ;; esac\n' "'{\"login\":\"me\"}'" >"$scratch/bin/tea"
chmod +x "$scratch/bin/gh" "$scratch/bin/tea"
export PATH="$scratch/bin:$PATH" HOME="$scratch/home" CLAUDE_PLUGIN_DATA="$scratch/data" CLAUDE_PLUGIN_OPTION_GUARD_PR=true
unset CLAUDE_CONFIG_DIR
for forge in hub gitea off; do
  git init -q -b main "$scratch/$forge"
  git -C "$scratch/$forge" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init
  git -C "$scratch/$forge" switch -q -c feat/one
done
git -C "$scratch/hub" remote add origin https://github.com/o/r.git
git -C "$scratch/off" remote add origin https://github.com/o/r.git
git -C "$scratch/gitea" remote add origin https://forge.example/o/r.git
mkdir -p "$scratch/off/docs/agents"
printf '# Tickets\n\nPR template: off\n' >"$scratch/off/docs/agents/issue-tracker.md"
printf '## Status\n\n`Done:` x\n\n## Summary\n\nx\n\n## Proof\n\n- Tests: x\n\n## Risk\n\n- Undo: a revert\n' >"$scratch/full.md"
printf '## Status\n\n`Done:` x\n\n## Proof\n\n- Tests: x\n' >"$scratch/thin.md"
fail=0
# Prints the exit status, then everything the hook said.
run() {
  local out status
  out=$(jq -nc --arg c "$2" --arg d "$scratch/$1" \
    '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, session_id: "s1", tool_input: {command: $c}}' | bash "$hook" 2>&1)
  status=$?
  printf '%s\n%s' "$status" "$out"
}
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a session opening or editing a pull request
# When its body has no Summary, Proof, Risk or Status section
# Then the command is refused, names each missing section, and says to write the body with ship-it
create=$(run hub "gh pr create --draft --title x --body-file $scratch/thin.md")
edit=$(run hub "gh pr edit 7 --body-file $scratch/thin.md")
inline=$(run hub "gh pr create --title x --body 'Fixes it.'")
check "a body missing a section is refused" \
  '[ "$(head -1 <<<"$create")" = 2 ] && grep -q "Summary" <<<"$create" && grep -q "Risk" <<<"$create" && ! grep -q "Proof" <<<"$create" && grep -q "ship-it" <<<"$create" && [ "$(head -1 <<<"$edit")" = 2 ] && [ "$(head -1 <<<"$inline")" = 2 ]'

# Given a body with Status, Summary, Proof and Risk sections
# When the session opens or edits a pull request with it
# Then the command runs
check "a body in the template goes through" \
  '[ "$(run hub "gh pr create --draft --title x --body-file $scratch/full.md" | head -1)" = 0 ] && [ "$(run hub "gh pr edit 7 --body-file $scratch/full.md" | head -1)" = 0 ]'

# Given a session that changes only a pull request's title, labels or reviewers
# When it runs the edit with no body
# Then the command runs
check "an edit that leaves the body alone goes through" \
  '[ "$(run hub "gh pr edit 7 --title y --add-label stacked --add-reviewer me" | head -1)" = 0 ]'

# Given a session opening a pull request
# When it fills the body from its commits instead of writing one
# Then the command is refused and says to write the body with ship-it
fill=$(run hub "gh pr create --fill")
check "a body filled from the commits is refused" '[ "$(head -1 <<<"$fill")" = 2 ] && grep -q "ship-it" <<<"$fill"'

# Given a repo whose docs/agents/issue-tracker.md says PR template: off
# When a session opens a pull request with any body
# Then the command runs
check "a repo can switch the check off" \
  '[ "$(run off "gh pr create --title x --body-file $scratch/thin.md" | head -1)" = 0 ] && [ "$(run off "gh pr create --fill" | head -1)" = 0 ]'

# Given a Gitea repo
# When tea opens a pull request whose description is missing a section
# Then it is refused the same way
tea=$(run gitea "tea pr create --title x --description 'Fixes it.' </dev/null")
check "Gitea gets the same check" '[ "$(head -1 <<<"$tea")" = 2 ] && grep -q "Summary" <<<"$tea" && grep -q "ship-it" <<<"$tea"'
exit $fail
