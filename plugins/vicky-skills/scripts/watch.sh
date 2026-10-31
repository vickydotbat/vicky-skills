#!/usr/bin/env bash
# The one way an agent waits: runs a check every 30 seconds, at most 60
# times, and prints a line only when the check's output changes. Exits 0 when
# the check passes, 3 after the last round with what it still waits on.
# Run it under Monitor or as a background command.
set -u
usage() {
  cat <<'EOF'
usage: watch.sh '<check>' [--every SECONDS] [--rounds N]
Runs the check every 30 seconds, at most 60 times, unless told otherwise.
Prints the check's output each time it changes. Exits 0 when the check
exits 0, and 3 after the last round, naming what it still waits on.
EOF
}
check="" every=30 rounds=60
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --every) every=${2:-}; shift 2 ;;
    --rounds) rounds=${2:-}; shift 2 ;;
    *) check=$1; shift ;;
  esac
done
case "$every$rounds" in *[!0-9]*|'') usage >&2; exit 2 ;; esac
[ -n "$check" ] || { usage >&2; exit 2; }
last=""
for ((round = 1; round <= rounds; round++)); do
  out=$(bash -c "$check" 2>&1); status=$?
  [ "$out" != "$last" ] && printf '%s\n' "$out"
  last=$out
  [ $status = 0 ] && exit 0
  [ $round -lt "$rounds" ] && sleep "$every"
done
echo "watch: $rounds rounds passed, still waits on: $check"
exit 3
