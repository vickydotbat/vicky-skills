#!/usr/bin/env bash
# approved-spec: the examples ticked on the drafts page for summit-automatic,
# 2026-11-20, and the verdict examples approved on the star "Summit: an
# opened-versus-closed record", 2026-11-01. Each check runs the session-start
# hooks in a fixture repo, then reads the line the band shows with
# summit.sh show, so each check sees what the session sees.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
summit="$plugin/scripts/summit.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/bin" "$fx/repo/docs/agents" "$fx/data"
printf '#!/usr/bin/env bash\necho "[]"\n' > "$fx/bin/gh"; chmod +x "$fx/bin/gh"
export PATH="$fx/bin:$PATH" CLAUDE_PROJECT_DIR="$fx/repo" CLAUDE_PLUGIN_DATA="$fx/data" CLAUDE_PLUGIN_ROOT="$plugin"
git -C "$fx/repo" init -q
printf '.todo\n' > "$fx/repo/.gitignore"
doc="$fx/repo/docs/agents/issue-tracker.md"
stamp="$fx/repo/.git/summit-last-session"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# A tracker doc whose count prints <since> for the time of the last session
# and <thirty> for the date 30 days ago.
counts() { printf '# Tickets\n\nSummit count: `case "$SUMMIT_SINCE" in *T*) echo %s ;; *) echo %s ;; esac`\n' "$1" "$2" > "$doc"; }
# The agent's words from every session-start hook that speaks of the summit.
start() {
  local in='{"hook_event_name":"SessionStart","source":"startup"}'
  { echo "$in" | bash "$plugin/scripts/summit.sh" auto; echo "$in" | bash "$plugin/scripts/springboard.sh"; } 2>/dev/null
}
band() { (cd "$fx/repo" && bash "$summit" show 2>/dev/null); }
fresh() { rm -f "$fx/repo/.git/summit-line" "$stamp"; }
verdict() { fresh; counts "0 0" "$1 $2"; start >/dev/null; band | grep -o '30 days: .*'; }

# Given a repo whose tracker doc has a Summit count line, and your last session started on Friday
# When a session starts
# Then the band shows Since Fri: 0 opened, 3 closed · 30 days: +322 / −30, C
# And the agent is told nothing about tracker counts or the summit
fresh; counts "0 3" "322 30"; date -d '2 days ago' -Iseconds > "$stamp"
told=$(start)
check "SA1 the band shows the summit with no agent work" \
  '[ "$(band)" = "summit: Since $(date -d "2 days ago" +%a): 0 opened, 3 closed · 30 days: +322 / −30, C" ] && ! grep -qi "summit\|tracker\|opened" <<<"$told"'

# Given a repo whose tracker doc has no Summit count line
# When a session starts
# Then the band shows no summit line, and the agent is told nothing about it
fresh; printf '# Tickets\n' > "$doc"; told=$(start)
check "SA2 no Summit count line, no summit" '[ -z "$(band)" ] && ! grep -qi "summit\|tracker" <<<"$told"'

# Given a repo whose Summit count command fails or prints something that is not two numbers
# When a session starts
# Then the band shows no summit line, and the agent is told nothing about it
fresh; printf 'Summit count: `false`\n' > "$doc"; told=$(start)
fresh2=$(band)
fresh; printf 'Summit count: `echo lots`\n' > "$doc"; told2=$(start)
check "SA3 a count that fails shows nothing" '[ -z "$fresh2" ] && [ -z "$(band)" ] && ! grep -qi "summit" <<<"$told$told2"'

# Given a repo whose Summit count command never ends
# When a session starts
# Then the session opens within the hook's time limit, with no summit line
fresh; printf 'Summit count: `sleep 60`\n' > "$doc"
limit=$(jq '[.hooks.SessionStart[].hooks[] | select(.command | test("summit.sh"))][0].timeout' "$plugin/hooks/hooks.json" 2>/dev/null)
t0=$(date +%s); start >/dev/null; took=$(( $(date +%s) - t0 ))
check "SA4 a count that hangs never holds up the session" '[ -n "$limit" ] && [ "$limit" != null ] && [ "$took" -lt "$limit" ] && [ -z "$(band)" ]'

# Given no earlier session in this repo
# When a session starts
# Then the band shows only the 30-day part: 30 days: +611 / −451, C
fresh; counts "4 9" "611 451"; start >/dev/null
check "SA5 first session in a repo" '[ "$(band)" = "summit: 30 days: +611 / −451, C" ]'

# Given an Obsidian tracker and the obsidian_vault setting naming your vault
# When a session starts
# Then the band counts that vault's notes
# And with the setting empty, the band shows no summit line
fresh; vault="$fx/vault"; mkdir -p "$vault/proj"
printf 'Summit count: `bash "$CLAUDE_PLUGIN_ROOT/scripts/summit-obsidian.sh" "$CLAUDE_PLUGIN_OPTION_OBSIDIAN_VAULT/proj"`\n' > "$doc"
printf -- '---\nstatus: open\n---\n' > "$vault/proj/$(date -d '1 day ago' +%Y%m%d%H%M%S) New one.md"
printf -- '---\nstatus: done\nclosed: %s\n---\n' "$(date +%F)" > "$vault/proj/$(date -d '60 days ago' +%Y%m%d%H%M%S) Old one.md"
touch -d '60 days ago' "$vault/proj/"*Old*
date -d '2 days ago' -Iseconds > "$stamp"
CLAUDE_PLUGIN_OPTION_OBSIDIAN_VAULT="$vault" start >/dev/null; seen=$(band)
fresh; CLAUDE_PLUGIN_OPTION_OBSIDIAN_VAULT= start >/dev/null
check "SA6 an Obsidian tracker reads the vault from the plugin setting" \
  '[ "$seen" = "summit: Since $(date -d "2 days ago" +%a): 1 opened, 1 closed · 30 days: +1 / −1, B" ] && [ -z "$(band)" ]'

# Given 611 tickets opened and 451 closed in the last 30 days
# When a session starts
# Then the line ends 30 days: +611 / −451, C
check "the 30-day verdict, C" '[ "$(verdict 611 451)" = "30 days: +611 / −451, C" ]'

# Given 100 tickets opened and 111 closed in the last 30 days
# When a session starts
# Then the verdict is A
check "the 30-day verdict, A" 'verdict 100 111 | grep -q ", A$"'

# Given 100 tickets opened and 110 closed in the last 30 days
# When a session starts
# Then the verdict is B
check "B at the top edge" 'verdict 100 110 | grep -q ", B$"'

# Given 100 tickets opened and 90 closed in the last 30 days
# When a session starts
# Then the verdict is B
check "B at the bottom edge" 'verdict 100 90 | grep -q ", B$"'

# Given 100 tickets opened and 89 closed in the last 30 days
# When a session starts
# Then the verdict is C
check "just below B" 'verdict 100 89 | grep -q ", C$"'

# Given no tickets opened and none closed in the last 30 days
# When a session starts
# Then the verdict is B
check "nothing happened" 'verdict 0 0 | grep -q ", B$"'

# Given no tickets opened and 3 closed in the last 30 days
# When a session starts
# Then the verdict is A
check "only closing" 'verdict 0 3 | grep -q ", A$"'

# The band's examples run in Claude Code's mod test kit, from
# plugins/vicky-skills/tests/summit_approved_examples.test.tsx.
check "the band's summit examples pass in the mod test kit" \
  'out=$(timeout 120 claude plugin test "$plugin" 2>&1) && [ "$(grep -c "^(pass) summit > " <<<"$out")" = 3 ]'
exit $fail
