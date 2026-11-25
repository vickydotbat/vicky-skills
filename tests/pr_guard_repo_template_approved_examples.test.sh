#!/usr/bin/env bash
# shellcheck disable=SC2016 # single quotes write a literal $1 into the stand-in gh and the jq filter
# approved-spec: the examples approved on the notes "RS-S3 ship-it follows the
# repo template", "RS-S4 ship-it knows where Status lives" and "RS-S6 ship-it
# takes groundhog-day replay and related lines", on 2026-11-25. Each check runs
# pr-guard the way Claude Code does, with a stand-in gh that lists no open
# pull request.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pr-guard.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin" "$scratch/data"
printf '#!/usr/bin/env bash\n[ "$1 $2" = "pr list" ] && echo "[]"\n' >"$scratch/bin/gh"
chmod +x "$scratch/bin/gh"
export PATH="$scratch/bin:$PATH" HOME="$scratch/home" CLAUDE_PLUGIN_DATA="$scratch/data" CLAUDE_PLUGIN_OPTION_GUARD_PR=true
unset CLAUDE_CONFIG_DIR
# repo <name> <PR template line>: a GitHub repo on a feature branch.
repo() {
  git init -q -b main "$scratch/$1"
  git -C "$scratch/$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init
  git -C "$scratch/$1" switch -q -c feat/one
  git -C "$scratch/$1" remote add origin https://github.com/o/r.git
  mkdir -p "$scratch/$1/docs/agents" "$scratch/$1/.github"
  printf '# Tickets\n\nPR template: %s\n' "$2" >"$scratch/$1/docs/agents/issue-tracker.md"
}
# The repo's own template, the one cx#436 ran into.
own_template() {
  printf '%s\n' '<!-- Fill each section. -->' '' '## Agreed' '' '<!-- The agreement. -->' '' '## What it does' '' \
    '## How to try it' '' '<!-- Optional. Numbered steps. -->' '' '## Proof' '' '## Performance' '' \
    '<!-- Write "no impact" and why. -->' '' '## Understanding' '' '- [ ] I understand this change' >"$scratch/$1/.github/pull_request_template.md"
}
repo own on; own_template own
repo own_off off; own_template own_off
repo plain on
printf '## Agreed\n\nx\n\n## What it does\n\nx\n\n## Proof\n\nx\n\n## Performance\n\nno impact\n\n## Understanding\n\n- [ ] I understand this change\n' >"$scratch/own.md"
printf '## Status\n\n`Done:` x\n\n## Summary\n\nx\n\n## Proof\n\n- Tests: x\n\n## Risk\n\n- Undo: a revert\n' >"$scratch/ours.md"
printf '## Status\n\n`Done:` x\n\n## Summary\n\nx\n\n## Proof\n\nx\n' >"$scratch/norisk.md"
fail=0
run() {
  jq -nc --arg c "$2" --arg d "$scratch/$1" \
    '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, session_id: "s1", tool_input: {command: $c}}' |
    (cd "$scratch/$1" && bash "$hook") >"$scratch/out" 2>&1
}
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (exit $2, wanted $3)"; sed 's/^/     /' "$scratch/out"; fail=1; fi; }

# Given a repo with its own template and PR template: on
# When the agent creates a pull request whose body fills that template's headings
# Then pr-guard lets it through, with no ask for Status, Summary or Risk
run own "gh pr create --draft --title T --body-file $scratch/own.md"
check "RS-S3 E4 a body in the repo's own headings goes through" $? 0

# Given the same repo
# When the body uses ship-it's headings and leaves out the template's Agreed and Understanding
# Then pr-guard refuses it and names the missing headings
run own "gh pr create --draft --title T --body-file $scratch/ours.md"
s=$?; cp "$scratch/out" "$scratch/ours.out"
grep -q 'Agreed' "$scratch/ours.out" && grep -q 'Understanding' "$scratch/ours.out" || s=0
check "RS-S3 E4 pr-guard checks the repo template's headings" $s 2
# not_asked <heading>: 0 when the refusal of the ship-it-headed body above
# names the template's headings and not this one.
not_asked() { grep -q 'Agreed' "$scratch/ours.out" && ! grep -q "$1" "$scratch/ours.out"; }

# Given the repo template marks How to try it optional
# When the body leaves it out
# Then pr-guard does not ask for it
not_asked 'How to try it'; s=$?
check "RS-S6 E6 an optional template section is not asked for" $s 0

# Given a repo template with no Risk heading
# When the body has no Risk heading
# Then pr-guard does not ask for Risk
not_asked 'Risk'; s=$?
check "RS-S3 E8 no Risk is asked of a template that has none" $s 0

# Given a template with no Status heading
# When the body has no Status
# Then pr-guard accepts it (Status lives in a sticky comment)
not_asked 'Status'; s=$?
check "RS-S4 E5 no Status is asked of a template that has none" $s 0

# Given a repo template and PR template: off
# When the body fills no heading at all
# Then pr-guard checks nothing
printf 'x\n' >"$scratch/bare.md"
run own_off "gh pr create --draft --title T --body-file $scratch/bare.md"
check "RS-S3 E9 PR template: off checks nothing" $? 0

# Given a repo with no template
# When the body lacks Risk
# Then pr-guard still asks for ship-it's sections
run plain "gh pr create --draft --title T --body-file $scratch/norisk.md"
check "RS-S3 E6 a repo with no template keeps ship-it's sections" $? 2

# Given a repo with no template
# When the body has no How to try it, More cases or Related heading
# Then pr-guard accepts it
run plain "gh pr create --draft --title T --body-file $scratch/ours.md"
check "RS-S6 E7 a body with no Related or How to try it goes through" $? 0

exit $fail
