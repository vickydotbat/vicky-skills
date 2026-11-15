#!/usr/bin/env bash
# approved-spec: the AFK label examples (A1 to A4), ticked on the drafts page
# 2026-11-15. Agents follow skill text, so each check reads the text that
# tells an agent to set, keep off, drop or list the label.
set -u
root="$(dirname "$0")/.."
skills="$root/plugins/vicky-skills/skills/engineering"
chart="$skills/lay-course/STAR-CHART.md"
templates=("$skills"/first-contact/issue-tracker-*.md "$root/docs/agents/issue-tracker.md")
fail=0
check() { if (eval "$2"); then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
ready() { awk '/^## Ready to warp/{f=1;next} /^## /{f=0} f' "$chart"; }

# Given an open star chart with no open anomaly or probe, no Confirm line, every star's examples approved, and no task that needs your account
# When an agent records the answer that made it so
# Then the chart carries the label starchart:afk
check "A1 a chart nobody needs to answer gets the label" \
  'r=$(ready); grep -q "starchart:afk" <<<"$r" && grep -q "Add" <<<"$r" && grep -q "Ready to warp" "$skills/lay-course/SKILL.md" && grep -q "Ready to warp" "$skills/warp/SKILL.md"'

# Given the same chart with one anomaly still open
# When an agent records any other answer
# Then the chart has no starchart:afk label
check "A2 one open question keeps it off" \
  'r=$(ready | grep "Add"); for w in anomaly probe "Confirm:" "examples approved" "task that needs"; do grep -q "$w" <<<"$r" || exit 1; done; grep -q "every one" <<<"$r"'

# Given a chart labelled starchart:afk
# When an agent files an anomaly, a probe, a Confirm line or a star without approved examples on it
# Then the chart loses the starchart:afk label
check "A3 new work for you takes it off" \
  'r=$(ready); grep -q "Remove" <<<"$r" && grep -q "Ready to warp" "$skills/mission-brief/SKILL.md" && awk "/^## Filing a star/{f=1;next} /^## /{f=0} f" "$chart" | grep -q "Ready to warp"'

# Given a repo set up by first-contact with any of its trackers, this repo's Obsidian tracker included
# When an agent lists the charts ready to warp
# Then the repo's issue-tracker doc names a List charts ready to warp operation that returns only open charts with the label
check "A4 every tracker lists the charts ready to warp" \
  '[ ${#templates[@]} -eq 7 ] && (for t in "${templates[@]}"; do l=$(grep -F "**List charts ready to warp**" "$t"); grep -q "\`" <<<"$l" && grep -q "afk" <<<"$l" && grep -qi "open" <<<"$l" || { echo "  missing in $t"; exit 1; }; done)'
exit $fail
