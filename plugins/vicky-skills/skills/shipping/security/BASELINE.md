# Baseline level

Proves **Security policy** ([STANDARDS.md](../../STANDARDS.md), Security) with `scorecard --checks Security-Policy`, on a GitHub or GitLab repo. scorecard reads the forge's API, so a repo on any other forge gets no answer either way.

- A score of 10 means a policy was found. A score of -1 means scorecard could not decide, which is no finding.
- scorecard reads the default branch. A `SECURITY.md` on a branch passes only once it merges: run the level again then. Until then the level prints `unchecked` in place of a missing-policy finding.
- On GitHub the level also reads the repo's private vulnerability reporting setting with `gh api repos/<owner>/<repo>/private-vulnerability-reporting`. Off is a finding: the policy's **Report a vulnerability** button does not exist until it is on. The fix is `gh api -X PUT repos/<owner>/<repo>/private-vulnerability-reporting`, a public repo setting, so ask the user first.
- The fix for a missing policy is a `SECURITY.md` written from [SECURITY-TEMPLATE.md](SECURITY-TEMPLATE.md). Fill each `<...>` with the repo's own answer, and ask the user for the reply time and the supported versions rather than guess them.
