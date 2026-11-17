#!/usr/bin/env bash
# approved-spec: machine-spirit proves a CI change with a local run of the
# whole job first, and stops after one try when the machine cannot run it.
# Each check is named after its example, and pins step 5 of the skill. The
# eval case machine-spirit/no-local-runner carries the behaviour proof.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
s="$root/skills/engineering/machine-spirit/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step5() { awk '/^5\. /{on=1} /^6\. /{on=0} on' "$s"; }
check "given a CI change on Gitea, when the agent proves it, then it runs each whole job it reaches with gitea-runner exec in host mode, under a memory scope and a timeout" \
  'step5 | grep -q "Run the whole of each job the change reaches" && step5 | grep -qF "gitea-runner exec -i -self-hosted" && step5 | grep -q "MemoryMax="'
check "given a job the path map or an if: skips, when exec reports success, then the agent reads each step's Success line, never the exit code" \
  'step5 | grep -q "Success. line in the log, never the exit code"'
check "given a machine where the runner cannot start, when the agent proves a CI change, then it tries once, falls back to the job's run: steps in its shell, and never loops retries" \
  'step5 | grep -q "make one attempt" && step5 | grep -q "Never retry in a loop, swap tools or rebuild the runner by hand"'
check "given steps left unproven locally, when the agent writes the PR body, then it names each job and step and why" \
  'step5 | grep -q "Write in the PR body which jobs and steps are unproven locally, and why"'
c="$root/evals/machine-spirit/no-local-runner"
check "given the skill's eval suite, then a case recreates the no-runner machine, with both its graders" \
  'grep -qi "gitea-runner" "$c/prompt.md" && [ -f "$c/case.yaml" ] && [ -f "$c/graders/names-unproven-in-pr-body.md" ] && [ -f "$c/graders/stops-after-one-try.md" ]'
exit $fail
