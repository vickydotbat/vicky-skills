# vicky-skills: agent rules

This repo is a public Claude Code plugin. Every commit on `main` reaches users as an update. Every file stays free of local paths, hostnames and any project's infrastructure: run `loose-lips` before a commit.

Develop a skill or hook in this order: Add a skill or Change a skill (or Add or change a hook), Before every push, Evals, Pull request.

## Add a skill

1. Create `plugins/vicky-skills/skills/<group>/<name>/SKILL.md`, where `<group>` is the README section the skill sits in: `commands`, `planning`, `building`, `shipping`, `writing` or `housekeeping`. Done when its `name:` equals the folder name.
2. List `./skills/<group>/<name>` in `skills` in `plugins/vicky-skills/.claude-plugin/plugin.json`, and add a README table row that starts `**\`<name>\`**`. Done when `tests/plugin-layout.test.sh` passes and the README row is there.
3. Write the skill with `robot-voice`. The description begins with the trigger and holds "Use when", "Use whenever" or "Use before". A skill only a person starts sets `disable-model-invocation: true`, and its README row says "When you type it". Done when `tests/skill-descriptions.test.sh` passes.
4. Give the file a `# ` title, and end every numbered step under `## Steps` in "Done when". Done when `tests/skill-steps.test.sh` passes.
5. A skill the agent can start asks the user to type a typed-only skill and never starts it itself. Done when `tests/skill-links.test.sh` passes.
6. End the skill with a `Charter:` line naming the lines of `plugins/vicky-skills/skills/CHARTER.md` it serves. Done when `tests/charter_approved_examples.test.sh` passes.
7. Add the eval case of step "Change a skill" below. Done when it fails on a checkout without the skill and passes with it.

## Change a skill

1. Change the text, then add or change an eval case under `plugins/vicky-skills/evals/<skill>/` that recreates the situation and grades what the agent does: a file it writes, a tool it calls, its reply. Never prove a skill by grepping its text: a phrase in a skill is prose, and only the agent's behaviour is proof. Done when you have seen the case fail on the old text and pass on the new. Keep runs cheap: `--runs 1 --ablation none --max-cost-usd <cap>`, and regex graders over judge graders.
2. Keep each meaning in one home and point at it from elsewhere. Keep a line marked `<!-- kept`. Done when `grep -rn` for a phrase you moved finds it in one skill file.

`tests/skill-change-tested.test.sh` fails a branch that changes skill text and no eval case. Whether the case proves the intent is the review's call.

## Add or change a hook

1. Choose the container. Back each rule with the strongest that fits: a hook that refuses or asks; a test or CI step; a hint a hook injects when the rule applies (a skill starting, or before the tool call it governs). A skill line comes last and names what backs it. A hook that asks the user is training wheels, the last resort: refuse with a steer, or inject context. When asking is all that fits, say in the script's header comment what would replace it. Done when the chosen container is the first one down that list that can decide the rule.
2. Put the script in `plugins/vicky-skills/scripts/` and register it in `plugins/vicky-skills/hooks/hooks.json`. Done when `tests/hook-audit.test.sh` passes.
3. Optional guard: declare a `userConfig` option in `plugin.json` (default `false`) and have the script exit early unless `CLAUDE_PLUGIN_OPTION_<NAME>` is `true` or `1`. A guard the user chose to have on by default (`guard_read_before_asking`) defaults to `true` and exits early only when the option is `false` or `0`. Done when the test covers the setting off.
4. Brief mode: every word the user reads is a `SendUserMessage` call, so a hook that reads the agent's words reads those bodies too (source `stop-reply.sh`), and its test sends a case through `SendUserMessage`. A "Going with" exemption covers only the text above it, never a later ask. Done when `tests/sendusermessage-mode.test.sh` passes.
5. Add `tests/<hook>.test.sh` and a CI step for it. It covers every decision the hook makes: each refusal or ask, each pass, the setting off, a missing tool, bad input. Done when `tests/<hook>.test.sh` passes.
6. Add a row to the README hooks table, tagged (recommended) when the hook only refuses, asks or warns, and (experimental) when it starts work on its own. Done when the row is in the table.
7. Refresh the mutation proof: `python3 tests/mutate-hooks.py --record`, then commit `tests/mutation-proof.tsv` with the script. Done when `python3 tests/mutate-hooks.py --check` passes and a `sentinels` pass leaves no survivor.

## Add a check a skill runs on the user's repo

Give the user's repo an opt-out in the same pull request: a line in a `docs/agents/` file that `first-contact` writes, like `ADR format:` in `docs/agents/domain.md`. Done when a repo with its own way of working can switch the check off.

## Before every push

1. Run `claude plugin validate .`. Done when it exits 0.
2. Run `tests/run-all.sh`, which runs every `tests/*.test.sh`; CI runs each as a step in `.github/workflows/ci.yml`. Done when it exits 0 and every new test script has a CI step.

A test stops only the processes it started, by the id it saved: `pkill -f <pattern>` also matches the shell that ran the test.

- A test or hook script that calls a tool beyond bash and coreutils names it in `tests/tools`, so it runs on any machine with the listed tools, not only the one that wrote it.
  Proven by: tests/tools-declared.test.sh

## Evals

Run an eval for each skill whose steps changed and that has a folder under `plugins/vicky-skills/evals/`. Each run starts a real Claude session on your credential, so CI never runs them.

1. `EVAL_SPEND=yes tests/evals/every_case.sh <skill>`. Done when every case passes.
2. A skill with no case: `tests/eval-coverage.sh plugins/vicky-skills` lists it. Done when you have added a case or accepted the gap in the pull request body.

## Pull request

1. Open the pull request as a draft. CI refuses a draft and runs once it is marked ready. Done when `gh pr view --json isDraft` says `true`.
2. Finish it with `make-it-so`, then merge it yourself: `gh pr merge <n> --squash`. It needs no human approval. Done when `checks` is green and the pull request is merged.

## Where a rule lives

A rule for agents lives in this repo, as a hook, a test or a skill line. The user's own global agent file changes only where it contradicts a rule here, and the pull request names that line.

## Voice

- Skills, agent files and prompts are agent-facing: write them with `robot-voice`, fresh in this repo's words. An idea taken from another project gets a thanks line in the README.
- The README follows `human-voice`.

## Agent skills

- Tickets: notes in the user's Obsidian vault, `vicky-skills/` folder. See `docs/agents/issue-tracker.md`.
- Domain: single context. See `docs/agents/domain.md`.
