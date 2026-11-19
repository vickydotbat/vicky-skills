# CI level

Proves **Workflow injection** ([STANDARDS.md](../../STANDARDS.md), Security) with `zizmor` over `.github/workflows`, `.gitea/workflows` and `.forgejo/workflows`.

- A finding names the workflow, its line and zizmor's rule, such as `template-injection`.
- The fix passes the outside text through `env:` and reads it as a shell variable, never as `${{ }}` inside `run:`.
- A repo with no workflows has nothing to check. zizmor exits 10 to 14 on findings, by severity. Any other exit but 0 is a failed run.
