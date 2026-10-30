# vicky-skills: agent rules

This repo is a public Claude Code plugin. Every commit on `main` reaches users as an update.

## Branching

- Work on a branch and open a pull request on GitHub. `main` gets finished work only and merges by squash once `checks` passes.
- CI refuses a draft pull request and runs once it is marked ready.

## Before every push

Run `claude plugin validate .` and `tests/run-all.sh`, which runs every script in `tests/` (CI runs each as a step in `.github/workflows/ci.yml`). A new test script also gets a step in that workflow.

## Public repo

Every file stays free of local paths, hostnames and any project's infrastructure. Run `loose-lips` before a commit.

## Add a skill

1. Create `plugins/vicky-skills/skills/<engineering|productivity>/<name>/SKILL.md`. Done when its `name:` equals the folder name.
2. List `./skills/<group>/<name>` in `skills` in `plugins/vicky-skills/.claude-plugin/plugin.json`. Done when `tests/plugin-layout.test.sh` passes.
3. Add a row to the README table that starts `**\`<name>\`**`. Done when the same test passes.
4. Write the description with `robot-voice`: it begins with the trigger and holds "Use when", "Use whenever" or "Use before". A skill only a person starts sets `disable-model-invocation: true` and its README row says "When you type it". Done when `tests/skill-descriptions.test.sh` passes.
5. Every numbered step under a `## Steps` heading ends in "Done when", and the file has a `# ` title. Done when `tests/skill-steps.test.sh` passes.
6. A skill the agent can start asks the user to type a typed-only skill and never starts it itself. Done when `tests/skill-links.test.sh` passes.

## Add or change a hook

- Script in `plugins/vicky-skills/scripts/`, registered in `plugins/vicky-skills/hooks/hooks.json`.
- An optional guard is off until the user turns it on: declare a `userConfig` option in `plugin.json` (default `false`) and have the script exit early unless `CLAUDE_PLUGIN_OPTION_<NAME>` is `true` or `1`.
- Add `tests/<hook>.test.sh`, a CI step for it, and a README bullet under the hooks list.

## Add a check a skill runs on the user's repo

- The same pull request gives the user's repo a way to opt out: a line in a `docs/agents/` file that `first-contact` writes, like `ADR format:` in `domain.md`. Done when a repo with its own way of working on purpose can switch the check off.

## Voice

- Skills, agent files and prompts are agent-facing: write them with `robot-voice`, fresh in this repo's words. An idea taken from another project gets a thanks line in the README.
- The README follows `human-voice`.
