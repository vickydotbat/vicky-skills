#!/usr/bin/env bash
# approved-spec: chart sharding and found work, shape S1 to S4 and F1 to F4,
# approved by the user in chat 2026-11-15. The behaviour is the agent's, so
# each check reads the plugin files that drive it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
skills="$root/plugins/vicky-skills/skills"
brief="$skills/planning/mission-brief/SKILL.md"
chart="$skills/commands/lay-course/STAR-CHART.md"
warp="$skills/building/warp/SKILL.md"
course="$skills/commands/lay-course/SKILL.md"
mis="$skills/shipping/make-it-so/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# The Sharding section alone, so a phrase elsewhere in the file can't pass a check.
shard="$(awk '/^## Sharding/{on=1;print;next} on&&/^## /{exit} on' "$chart")"

# Given a conversation that settled a big effort
# When mission-brief writes the spec
# Then it shards the slices before the examples go to red-pen
check "mission-brief shards between the spec and red-pen" \
  'awk "/^1\. \*\*Write the spec/{a=NR} /^2\. \*\*Shard/{b=NR} /^3\. \*\*Hand the examples/{c=NR} END{exit !(a&&b&&c&&a<b&&b<c)}" "$brief" && grep -q "STAR-CHART.md)'"'"'s \"Sharding\"" "$brief"'

# Given a slice the chart's milestone ships without
# When the chart is sharded
# Then the slice leaves the chart, judged against that chart's own mission
check "each slice is judged against the chart's own mission and milestone" \
  'grep -q "the chart'"'"'s own mission" <<<"$shard" && grep -q "milestone ships without" <<<"$shard"'

# Given a cut slice that is a new feature, another effort's work, or polish
# When the chart is sharded
# Then it goes to its own seed chart, that effort's chart, or the area's polish chart, never a backlog
check "cut slices go to a seed chart, another effort's chart or a polish chart" \
  'grep -q "seed chart" <<<"$shard" && grep -q "that effort'"'"'s chart" <<<"$shard" && grep -q "polish chart" <<<"$shard" && grep -q "opens one" <<<"$shard" && ! grep -qi "backlog" <<<"$shard"'

# Given a polish chart after alpha
# When it is sharded
# Then its polish stars stay, because polish is its mission
check "a polish chart keeps its polish" \
  'grep -q "A polish chart keeps its polish" <<<"$shard"'

# Given a chart with more than 8 planned stars
# When it is sharded
# Then it splits into linked sibling charts, each with its own mission
check "past 8 planned stars a chart splits into linked siblings" \
  'grep -q "more than 8 planned stars" <<<"$shard" && grep -q "sibling charts" <<<"$shard" && grep -q "its own mission" <<<"$shard"'

# Given work found while building a star
# When the agent files it
# Then it goes on the active chart, uncounted by the cap, on the same branch and pull request, and no star leaves a chart once a build starts
check "found work joins the chart and the same pull request, outside the cap" \
  'grep -q "Found work never counts" <<<"$shard" && grep -q "same branch and pull request" <<<"$shard" && grep -q "once a build has started" <<<"$shard" && grep -q "Found work" <(awk "/^## Filing a star/{on=1;next} on&&/^## /{exit} on" "$chart")'

# Given an existing chart past the cap
# When warp or lay-course starts on it
# Then it is sharded before the course is plotted
check "warp and lay-course shard an oversized chart first" \
  'grep -q "\"Sharding\"" "$warp" && grep -q "\"Sharding\"" "$course" && ! grep -q "When the chart is too big for one run and you offer the user a choice of scopes" "$warp"'

# Given a ticket opened during the effort and left on no Closes or Waits on line
# When make-it-so runs its checklist
# Then Q13 fails and the pull request does not go ready
check "make-it-so Q13 fails on a ticket left behind" \
  'grep -q "^- \*\*Q13 Nothing left behind.\*\*" "$mis" && grep -q "List items created or changed since" "$mis" && grep -q "Q7 to Q10, Q12 and Q13" "$mis" && grep -q "Q0-Q13 pass" "$mis"'
exit $fail
