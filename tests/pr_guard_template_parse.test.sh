#!/usr/bin/env bash
# shellcheck disable=SC2016 # single quotes write a literal $1 into the stand-in gh and the jq filter
# Deathmatch findings on pr-guard's reading of a repo's pull request
# template: headings with regex characters, CRLF line endings, an Optional
# comment over several lines, and a template with no headings.
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
fail=0
run() {
  jq -nc --arg c "$2" --arg d "$scratch/$1" \
    '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, session_id: "s1", tool_input: {command: $c}}' |
    (cd "$scratch/$1" && bash "$hook") >"$scratch/out" 2>&1
}
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (exit $2, wanted $3)"; sed 's/^/     /' "$scratch/out"; fail=1; fi; }
tpl() { printf '%b' "$2" >"$scratch/$1/.github/pull_request_template.md"; }

# A heading with regex characters matches its own text.
repo meta on; tpl meta '## Why?\n\nx\n\n## C++ notes\n\nx\n'
printf '## Why?\n\nx\n\n## C++ notes\n\nx\n' >"$scratch/meta.md"
run meta "gh pr create --draft --title T --body-file $scratch/meta.md"
check "a heading with regex characters matches its own text" $? 0
printf '## Wh\n\nx\n\n## C++ notes\n\nx\n' >"$scratch/meta-short.md"
run meta "gh pr create --draft --title T --body-file $scratch/meta-short.md"
check "a heading with ? is not matched by a shorter one" $? 2

# A template saved with CRLF line endings still names its headings.
repo crlf on; tpl crlf '## Summary\r\n\r\ntext\r\n'
printf '## Summary\n\nx\n' >"$scratch/crlf.md"
run crlf "gh pr create --draft --title T --body-file $scratch/crlf.md"
check "a CRLF template's heading matches" $? 0

# An Optional comment over several lines is optional.
repo multi on; tpl multi '## Summary\n\nx\n\n## Notes\n\n<!--\nOptional: only if any.\n-->\n\n## Extra\n\n<!--\nFill it in,\nOptional or not. -->\n'
printf '## Summary\n\nx\n\n## Extra\n\nx\n' >"$scratch/multi.md"
run multi "gh pr create --draft --title T --body-file $scratch/multi.md"
check "an Optional comment over several lines is not asked for" $? 0
printf '## Summary\n\nx\n' >"$scratch/multi-noextra.md"
run multi "gh pr create --draft --title T --body-file $scratch/multi-noextra.md"
s=$?; grep -q 'Extra' "$scratch/out" || s=0
check "a comment with Optional later in it still asks for its heading" $s 2

# A template with no heading falls back to ship-it's four.
repo bare on; tpl bare 'Please describe your change.\n'
printf 'whatever\n' >"$scratch/bare.md"
run bare "gh pr create --draft --title T --body-file $scratch/bare.md"
check "a template with no heading asks for ship-it's sections" $? 2

exit $fail
