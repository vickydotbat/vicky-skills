#!/usr/bin/env bash
# approved-spec: the examples approved for showing every hook in one README
# table. Each hook in hooks.json is found by the plugin setting its script
# reads, or by name for the few that have no setting.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
rows=$(awk '/^## Hooks$/{on=1; next} /^## /{on=0} on && /^\| \*\*/' "$root/README.md")
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
row() { grep -F "| **$1**" <<<"$rows"; }

# Given the README
# When I read its hooks section
# Then every hook the plugin registers is one row of a table, with what it does and how to turn it on
missing=""
for script in $(jq -r '.hooks[][].hooks[].command' "$plugin/hooks/hooks.json" | sed 's/.*scripts\///; s/"//g' | sort -u); do
  opts=$(grep -o 'CLAUDE_PLUGIN_OPTION_[A-Z0-9_]*' "$plugin/scripts/$script" | sort -u | sed 's/CLAUDE_PLUGIN_OPTION_//' | tr 'A-Z' 'a-z')
  # A hook with no setting needs a line here naming its row.
  case "$script" in
    after-push.sh) name="After push" ;;
    pkill-guard.sh) name='No `pkill -f`' ;;
    stale-copy-hint.sh) name="Stale copy" ;;
    do-confirm-hint.sh) name="Confirm the objective" ;;
    screenshot-intake-hint.sh) name="Screenshots get taken in" ;;
    todo-reminder.sh) name="Todo reminder" ;;
    *) name="" ;;
  esac
  if [ -n "$name" ]; then row "$name" | grep -q 'Always on' || missing="$missing $script"
  else
    found=""; for opt in $opts; do grep -q "\`$opt\`" <<<"$rows" && found=1; done
    [ -n "$found" ] || missing="$missing $script"
  fi
done
jq -e '.modules | index("./viewscreen.tsx")' "$plugin/hooks/hooks.json" >/dev/null && { row "Viewscreen band" | grep -q . || missing="$missing viewscreen"; }
short=$(awk -F'|' 'NF != 5 || $3 ~ /^ *$/ || $4 ~ /^ *$/' <<<"$rows")
check "every hook the plugin registers is one row of the README table, with what it does and how to turn it on" \
  '[ -z "$missing" ] && [ -z "$short" ] && [ -n "$rows" ]' || echo "     missing:$missing"

# Given a hook that only refuses, asks or warns, such as the push-behind guard
# When I read its row
# Then it says (recommended)
untagged=$(grep -vc -e '(recommended)' -e '(experimental)' <<<"$rows")
check "a hook that only refuses, asks or warns, such as the push-behind guard, says (recommended)" \
  'row "No pushing behind main" | grep -q "(recommended)" && row "Short polls" | grep -q "(recommended)" && [ "$untagged" = 0 ]'

# Given a hook that acts on its own, such as gamma shift, auto-tidy or the springboard
# When I read its row
# Then it says (experimental)
check "a hook that acts on its own, such as gamma shift, auto-tidy or the springboard, says (experimental)" \
  'row "Gamma shift" | grep -q "(experimental)" && row "Auto-tidy" | grep -q "(experimental)" && row "Springboard" | grep -q "(experimental)"'

# Given the gamma shift row
# When I read it
# Then it names spark-joy and the drift check as part of it, and cautions me before I turn it on
g=$(row "Gamma shift")
check "the gamma shift row names spark-joy and the drift check as part of it, and cautions before it is turned on" \
  'grep -q "spark-joy" <<<"$g" && grep -q "ticket-drift" <<<"$g" && grep -q "experimental backlog-clearing powerhouse" <<<"$g" && grep -q "with care" <<<"$g" && ! grep -q "^| \*\*Spark-joy\|^| \*\*Ticket drift" <<<"$rows"'
exit $fail
