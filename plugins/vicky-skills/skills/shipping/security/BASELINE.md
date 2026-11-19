# Baseline level

Proves **Security policy** ([STANDARDS.md](../../STANDARDS.md), Security) with `scorecard --checks Security-Policy`, on a GitHub or GitLab repo. scorecard reads the forge's API, so a repo on any other forge gets no answer either way.

- A score of 10 means a policy was found. A score of -1 means scorecard could not decide, which is no finding.
- The fix is a `SECURITY.md` that says how to report a weakness privately and how long a reply takes.
