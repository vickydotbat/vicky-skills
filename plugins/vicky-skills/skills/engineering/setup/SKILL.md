---
name: setup
description: "Configure a repo for these skills: where its tickets live and where its glossary and decision records live. Run once before the other engineering skills in a new repo."
disable-model-invocation: true
---

# Setup

The engineering skills read two files from a repo: `docs/agents/issue-tracker.md` says where tickets live and how to work them, and `docs/agents/domain.md` says where the glossary and decision records live. This skill writes both, plus a short pointer block in the repo's agent file.

1. **Look first.** Read `git remote -v`, `AGENTS.md` and `CLAUDE.md`, `docs/agents/`, `GLOSSARY.md` or `GLOSSARY-MAP.md`, and every `docs/adr/` folder. Done when you know which of the three files already exist and what they say.
2. **Pick the tracker.** Propose the forge the remote points at. The templates beside this file cover [GitHub](issue-tracker-github.md), [GitLab](issue-tracker-gitlab.md), [Gitea](issue-tracker-gitea.md), [Plane](issue-tracker-plane.md) and [local files](issue-tracker-local.md). A Plane repo also names its forge for pull requests. For any other tracker, ask the user to describe it in a paragraph and write the file from that, with a "Wayfinding operations" section in the same form as the templates. Done when the user has picked.
3. **Pick the domain layout.** One `GLOSSARY.md` and one `docs/adr/` at the root fits almost every repo. Offer a `GLOSSARY-MAP.md` with one glossary per package only when the repo is a monorepo. Done when the layout is picked.
4. **Show the drafts** of both files and the pointer block, and let the user edit them. Done when the user approves.
5. **Write.** Edit `CLAUDE.md` if it exists, else `AGENTS.md`, else ask which to create. Update an existing `## Agent skills` block in place. Done when the three writes are on disk.

The pointer block:

```markdown
## Agent skills

- Tickets: <where they live>. See `docs/agents/issue-tracker.md`.
- Domain: <single or multi-context>. See `docs/agents/domain.md`.
```
