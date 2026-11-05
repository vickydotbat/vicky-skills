#!/usr/bin/env bash
# The session lister's new-session check with sessions in a repo that turned
# the familiar off: each one prints once, by its own id.
set -u
lister="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-sessions.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/p/-a" "$dir/s" "$dir/off/docs/agents"
printf 'Familiar: off\n' > "$dir/off/docs/agents/issue-tracker.md"
for id in 3333cccc 4444dddd; do printf '{"type":"user","cwd":"%s"}\n' "$dir/off" > "$dir/p/-a/$id.jsonl"; done
run() { FAMILIAR_PROJECTS_DIR="$dir/p" FAMILIAR_SESSIONS_DIR="$dir/s" FAMILIAR_SESSIONS_ROUNDS=1 FAMILIAR_SESSIONS_EVERY=0 CLAUDE_CODE_SESSION_ID=self timeout 20 bash "$lister" "$@"; }
out=$(run --new watched-elsewhere)
check "each new session in an off repo prints once as NEW OFF, by its own id" \
  '[ "$(grep -c "^NEW OFF " <<<"$out")" = 2 ] && grep -q "^NEW OFF 3333cccc " <<<"$out" && grep -q "^NEW OFF 4444dddd " <<<"$out"'
out=$(run --new)
check "off sessions live at the start count as known, so none prints as new" '[ -z "$out" ]'
mkdir -p "$dir/p2/-b" "$dir/crlf/docs/agents" "$dir/on/docs/agents" "$dir/repo/docs/agents" "$dir/repo/sub"
printf 'familiar: off \r\n' > "$dir/crlf/docs/agents/issue-tracker.md"
printf 'Familiar: on\n' > "$dir/on/docs/agents/issue-tracker.md"
printf 'Familiar: off\n' > "$dir/repo/docs/agents/issue-tracker.md"; git -C "$dir/repo" init -q
printf '{"type":"user","cwd":"%s"}\n' "$dir/crlf" > "$dir/p2/-b/5555eeee.jsonl"
printf '{"type":"user","cwd":"%s"}\n' "$dir/on" > "$dir/p2/-b/6666ffff.jsonl"
printf '{"type":"user","cwd":"%s"}\n' "$dir/repo/sub" > "$dir/p2/-b/7777aaaa.jsonl"
printf '{"type":"user"}\n' > "$dir/p2/-b/8888bbbb.jsonl"
out=$(FAMILIAR_PROJECTS_DIR="$dir/p2" FAMILIAR_SESSIONS_DIR="$dir/s" CLAUDE_CODE_SESSION_ID=self timeout 20 bash "$lister")
check "an off line in any case, with a trailing space or a carriage return, still turns the familiar off" 'grep -q "^OFF 5555eeee " <<<"$out"'
check "a repo whose doc says Familiar: on is watched" 'grep -q "^6666ffff " <<<"$out"'
check "a session in a subfolder of an off repo reads the repo root's doc" 'grep -q "^OFF 7777aaaa " <<<"$out"'
check "a session with no working folder is listed and watched" 'grep -q "^8888bbbb " <<<"$out"'
exit $fail
