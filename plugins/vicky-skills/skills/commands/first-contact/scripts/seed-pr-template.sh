#!/usr/bin/env bash
# seed-pr-template.sh <repo>: writes ship-it's seeded pull request template
# into a repo that has none, in its forge's place: .github/pull_request_template.md
# for GitHub, .gitea/PULL_REQUEST_TEMPLATE.md for any other remote. A repo that
# already holds a template at any place a forge reads one keeps it, and a repo
# whose docs/agents/issue-tracker.md says "Seed PR template: off" gets nothing.
# Prints the path it wrote, or why it wrote nothing.
set -eu
repo=${1:?usage: seed-pr-template.sh <repo>}
template="$(cd "$(dirname "$0")/../../../shipping/ship-it" && pwd)/SEEDED-TEMPLATE.md"
if grep -qix 'Seed PR template:[[:space:]]*off' "$repo/docs/agents/issue-tracker.md" 2>/dev/null; then
  echo "seed-pr-template: off in docs/agents/issue-tracker.md, so no template written"; exit 0
fi
found=$(find "$repo" -maxdepth 2 -path "$repo/.git" -prune -o -type f -iname pull_request_template.md -print | head -n 1)
if [ -n "$found" ]; then
  echo "seed-pr-template: the repo keeps its own template at ${found#"$repo"/}"; exit 0
fi
case "$(git -C "$repo" remote get-url origin 2>/dev/null)" in
  *github.com[:/]*) dest=.github/pull_request_template.md ;;
  *) dest=.gitea/PULL_REQUEST_TEMPLATE.md ;;
esac
mkdir -p "$repo/$(dirname "$dest")"
cp "$template" "$repo/$dest"
echo "$dest"
