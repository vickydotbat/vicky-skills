#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses pkill -f. It matches every command line
# holding the pattern, the shell running this very command among them, so it
# stops the agent's own shell. Memory is the OS's job: the agent runs inside a
# capped scope, so a heavy command needs no cap of its own.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the read below comes back empty, and no pkill matches
cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null)
cmd=$(awk -v code=1 -f "$(dirname "$0")/heredoc-strip.awk" <<<"$cmd")
if grep -Eq '(^|[;&|(]|[[:space:]])pkill([[:space:]]+-[[:alnum:]]+)*[[:space:]]+(-[[:alnum:]]*f[[:alnum:]]*|--full)([[:space:]]|$)' <<<"$cmd"; then
  echo "pkill-guard: pkill -f matches the shell running this command too, since its command line holds the pattern. Stop what you started by the process id you saved when you started it (kill <pid>), or match the process name exactly with pkill -x <name>. Nothing in this command ran." >&2
  exit 2
fi
exit 0 # mutant-ok delete: the if above ends with status 0 when it does not refuse
