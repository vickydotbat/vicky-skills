---
name: machine-spirit
description: Write, change or debug CI. Use when editing a workflow under .gitea/workflows or .github/workflows, a path filter, a runner or its limits, a CI cache, a release pipeline, or branch protection and required checks; and when a CI run is red, slow, stuck or never reports.
---

# Machine spirit

> _The machine spirit is appeased by proof, not prayer._

A workflow change is a guess until the platform, the diff and the runner have each been checked. Every claim about how the CI platform behaves comes from the running server's version and a source you can quote. Memory is the usual source of CI mistakes, because Gitea changes behaviour between releases.

## Steps

Run them in order for every workflow change. Diagnosing a run starts at step 7.

1. **Read the platform.** Run `tea api version </dev/null` and `tea api repos/<owner>/<repo>/branch_protections </dev/null`. Note the required status contexts and the protected file patterns. A pattern like `.gitea/**` means only some branch names may push a workflow change; pick the branch from the rule, never by guessing. Check each platform behaviour you rely on against [GITEA.md](GITEA.md) and its version column. A behaviour not listed there: find it in Gitea's docs, release notes or source, quote it, and add a row. Done when you can name the server version, every required context, and the branch the change may be pushed from.

2. **Prefer declarative syntax.** Express job selection with `on.<event>.paths`, `if:`, `needs:` and `concurrency` before any shell. Write shell only for what the syntax cannot say. Then the data is a list with one item per line, the logic is a few lines, and one comment says why the declarative form fails. Done when every shell block in the diff has that reason.

3. **Map what the diff runs.** For a path filter, find the build inputs by tracing the build entry point and every script it calls, reading each for the files it opens. Test the filter both ways against a table of sample paths: one under each input that must build, plus docs, media, Markdown and a new top-level folder. A path the filter does not recognise builds, unless the repository's own guide says otherwise. Done when the table passes and the PR body says which jobs this pull request runs.

4. **Lint.** The workflow-lint hook runs actionlint, with shellcheck on every `run:` script, each time you write a workflow file with Edit or Write. It never sees a file written through Bash. For those, run `nix shell nixpkgs#actionlint nixpkgs#shellcheck --command actionlint <files>`, naming Gitea files explicitly. List self-hosted runner labels in the repository's `.github/actionlint.yaml`. Done when actionlint is clean.

5. **Dry-run in a scratch clone.** Copy the repository with `git clone --no-local <repo> /tmp/<your scratch folder>/ci-try` and run new steps there, never in the working checkout. A step that fetches with `--depth`, cleans or rewrites the tree damages the checkout it runs in. Run each step in the job's own shell (`nix develop .#ci --command ...`): the runner has only the tools that shell declares. Done when every new or changed step ran once in the job's shell.

6. **Budget.** Name what each job costs: time, peak memory and disk. A docs-only change builds nothing. Release work (cross-builds, images, packaging) stays on the release trigger. Push once, and push again to a green pull request only when the result can change. Done when the PR body states the expected cost, and the cost of a new step comes from the runner log after its first run.

7. **Watch every terminal state.** Poll the commit status until every required context is final, matching failure, cancelled and timeout as well as success. Read the failing job's log before you change anything: `tea api repos/<owner>/<repo>/actions/jobs/<id>/logs </dev/null`. A local run says which step is slow; only the runner log says why. Done when you quote each required context's final state.

## Rules

- **Status contexts are names.** A required check is `<workflow name> / <job> (<event>)`. Renaming a workflow or job makes a new context, and the old required one never reports. Keep required job names static, and change branch protection in the same effort.
- **One concurrency group per workflow.** Two workflows that share a group cancel each other's runs.
- **Aggregate gate jobs** use `if: always()` and test each `needs.<job>.result` themselves.
- **Runner limits** are tested against the heaviest real job and every scheduled workflow before merge. A soft memory cap throttles instead of killing, and turns a 14-second check into a 10-minute one.
- **Caches are proven.** A cache works when the second run logs a hit or a restore. A failed cache save can leave the job green and slow. Measure the miss path on the runner before you remove or rekey a cache.
- **Release and pull request share one build script.** A step only the release runs breaks only at release. A release moves every channel or none.
- **Runner and host configuration is declared in code.** Hand no one a `systemctl set-property` or a manual edit as the fix.
- **CI automation never widens who can approve or merge.**
- **Write for a hostile reader.** Workflow comments name no run numbers, runner, host or cache, so a public copy maps nothing. A value a command needs (a `runs-on:` label, a URL it fetches) stays as config, with no prose around it, or moves to a CI variable.

## Gate rules

- A pull request's CI finishes in a few minutes and uses as little of the runner as the change needs. A timeout is a crash guard, never the bar.
- A gate runs only what the change can reach. A path the gate does not recognise runs everything, loudly, so the map gets fixed.
- A test proves one result in one place. Shared setup starts once per suite, and an expensive evaluation runs once and is shared.
- Evidence about CI comes from the runner's own log. A local run shows which step is slow, never why the runner is.
- Two gates on one runner slow each other, so the fix is often to stop one of them running.
