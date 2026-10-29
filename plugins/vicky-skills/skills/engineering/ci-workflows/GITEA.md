# Gitea Actions: checked behaviour

Each row names the release it holds from and the source that proves it. Compare the version column with `tea api version </dev/null` before relying on a row. Gitea numbers releases 1.26, 1.27, then 28.0 (2026-09-29): 28.x is newer than 1.27.

| Behaviour | Holds from | Source |
| --- | --- | --- |
| An Actions secret keeps its line breaks, so a PEM key fits in one. The web form saves `util.NormalizeStringEOL(form.Data)`, turning CRLF into LF, and a value holds up to 65536 bytes (`SecretDataMaxLength`). | 28.1.0 | `routers/web/shared/secrets/secrets.go`, `models/secret/secret.go` at v28.1.0 |
| A workflow skipped by `paths`, `paths-ignore`, `branches` or `branches-ignore` gets a `skipped` commit status for each job whose context matches a required-check pattern in some branch protection rule. `skipped` counts as success, so the merge is not blocked. Contexts no rule requires get no status. | 1.27.0 | go-gitea/gitea#38237, #38371, v1.27.0 release notes |
| Before 1.27.0, the same skipped workflow left its required check pending, and the merge stayed blocked. | before 1.27.0 | go-gitea/gitea#36895 |
| A job skipped by `if:` reports `skipped`, which satisfies a required check. | source on main, 2026-10 | `services/actions/commit_status.go` (`toCommitStatus`), `modules/commitstatus/commit_status.go` (`Combine`) |
| A commit status context is `<workflow name> / <job> (<event>)`, for example `ci / build (pull_request)`. For a skipped workflow the context is predicted from the workflow file, so keep job names free of expressions. | 1.27.0 | `CreateSkippedCommitStatusForFilteredWorkflow` in `services/actions/commit_status.go` |
| Expressions take GitHub's contexts, so `github.ref` and friends work. Some workflows use `gitea.*` instead, which actionlint flags as undefined; write `github.*`. | all current | https://docs.gitea.com/usage/actions/comparison ("Expressions support the standard GitHub functions and contexts") |
| Gitea ignores some GitHub workflow features, among them `environment` and problem matchers, and resolves `uses:` actions from GitHub by default. Read the comparison page before using a GitHub-only feature. | all current | https://docs.gitea.com/usage/actions/comparison |
| A job log is `tea api repos/<owner>/<repo>/actions/jobs/<id>/logs </dev/null`. Anonymous access returns 401. | 28.1.0, observed | API call |
| A failed run reruns with `tea api -X POST repos/<owner>/<repo>/actions/runs/<run id>/rerun </dev/null`. It answers with the run, `run_attempt` raised by one and `status` queued, and the same run id reports the new attempt. `tea actions runs` has no rerun command. | 28.1.0, observed | API call |

## Unverified

Treat these as open until a run or the source proves them, then move them into the table.

- Whether a job skipped because a `needs:` dependency failed reports `skipped`, which would pass a required check. Until proven, an aggregate gate uses `if: always()` and tests `needs.<job>.result`.
- Whether Gitea enforces a workflow's `permissions:` block.
- Whether a job that hits `timeout-minutes` shows as cancelled rather than failed. Agents have read it as cancelled.

## GitHub, for comparison

On GitHub a workflow skipped by `paths` leaves its required check pending, and a job skipped by `if:` reports success: https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks. A GitHub repository that requires checks keeps an always-running gate job.
