#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit): refuses the first edit to
# production code in a session that never started `do`, and steers the agent
# to start it. Every build runs through `do`, a warp's stars included, so the
# approved tests go red before any code. Production code is a source file in
# a git checkout, outside a test folder and not named as a test. A session
# counts `do` from a Skill call or a typed /do in its transcript. `spark-joy`
# counts too: it refactors with behaviour held by the tests at its seam. A missing
# transcript lets the edit through. Once do has started, the edit also waits
# for approved examples: an examples or red-pen start after the latest do, or
# an "Examples: approved on" or "Examples: none, because" line. Off unless the plugin option step_guard
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
# One mark per event, in order: D a do start, S a spark-joy start, E an
# examples or red-pen start, or the agent's "Examples: approved on <ticket>"
# or "Examples: none, because <reason>" line.
marks=$(jq -r '
  if .type=="assistant" then .message.content[]? |
    if .type=="tool_use" and .name=="Skill" then (.input.skill // "" | sub(".*:";"")) |
      if .=="do" then "D" elif .=="spark-joy" then "S" elif .=="examples" or .=="red-pen" then "E" else empty end
    elif .type=="text" and ((.text // "") | test("(^|\\n)Examples: (approved on |none, because )")) then "E"
    else empty end
  elif .type=="user" and ((.message.content | if type=="string" then . else "" end) | test("<command-name>/(vicky-skills:)?do</command-name>")) then "D"
  else empty end' "$transcript" 2>/dev/null | tr -d '\n')
case "$marks" in
  *D*) ;;
  *S*) exit 0 ;;
  *) jq -n --arg f "$rel" '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: ("\($f) is production code, and this session has not started the do skill. Every build runs through do, a warp'"'"'s stars included: start do on the change now, and it writes the approved tests red before this edit.")
}}'
     exit 0 ;; # mutant-ok delete: jq above leaves status 0, so the script ends the same way
esac
# do has started: its code waits for approved examples after the latest start.
[[ ${marks##*D} == *E* ]] && exit 0
jq -n --arg f "$rel" '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: ("\($f) is production code, and this do build has no approved examples yet. Run the examples skill, which hands its drafts to the user through red-pen, and write code once each one comes back ticked. When the ticket already holds approved examples, write the line \"Examples: approved on <ticket>\" in a reply. When no example needs the user (examples'"'"' \"Approval is for what the human asks for or designs\"), write \"Examples: none, because <reason>\". Then make this edit again.")
}}'
exit 0 # mutant-ok delete: jq above leaves status 0, so the script ends the same way
