# Secrets level

Proves **Committed secrets** ([STANDARDS.md](../../STANDARDS.md), Security) with `gitleaks git`, over the whole history or, from `review.sh`, the branch's commits.

- A finding names the file, the line and the commit, never the secret: the kit runs gitleaks with `--redact` and reads only where each leak sits.
- The fix is rotating the key with its issuer, then removing it. A leak in an old commit stays leaked after a new commit deletes it.
- Exit 0 is a clean history. Any exit but 0 or 1 is a failed run, which says nothing either way.
