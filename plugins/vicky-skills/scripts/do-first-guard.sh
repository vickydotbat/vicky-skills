#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit): refuses the first edit to
# production code in a session that never started `do`, and steers the agent
# to start it. Every build runs through `do`, a warp's stars included, so the
# approved tests go red before any code. Production code is a source file in
# a git checkout, outside a test folder and not named as a test. A session
# counts `do` from a Skill call or a typed /do in its transcript. `spark-joy`
# counts too: it refactors with behaviour held by the tests at its seam. A missing
# transcript lets the edit through. Off unless the plugin option step_guard
# is true.
case "${CLAUDE_PLUGIN_OPTION_STEP_GUARD:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$payload")
case "$file" in
  *.sh | *.bash | *.py | *.ts | *.tsx | *.js | *.jsx | *.mjs | *.cs | *.go | *.rs | *.nix | *.nss | *.java | *.kt | *.rb | *.lua | *.c | *.h | *.cpp | *.swift) ;;
  *) exit 0 ;;
esac
dir=$(dirname -- "$file")
while [ ! -d "$dir" ]; do dir=$(dirname -- "$dir"); done
top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
rel=${file#"$top"/}
# A test is no production code: a test folder, or a name that says test or spec.
grep -qiE '(^|/)(tests?|spec|__tests__|testdata|fixtures)/|(^|[._/-])(test|spec)s?([._-][^/]*)?\.[a-z]+$' <<<"$rel" && exit 0
transcript=$(jq -r '.transcript_path // empty' <<<"$payload")
[ -f "$transcript" ] || exit 0
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill' "$transcript" 2>/dev/null |
  sed 's/.*://' | grep -qxE 'do|spark-joy' && exit 0
grep -qE '<command-name>/(vicky-skills:)?do</command-name>' "$transcript" && exit 0
jq -n --arg f "$rel" '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: ("\($f) is production code, and this session has not started the do skill. Every build runs through do, a warp'"'"'s stars included: start do on the change now, and it writes the approved tests red before this edit.")
}}'
exit 0 # mutant-ok delete: jq above leaves status 0, so the script ends the same way
