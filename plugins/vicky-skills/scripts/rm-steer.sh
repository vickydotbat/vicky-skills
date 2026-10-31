#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses an `rm -r` or `rm -f` whose path is built
# from a shell variable or a command substitution, and steers the agent to
# spell the path out. Claude Code's own removal check stops to ask the user
# about such a command; the steer means that prompt never comes. A plain
# `rm` of a file, a spelled-out path, and text that only mentions rm (in
# quotes or a heredoc body) pass. It reads rm as a command, alone or behind a
# wrapper such as sudo, nice or xargs; rm inside find -exec, bash -c or a
# command substitution passes, and Claude Code's prompt may still come.
# Off unless the plugin option guard_rm_steer is true.
case "${CLAUDE_PLUGIN_OPTION_GUARD_RM_STEER:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the read below comes back empty, and the hook exits 0 the same way
command=$(jq -r '.tool_input.command // ""' 2>/dev/null)
# Heredoc bodies and single-quoted text are data, never a command.
code=$(awk -f "$(dirname "$0")/heredoc-strip.awk" <<<"$command" | sed "s/'[^']*'//g")

while IFS= read -r segment; do
  read -ra words <<<"$segment"
  # Skip leading VAR=value assignments. A wrapper that runs another command
  # (sudo -u bob, nice -n 5, timeout 30, xargs) takes flags and values of
  # its own, so after one the first word that is rm is the command.
  i=0
  while [ "$i" -lt "${#words[@]}" ] && [[ ${words[$i]} == *=* ]]; do i=$((i + 1)); done
  case "${words[$i]:-}" in
    rm) ;;
    sudo | run0 | command | nice | env | timeout | nohup | xargs | time)
      while [ "$i" -lt "${#words[@]}" ] && [ "${words[$i]}" != rm ]; do i=$((i + 1)); done ;;
    *) continue ;;
  esac
  forced="" variable=""
  for word in "${words[@]:$((i + 1))}"; do
    case "$word" in
      --recursive | --force) forced=yes ;;
      --*) ;;
      -*[rRf]*) forced=yes ;;
      -*) ;;
      *'$'* | *'`'*) variable=${variable:-$word} ;;
    esac
  done
  if [ -n "$forced" ] && [ -n "$variable" ]; then
    echo "rm-steer: refused. $variable is built from a shell variable, so Claude Code's removal check would stop to ask the user. Spell the full path out in the rm command: print the variable first if you need its value, then run rm with that literal path." >&2
    exit 2
  fi
done < <(tr ';&|()\n' '\n\n\n\n\n\n' <<<"$code")
exit 0 # mutant-ok delete: the loop above leaves status 0
