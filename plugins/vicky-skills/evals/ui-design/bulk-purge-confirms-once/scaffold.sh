#!/usr/bin/env bash
# A bulk purge that cannot be undone.
set -eu
git init -q -b main .
mkdir -p tickets data
printf -- '---
kind: star
---
# Purge spam posts

The moderation page lists reported forum posts. A moderator ticks the spam posts, often a hundred or more, and presses Purge. A purged post is deleted for good, with no backup.

## Comments
' > tickets/4-page.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
