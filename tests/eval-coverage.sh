#!/usr/bin/env bash
# Checks a plugin's eval suite without running it: every skill plugin.json
# lists has a case under evals/<skill>/, and every case has a grader, which
# `claude plugin eval` refuses to load a case without. Starts no model, so CI
# can run it.
# Usage: eval-coverage.sh <plugin dir>
# Prints one line per gap and exits 1, or exits 0 when nothing is missing.
set -u
[ $# = 1 ] || { echo "usage: eval-coverage.sh <plugin dir>" >&2; exit 2; }
plugin=$1
manifest="$plugin/.claude-plugin/plugin.json"
[ -f "$manifest" ] || { echo "eval-coverage: no $manifest" >&2; exit 2; }
fail=0
while read -r skill; do
  cases=$(find "$plugin/evals/$skill" \( -name prompt.md -o -name case.yaml \) 2>/dev/null)
  [ -n "$cases" ] || { echo "eval-coverage: skill $skill has no eval case under evals/$skill/"; fail=1; }
done < <(jq -r '.skills // [] | if type == "string" then [.] else . end | .[] | sub("/+$"; "") | split("/") | last' "$manifest")
# A case is a folder holding prompt.md or case.yaml. Its graders are graders/*.md, or a graders: list in case.yaml.
while read -r case_dir; do
  compgen -G "$case_dir/graders/*.md" >/dev/null && continue
  [ -f "$case_dir/case.yaml" ] && grep -q '^graders:' "$case_dir/case.yaml" && continue
  echo "eval-coverage: case ${case_dir#"$plugin/evals/"} has no grader, so the eval tool refuses to load it"; fail=1
done < <(find "$plugin/evals" \( -name prompt.md -o -name case.yaml \) -not -path '*/results/*' 2>/dev/null | sed 's|/[^/]*$||' | sort -u)
exit $fail
