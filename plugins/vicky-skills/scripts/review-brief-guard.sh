#!/usr/bin/env bash
# PreToolUse hook (Agent): refuses a reviewer brief that names a file outside any
# git checkout that does not exist. A reviewer told to read a missing law file
# reviews without the repo's outside rules, and its report reads clean. The usual
# cause is a scratch path typed with a session id remembered from an earlier
# session. A file inside a checkout may be one the diff deletes, so it passes.
# Always on, with no setting: a reviewer only reads, so a missing file it is told
# to read is always a broken brief.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq the reads below come back empty and nothing is refused
input=$(cat)
type=$(jq -r '.tool_input.subagent_type // ""' <<<"$input" 2>/dev/null)
[[ "$type" == *reviewer ]] || exit 0
prompt=$(jq -r '.tool_input.prompt // ""' <<<"$input" 2>/dev/null)
missing=()
while IFS= read -r path; do
  [[ -e "$path" ]] && continue
  dir=$(dirname "$path")
  while [[ ! -d "$dir" ]]; do dir=$(dirname "$dir"); done
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && continue
  missing+=("$path")
done < <(grep -oE '(^|[^[:alnum:]_.~/-])/[[:alnum:]_.+-]+(/[[:alnum:]_.+-]+)*\.[[:alnum:]]+' <<<"$prompt" | sed -E 's#^[^/]##' | sort -u)
if ((${#missing[@]})); then
  echo "review-brief-guard: the brief names ${missing[*]}, and no such file exists. Write the file first, then run test -s <file> && realpath <file> and paste the path it prints: a session id typed from memory can belong to an earlier session. Nothing was dispatched." >&2
  exit 2
fi
exit 0 # mutant-ok delete: the if above ends with status 0 when it does not refuse
