#!/usr/bin/env bash
# approved-spec: the O3 and O7 examples approved on the note "Charter for the
# workflow". E27 runs the session lister on a fixture.
set -u
root="$(dirname "$0")/../plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a repo whose tracker doc says Familiar: off
# When the familiar lists the sessions to watch
# Then it watches no session working in that repo, and its reply says so
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/projects/-a" "$dir/projects/-b" "$dir/sessions" "$dir/quiet/docs/agents" "$dir/busy"
printf 'Familiar: off\n' > "$dir/quiet/docs/agents/issue-tracker.md"
printf '{"type":"user","cwd":"%s","message":{"content":"hi"}}\n' "$dir/quiet" > "$dir/projects/-a/1111aaaa.jsonl"
printf '{"type":"user","cwd":"%s","message":{"content":"hi"}}\n' "$dir/busy" > "$dir/projects/-b/2222bbbb.jsonl"
out=$(FAMILIAR_PROJECTS_DIR="$dir/projects" FAMILIAR_SESSIONS_DIR="$dir/sessions" CLAUDE_CODE_SESSION_ID=self bash "$root/skills/commands/familiar/scripts/familiar-sessions.sh")
check "E27 a session in a repo with Familiar: off is not watched, and the familiar's reply names it" \
  'grep -q "^2222bbbb " <<<"$out" && ! grep -q "^1111aaaa " <<<"$out" && grep -q "^OFF 1111aaaa " <<<"$out"'

exit $fail
