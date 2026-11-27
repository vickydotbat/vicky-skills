#!/usr/bin/env bash
# A repo whose tracker file is first-contact's Backlog.md template, and a
# backlog beside it with one task never edited since it was filed and one
# edited after. A task nobody edited has no updatedAt.
set -eu
template="$(cd "$(dirname "$0")/../../.." && pwd)/skills/commands/first-contact/issue-tracker-backlog.md"
git init -q -b main .
git remote add origin https://example.invalid/acme/widget.git
printf '# Widget\n' > README.md
# The eval sandbox's PATH holds $HOME/.nix-profile/bin under the eval's own
# HOME. Link the backlog binary there, and never into a real home.
case "$HOME" in */claude-eval-*/home) ;; *) echo "scaffold: HOME is not an eval home" >&2; exit 1 ;; esac
mkdir -p "$HOME/.nix-profile/bin"
ln -sf "$(readlink -f "$(command -v backlog)")" "$HOME/.nix-profile/bin/backlog"
folder="$(cd .. && pwd)/widget-backlog"
mkdir -p docs/agents "$folder"
sed "s|<folder>|$folder|g" "$template" > docs/agents/issue-tracker.md
(cd "$folder" && backlog init Widget --no-git --defaults >/dev/null)
sed -i -e 's/^default_status: .*/default_status: "Open"/' -e 's/^statuses: .*/statuses: ["Open", "Claimed", "Waiting", "Done"]/' "$folder/backlog/config.yml"
export BACKLOG_CWD="$folder"
backlog task create "Fresh idea" -l task --plain >/dev/null
backlog task create "Edited idea" -l task --plain >/dev/null
backlog task edit TASK-2 --comment "looked at it" --comment-author eval >/dev/null
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
