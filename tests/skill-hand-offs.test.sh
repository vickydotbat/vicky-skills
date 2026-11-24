#!/usr/bin/env bash
# Each skill's hands-off frontmatter field lists exactly the skills its steps
# hand off to, as skill-graph.py reads them.
# Usage: skill-hand-offs.test.sh [skills dir]
set -u
root="${1:-$(dirname "$0")/../plugins/vicky-skills/skills}"
python3 "$(dirname "$0")/../plugins/vicky-skills/scripts/skill-graph.py" check "$root" || exit 1
echo "ok   every skill's hands-off field matches its steps"
