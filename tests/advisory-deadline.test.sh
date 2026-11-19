#!/usr/bin/env bash
# advisory-deadline: the session-start reminder's window edges, a shipped
# fix, a published draft, another repo's drafts, and a project that is no repo.
set -u
. "$(dirname "$0")/lib/security-fixture.sh"
hook="$plugin/scripts/advisory-deadline.sh"
r=$(repo widget https://github.com/acme/widget.git)
start() { echo '{"hook_event_name":"SessionStart","source":"startup"}' | CLAUDE_PROJECT_DIR="${2:-$r}" bash "$hook" 2>&1; }
# draft <repo key> <id> <deadline offset days> <fixed> <state>: a kept draft.
draft() { mkdir -p "$fx/data/advisories/$1/$2"; jq -n --arg id "$2" --arg d "$(date -d "$3 days" +%F)" --arg f "$4" --arg s "$5" '{id:$id,route:"github",state:$s,fixed:$f,deadline:$d}' > "$fx/data/advisories/$1/$2/state.json"; }
draft acme-widget TODAY 0 "" draft; draft acme-widget SEVEN 7 "" draft; draft acme-widget EIGHT 8 "" draft
draft acme-widget SHIPPED 3 "2.4.1" draft; draft acme-widget DONE -5 "" published; draft acme-widget LATE -1 "2.4.1" draft
draft acme-other OTHER 1 "" draft
out=$(start); echo '{}' | CLAUDE_PROJECT_DIR="$r" bash "$hook" >/dev/null 2>&1; code=$?
check "the hook exits 0" '[ "$code" = 0 ]'
check "due today warns" 'grep -q "TODAY is due on $(date +%F)" <<<"$out"'
check "due in seven days warns" 'grep -q "SEVEN is due" <<<"$out"'
check "due in eight days is silent" '! grep -q "EIGHT" <<<"$out"'
check "a shipped fix due soon is silent" '! grep -q "SHIPPED" <<<"$out"'
check "a published advisory past its deadline is silent" '! grep -q "DONE" <<<"$out"'
check "a passed deadline with the fix shipped still warns" 'grep -q "LATE: the reporter.s deadline passed" <<<"$out"'
check "another repo's drafts are silent" '! grep -q "OTHER" <<<"$out"'
mkdir -p "$fx/plain"; check "a project that is no repo is silent" '[ -z "$(start x "$fx/plain")" ]'
check "no data folder is silent" '[ -z "$(echo "{}" | env -u CLAUDE_PLUGIN_DATA CLAUDE_PROJECT_DIR="$r" bash "$hook" 2>&1)" ]'
mkdir -p "$fx/data/advisories/acme-widget/ZZZ"; echo 'not json' > "$fx/data/advisories/acme-widget/ZZZ/state.json"
out=$(start); echo '{}' | CLAUDE_PROJECT_DIR="$r" bash "$hook" >/dev/null 2>&1; code=$?
check "a broken draft file is skipped and the rest still show" 'grep -q "TODAY" <<<"$out" && grep -q "SEVEN" <<<"$out" && [ "$code" = 0 ]'
check "the reminder runs on every session start: new, resumed, cleared and compacted" 'jq -e "[.hooks.SessionStart[] | select((.matcher // \"\") == \"\") | .hooks[].command | select(test(\"advisory-deadline\"))] | length == 1" "$plugin/hooks/hooks.json" >/dev/null'
exit $fail
