#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses claude plugin eval when its TMPDIR sits under
# /tmp, /var/tmp, /dev/shm or /run/shm. The eval puts its run folder under
# TMPDIR, and its sandbox denies writes under those four roots after it allows
# the run folder, so every Bash write in a case fails as a read-only file system.
# Always on, with no setting: a refused run costs nothing, a run that goes ahead
# spends credits on cases that cannot pass.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the read below comes back empty, and no eval matches
cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null)
cmd=$(awk -v code=1 -f "$(dirname "$0")/heredoc-strip.awk" <<<"$cmd")
seg=$(grep -E '(^|[;&|(]|[[:space:]])claude[[:space:]]+plugin[[:space:]]+eval([[:space:]]|$)' <<<"$cmd" | head -n1)
[ -n "$seg" ] || exit 0
# The TMPDIR the eval sees: an inline assignment in its own command wins.
seg=${seg%%claude*plugin*eval*}
seg=${seg##*[;&|(]}
tmp=${TMPDIR:-/tmp}
inline=$(grep -oE '(^|[[:space:]])TMPDIR=("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]*)' <<<"$seg" | tail -n1)
if [ -n "$inline" ]; then
  tmp=${inline#*TMPDIR=}
  tmp=${tmp#[\"\']}; tmp=${tmp%[\"\']}
  tmp=${tmp//'${XDG_RUNTIME_DIR}'/${XDG_RUNTIME_DIR:-}}
  tmp=${tmp//'$XDG_RUNTIME_DIR'/${XDG_RUNTIME_DIR:-}}
  [ -n "$tmp" ] || tmp=/tmp
fi
real=$(realpath -m -- "$tmp" 2>/dev/null) || real=$tmp
for root in /tmp /var/tmp /dev/shm /run/shm; do
  case "$real/" in
    "$root"/*)
      echo "eval-tmpdir-guard: claude plugin eval would put its run folder in $real, under $root, where its own sandbox denies every write, so each Bash step in a case fails as a read-only file system. Run it as TMPDIR=\"\$XDG_RUNTIME_DIR\" claude plugin eval ..., or through the repo's own eval runner when it has one. Keep TMPDIR short: a long path fails the sandbox's socket setup. Nothing in this command ran." >&2
      exit 2
      ;;
  esac
done
exit 0 # mutant-ok delete: the loop above ends with status 0 when it does not refuse
