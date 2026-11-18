# Machine spirit rules

The standing rules behind [SKILL.md](SKILL.md)'s steps.

## Rules

- **Status contexts are names.** A required check is `<workflow name> / <job> (<event>)`. Renaming a workflow or job makes a new context, and the old required one never reports. Keep required job names static, and change branch protection in the same effort.
- **One concurrency group per workflow.** Two workflows that share a group cancel each other's runs.
- **Aggregate gate jobs** use `if: always()` and test each `needs.<job>.result` themselves.
- **Runner limits** are tested against the heaviest real job and every scheduled workflow before merge. A soft memory cap throttles instead of killing, and turns a 14-second check into a 10-minute one.
- **Caches are proven.** A cache works when the second run logs a hit or a restore. A failed cache save can leave the job green and slow. Measure the miss path on the runner before you remove or rekey a cache.
- **Release and pull request share one build script.** A step only the release runs breaks only at release. A release moves every channel or none.
- **Runner and host configuration is declared in code.** Hand no one a `systemctl set-property` or a manual edit as the fix.
- **CI automation never widens who can approve or merge.**
- **A run already going is spent.** Do not hold, re-push or rebase a pull request, or park a merge-ready one behind a CI fix, just so a cheaper gate applies. Fix the gate for future pull requests and let the current run finish. The `run-already-going` eval case backs this line.
- **Write for a hostile reader.** Workflow comments name no run numbers, runner, host or cache, so a public copy maps nothing. A value a command needs (a `runs-on:` label, a URL it fetches) stays as config, with no prose around it, or moves to a CI variable.

## Gate rules

- A draft runs nothing past its first step ([CLEAN-GATE.md](CLEAN-GATE.md)). A run that stops at the draft gate is expected: triage it as no run yet, never as red.
- A pull request's CI finishes in a few minutes and uses as little of the runner as the change needs. A timeout is a crash guard, never the bar.
- A gate runs only what the change can reach. A docs-only or decision-record-only change runs the cheap checks and no build; a test row proves it. A path the gate does not recognise runs everything, loudly, so the map gets fixed.
- A test proves one result in one place. Shared setup starts once per suite, and an expensive evaluation runs once and is shared.
- Evidence about CI comes from the runner's own log. A local run shows which step is slow, never why the runner is.
- Two gates on one runner slow each other, so the fix is often to stop one of them running.
