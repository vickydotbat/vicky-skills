#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a heavy run (ImageMagick, Real-ESRGAN,
# ffmpeg, Blender, sd-cli, dotnet build or test, python on image or build
# work, nix develop or nix shell -c) that no systemd-run memory cap wraps, and
# prints the command with the cap in place. A timeout bounds time, not memory:
# an uncapped run froze a desktop. A repo declares its self-capping scripts on
# a "Bounded scripts: <glob> ..." line in docs/agents/*.md. Off unless the
# plugin option guard_heavy_run is true. Needs jq and gawk; without them it
# says so and stays off.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_HEAVY_RUN:-}" in true | 1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || { echo "heavy-run-guard: jq is missing, guard is off" >&2; exit 0; } # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
command -v gawk >/dev/null || { echo "heavy-run-guard: gawk is missing, guard is off" >&2; exit 0; } # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
# The cap it steers to is systemd-run's, so a system without systemd has none to offer.
command -v systemd-run >/dev/null || exit 0
here="$(dirname "$0")"
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null)
# A heredoc body is text, unless the heredoc feeds a shell. Python reads its
# heredoc as code, so heavy-run.awk sees the whole command as HEAVY_RAW.
raw=$cmd
cmd=$(gawk -v code=1 -f "$here/heredoc-strip.awk" <<<"$cmd")
top=$(git -C "$(jq -r '.cwd // "."' <<<"$payload" 2>/dev/null)" rev-parse --show-toplevel 2>/dev/null)
# Each declared glob becomes a regex: * and ? stay inside one folder.
decl=$([ -n "$top" ] && sed -n 's/^Bounded scripts:[[:space:]]*//p' "$top"/docs/agents/*.md 2>/dev/null \
  | tr ' ' '\n' | sed '/^$/d; s/[.]/\\./g; s/[*]/[^\/]*/g; s/[?]/[^\/]/g' | paste -sd'|')
fixed=$(printf '%s' "$cmd" | HEAVY_RAW=$raw gawk -v decl="$decl" -f "$here/heavy-run.awk")
[ -n "$fixed" ] || exit 0
echo "heavy-run-guard: a heavy run needs a memory cap (systemd-run with MemoryMax=), since a timeout alone lets it fill memory and freeze the desktop; run it like this:" >&2
printf '%s\n' "$fixed" "Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2
exit 2
