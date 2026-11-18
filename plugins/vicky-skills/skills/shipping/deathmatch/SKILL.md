---
name: deathmatch
description: "Send opponents to break a branch since a fixed point, keep only the findings a run or an arena contest proves, and fix them on the effort's own branch. Use when make-it-so reaches its ready step, when assimilate needs a verdict, when an outside report or review arrives, and when the user asks to review, break or deathmatch a branch."
---

# Deathmatch

> _Two branches enter. One branch leaves._

A **deathmatch** sends **opponents** at the diff between `HEAD` and a fixed point. Each opponent holds one angle, reads [STANDARDS.md](../../STANDARDS.md) and the repo's own rules, and tries to break the change. A **finding** counts only when it is **proven**: a command shows the failure and the failure breaks the intent, or the finding's own fix beats the branch in an arena contest. A finding that is neither is **unproven**: it is listed and never blocks.

The main thread does the TDD, red to green. Deathmatch is the refactor: its job is to kill the weaknesses the build left. It runs once per effort, inside `make-it-so` before the pull request goes ready (`verdict.sh due` says whether the head commit still needs one), and on outside text when `assimilate` or another skill hands it a report.

## Opponents

Six always fight:

- **Intent**: the approved examples and the observer's view. Does each example pass, and which prose ask has no example?
- **Holds**: break each path the change reaches. Can its tests fail?
- **Cause**: symptom or cause, by [CAUSE.md](CAUSE.md). A symptom fix, or a suspected better way, opens the arena round.
- **Simplicity**: what can be deleted, merged or not built. Its proof is a deletion that leaves every check green.
- **Standards**: the repo's rules and STANDARDS.md, quoted by leading word.
- **Claims**: the pull request body's Proof and Status against what actually ran.

Triggered opponents fight only when `scripts/triggers.sh <fixed-point>` names them: **Runaway** (the diff starts a process, loop, server or container) and **Security** (a route, permission check, user input, parser, query, rendered user content, secret, process spawn, network call or CI permission). Every opponent run goes through `scripts/cap.sh`, so a run over its time or memory cap is stopped and reported, and nothing else on the machine is touched.

Before any opponent fights, `scripts/prefight.sh <fixed-point>` runs the Leak check. A local path, host or secret in the diff stops the deathmatch with the file and line. The Host check is the sealed copy: an undeclared tool fails there by itself.

## Steps

1. **Pin the checkout, the fixed point and the spec.** Take the effort's worktree and its pull request's merge-base when `make-it-so`, `warp` or `assimilate` calls this skill, and never ask. Otherwise use what the user named, or ask. Find the spec: the ticket's approved examples, or the user's ask. Done when `git diff <fixed-point>...HEAD` has content and you hold a spec or "none".
2. **Gather the law.** Read the repo's `AGENTS.md`, its `docs/agents/` files and STANDARDS.md. When they name rules kept outside the repo, write them verbatim into one law file in scratch and use the path `test -s <file> && realpath <file>` prints. `review-brief-guard` refuses an opponent brief that names a missing file. Done when you hold the law file's printed path, or can say the repo keeps no rules outside it.
3. **Pre-fight.** Run the checks once: `scripts/prefight.sh <fixed-point>`, then the repo's own tests and checks. Make the sealed copy: a fresh clone in scratch, its own home folder, only the dev shell's tools on PATH. A repo too heavy to copy runs on the host, and its findings say "proven on host". Done when the Leak check passed and you hold each failing check's failing lines, not its log.
4. **Fight.** Dispatch one opponent per angle in one message, plus each triggered one, on the default model. Give each the sealed copy, the fixed point, the law file's path, the spec and the failing lines that bear on its angle. Each opponent returns findings, each with the command that proves it, or the patch that would fix it. Done when every opponent has reported on every changed file.
5. **Prove.** Run each finding's command again in the sealed copy, under `scripts/cap.sh`. Keep the finding when the output shows the failure and the failure breaks the intent. A finding with no command, such as a deletion or a rename, goes to the arena. When two opponents disagree on one finding, a second model judges that finding alone, and no undisputed finding reaches it. Done when each finding is proven, unproven, or waiting for the arena.
6. **Arena**, only when Cause ruled a symptom fix, an opponent suspects a better way, or a finding waits for a contest. Build a rival from the problem alone, as CAUSE.md's third question does, and each waiting finding's patch. Run every check on each candidate and on the branch. Score them on one rubric: does the bad state still happen, what it deletes, what it adds, what STANDARDS.md says. Graft each part where a rival wins onto the branch, and keep the rest of the branch. A finding whose patch wins is proven. A branch that fixes the cause, with no better way suspected, holds no arena. Done when each candidate has its score and each graft is named.
7. **Fix or report.** On the effort's own branch, fix each proven finding that waits on no one: its test red first, then green, never changing an approved test. On outside text (an outside pull request, bug report or review), run `scripts/mark-outside.sh <session id> <what you read>` as soon as you read it, then fix nothing, push nothing, file nothing and post nothing: return the findings, and a person or a later run acts on them (`outside-text-guard` holds this). Done when each proven finding is fixed with its test, or listed for its owner.
8. **Report** to `deathmatch.md` in scratch, and in the pull request's Proof as `Deathmatch verdict for <head sha>: <n> proven findings`. List proven findings with their command and output, then unproven ones under `Unproven, not blocking`, then each arena score and graft. Add the Laws line from `bash ${CLAUDE_PLUGIN_ROOT}/skills/shipping/engrave/scripts/law-lint.sh prove <fixed-point>`. Give each fixed finding a prevention verdict: engrave it as the cheapest check, hook or STANDARDS.md line that holds it, or say why not. Then run `cerebro` as a forecast. Done when the report holds every finding, the verdict line is in the pull request, and cerebro has proposed or found nothing.

Proven by: plugins/vicky-skills/evals/deathmatch

Charter: C1, C2, C4, C6 ([CHARTER.md](../../CHARTER.md)).
