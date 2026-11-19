#!/usr/bin/env bash
# review.sh [base]: the security review of the branch since <base> (origin's
# default branch when left out). /security-review ships with Claude Code, so
# with fp-check installed the review goes to those two and the kit adds none
# of its own. Without fp-check, the kit runs each security rule's proving run
# on the branch, through levels.sh, and reports only what a run showed.
set -u
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=kit.sh
. "$here/kit.sh"
base=${1:-$(git -C "$top" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo main)}
if fp_installed; then
  echo "review: run /security-review on this branch, then check each finding it reports with fp-check. The kit adds no review of its own."
  exit 0
fi
echo "review: fp-check is not installed, so the kit runs each security rule's own run on the branch since $base."
SECURITY_SINCE=$base exec bash "$here/levels.sh"
