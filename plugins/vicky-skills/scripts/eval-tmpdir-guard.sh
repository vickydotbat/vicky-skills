#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses claude plugin eval when its TMPDIR sits under
# /tmp, /var/tmp, /dev/shm or /run/shm. The eval puts its run folder under
# TMPDIR, and its sandbox denies writes under those four roots after it allows
# the run folder, so every Bash write in a case fails as a read-only file system.
# Always on, with no setting: a refused run costs nothing, a run that goes ahead
# spends credits on cases that cannot pass. It fails closed: any TMPDIR= in an
# eval command must be a literal absolute path, or $XDG_RUNTIME_DIR under one.
# An eval inside a quoted string (bash -c "...", env -S "...") reads as text.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the read below comes back empty, and no eval matches
cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null)
cmd=$(awk -v code=1 -f "$(dirname "$0")/heredoc-strip.awk" <<<"$cmd")
# Quoted text is data: a commit message that names the eval never matches it.
masked=$(awk -f "$(dirname "$0")/quote-mask.awk" <<<"$cmd") && [ -n "$masked" ] || masked=$cmd # an unclosed quote reads the command unmasked
q="[\"']?"
eval_re="(^|[[:space:]/\"'])claude$q([[:space:]]+[^[:space:]]+)*[[:space:]]+${q}plugin$q[[:space:]]+${q}eval([\"'[:space:]]|$)"
grep -Eq "$eval_re" <<<"$masked" || exit 0
refuse() {
  echo "eval-tmpdir-guard: $1 Run it as TMPDIR=\"\$XDG_RUNTIME_DIR\" claude plugin eval ..., or through the repo's own eval runner when it has one. Nothing in this command ran." >&2
  exit 2
}
# under <path>: prints the denied root the path resolves under, if any.
under() {
  local real root # mutant-ok delete: the hook runs no other use of these names
  real=$(realpath -m -- "$1")
  for root in /tmp /var/tmp /dev/shm /run/shm; do
    case "$real/" in "$root"/*) echo "$real, under $root"; return ;; esac
  done
}
denied="where its own sandbox denies every write, so each Bash step in a case fails as a read-only file system."
unknown="is not a literal absolute path, so the guard cannot tell where claude plugin eval puts its run folder."
# Every TMPDIR= the command sets must be one the guard can resolve, and good.
while IFS= read -r val; do
  val=${val#*TMPDIR=}
  val=${val#[\"\']}; val=${val%[\"\']}
  val=${val//'${XDG_RUNTIME_DIR}'/${XDG_RUNTIME_DIR:-}}
  val=${val//'$XDG_RUNTIME_DIR'/${XDG_RUNTIME_DIR:-}}
  case "$val" in
    ""|[!/]*|*['$~`\\']*) refuse "TMPDIR=$val $unknown" ;;
  esac
  hit=$(under "$val")
  [ -z "$hit" ] || refuse "claude plugin eval would put its run folder in $hit, $denied"
done < <(grep -oE "(^|[^[:alnum:]_])TMPDIR=(\"[^\"]*\"|'[^']*'|[^[:space:];&|)\"']*)" <<<"$cmd")
# Each eval its own command gives no TMPDIR takes the one the command left:
# the session's, one an earlier statement set (a bare assignment reaches it
# only when TMPDIR is already exported), or none after unset, which is /tmp.
if [ -n "${TMPDIR+set}" ]; then state=session; else state=unset; fi
while IFS= read -r seg; do
  if grep -Eq '^[[:space:]]*export[[:space:]]+TMPDIR=[^[:space:]]*[[:space:]]*$' <<<"$seg"; then
    state=set
  elif grep -Eq '^[[:space:]]*TMPDIR=[^[:space:]]*[[:space:]]*$' <<<"$seg"; then
    [ "$state" = unset ] || state=set
  elif grep -Eq '^[[:space:]]*unset([[:space:]]+-v)?[[:space:]]+TMPDIR[[:space:]]*$' <<<"$seg"; then
    state=unset
  elif grep -Eq "$eval_re" <<<"$seg"; then
    pre=${seg%%claude*}
    grep -q 'TMPDIR=' <<<"$pre" && continue
    tmp=${TMPDIR:-/tmp}
    [ "$state" = set ] && continue
    { [ "$state" = unset ] || grep -Eq '(-u[[:space:]]*|--unset=)TMPDIR' <<<"$pre"; } && tmp=/tmp
    hit=$(under "$tmp")
    [ -z "$hit" ] || refuse "claude plugin eval would put its run folder in $hit, $denied"
  fi
done < <(tr ';&|(\n' '\n\n\n\n\n' <<<"$masked")
exit 0 # mutant-ok delete: the loop above ends with status 0 when it does not refuse
