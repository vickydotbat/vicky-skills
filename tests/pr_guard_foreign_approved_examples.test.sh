#!/usr/bin/env bash
# approved-spec: pr-guard defers to a foreign repository's own template.
# A stub gh answers who administers each repository.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pr-guard.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin" "$scratch/home" "$scratch/repo/docs/agents"
export HOME="$scratch/home" CLAUDE_PLUGIN_DATA="$scratch/data"
git -C "$scratch/repo" init -q
printf 'PR template: on\n' >"$scratch/repo/docs/agents/issue-tracker.md"
cat >"$scratch/bin/gh" <<'GH'
#!/usr/bin/env bash
[ "$1 $2" = "repo view" ] || exit 1
[ "${FAIL:-}" = all ] && exit 1
case "${3:-}" in
  --json) echo '{"viewerPermission":"ADMIN","isFork":'"${FORK:-false}"',"parent":{"nameWithOwner":"'"${PARENT:-me/up}"'"}}' ;;
  me/*) echo '{"viewerPermission":"ADMIN","isFork":false,"parent":null}' ;;
  *) echo '{"viewerPermission":"READ","isFork":false,"parent":null}' ;;
esac
GH
chmod +x "$scratch/bin/gh"
printf '## What\n\nTheir template.\n' >"$scratch/theirs.md"
printf '## Summary\n\nx\n\n## Proof\n\nx\n\n## Risk\n\nx\n' >"$scratch/nostatus.md"
printf '## What\n\nx\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' >"$scratch/credit.md"
fail=0
run() { # command [env]
  jq -nc --arg c "$1" --arg d "$scratch/repo" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, session_id: "s", tool_input: {command: $c}}' |
    env PATH="$scratch/bin:$PATH" ${2:-X=1} bash "$hook" 2>"$scratch/err" >/dev/null
  echo $?
}
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: exit $2, want $3"; cat "$scratch/err"; fail=1; fi; }

# A foreign repo's own template passes
check "a foreign repo's own template passes" "$(run "gh pr create -R stranger/up -t T --body-file $scratch/theirs.md")" 0
check "a foreign repo's body edit passes" "$(run "gh pr edit 3 -R stranger/up --body-file $scratch/theirs.md")" 0

# AI credit is still refused there
check "AI credit is still refused there" "$(run "gh pr create -R stranger/up -t T --body-file $scratch/credit.md")" 2

# The user's own repo keeps the template
check "the user's own repo keeps the template" "$(run "gh pr create -R me/mine -t T --body-file $scratch/nostatus.md")" 2
grep -q '## Status' "$scratch/err" || { echo "FAIL the refusal names the missing section"; fail=1; }

# A forge that can't answer keeps the template
check "a forge that can't answer keeps the template" "$(run "gh pr create -R stranger/up -t T --body-file $scratch/theirs.md" FAIL=all)" 2

# The target with no -R is the checkout, or its parent when it is a fork
check "a fork of a foreign repo keeps that repo's template" "$(run "gh pr create -t T --body-file $scratch/theirs.md" "FORK=true PARENT=stranger/up")" 0
check "a fork of the user's own repo keeps the user's template" "$(run "gh pr create -t T --body-file $scratch/theirs.md" "FORK=true PARENT=me/up")" 2
check "the user's own checkout keeps the user's template" "$(run "gh pr create -t T --body-file $scratch/theirs.md")" 2
exit $fail
