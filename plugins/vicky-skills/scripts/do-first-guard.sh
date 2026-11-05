#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit): refuses an edit to production code
# (a source file in a git checkout, outside a test folder and not named as a
# test) until the session has started `do`, and then until that do build has
# approved examples. Every build runs through `do`, a warp's stars included.
# `spark-joy` passes on its own, since tests at its seam hold its behaviour,
# but a `do` started later needs examples like any other. Examples count when
# the user ticked them on a page for this branch: open-draft.sh writes the
# branch to examples-approved in the checkout's shared git folder, so a later
# session or another worktree on the branch reads it too. A reply line counts
# only when it asks for no approval: "Examples: none, because found work:
# <what>" followed by its drafted Given, When and Then lines, or "Examples:
# none, because <reason>" for a test the user never decides. A reason is real
# text, never a <placeholder>. A missing transcript lets the edit through. Off
# unless the plugin option step_guard is true.
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
ticked() { # the branch's examples were ticked on a page, in this session or an earlier one
  local branch common # mutant-ok delete: no later line reads branch or common, so a global copy changes nothing
  branch=$(git -C "$dir" symbolic-ref --short -q HEAD) &&
    common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir) &&
    grep -qxF -- "$branch" "$common/examples-approved" 2>/dev/null
}
# A test is no production code: a test or eval folder (IntegrationTests/ included), or
# a name that says test or spec. A reply line counts in chat text or a
# SendUserMessage, since brief mode sends every reply through the tool.
grep -qiE '(^|/)(tests?|spec|__tests__|testdata|fixtures|evals)/|(^|/)[A-Za-z]+Tests?/|(^|[._/-])(test|spec)s?([._-][^/]*)?\.[a-z]+$' <<<"$rel" && exit 0
transcript=$(jq -r '.transcript_path // empty' <<<"$payload")
[ -f "$transcript" ] || exit 0
marks=$(jq -r '
  if .type=="assistant" then .message.content[]? |
    if .type=="tool_use" and .name=="Skill" then (.input.skill // "" | sub(".*:";"")) |
      if .=="do" then "D" elif .=="spark-joy" then "S" else empty end
    elif ((if .type=="text" then .text elif .type=="tool_use" and .name=="SendUserMessage" then .input.message else null end) // "" |
      test("(^|\\n)Examples: none, because (?!found work)[^<\\s]") or
      (test("(^|\\n)Examples: none, because found work: [^<\\s]") and test("\\nGiven [^\\n]+\\nWhen [^\\n]+\\nThen [^\\n]+"))) then "E"
    else empty end
  elif .type=="user" and ((.message.content | if type=="string" then . else "" end) | test("<command-name>/(vicky-skills:)?do</command-name>")) then "D"
  else empty end' "$transcript" 2>/dev/null | tr -d '\n')
case "$marks" in
  *D*) [[ ${marks##*D} == *E* ]] && exit 0
       ticked && exit 0
       reason="this do build has no approved examples yet. Run the examples skill, which hands its drafts to the user through red-pen: the edit goes through once the user ticks them on the page, from a checkout on this branch. A line saying they are approved counts for nothing. For found work (a review finding, a bug a test caught), write \"Examples: none, because found work: <what>\" with its drafted Given, When and Then lines under it. For a test the user never decides, write \"Examples: none, because <reason>\". Then make this edit again." ;;
  *S*) exit 0 ;;
  *) reason="this session has not started the do skill. Every build runs through do, a warp's stars included: start do on the change now, and it writes the approved tests red before this edit." ;;
esac
jq -n --arg f "$rel" --arg r "$reason" '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: ("\($f) is production code, and \($r)")
}}'
exit 0 # mutant-ok delete: jq above leaves status 0, so the script ends the same way
