#!/usr/bin/env bash
# The security kit's edges no approved example names: bad input, the data
# folder an installed copy finds, what the GitHub route sends and keeps, and
# the opt-out lines in a bare repo. Runs against the same stand-ins as the
# approved tests.
set -u
. "$(dirname "$0")/lib/security-fixture.sh"
draft() { (cd "$1" && bash "$kit/advisory.sh" draft "$2" 2>&1); }
file_repo=$(repo gadget https://gitea.example.invalid/acme/gadget.git); line "$file_repo" "Advisories: file"
report "$fx/r.json" .

# The kit's scripts, run from an installed copy, find the plugin's data folder without being told.
inst="$fx/plugins/cache/mkt/vicky-skills/1.0"; mkdir -p "$inst/skills/shipping"
cp -r "$plugin/scripts" "$inst/"; cp -r "$plugin/skills/shipping/security" "$plugin/skills/shipping/deathmatch" "$inst/skills/shipping/"
out=$(cd "$file_repo" && env -u CLAUDE_PLUGIN_DATA bash "$inst/skills/shipping/security/scripts/advisory.sh" draft "$fx/r.json" 2>&1)
check "an installed copy finds its data folder" 'grep -q "^draft: $fx/plugins/data/vicky-skills-mkt/advisories/" <<<"$out"'
out=$(cd "$file_repo" && env -u CLAUDE_PLUGIN_DATA bash "$kit/advisory.sh" draft "$fx/r.json" 2>&1); code=$?
check "no data folder drafts nothing and says why" '[ "$code" != 0 ] && grep -qi "no data folder" <<<"$out"'

# Bad input is refused, with nothing drafted.
before=$(drafts)
jq 'del(.cwe)' "$fx/r.json" > "$fx/bad.json"; out=$(draft "$file_repo" "$fx/bad.json"); code=$?
check "a report missing a field is refused" '[ "$code" != 0 ] && grep -qi "no report file" <<<"$out" && [ "$before" = "$(drafts)" ]'
out=$(draft "$file_repo" "$fx/missing.json"); code=$?
check "a missing report file is refused" '[ "$code" != 0 ] && grep -qi "no report file" <<<"$out"'
jq 'del(.run)' "$fx/r.json" > "$fx/norun.json"; out=$(draft "$file_repo" "$fx/norun.json"); code=$?
check "a report with no proving run is unproven" '[ "$code" != 0 ] && grep -qi "unproven" <<<"$out" && [ "$before" = "$(drafts)" ]'
jq 'del(.received) | del(.deadline)' "$fx/r.json" > "$fx/nodate.json"; out=$(draft "$file_repo" "$fx/nodate.json"); code=$?
check "no deadline and no received date is refused" '[ "$code" != 0 ] && grep -qi "90 days" <<<"$out" && [ "$before" = "$(drafts)" ]'
off=$(repo off https://github.com/acme/off.git); line "$off" "Advisories: off"; out=$(draft "$off" "$fx/r.json"); code=$?
check "advisories off exits non-zero" '[ "$code" != 0 ]'
odd=$(repo odd https://github.com/acme/odd.git); line "$odd" "Advisories: maybe"; out=$(draft "$odd" "$fx/r.json"); code=$?
check "an unknown Advisories value is named" '[ "$code" != 0 ] && grep -q "github, file or off" <<<"$out"'
out=$(cd "$fx" && bash "$kit/advisory.sh" draft "$fx/r.json" 2>&1); code=$?
check "outside a repo drafts nothing" '[ "$code" != 0 ] && grep -qi "inside the repo" <<<"$out"'

# The file route says what it ran, and sends nothing to a forge or a CNA.
: > "$fx/calls.log"; out=$(draft "$file_repo" "$fx/r.json"); d=$(sed -n 's/^draft: //p' <<<"$out")
check "the file route sends nothing" '[ -n "$d" ] && [ ! -s "$fx/calls.log" ] && ! grep -q "on GitHub" <<<"$out"'
check "the output names the run that reproduced the claim" 'grep -q "reproduced by the run \"true\"" <<<"$out"'
check "the OSV file credits the reporter and links the fix" 'jq -e "(.credits[0].name == \"Rin Okabe\") and (.references[0].url | endswith(\"commit/abc123\")) and (.affected[0].ranges[0].events | map(.fixed // empty) == [\"2.4.1\"])" "$d/osv.json" >/dev/null'
a=$(sha256sum < "$d/osv.json"); sleep 1.1; draft "$file_repo" "$fx/r.json" >/dev/null
check "an unchanged re-draft keeps the OSV file" '[ "$a" = "$(sha256sum < "$d/osv.json")" ] && [ -z "$(find "$d" -name "*.new")" ]'
jq '.summary="A flaw whose weakness changed" | .cwe="CWE-79"' "$fx/r.json" > "$fx/cwe.json"; d2=$(draft "$file_repo" "$fx/cwe.json" | sed -n 's/^draft: //p')
jq '.summary="A flaw whose weakness changed" | .cwe="CWE-89"' "$fx/r.json" > "$fx/cwe.json"; draft "$file_repo" "$fx/cwe.json" >/dev/null
check "a changed re-draft rewrites the OSV file" 'jq -e ".database_specific.cwe_ids == [\"CWE-89\"]" "$d2/osv.json" >/dev/null'

# The GitHub route: what it sends, what it keeps, and the fork made once.
git init -q --bare "$fx/fork.git"
cat > "$fx/answers/gh.sh" <<EOF
case "\$*" in
  *"/forks"*) [ -f "$fx/no-fork" ] && { echo "HTTP 422" >&2; exit 1; }; echo '{"clone_url":"$fx/fork.git"}'; exit 0 ;;
  *"--input -"*) cat > "$fx/body.json"; [ -f "$fx/no-id" ] && { echo '{}'; exit 0; }
    [ -f "$fx/refuse" ] && { echo "HTTP 403: Must have admin rights" >&2; exit 1; }
    echo '{"ghsa_id":"GHSA-1111-2222-3333"}'; exit 0 ;;
esac
EOF
gh_repo=$(repo widget https://github.com/acme/widget.git); line "$gh_repo" "Advisories: github"
git -C "$gh_repo" branch fix-upload-path
touch "$fx/refuse"; before=$(drafts); out=$(draft "$gh_repo" "$fx/r.json"); code=$?
check "a refused first draft keeps nothing and says why" '[ "$code" != 0 ] && grep -qi "refused" <<<"$out" && grep -q "admin rights" <<<"$out" && [ "$before" = "$(drafts)" ]'
rm "$fx/refuse"; touch "$fx/no-id"; out=$(draft "$gh_repo" "$fx/r.json"); code=$?
check "a forge answer with no draft id is an error" '[ "$code" != 0 ] && grep -qi "without a draft id" <<<"$out" && [ "$before" = "$(drafts)" ]'
rm "$fx/no-id"; : > "$fx/calls.log"; out=$(draft "$gh_repo" "$fx/r.json"); d=$(sed -n 's/^draft: //p' <<<"$out")
check "the draft body carries the public fields" 'jq -e "(.summary | test(\"guest read\")) and (.cvss_vector_string | startswith(\"CVSS:4.0/\")) and (.cwe_ids == [\"CWE-22\"]) and (.vulnerabilities[0].vulnerable_version_range == \"< 2.4.1\") and (.vulnerabilities[0].patched_versions == \"2.4.1\") and (.vulnerabilities[0].package.name == \"widget\")" "$fx/body.json" >/dev/null && ! grep -q "secret-probe" "$fx/body.json"'
check "the GitHub draft keeps its text on this machine" '[ -s "$d/advisory.md" ] && grep -q "CVSS-B" "$d/advisory.md"'
check "the GitHub draft says it stays a draft" 'grep -q "on GitHub: GHSA-1111-2222-3333, a draft only the repo" <<<"$out" && grep -q "nothing is published" <<<"$out"'
check "the fix push is named" 'grep -q "pushed to the advisory.s private fork only" <<<"$out"'
: > "$fx/calls.log"; draft "$gh_repo" "$fx/r.json" >/dev/null
check "a re-draft makes no second fork" 'grep -q "security-advisories/GHSA-1111-2222-3333" "$fx/calls.log" && ! grep -q "/forks" "$fx/calls.log"'
other=$(repo other https://github.com/acme/other.git); line "$other" "Advisories: github"; git -C "$other" branch fix-upload-path
touch "$fx/no-fork"; out=$(draft "$other" "$fx/r.json")
check "an unreachable fork keeps the fix local" 'grep -q "stays local" <<<"$out" && ! git -C "$fx/other-public.git" rev-parse -q --verify refs/heads/fix-upload-path >/dev/null'
rm "$fx/no-fork"; nob=$(repo nob https://github.com/acme/nob.git); line "$nob" "Advisories: github"
jq 'del(.fix_branch)' "$fx/r.json" > "$fx/nobranch.json"; : > "$fx/calls.log"; out=$(draft "$nob" "$fx/nobranch.json")
check "no fix branch makes no fork" 'grep -q "^draft: " <<<"$out" && ! grep -q "/forks" "$fx/calls.log" && ! grep -q "fix branch" <<<"$out"'

# lines.sh outside a repo, and in a repo with no docs/agents folder yet.
out=$(cd "$fx" && bash "$kit/lines.sh" 2>&1); code=$?
check "lines outside a repo writes nothing" '[ "$code" != 0 ] && grep -qi "inside a repo" <<<"$out"'
plain=$(repo plain https://github.com/acme/plain.git); rm -rf "$plain/docs"; (cd "$plain" && bash "$kit/lines.sh" >/dev/null 2>&1)
check "lines makes docs/agents when it is missing" 'grep -qx "Advisories: github" "$plain/docs/agents/security.md"'
exit $fail
