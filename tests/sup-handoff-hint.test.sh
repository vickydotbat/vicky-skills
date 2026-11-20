#!/usr/bin/env bash
# sup-handoff-hint.sh runs the handoff finder when sup starts, typed or called,
# and hands its output to the agent; it stays silent for anything else, when
# turned off, and without jq. The finder is a stub, so no tracker is reached.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/sup-handoff-hint.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/plugin/scripts" "$dir/plugin/skills/housekeeping/sup/scripts" "$dir/work"
cp "$hook" "$dir/plugin/scripts/"
printf '#!/usr/bin/env bash\necho "found: in $(pwd)"\n' > "$dir/plugin/skills/housekeeping/sup/scripts/find-handoff.sh"
printf '#!/usr/bin/env bash\necho "done: - a line in $(pwd)"\n' > "$dir/plugin/skills/housekeeping/sup/scripts/parked-state.sh"
fail=0
run() { TMPDIR="$(mktemp -d -p "$dir")" CLAUDE_PLUGIN_ROOT="${proot-$dir/plugin}" CLAUDE_PLUGIN_OPTION_SUP_HANDOFF_HINT="${opt-}" bash "$dir/plugin/scripts/sup-handoff-hint.sh" <<<"$1" 2>&1; }
has() { if grep -qF -- "$2" <<<"$3"; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
none() { if [ -z "$2" ] && [ "${code:-0}" = 0 ]; then echo "ok   $1"; else echo "FAIL $1: got '$2'"; fail=1; fi; }
p() { jq -nc --arg p "$1" --arg c "$dir/work" '{hook_event_name:"UserPromptSubmit",prompt:$p,cwd:$c}'; }
s() { jq -nc --arg s "$1" --arg c "$dir/work" '{hook_event_name:"PostToolUse",tool_input:{skill:$s},cwd:$c}'; }
out=$(run "$(p '/sup')")
has "typed /sup runs the finder in the session's folder" "found: in $dir/work" "$out"
has "typed /sup answers as UserPromptSubmit" '"hookEventName":"UserPromptSubmit"' "$out"
has "an expanded /vicky-skills:sup command runs it" "found: in" "$(run "$(p '<command-name>/vicky-skills:sup</command-name>')")"
has "/sup with words after it runs it" "found: in" "$(run "$(p '/sup since lunch')")"
out=$(run "$(p 'what does /sup do')"); code=$?; none "a prompt that only mentions sup is skipped" "$out"; code=0
none "/super is not /sup" "$(run "$(p '/super')")"
out=$(run "$(s vicky-skills:sup)")
has "the sup skill called as a tool runs it" "found: in" "$out"
has "the skill call answers as PostToolUse" '"hookEventName":"PostToolUse"' "$out"
out=$(run "$(s vicky-skills:do)"); code=$?; none "another skill is skipped" "$out"; code=0
none "another event is skipped" "$(run '{"hook_event_name":"Stop"}')"
opt=false; out=$(run "$(p '/sup')"); code=$?; none "the setting off skips it" "$out"; code=0
opt=0; none "the setting 0 skips it" "$(run "$(p '/sup')")"
opt=true; has "the setting on runs it" "found: in" "$(run "$(p '/sup')")"
unset opt
m=$(mktemp -d -p "$dir"); once() { TMPDIR="$m" CLAUDE_PLUGIN_ROOT="$dir/plugin" bash "$dir/plugin/scripts/sup-handoff-hint.sh" <<<"$1"; }
has "a typed /sup runs the finder" "found: in" "$(once "$(p '/sup' | jq -c '.session_id="a"')")"
out=$(once "$(s sup | jq -c '.session_id="a"')"); code=$?; none "the skill call after it in the same session runs nothing" "$out"; code=0
has "another session still runs it" "found: in" "$(once "$(s sup | jq -c '.session_id="b"')")"
touch -d '11 minutes ago' "$m/sup-handoff-a"
has "a sup ten minutes later runs it again" "found: in" "$(once "$(s sup | jq -c '.session_id="a"')")"
has "typed /sup hands over each .todo line's verdict, read in the session's folder" "done: - a line in $dir/work" "$(run "$(p '/sup')")"
printf '#!/usr/bin/env bash\necho early; sleep 5\n' > "$dir/plugin/skills/housekeeping/sup/scripts/parked-state.sh"
out=$(SUP_PARKED_LIMIT=1 run "$(p '/sup')")
has "a parked-state run cut off at its limit keeps what it printed" "early" "$out"
has "a parked-state run cut off at its limit says so" "parked-state.sh hit its 1-second limit" "$out"
printf '#!/usr/bin/env bash\necho "done: - a line in $(pwd)"\n' > "$dir/plugin/skills/housekeeping/sup/scripts/parked-state.sh"
proot=""; has "with no plugin root it finds the finder beside itself" "found: in" "$(run "$(p '/sup')")"; unset proot
printf '#!/usr/bin/env bash\necho partial; sleep 5\n' > "$dir/plugin/skills/housekeeping/sup/scripts/find-handoff.sh"
out=$(SUP_HANDOFF_LIMIT=1 run "$(p '/sup')")
has "a finder cut off at its limit keeps what it printed" "partial" "$out"
has "a finder cut off at its limit says so" "not read: the rest, the finder hit its 1-second limit" "$out"
printf '#!/usr/bin/env bash\n' > "$dir/plugin/skills/housekeeping/sup/scripts/find-handoff.sh"
has "a silent finder says to run it by hand" "printed nothing: run it by hand" "$(run "$(p '/sup')")"
mkdir -p "$dir/nobin"; for t in bash cat sed grep mktemp; do ln -s "$(command -v "$t")" "$dir/nobin/$t"; done
none "without jq it stays silent" "$(PATH="$dir/nobin" run "$(p '/sup')")"
exit $fail
