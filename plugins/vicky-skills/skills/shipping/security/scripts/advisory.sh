#!/usr/bin/env bash
# advisory.sh draft <report.json> | cve <id> | publish <id>
# The security kit's advisory route, run from inside the repo. The repo's
# `Advisories:` line in docs/agents/ picks the route: github drafts a
# repository advisory through gh api, file keeps the advisory text and its
# OSV file in the plugin's data folder, off drafts nothing. Each draft keeps
# its own folder, <data>/advisories/<repo>/<id>, so a restart keeps it and no
# repo's git status ever shows it. ADVISORY.md beside this folder says what
# the report file holds.
set -u
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../../../../scripts/plugin-data.sh
. "$here/../../../../scripts/plugin-data.sh"
say() { printf '%s\n' "$*"; }
die() { say "$*"; exit 1; }
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || die "advisory: no data folder: run this from the installed plugin, or set CLAUDE_PLUGIN_DATA."
top=$(git rev-parse --show-toplevel 2>/dev/null) || die "advisory: run this inside the repo the report is about."

# line <name>: the value of the repo's first "<name>:" line in docs/agents/.
line() { sed -nE "s/^(- )?$1:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\2/p" "$top"/docs/agents/*.md 2>/dev/null | head -n1; }
remote=$(git -C "$top" config remote.origin.url 2>/dev/null || true)
slug=$(sed -nE 's#^(https://|git@|ssh://git@)github\.com[:/]([^/]+/[^/]+)/?$#\2#p' <<<"$remote"); slug=${slug%.git}
name=$(basename "${remote:-$top}" .git)
key=$(tr '[:upper:]' '[:lower:]' <<<"${slug:-$name}" | tr -c 'a-z0-9\n' '-')
store="$CLAUDE_PLUGIN_DATA/advisories/$key"

route() {
  local r; r=$(line Advisories)
  case "$r" in
    off) die "advisory: advisories are switched off in this repo (Advisories: off in docs/agents/)." ;;
    "") die "advisory: this repo has no Advisories line in docs/agents/. Ask the user to type /first-contact, which writes it." ;;
    github) [ -n "$slug" ] || die "advisory: the Advisories line says github, but the remote is not on GitHub: the Advisories line and the remote disagree. Fix one of them."
      echo github ;;
    file) echo file ;;
    *) die "advisory: the Advisories line says \"$r\"; it takes github, file or off." ;;
  esac
}

# fp_installed: whether Claude Code has the fp-check plugin installed.
fp_installed() { jq -e '.plugins | keys | any(startswith("fp-check@"))' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json" >/dev/null 2>&1; }

# The advisory text is public from its first word (loose-lips): it takes only
# these fields of the report, never its steps or payload.
write_text() { # write_text <report> <vector> <file>
  jq -r --arg v "$2" '
    "# \(.summary)\n",
    "Affected versions: \(.affected)",
    "Fixed in: \(.fixed // "")",
    "Weakness: \(.cwe)",
    "Severity: CVSS-B \($v) (the kit'"'"'s proposal: edit the vector here)",
    (if (.credit_declined // false) or ((.credit // "") == "") then empty else "Credit: \(.credit)" end),
    (if (.fix_link // "") == "" then empty else "Fix: \(.fix_link)" end)' "$1" > "$3"
}

write_osv() { # write_osv <report> <vector> <id> <file>
  jq --arg v "$2" --arg id "$3" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg pkg "$name" '
    {schema_version: "1.9.2", id: $id, modified: $now, summary: .summary, details: .summary,
     affected: [{ranges: [{type: "SEMVER", events: ([{introduced: "0"}] + (if (.fixed // "") == "" then [] else [{fixed: .fixed}] end))}],
                 database_specific: {affected: .affected, package: $pkg}}],
     severity: [{type: "CVSS_V4", score: $v}],
     database_specific: {cwe_ids: [.cwe]}}
    + (if (.credit_declined // false) or ((.credit // "") == "") then {} else {credits: [{name: .credit, type: "FINDER"}]} end)
    + (if (.fix_link // "") == "" then {} else {references: [{type: "FIX", url: .fix_link}]} end)' "$1" > "$4"
}

draft() {
  local report=$1 r rkey dir id vector deadline out fork
  [ -f "$report" ] && jq -e '.summary and .affected and .cwe and .cvss' "$report" >/dev/null 2>&1 ||
    die "advisory: $report is no report file: it needs at least summary, affected, cwe and cvss (ADVISORY.md)."
  r=$(route) || { say "$r"; exit 1; }
  # A report is a claim until a run shows the break, or fp-check judges it.
  if fp_installed; then
    case "$(jq -r '.fp_check // ""' "$report")" in
      "TRUE POSITIVE") say "claim: checked by fp-check, a true positive." ;;
      "FALSE POSITIVE") die "advisory: fp-check judged the claim a false positive, so nothing is drafted." ;;
      *) die "advisory: fp-check is installed, so check the report's claim with fp-check first, and put its verdict in the report's fp_check field. Nothing is drafted yet." ;;
    esac
  else
    local run; run=$(jq -r '.run // ""' "$report")
    [ -n "$run" ] || die "advisory: the claim is unproven: the report names no proving run."
    (cd "$top" && bash "$here/../../deathmatch/scripts/cap.sh" 300 2G -- bash -c "$run") >/dev/null 2>&1 ||
      die "advisory: the claim is unproven: the run \"$run\" did not show the break, so nothing is drafted."
    say "claim: reproduced by the run \"$run\"."
  fi
  rkey=$(jq -r '.summary' "$report" | sha256sum | cut -c1-16)
  dir=$(grep -lx "$rkey" "$store"/*/report-key 2>/dev/null | head -n1 | xargs -r dirname)
  vector=$(jq -r '.cvss' "$report")
  # A vector the maintainer edited in the draft stays.
  [ -f "${dir:-/nonexistent}/advisory.md" ] &&
    vector=$(sed -nE 's/^Severity: CVSS-B (CVSS:4\.0\/[^ ]+).*/\1/p' "$dir/advisory.md" | head -n1)
  deadline=$(jq -r '.deadline // empty' "$report")
  [ -n "$deadline" ] || deadline=$(date -d "$(jq -r '.received' "$report") +90 days" +%F 2>/dev/null) ||
    die "advisory: the report has no deadline and no received date to count 90 days from."
  if [ "$r" = github ]; then
    if [ -n "$dir" ]; then
      id=$(basename "$dir")
      out=$(gh api -X PATCH "repos/$slug/security-advisories/$id" -f summary="$(jq -r .summary "$report")" \
        -f description="$(write_text "$report" "$vector" /dev/stdout)" -f cvss_vector_string="$vector" 2>&1) ||
        die "advisory: the forge refused to update the draft: $out. Nothing was put anywhere else."
    else
      out=$(jq --arg v "$vector" --arg pkg "$name" --arg d "$(write_text "$report" "$vector" /dev/stdout)" '
        {summary, description: $d, cvss_vector_string: $v, cwe_ids: [.cwe],
         vulnerabilities: [{package: {ecosystem: "other", name: $pkg}, vulnerable_version_range: .affected,
                            patched_versions: (if (.fixed // "") == "" then null else .fixed end)}]}' "$report" |
        gh api -X POST "repos/$slug/security-advisories" --input - 2>&1) ||
        die "advisory: the forge refused the draft: $out. Nothing was put anywhere else: no issue, no comment, no pull request."
      id=$(jq -r '.ghsa_id // empty' <<<"$out" 2>/dev/null)
      [ -n "$id" ] || die "advisory: the forge answered without a draft id: $out"
      dir="$store/$id"; mkdir -p "$dir"
    fi
  else
    if [ -z "$dir" ]; then
      local prefix n; prefix=$(tr '[:lower:]' '[:upper:]' <<<"$name" | tr -c 'A-Z0-9\n' '-')
      n=$(find "$store" -mindepth 1 -maxdepth 1 -type d | wc -l)
      # OSV 1.9.2 takes a prefix no database registers only after "x_".
      id="x_$prefix-$(date +%Y)-$((n + 1))"; dir="$store/$id"; mkdir -p "$dir"
    fi
    id=$(basename "$dir")
    # A re-draft that changes nothing keeps the file, and its modified time, as it was.
    write_osv "$report" "$vector" "$id" "$dir/osv.json.new"
    if [ -f "$dir/osv.json" ] && [ "$(jq -S 'del(.modified)' "$dir/osv.json")" = "$(jq -S 'del(.modified)' "$dir/osv.json.new")" ]; then
      rm "$dir/osv.json.new"
    else
      mv "$dir/osv.json.new" "$dir/osv.json"
    fi
  fi
  echo "$rkey" > "$dir/report-key"
  write_text "$report" "$vector" "$dir/advisory.md"
  jq -n --arg id "$id" --arg route "$r" --arg slug "$slug" --arg deadline "$deadline" --slurpfile rep "$report" \
    --arg old "$(cat "$dir/state.json" 2>/dev/null || echo '{}')" '
    ($old | fromjson) + {id: $id, route: $route, repo: $slug, deadline: $deadline, state: "draft",
     summary: $rep[0].summary, fixed: ($rep[0].fixed // ""), fix_branch: ($rep[0].fix_branch // "")}' > "$dir/state.json.new" &&
    mv "$dir/state.json.new" "$dir/state.json"
  say "draft: $dir"
  say "draft id: $id"
  say "deadline: $deadline"
  [ "$r" = github ] && say "on GitHub: $id, a draft only the repo's maintainers see. No CVE is requested and nothing is published."
  local branch; branch=$(jq -r '.fix_branch // ""' "$report")
  if git -C "$top" rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
    if [ "$r" = github ]; then
      fork=$(jq -r '.fork // ""' "$dir/state.json")
      if [ -z "$fork" ]; then
        out=$(gh api -X POST "repos/$slug/security-advisories/$id/forks" 2>&1) && fork=$(jq -r '.clone_url // empty' <<<"$out" 2>/dev/null)
        [ -n "$fork" ] && jq --arg f "$fork" '.fork = $f' "$dir/state.json" > "$dir/state.json.new" && mv "$dir/state.json.new" "$dir/state.json"
      fi
      if [ -n "$fork" ] && git -C "$top" push -q "$fork" "refs/heads/$branch:refs/heads/$branch" 2>/dev/null; then
        say "fix branch: $branch, pushed to the advisory's private fork only."
      else
        say "fix branch: $branch stays local: the private fork could not be made or reached. Push it nowhere else."
      fi
    else
      say "fix branch: $branch, a local branch, not pushed."
    fi
  fi
  [ -n "$(jq -r '.fixed // ""' "$report")" ] || say "the draft waits on the fix: no fixed version yet."
}

case "${1:-}" in
  draft) [ $# -eq 2 ] || die "usage: advisory.sh draft <report.json>"; draft "$2" ;;
  *) die "usage: advisory.sh draft <report.json> | cve <id> | publish <id>" ;;
esac
