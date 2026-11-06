#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses marking a pull request ready in a session
# that started `warp` but never `do`, or `do` but never `sentinels` or
# `review`, unless the body says "Skipped: <step>, because <reason>" for each
# missing step. A written reason never skips sentinels, whose manual pass
# covers any file type. It also refuses a do build's pull request whose body has no
# "Plan check: <what it found>" line. On GitHub that is `gh pr ready`. On
# Gitea it is `tea pr edit <n> -t <title>` with a title that has no "WIP:".
# Text that only names the command (a quoted string, a heredoc body) is no command.
# Reads the session transcript for Skill calls. A failed body lookup lets the
# command through. It also refuses one whose branch changed an approved
# example's Given, When or Then line with no ticked red-pen page for that
# file, and a do build whose body has no "Examples:" line. Off unless the
# plugin option step_guard is true.
case "${CLAUDE_PLUGIN_OPTION_STEP_GUARD:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload")
forge=""
# Text that only names the command is no command: heredoc bodies and quoted strings go before the gh match.
# A string or heredoc a shell runs (bash -c "...", eval '...', bash <<EOF) is code, so it stays.
# So does any command with a substitution ($( or a backtick) or a backslash, since quotes
# cannot be told apart there: the guard then reads it all and errs toward refusing.
# The tea branch below reads the whole command, since its title is a quoted string.
code=$(awk -v code=1 -f "$(dirname "$0")/heredoc-strip.awk" <<<"$cmd")
[[ $cmd =~ (^|[[:space:];\&\|\(])(bash|sh|zsh|eval)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*[\"\'] || $cmd =~ (^|[[:space:];\&\|\(])(ssh|watch)[[:space:]][^\;\&\|]*[\"\'] || $cmd =~ [[:space:]]-c[[:space:]]+[\"\'] || $cmd == *'$('* || $cmd == *'`'* || $cmd == *'\'* ]] ||
  code=$(sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g" <<<"$code")
if [[ $code =~ gh[[:space:]]+pr[[:space:]]+ready([[:space:]]+([0-9]+))? ]]; then
  forge=gh pr=${BASH_REMATCH[2]}
elif [[ $cmd =~ tea[[:space:]]+(pulls|pull|pr)[[:space:]]+edit[[:space:]]+([0-9]+).*[[:space:]](-t|--title)[[:space:]=]+(\"[^\"]*\"|\'[^\']*\'|[^[:space:]]+) ]] &&
     [[ ${BASH_REMATCH[4]} != *WIP:* ]]; then
  forge=tea pr=${BASH_REMATCH[2]}
fi
[ -n "$forge" ] || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$payload")
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null
# An approved example's wording (a Given, When or Then comment line in a file
# that holds approved examples) changes only through a ticked red-pen page,
# which writes the file's path to approved-spec-grants in the git folder. It
# reads the repo the payload's cwd names, and with no cwd it reads none.
. "$(dirname "$0")/approved-spec.sh"
msg="" wording=()
if [ -n "$cwd" ] && base=$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null); then
  grants="$(git rev-parse --absolute-git-dir 2>/dev/null)/approved-spec-grants"
  while IFS= read -r f; do
    approved "$f" || continue
    git cat-file -e "$base:$f" 2>/dev/null || continue # a new file's wording is approved through do's Examples line
    git diff "$base" -- "$f" | grep -qE '^[+-][[:space:]]*(#|//|--|;)[[:space:]]*(Given|When|Then)[[:space:]]' || continue
    grep -qxF -- "$f" "$grants" 2>/dev/null || wording+=("$f")
  done < <(git diff --name-only "$base" 2>/dev/null)
fi
[ ${#wording[@]} -gt 0 ] &&
  msg="approved wording changed in ${wording[*]} with no ticked red-pen page for it. Take the new wording through the examples skill's Changing an approved example, or restore the old lines."
transcript=$(jq -r '.transcript_path // ""' <<<"$payload")
skills="" # mutant-ok delete: an unset variable reads the same as an empty one
[ -f "$transcript" ] && skills=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill' "$transcript" 2>/dev/null | sed 's/.*://')
if ! grep -qxE 'do|warp' <<<"$skills"; then
  [ -n "$msg" ] || exit 0
  echo "step-guard: $msg Then mark it ready again." >&2
  exit 2
fi
missing=()
grep -qx warp <<<"$skills" && ! grep -qx do <<<"$skills" && missing+=(do)
for step in sentinels review; do grep -qx "$step" <<<"$skills" || missing+=("$step"); done
if [ "$forge" = gh ]; then
  body=$(timeout 10 gh pr view ${pr:+"$pr"} --json body -q .body 2>/dev/null) || exit 0
else
  json=$(timeout 10 tea pr "$pr" --output json </dev/null 2>/dev/null) || exit 0
  body=$(jq -r '.body // empty' <<<"$json" 2>/dev/null) || exit 0
fi
grep -qx do <<<"$skills" && ! grep -qE '(^|[[:space:]])Examples: [^<[:space:]]' <<<"$body" &&
  msg="${msg:+$msg }This do build's pull request body has no Examples line: add 'Examples: approved on <ticket>' or 'Examples: none, because <reason>'."
unmet=(); skippable=(); never="" # mutant-ok delete: an unset array or variable reads the same as an empty one
for step in "${missing[@]}"; do
  if [ "$step" = sentinels ]; then unmet+=("$step"); never=yes; continue; fi
  grep -q "Skipped: $step, because " <<<"$body" || { unmet+=("$step"); skippable+=("$step"); }
done
if [ ${#unmet[@]} -gt 0 ]; then
  msg="${msg:+$msg }this build never ran its ${unmet[*]} step. Run the ${unmet[*]} skill."
  [ ${#skippable[@]} -gt 0 ] && msg+=" For ${skippable[*]}, add 'Skipped: <step>, because <reason>' with its proof to the pull request body instead."
  [ -n "$never" ] && msg+=" Sentinels is never skipped: its manual pass covers any file type, and a 'Skipped: sentinels' line does not count."
  msg+=" A warp builds each star with do, and do runs sentinels on what it changed."
fi
grep -qx do <<<"$skills" && ! grep -qE '(^|[[:space:]])Plan check: [^<[:space:]]' <<<"$body" &&
  msg="${msg:+$msg }This do build's pull request body has no Plan check line: add one line 'Plan check: <what the check found>', or 'Plan check: none found'."
[ -n "$msg" ] || exit 0
echo "step-guard: $msg Then mark it ready again." >&2
exit 2
