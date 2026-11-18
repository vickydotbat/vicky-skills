#!/usr/bin/env bash
# AGENTS.md is the one development path: each section ends its steps in
# "Done when", and the path names the commands that prove each step.
set -u
cd "$(dirname "$0")/.."
fail=0
chk() { grep -qF -- "$2" AGENTS.md || { echo "FAIL $1: AGENTS.md lacks: $2"; fail=1; }; }
for h in "## Add a skill" "## Change a skill" "## Add or change a hook" "## Before every push" "## Evals" "## Pull request"; do chk "section" "$h"; done
for sec in "Add a skill" "Change a skill" "Add or change a hook" "Before every push" "Evals" "Pull request"; do
  n=$(awk -v s="## $sec" '$0==s{f=1;next} /^## /{f=0} f&&/^[0-9]+\. /' AGENTS.md | grep -vc "Done when")
  [ "$n" -eq 0 ] || { echo "FAIL $sec: $n numbered step(s) without Done when"; fail=1; }
done
[ $fail -eq 0 ] && echo "ok   agents-doc: AGENTS.md is one path with a Done when per step"
exit $fail
