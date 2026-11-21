#!/usr/bin/env bash
# A moderation list where hiding a post can be undone.
set -eu
git init -q -b main .
mkdir -p tickets
printf -- "---\nkind: star\n---\n# Hide posts from the moderation list\n\nThe moderation page lists reported forum posts, newest first. Each row gets a Hide action. A hidden post disappears from the forum for players, and a moderator can unhide it later from the same list.\n\n## Comments\n" > tickets/3-hide-posts.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
