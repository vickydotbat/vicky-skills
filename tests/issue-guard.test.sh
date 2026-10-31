#!/usr/bin/env bash
# issue-guard refuses a body-only issue read, passes the rest, and is off by default.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/issue-guard.sh"
fail=0
check() { # want command [option]
  jq -n --arg c "$2" '{tool_input:{command:$c}}' | CLAUDE_PLUGIN_OPTION_GUARD_ISSUE_THREADS="${3-true}" "$hook" >/dev/null 2>&1; got=$?
  if [ "$got" = "$1" ]; then echo "ok   $2 -> $1"; else echo "FAIL $2: got $got, want $1"; fail=1; fi
}
allow() { check 0 "$1"; }
refuse() { check 2 "$1"; }
allow 'gh pr view 13 --json state'
allow 'gh pr view 13 --json state,title,mergedAt'
allow 'gh issue view 12 --json=number,labels'
refuse 'gh pr view 13 --json state,body'
refuse 'gh issue view 12 --json body'
refuse 'gh pr view 13 --json title,reviews'
refuse 'gh pr view 13 --json latestReviews,state'
refuse 'gh issue view 12'
refuse 'gh pr view 12'
refuse 'gh issue view 12 --repo owner/name'
refuse 'cd /tmp && gh issue view 12'
refuse 'tea issues 12'
refuse 'tea i 7'
refuse 'tea pulls 3'
refuse 'tea pr 3'
allow 'gh issue view 12 --comments'
allow 'gh pr view 12 -c'
allow 'gh issue view 12 --json title,body,comments'
allow 'gh issue view 12 --web'
allow "cat > notes.md <<'EOF'
Read a thread with gh issue view 12, never the body alone
EOF"
allow "grep -n 'gh issue view 12' notes.md"
allow 'echo "tea issues 12" >> notes.md'
refuse "cat > notes.md <<'EOF'
text
EOF
gh issue view 12"
allow 'tea issues 12 --comments'
allow 'tea pulls 3 --comments'
allow 'gh issue list'
allow 'gh pr list --state open'
allow 'gh issue create --title x --body y'
allow 'tea issues list'
allow 'tea issues create --title x'
allow 'gh api repos/owner/name/issues/12'
allow 'git status'
check 0 'gh issue view 12' ""
check 0 'gh issue view 12' false
check 2 'gh issue view 12' 1
exit $fail
