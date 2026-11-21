#!/usr/bin/env bash
# approved-spec: shellcheck runs on the shell files a branch changes before a push.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/shellcheck-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
gi() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }
run() { # dir
  jq -n --arg d "$1" '{cwd:$d,tool_input:{command:"git push -u origin topic"}}' | "$hook" >"$scratch/out" 2>&1
  echo $?
}
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: exit $2, want $3"; cat "$scratch/out"; fail=1; fi; }
repo() { # name: a clone of a remote whose main holds one clean script, on branch topic
  local rem="$scratch/$1-rem" w="$scratch/$1"
  git init -q --bare -b main "$rem"; git clone -q "$rem" "$w" 2>/dev/null
  gi "$w" checkout -q -b main 2>/dev/null
  printf '#!/usr/bin/env bash\necho ok\n' >"$w/clean.sh"
  gi "$w" add -A; gi "$w" commit -q -m one; gi "$w" push -q origin main
  gi "$w" remote set-head origin main
  gi "$w" checkout -q -b topic
}
bad='#!/usr/bin/env bash\nc=$1\nout=$(moved $c)\necho "$out"\n'

# A shellcheck failure stops the push
repo fails; printf "$bad" >"$scratch/fails/move.sh"; gi "$scratch/fails" add -A; gi "$scratch/fails" commit -q -m move
check "a shellcheck failure stops the push" "$(run "$scratch/fails")" 2
grep -q SC2086 "$scratch/out" || { echo "FAIL the refusal shows shellcheck's SC2086 line"; fail=1; }

# Clean scripts push
repo clean; printf '#!/usr/bin/env bash\nc=$1\nout=$(moved "$c")\necho "$out"\n' >"$scratch/clean/move.sh"; gi "$scratch/clean" add -A; gi "$scratch/clean" commit -q -m move
check "clean scripts push" "$(run "$scratch/clean")" 0

# Only the branch's own shell files count
repo old; printf "$bad" >"$scratch/old/legacy.sh"; gi "$scratch/old" add -A; gi "$scratch/old" commit -q -m legacy
gi "$scratch/old" push -q origin topic:main; gi "$scratch/old" fetch -q origin
printf 'notes\n' >"$scratch/old/notes.txt"; gi "$scratch/old" add -A; gi "$scratch/old" commit -q -m notes
check "only the branch's own shell files count" "$(run "$scratch/old")" 0

# A repo can switch the check off
repo off; printf "$bad" >"$scratch/off/move.sh"; mkdir -p "$scratch/off/docs/agents"
printf 'Shellcheck: off\n' >"$scratch/off/docs/agents/testing.md"; gi "$scratch/off" add -A; gi "$scratch/off" commit -q -m move
check "a repo can switch the check off" "$(run "$scratch/off")" 0
exit $fail
