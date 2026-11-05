#!/usr/bin/env bash
# approved-spec: the O3 and O7 examples approved on the note "Charter for the
# workflow". E27 runs the session lister on a fixture; the rest read the
# instruction that drives the agent.
set -u
root="$(dirname "$0")/../plugins/vicky-skills"
fam="$root/skills/productivity/familiar/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$2" '$0 ~ "^"n"\\. "{on=1; print; next} /^[0-9]+\. /{on=0} /^## /{on=0} on' "$1"; }
close=$(step "$fam" 6)

# Given a watched session hands off
# When the familiar closes its list
# Then it reads that session's transcript whole against the session's first ask and each charter line, and logs each place the work broke one
check "E24 at handoff the familiar reads the transcript whole against the first ask and each charter line" \
  'grep -q "read the session'"'"'s transcript whole" <<<"$close" && grep -q "first ask" <<<"$close" && grep -q "each charter line" <<<"$close"'

# Given a session whose first ask named every tab, and whose work covered only the first tab
# When the familiar closes its list
# Then it logs a C1 snag naming the tabs the work left out
check "E25 an ask answered partly is a C1 snag naming what the work left out" \
  'grep -q "answered only in part" <<<"$close" && grep -q "C1 snag" <<<"$close" && grep -q "left out" <<<"$close"'

# Given first-contact sets up a repo
# When it writes the repo's tracker doc
# Then the doc holds the line Familiar: on, and says that off stops the familiar watching sessions there
ok=1
for t in "$root"/skills/engineering/first-contact/issue-tracker-*.md; do
  grep -qx 'Familiar: on' "$t" && grep -q 'to `off` to stop `familiar` watching sessions in this repo' "$t" || ok=0
done
check "E26 every tracker doc first-contact writes holds Familiar: on and how to turn it off" '[ $ok = 1 ]'

# Given a repo whose tracker doc says Familiar: off
# When the familiar lists the sessions to watch
# Then it watches no session working in that repo, and its reply says so
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/projects/-a" "$dir/projects/-b" "$dir/sessions" "$dir/quiet/docs/agents" "$dir/busy"
printf 'Familiar: off\n' > "$dir/quiet/docs/agents/issue-tracker.md"
printf '{"type":"user","cwd":"%s","message":{"content":"hi"}}\n' "$dir/quiet" > "$dir/projects/-a/1111aaaa.jsonl"
printf '{"type":"user","cwd":"%s","message":{"content":"hi"}}\n' "$dir/busy" > "$dir/projects/-b/2222bbbb.jsonl"
out=$(FAMILIAR_PROJECTS_DIR="$dir/projects" FAMILIAR_SESSIONS_DIR="$dir/sessions" CLAUDE_CODE_SESSION_ID=self bash "$root/skills/productivity/familiar/scripts/familiar-sessions.sh")
check "E27 a session in a repo with Familiar: off is not watched, and the familiar's reply names it" \
  'grep -q "^2222bbbb " <<<"$out" && ! grep -q "^1111aaaa " <<<"$out" && grep -q "^OFF 1111aaaa " <<<"$out" && step "$fam" 1 | grep -q "OFF"'

# Given a snag whose fix lands in a skill or hook of this plugin, and the familiar_plugin_repo setting names a checkout of the plugin
# When the familiar closes the list
# Then it builds the fix in that checkout
check "E28 a plugin fix is built in the checkout familiar_plugin_repo names" \
  'grep -q "familiar_plugin_repo" <<<"$close" && grep -q "build it in that checkout" <<<"$close" && jq -e ".userConfig.familiar_plugin_repo.default == \"\"" "$root/.claude-plugin/plugin.json" >/dev/null'

# Given the same snag, and familiar_plugin_repo unset
# When the familiar closes the list
# Then it files the fix on the watched repo's tracker, with a Waits on: line naming the plugin's repository
check "E29 with no plugin repo set, a plugin fix is filed on the watched repo's tracker, waiting on the plugin's repository" \
  'grep -q "unset, file it on the watched repo'"'"'s tracker" <<<"$close" && grep -q "Waits on:\` line naming the plugin'"'"'s repository" <<<"$close"'
exit $fail
