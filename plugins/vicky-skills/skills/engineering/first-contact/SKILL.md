---
name: first-contact
description: "Configure a repo for these skills: where its tickets live and where its glossary and decision records live. Run once before the other engineering skills in a new repo."
disable-model-invocation: true
---

# First contact

> _Learn where they keep their records before you speak._

The engineering skills read these from a repo: `docs/agents/issue-tracker.md` says where tickets live and how to work them, `docs/agents/domain.md` says where the glossary and decision records live, and the testing standards say how testing is done. The `Testing standards:` line in `docs/agents/testing.md` names where the testing standards live: `TESTING_STANDARDS.md` at the root, or wherever the repo already keeps them, such as a wiki page. This skill writes these files, plus a short pointer block in the repo's agent file.

1. **Look first.** Read `git remote -v`, `AGENTS.md` and `CLAUDE.md`, `docs/agents/`, `GLOSSARY.md` or `GLOSSARY-MAP.md`, and every `docs/adr/` folder, `TESTING_STANDARDS.md` and any `Testing standards:` line, the test folders and the README's test commands. Done when you know which of these files already exist and what they say.
2. **Pick the tracker.** Propose the forge the remote points at. When the user would rather keep tickets on their own machine, propose the notes folder they already keep, such as an Obsidian vault, and local files in the repo when they keep none. The templates beside this file cover [GitHub](issue-tracker-github.md), [GitLab](issue-tracker-gitlab.md), [Gitea](issue-tracker-gitea.md), [Plane](issue-tracker-plane.md), [Obsidian](issue-tracker-obsidian.md) and [local files](issue-tracker-local.md). An Obsidian tracker also names the vault folder, `<vault>/<Project>/` unless the user picks another. A Plane repo also names its forge for pull requests. For any other tracker, ask the user to describe it in a paragraph and write the file from that, with "Star chart operations" and "Waiting work" sections in the same form as the templates. Ask too where a new idea goes, a behaviour no approved example names: write the answer as an `Ideas: <place>` line in `issue-tracker.md`. A repo several people share leaves the line out, so each person's own agent instructions name their place, and the pull request body is the last resort. Done when the user has picked.
3. **Pick the domain layout.** One `GLOSSARY.md` and one `docs/adr/` at the root fits almost every repo. Offer a `GLOSSARY-MAP.md` with one glossary per package only when the repo is a monorepo. Then pick the ADR format: run `decision-record`'s `scripts/check-adr.sh` on the existing records. When they fail it, ask whether the repo keeps its own format, and write the path of a template made from one of its records, or takes `decision-record` (its [FORMAT.md](../decision-record/FORMAT.md)) for new records. Records that pass in an older shape stay as they are. Done when the layout and the ADR format are picked.
4. **Draft the testing standards.** When the repo already keeps testing standards somewhere (a doc, a wiki page), write that place as the `Testing standards:` line in `docs/agents/testing.md` and check them against [testing-standards.md](testing-standards.md). Otherwise write `TESTING_STANDARDS.md` at the root from that template, and write `Testing standards: TESTING_STANDARDS.md` in `docs/agents/testing.md`. Fill each line from what the repo shows: its test folders, its boot and test commands, its README. Keep `Commit test cruft: no` unless the repo says otherwise, and ask the user about each line it can't fill. Done when the `Testing standards:` line names them and every line holds an answer or `ask`.
5. **Show the drafts** of every file and the pointer block, and let the user edit them. Done when the user approves.
6. **Write.** Edit `CLAUDE.md` if it exists, else `AGENTS.md`, else ask which to create. Update an existing `## Agent skills` block in place. Add `.todo` to the repo's `.gitignore`: it is the local list the plugin's session-start hook reminds the agent of. Add `.claude/worktrees/` too: every worktree lives there, and the main clone never lists them. A repo whose `domain.md` already says `Todo file: off` keeps that line, and its `.gitignore` stays as it is. Done when every write and the `.gitignore` lines are on disk.

The pointer block:

```markdown
## Agent skills

- Tickets: <where they live>. See `docs/agents/issue-tracker.md`.
- Domain: <single or multi-context>. See `docs/agents/domain.md`.
```

Charter: C8 ([CHARTER.md](../../CHARTER.md)).
