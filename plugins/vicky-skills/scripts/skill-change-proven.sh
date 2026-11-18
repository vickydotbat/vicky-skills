#!/usr/bin/env bash
# Reads a branch's changed paths on stdin. Exits 1, naming the skill files,
# when skill text changed and no eval case did: a skill's behaviour is what an
# agent does with it, which an eval case proves. A test that reads the skill's
# text proves only that the text holds a phrase, so a tests/ change never
# counts as the proof.
set -u
files=$(cat)
skills=$(printf '%s\n' "$files" | grep -E '^plugins/vicky-skills/skills/.+\.md$')
[ -z "$skills" ] && exit 0
printf '%s\n' "$files" | grep -qE '^plugins/vicky-skills/evals/' && exit 0
echo "skill text changed with no eval case: add or change an eval case under plugins/vicky-skills/evals/ that fails on the old text and passes on the new (AGENTS.md, Change a skill):"
printf '  %s\n' $skills
exit 1
