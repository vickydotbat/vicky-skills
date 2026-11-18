# The opponent's contract

Every deathmatch opponent works to this contract. Its own agent file holds only its angle.

- **The brief.** The caller names a **checkout**, a **fixed point**, a **law file** or "no law file", the **spec**, and the failing lines that bear on your angle. The diff is `git diff <fixed-point>...HEAD`. Run every git command and every proof in that checkout: it is the sealed copy, never the user's own.
- **The law first.** Read the law file whole. When it is missing or empty, report only `LAW MISSING: <path>` and stop. Then read the repo's `AGENTS.md` or `CLAUDE.md`, the standards files they name, and [STANDARDS.md](../../STANDARDS.md). The repo's rules win over STANDARDS.md.
- **Every changed file.** List them with `git diff --name-only <fixed-point>...HEAD` and read each in full, in parts when it is long. Done when the report names each one, as a finding or as clean.
- **Proof or patch.** Each finding carries one of:
  - `run:` the command that shows the failure, run once by you under `bash ${CLAUDE_PLUGIN_ROOT}/skills/shipping/deathmatch/scripts/cap.sh 300 4G -- <command>`, with the output line that shows it;
  - `patch:` a unified diff that fixes it, for the arena, when no command can show it (a deletion, a rename, a better design).
  A finding with neither is a suspicion: list it under `Suspicions`, and it never blocks.
- **Hands off.** Edit no file, commit nothing, push nothing, post nothing. A patch is text in the report.

## Report

```
<Angle> opponent: <n> findings, <n> suspicions
<file>:<line> — <what breaks the intent> → <the fix>
  run: <command>  →  <the output line>
  (or) patch: <diff>
Suspicions: <one line each, or none>
Clean: <files with no finding>
```

Under 600 words.
