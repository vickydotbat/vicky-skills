---
name: machine-spirit
description: Write, change or debug CI. Use before editing a workflow under .gitea/workflows or .github/workflows, a path filter, a runner or its limits, a CI cache, a release pipeline, or branch protection and required checks; and when a CI run is red, slow, stuck or never reports.
---

# Machine spirit

> _The machine spirit is appeased by proof, not prayer._

A workflow change is a guess until the platform, the diff and the runner have each been checked. Every claim about how the CI platform behaves comes from the running server's version and a source you can quote. Memory is the usual source of CI mistakes, because Gitea changes behaviour between releases. The doctrine's primary sources are quoted in [SOURCES.md](SOURCES.md).

## Steps

Run them in order for every workflow change. Diagnosing a run starts at step 7.

1. **Read the platform.** Run `tea api version </dev/null` and `tea api repos/<owner>/<repo>/branch_protections </dev/null`. On GitHub, run `gh api repos/<owner>/<repo>/branches/<base>/protection` instead. Note the required status contexts and the protected file patterns. A pattern like `.gitea/**` means only some branch names may push a workflow change; pick the branch from the rule, never by guessing. Check each platform behaviour you rely on against [GITEA.md](GITEA.md) and its version column. A behaviour not listed there: find it in Gitea's docs, release notes or source, quote it, and add a row. Done when you can name the server version, every required context, and the branch the change may be pushed from.

2. **Put each decision in the layer that owns it, declarative first.** A fix in the wrong layer is a patch: it works today and breaks the next change.

   | Decision | Owner | Wrong-layer tell |
   | --- | --- | --- |
   | Which jobs run | Forge syntax: `on.<event>.paths`, `if:`, `needs:`, `concurrency` | A shell `if` over `git diff` inside a job |
   | Which targets a change affects, and what is cached | The build system (Nix, Bazel, the repo's own build) and cache keys from its inputs | A CI step that rebuilds what the build system already holds |
   | Tools and their versions | The job's declared shell (`nix develop .#ci` in a Nix repo) | An install step, or a tool assumed to be on the runner |
   | Runner limits | The runner's config, declared in code | A raised `timeout-minutes` |
   | Slow and flaky tests | The test harness: test sizes, isolation, fixtures. A flaky test is red, as `make-it-so` step 6 says | A retry or a sleep in the workflow |

   Write shell only for what the syntax cannot say. Then the data is a list with one item per line, the logic is a few lines, and one comment says why the declarative form fails. Done when each change in the diff names its layer in the PR body, and every shell block in the diff has that reason.

3. **Map what the diff runs.** In a repository the user owns, pull-request CI has the clean gate's shape: one gate that always starts, a draft gate, and a path map with a `map-check` ([CLEAN-GATE.md](CLEAN-GATE.md)). Build that shape, or audit existing CI against it. For the map, find the build inputs by tracing the build entry point and every script it calls, reading each for the files it opens. Then, in this order:
   a. List every file kind in the repository: each top-level folder and each extension. Give each kind its own arm that names the cheapest target able to check it. A docs or decision-record folder, a tooling script and a markdown file are kinds. A kind with no arm falls through to "unknown" and builds everything.
   b. Put a sample-path table in the map's contract test: one path per arm, plus docs, media, Markdown, a new top-level folder and an unmapped path. Each row states the exact target set it selects, in both directions: what it runs and what it must not run. A docs-only row asserts the build targets are false.
   c. Run the map on this pull request's own changed paths (`git diff --name-only <base> HEAD | <map script>`) and read the result. A change that adds or renames a file kind adds its arm and its table row in the same pull request.
   Prose in a comment or a rule is not the map. Done when the table passes, the map run on the pull request's own paths selects only what the change can reach, and the PR body says which jobs this pull request runs.

4. **Lint.** The `workflow-lint` hook runs actionlint, with shellcheck on every `run:` script, each time you write a workflow file with Edit or Write, and hands its findings back. Without the workflow-lint hook (actionlint not installed, or the hook switched off), and for a file written through Bash, which it never sees, lint every workflow file the diff touches yourself: run `actionlint <files>` with actionlint and shellcheck installed (on Nix: `nix shell nixpkgs#actionlint nixpkgs#shellcheck --command actionlint <files>`), naming Gitea files explicitly. List self-hosted runner labels in the repository's `.github/actionlint.yaml`. Done when actionlint is clean.

5. **Run each job locally in a scratch clone.** Copy the repository with `git clone --no-local <repo> /tmp/<your scratch folder>/ci-try` and run there, never in the working checkout. A step that fetches with `--depth`, cleans or rewrites the tree damages the checkout it runs in. Run the whole of each job the change reaches, not only its new steps, before the shared runner sees it:
   a. **Gitea: the runner's local mode.** Use the repo's own local-CI wrapper when it has one. Otherwise run `gitea-runner exec -i -self-hosted -W <workflow> -j <job> -E pull_request -e <event.json>` under `systemd-run --user --scope -p MemoryMax=6G` and `timeout`. On Nix the package is `nixpkgs#gitea-actions-runner`, and the binary is `gitea-runner`, not `act_runner`. `-i -self-hosted` runs on the host, with the host's tools. Exec runs the job's `needs` first and honours `if:`, and a job whose `if:` is false exits 0 with no step output. So the proof is each step's `Success` line in the log, never the exit code, and the event and base ref must give a diff that reaches the job. A skipped need reads locally as an empty `needs.<job>.result`, not `skipped`. Skip the steps that call the forge API or need a secret the machine cannot supply, and name them.
   b. **When the runner cannot start** (no Nix, no host-mode runner, a runner label or secret the machine cannot supply): make one attempt. Then run the job's own `run:` steps in the shell its workflow sets up (`nix develop .#ci --command ...` in a Nix repo). When that fails too, stop. Never retry in a loop, swap tools or rebuild the runner by hand to force a local run. Write in the PR body which jobs and steps are unproven locally, and why. The pull request's first run on the shared runner proves them: the run once it is marked ready behind a draft gate, the draft's own run where CI runs on drafts.
   Done when each job the change reaches has a `Success` line per step in a local log, or the PR body names what is unproven and why.

6. **Budget, and fight the biggest cost first.** The baseline is the base branch's recent runs: `gh run list --branch <base> --limit 5`, or `tea actions runs list` on Gitea, with each job's time from its log. Name what each job costs: time, peak memory and disk. Rank the jobs by measured cost, fix the biggest measured cost first, then measure again. CI is a long war: one structural fix to the top job beats tuning every cheap one. A docs-only change builds nothing. Release work (cross-builds, images, packaging) stays on the release trigger. Push once, and push again to a green pull request only when the result can change. Done when the PR body states the expected cost against the baseline and names the top cost, and the cost of a new step comes from the runner log after its first run.

7. **Watch every terminal state.** Poll the commit status until every required context is final, matching failure, cancelled and timeout as well as success. Read the failing job's log before you change anything: `tea api repos/<owner>/<repo>/actions/jobs/<id>/logs </dev/null`. On GitHub, the job's step list and `gh run view --log` can come back partial. To prove a step ran, read the run's log archive: `gh api repos/<owner>/<repo>/actions/runs/<id>/logs > <scratch>/logs.zip`, then `0_<job>.txt` inside it. Name the cause before you edit: one line, from the log. A fix removes the cause or its whole class. A patch hides it: a retry, a raised timeout, a sleep, a skipped or deleted test, `continue-on-error`, a loosened assertion or a cache cleared by hand. A patch never lands as the fix, and `patch-tell-hint` says so when a workflow edit adds one. When one must hold the line while the fix lands, the PR body names the cause and the ticket that removes it. A local run says which step is slow; only the runner log says why. Done when you quote each required context's final state, and each fix has its cause line.

## Rules

- **Status contexts are names.** A required check is `<workflow name> / <job> (<event>)`. Renaming a workflow or job makes a new context, and the old required one never reports. Keep required job names static, and change branch protection in the same effort.
- **One concurrency group per workflow.** Two workflows that share a group cancel each other's runs.
- **Aggregate gate jobs** use `if: always()` and test each `needs.<job>.result` themselves.
- **Runner limits** are tested against the heaviest real job and every scheduled workflow before merge. A soft memory cap throttles instead of killing, and turns a 14-second check into a 10-minute one.
- **Caches are proven.** A cache works when the second run logs a hit or a restore. A failed cache save can leave the job green and slow. Measure the miss path on the runner before you remove or rekey a cache.
- **A red the local loop missed is the tooling's gap.** When a developer ran the repo's documented local loop, it passed, and CI went red on a product change, the gap between the two failed them. Fix the gap for that whole class of red, in the tooling. Never ask developers to run CI's suite, or more of it, before ready: CI exists to catch what a fast local run cannot. The fix takes one of these shapes. The local run calls the selector script CI calls, so both pick the same tests. The harness enforces a timing or isolation rule on every machine, such as failing a wait that used most of its budget. A red test reruns alone on the same tree to say whether the test or the tooling is at fault, and the job stays red either way. A pipeline path no developer runs, such as a cache hit or miss, gets its own test in CI. A change to the workflow itself still runs locally first, as step 5 says.
  Proven by: plugins/vicky-skills/evals/machine-spirit/local-green-ci-red
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
- Two gates on one runner slow each other, so the fix is often to stop one of them running.

Charter: C4, C7 ([CHARTER.md](../../CHARTER.md)).
