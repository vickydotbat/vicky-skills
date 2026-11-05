#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses marking a pull request ready in a session
# that started `warp` but never `do`, or `do` but never `sentinels` or
# `review`, unless the body says "Skipped: <step>, because <reason>" for each
# missing step. A written reason never skips sentinels, whose manual pass
# covers any file type. It also refuses a do build's pull request whose body has no
# "Plan check: <what it found>" line. On GitHub that is `gh pr ready`. On
# Gitea it is `tea pr edit <n> -t <title>` with a title that has no "WIP:".
# Reads the session transcript for Skill calls. A failed body lookup lets the
# command through. Off unless the plugin option step_guard is true.
case "${CLAUDE_PLUGIN_OPTION_STEP_GUARD:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload")
forge=""
if [[ $cmd =~ gh[[:space:]]+pr[[:space:]]+ready([[:space:]]+([0-9]+))? ]]; then
  forge=gh pr=${BASH_REMATCH[2]}
elif [[ $cmd =~ tea[[:space:]]+(pulls|pull|pr)[[:space:]]+edit[[:space:]]+([0-9]+).*[[:space:]](-t|--title)[[:space:]=]+(\"[^\"]*\"|\'[^\']*\'|[^[:space:]]+) ]] &&
     [[ ${BASH_REMATCH[4]} != *WIP:* ]]; then
  forge=tea pr=${BASH_REMATCH[2]}
fi
[ -n "$forge" ] || exit 0
transcript=$(jq -r '.transcript_path // ""' <<<"$payload")
[ -f "$transcript" ] || exit 0 # mutant-ok delete: jq reads no skills from a missing file, and the next line exits 0
skills=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill' "$transcript" 2>/dev/null | sed 's/.*://')
grep -qxE 'do|warp' <<<"$skills" || exit 0
missing=()
grep -qx warp <<<"$skills" && ! grep -qx do <<<"$skills" && missing+=(do)
for step in sentinels review; do grep -qx "$step" <<<"$skills" || missing+=("$step"); done
if [ "$forge" = gh ]; then
  body=$(timeout 10 gh pr view ${pr:+"$pr"} --json body -q .body 2>/dev/null) || exit 0
else
  json=$(timeout 10 tea pr "$pr" --output json </dev/null 2>/dev/null) || exit 0
  body=$(jq -r '.body // empty' <<<"$json" 2>/dev/null) || exit 0
fi
unmet=(); skippable=()
for step in "${missing[@]}"; do
  if [ "$step" = sentinels ]; then unmet+=("$step"); continue; fi # a written reason never skips sentinels: its manual pass covers any file type
  grep -q "Skipped: $step, because " <<<"$body" || { unmet+=("$step"); skippable+=("$step"); }
done
if [ ${#unmet[@]} -gt 0 ]; then
  msg="this build never ran its ${unmet[*]} step. Run the ${unmet[*]} skill."
  [ ${#skippable[@]} -gt 0 ] && msg+=" For ${skippable[*]}, add 'Skipped: <step>, because <reason>' with its proof to the pull request body instead."
  grep -qx sentinels < <(printf '%s\n' "${unmet[@]}") && msg+=" Sentinels is never skipped: its manual pass covers any file type, and a 'Skipped: sentinels' line does not count."
  msg+=" A warp builds each star with do, and do runs sentinels on what it changed."
fi
grep -qx do <<<"$skills" && ! grep -qE '(^|[[:space:]])Plan check: [^<[:space:]]' <<<"$body" &&
  msg="${msg:+$msg }This do build's pull request body has no Plan check line: add one line 'Plan check: <what the check found>', or 'Plan check: none found'."
[ -n "$msg" ] || exit 0
echo "step-guard: $msg Then mark it ready again." >&2
exit 2
