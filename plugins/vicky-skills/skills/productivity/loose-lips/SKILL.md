---
name: loose-lips
description: Check text that leaves the machine for an attack map — hosts, versions, secrets, account powers, sign-in internals, open gaps — and rewrite it by role. Use before any commit, push, pull request, ticket, wiki page or public post, and when writing docs, workflow comments or config a stranger could read.
---

# Loose lips

Write as if a hostile reader holds a copy. An **attack map** is text that tells that reader where to aim: what runs where, what unlocks what, and where the gap is. Text gets one of three tiers. The repo's agent docs may name its tier; without one, treat it as public.

- **Public**: anything a stranger can reach, such as a public repo, wiki, release notes or a post.
- **Contributor**: a private repo or tracker that collaborators read. Write it as public too, since a contributor's laptop leaks.
- **Infrastructure**: the one compartment the repo's docs name for operations. Only there may text say what runs where.

## Steps

1. **Collect the outgoing text**: the staged diff, the commit message, the pull request or ticket body, the post. Done when you hold every piece that will leave.
2. **Scan it** for each kind below, by reading it and with a grep for the usual forms: IP addresses, hostnames and domains, `:<port>`, version numbers beside a service name, and the words `token`, `key`, `secret`, `password`, `admin`, `root` and `sudo`. Done when every hit is either rewritten or confirmed harmless.
3. **Rewrite by role.** Name a thing by what it does ("the CI runner", "the asset store", "the deploy account"). Write an open gap as its fix plus the ticket that tracks it. Done when no line names one of the kinds below.
4. **Fix a slip going forward.** A leak already pushed is fixed in a new commit. Leave history alone, since a copy is already out, and say what leaked so the owner can rotate anything sensitive. Done when the current text is clean and the owner knows.

## What never leaves

- **Where things run**: which host, provider, address or port runs what.
- **The stack**: which software and version runs a given service. Naming the forge, the tracker and their command-line tools is fine, since readers use them directly.
- **Secrets**: that a secret exists, where it is kept, and what it unlocks.
- **Power**: which account holds which right.
- **Gates**: how sign-in, approval or signing works inside.
- **Open gaps**: a weakness together with the way to reach it.
- **This machine**: absolute paths, home folders, usernames, hostnames, and paths outside the repo. Repo-relative paths are fine.

Ticket keys, repo names, decision record numbers and doc links are navigation, and they stay.
