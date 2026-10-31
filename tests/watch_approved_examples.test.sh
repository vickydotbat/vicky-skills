#!/usr/bin/env bash
# approved-spec: the examples approved on the star "One watch script for every
# wait". Each check is named after its example. The watch and the hook are
# run; the skill checks read the instruction that drives the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
watch="$root/plugins/vicky-skills/scripts/watch.sh"
pace="$root/plugins/vicky-skills/scripts/poll-pace.sh"
skills="$root/plugins/vicky-skills/skills"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# A check that counts its rounds in a file and passes from round $1 on.
cat > "$dir/count.sh" <<'SH'
n=$(( $(cat "$2" 2>/dev/null || echo 0) + 1 )); echo $n > "$2"
[ "$n" -ge "$1" ]
SH
timeout 20 bash "$watch" "bash $dir/count.sh 3 $dir/a" --every 0 --rounds 10 > "$dir/a.out" 2>&1; a=$?
check "a check that first passes on its third round ends the watch with exit 0 on the third round" \
  '[ $a = 0 ] && [ "$(cat "$dir/a")" = 3 ]'
timeout 20 bash "$watch" "bash $dir/count.sh 99 $dir/b" --every 0 --rounds 3 > "$dir/b.out" 2>&1; b=$?
check "a check that never passes ends a 3-round watch with exit 3 after the third round, with a line naming what it still waits on" \
  '[ $b = 3 ] && [ "$(cat "$dir/b")" = 3 ] && tail -1 "$dir/b.out" | grep -q "still waits on: bash $dir/count.sh 99"'
cat > "$dir/change.sh" <<'SH'
n=$(( $(cat "$1" 2>/dev/null || echo 0) + 1 )); echo $n > "$1"
[ "$n" -ge 3 ] && echo second || echo first
[ "$n" -ge 5 ]
SH
timeout 20 bash "$watch" "bash $dir/change.sh $dir/c" --every 0 --rounds 5 > "$dir/c.out" 2>&1
check "a check whose output changes once in five rounds prints a line for the first output and one for the change, and nothing between" \
  '[ "$(grep -c first "$dir/c.out")" = 1 ] && [ "$(grep -c second "$dir/c.out")" = 1 ] && [ "$(wc -l < "$dir/c.out")" = 2 ]'
check "a watch with no --every or --rounds checks every 30 seconds, at most 60 times" \
  'bash "$watch" --help | grep -q "every 30 seconds" && bash "$watch" --help | grep -q "at most 60 times"'
decide() { jq -n --arg c "$1" --argjson bg "${2:-false}" '{tool_name: "Bash", tool_input: {command: $c, run_in_background: $bg}}' | CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=true bash "$pace" 2>"$dir/why"; echo $?; }
check "with the poll-pace guard on, a foreground loop that sleeps and checks is refused, and the refusal names watch.sh and the Monitor call that runs it" \
  '[ "$(decide "while true; do gh pr status; sleep 10; done")" = 2 ] && grep -q "watch.sh" "$dir/why" && grep -q "Monitor" "$dir/why" && [ "$(decide "for i in \$(seq 1 5); do curl -s x && break; sleep 5; done")" = 2 ]'
check "with the poll-pace guard on, one blocking watch such as gh pr checks --watch, or watch.sh itself, runs" \
  '[ "$(decide "gh pr checks 5 --watch --required")" = 0 ] && [ "$(decide "bash scripts/watch.sh \"gh pr status\" --every 30")" = 0 ]'
check "with the poll-pace guard on, a sleeping loop run as a background command runs" \
  '[ "$(decide "while true; do gh pr status; sleep 10; done" true)" = 0 ]'
ok=0
for f in engineering/warp engineering/make-it-so productivity/red-pen productivity/codex-image-gen engineering/gamma-shift; do
  s="$skills/$f/SKILL.md"
  grep -q "watch.sh" "$s" && ! grep -qE "every 30 seconds|at most 60 times|60 polls|60th poll" "$s" && ok=$((ok + 1)) || echo "     $f"
done
check "warp, make-it-so, red-pen, codex-image-gen and gamma-shift point every wait at watch.sh and state no poll pace of their own" '[ $ok = 5 ]'
exit $fail
