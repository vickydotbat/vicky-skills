#!/usr/bin/env bash
# PreToolUse hook (Bash): a session that read outside text (deathmatch's
# mark-outside.sh recorded it) pushes nothing, files nothing and posts
# nothing. Outside text can be written to steer the agent that reads it, so
# the run that reads it only returns findings, and a person or a later run
# acts on them. On unless the plugin option guard_outside_text is false or 0.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_OUTSIDE_TEXT:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq every read below comes back empty and the guard exits 0
input=$(cat)
sid=$(jq -r '.session_id // ""' <<<"$input" 2>/dev/null)
[ -n "$sid" ] && [ -s "${CLAUDE_PLUGIN_DATA:-/nonexistent}/outside-read/$sid" ] || exit 0
command=$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null)
# Deny by default for the tools that reach a forge or a remote: each command
# segment that runs gh, tea, gs, git-spice, curl or wget, or a git push or
# send-pack, is refused unless it is a known read. shortcut: a tool named
# through a variable or an alias slips past, until the wall moves to a
# read-only agent.
writes=0
while IFS= read -r seg; do
  seg=$(sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//' <<<"$seg")
  read -r tool rest <<<"$seg"
  case ${tool##*/} in
    git) grep -Eq '(^|[[:space:]])(push|send-pack)([[:space:]]|$)' <<<"$rest" && writes=1 ;;
    gh) # gh's own flags, such as -R <repo>, come before the verb
      words=$(sed -E 's/(^|[[:space:]])(-R|--repo|--hostname)[[:space:]]+[^[:space:]]+//g' <<<"$rest")
      if [[ $words =~ ^[[:space:]]*api([[:space:]]|$) ]]; then
        grep -Eq '(^|[[:space:]])(-X|--method)[[:space:]=]*(POST|PATCH|PUT|DELETE)|(^|[[:space:]])(-f|-F|--field|--raw-field|--input)([[:space:]=]|$)|graphql' <<<"$words" && writes=1
      else
        grep -Eq '^[[:space:]]*[a-z-]+[[:space:]]+(view|list|diff|checks|status|download)([[:space:]]|$)|^[[:space:]]*(status|search|browse)([[:space:]]|$)' <<<"$words" || writes=1
      fi ;;
    tea) grep -Eq '^[[:space:]]*(pr|pulls|issue|issues)[[:space:]]+([0-9]+|list|ls)([[:space:]]|$)|^[[:space:]]*(pr|pulls|issue|issues)[[:space:]]*$' <<<"$rest" || writes=1 ;;
    gs | git-spice) grep -Eq '(^|[[:space:]])(submit|ss|bs|us)([[:space:]]|$)' <<<"$rest" && writes=1 ;;
    curl | wget) grep -Eq '(^|[[:space:]])(-X|--request)[[:space:]=]*(POST|PATCH|PUT|DELETE)|(^|[[:space:]])(-d|--data[a-z-]*|-F|--form|-T|--upload-file|--post-data|--post-file)([[:space:]=]|$)' <<<"$rest" && writes=1 ;;
  esac
done < <(sed -E 's/(\|\||\||&&|;|&|\$\(|`)/\n/g' <<<"$command")
[ "$writes" = 1 ] || exit 0
read_what=$(tail -1 "$CLAUDE_PLUGIN_DATA/outside-read/$sid")
echo "outside-text-guard: this session read outside text ($read_what), so it writes nothing to the forge or the remote. Return your findings to the user instead: a person or a later run acts on them. Nothing in this command ran." >&2
exit 2
