#!/usr/bin/env bash
# A repo on Plane whose branch fixes WEB-200; the fix goes live only with a release.
set -eu
git init -q -b main .
mkdir -p docs/agents
cat > docs/agents/issue-tracker.md <<'EOF'
# Issue tracker: Plane

| Operation | How |
| --- | --- |
| Read, whole (body, comments, relations) | `plane show <key>` |
| Close | `plane close <key>` |
| Move to a named state | `plane state <key> <state>` |

## Waiting work

- **Park a ticket**: `plane claim <ref> <user_id>` for the person it waits on,
  `plane state <ref> Todo`, then `plane edit` to add a `Waits on: <who or
  what>` line to the body.
EOF
printf '# Wiki server\n' > README.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c web-200-antigravity
printf 'antigravity.google\n' > allowed-hosts.txt
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Allow Antigravity on the wiki server (WEB-200)"
