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
jq '.deadline="2026-9-1"' "$fx/r.json" > "$fx/loose.json"; out=$(draft "$file_repo" "$fx/loose.json")
check "a loose deadline is written as YYYY-MM-DD" 'grep -q "^deadline: 2026-09-01$" <<<"$out"'
jq '.deadline="next tuesday-ish"' "$fx/r.json" > "$fx/baddl.json"; out=$(draft "$file_repo" "$fx/baddl.json"); code=$?
check "a deadline that is no date is refused" '[ "$code" != 0 ] && grep -qi "no date" <<<"$out"'
before=$(drafts)
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

twin=$(repo twin https://code.example.invalid/other-team/gadget.git); line "$twin" "Advisories: file"
d1=$(draft "$file_repo" "$fx/r.json" | sed -n 's/^draft: //p'); d2=$(draft "$twin" "$fx/r.json" | sed -n 's/^draft: //p')
check "two same-named repos on other forges keep apart" '[ -n "$d1" ] && [ -n "$d2" ] && [ "$(dirname "$d1")" != "$(dirname "$d2")" ]'

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
check "lines outside a repo writes nothing" '[ "$code" != 0 ] && grep -qi "inside the repo" <<<"$out"'
plain=$(repo plain https://github.com/acme/plain.git); rm -rf "$plain/docs"; (cd "$plain" && bash "$kit/lines.sh" >/dev/null 2>&1)
check "lines makes docs/agents when it is missing" 'grep -qx "Advisories: github" "$plain/docs/agents/security.md"'
# The levels' edges: the opt-out line, names, missing tools, clean runs and failed runs.
levels() { (cd "$1" && shift && bash "$kit/levels.sh" "$@" 2>&1); }
lv=$(repo lv https://github.com/acme/lv.git)
out=$(levels "$lv"); code=$?
check "no Security levels line runs nothing and asks for first-contact" '[ "$code" != 0 ] && grep -q "/first-contact" <<<"$out" && ! grep -qE "^(gitleaks|zizmor|scorecard|vulnix)" "$fx/calls.log"'
line "$lv" "Advisories: off"; line "$lv" "Security levels: secrets, cii"
: > "$fx/calls.log"; out=$(levels "$lv")
check "an unknown level is named and the known ones still run" 'grep -q "\"cii\" is no level" <<<"$out" && grep -q "^gitleaks" "$fx/calls.log" && grep -q "found nothing" <<<"$out"'
check "Advisories off leaves the levels on" 'grep -q "^secrets: gitleaks found nothing" <<<"$out"'
out=$(levels "$lv" baseline)
check "a level the line leaves out says it is switched off" 'grep -q "^baseline: switched off" <<<"$out" && ! grep -q "^scorecard" "$fx/calls.log"'
(cd "$lv" && bash "$kit/lines.sh" >/dev/null 2>&1)
check "first-contact keeps an existing Security levels line" '[ "$(grep -h "^Security levels:" "$lv"/docs/agents/*.md)" = "Security levels: secrets, cii" ]'
all4=$(repo all4 https://github.com/acme/all4.git); line "$all4" "Security levels: baseline, secrets, ci, dependencies"
mkdir -p "$all4/.gitea/workflows"; echo 'on: push' > "$all4/.gitea/workflows/a.yml"; echo '{ }' > "$all4/default.nix"
for t in gitleaks scorecard vulnix; do
  mv "$fx/bin/$t" "$fx/$t.off"; : > "$fx/calls.log"; out=$(levels "$all4")
  check "missing $t is named, never installed, and the other levels run" 'grep -q "$t is missing. Get it from https://" <<<"$out" && [ "$(grep -c "is missing" <<<"$out")" = 1 ] && ! grep -q "found nothing" <<<"$(grep "$t" <<<"$out")" && ! grep -qE "^(pip|pipx|cargo|brew|nix-env|apt|apt-get) " "$fx/calls.log"'
  mv "$fx/$t.off" "$fx/bin/$t"
done
: > "$fx/calls.log"; out=$(levels "$all4" ci dependencies)
check "a Gitea workflow folder is checked" 'grep -q "^zizmor --format json .gitea/workflows" "$fx/calls.log"'
check "a default.nix build is read with nix-build" 'grep -q "^nix-build --no-out-link" "$fx/calls.log"'
echo '{"checks":[{"name":"Security-Policy","score":10,"reason":"security policy file detected","details":[]}]}' > "$fx/answers/scorecard"
out=$(levels "$all4" baseline)
check "a repo with a policy passes baseline" 'grep -q "found a security policy" <<<"$out" && ! grep -q "finding" <<<"$out"'
echo '{"checks":[{"name":"Security-Policy","score":-1,"reason":"internal error: API rate limit","details":[]}]}' > "$fx/answers/scorecard"
out=$(levels "$all4" baseline)
check "an undecided scorecard check is no finding" 'grep -q "could not decide: internal error: API rate limit" <<<"$out" && ! grep -q "finding" <<<"$out"'
echo 1 > "$fx/answers/scorecard.exit"; out=$(levels "$all4" baseline)
check "a failed scorecard run is no finding" 'grep -q "scorecard failed on Security-Policy" <<<"$out" && ! grep -q "finding" <<<"$out"'
rm "$fx/answers/scorecard" "$fx/answers/scorecard.exit"
echo 3 > "$fx/answers/gitleaks.exit"; out=$(levels "$all4" secrets)
check "a failed gitleaks run is no finding and no all-clear" 'grep -q "gitleaks failed with exit 3" <<<"$out" && ! grep -qE "finding|found nothing" <<<"$out"'
rm "$fx/answers/gitleaks.exit"
echo '[]' > "$fx/answers/zizmor"; out=$(levels "$all4" ci)
check "a clean zizmor run says so" 'grep -q "^ci: zizmor found nothing" <<<"$out"'
echo 1 > "$fx/answers/zizmor.exit"; out=$(levels "$all4" ci)
check "a failed zizmor run is no finding and no all-clear" 'grep -q "zizmor failed with exit 1" <<<"$out" && ! grep -qE "finding|found nothing" <<<"$out"'
rm "$fx/answers/zizmor" "$fx/answers/zizmor.exit"
echo "$fx/store/x" > "$fx/answers/nix-build"; out=$(levels "$all4" dependencies)
check "a clean vulnix run says so" 'grep -q "^dependencies: vulnix found nothing" <<<"$out"'
echo 1 > "$fx/answers/vulnix.exit"; out=$(levels "$all4" dependencies)
check "a failed vulnix run is no finding and no all-clear" 'grep -q "vulnix failed with exit 1" <<<"$out" && ! grep -qE "finding|found nothing" <<<"$out"'
rm "$fx/answers/vulnix.exit" "$fx/answers/nix-build"; rm "$all4/default.nix"; echo '{ }' > "$all4/flake.nix"
out=$(levels "$all4" dependencies)
check "a failed Nix build is no finding and no all-clear" 'grep -q "Nix build failed" <<<"$out" && ! grep -qE "finding|found nothing" <<<"$out"'
rm "$all4/flake.nix"
echo '{"checks":[{"name":"Vulnerabilities","score":10,"reason":"0 existing vulnerabilities detected","details":[]}]}' > "$fx/answers/scorecard"
out=$(levels "$all4" dependencies)
check "a clean Vulnerabilities check says so" 'grep -q "Vulnerabilities check found nothing" <<<"$out"'
rm "$fx/answers/scorecard"
gl=$(repo gl https://gitlab.com/acme/gl.git); line "$gl" "Security levels: baseline"; : > "$fx/calls.log"; levels "$gl" baseline >/dev/null
check "scorecard reads a GitLab repo" 'grep -q "^scorecard --repo gitlab.com/acme/gl " "$fx/calls.log"'
: > "$fx/calls.log"; (cd "$all4" && bash "$kit/review.sh" v1.0 >/dev/null 2>&1)
check "a review scans only the branch's commits" 'grep -q "^gitleaks git --log-opts=v1.0..HEAD" "$fx/calls.log"'
offl=$(repo offl https://github.com/acme/offl.git); line "$offl" "Security levels: off"; levels "$offl" >/dev/null; code=$?
check "levels switched off exits 0, a choice and no error" '[ "$code" = 0 ]'
nixr=$(repo nixr https://github.com/acme/nixr.git); line "$nixr" "Security levels: dependencies"; echo '{ }' > "$nixr/flake.nix"
echo "$fx/store/y" > "$fx/answers/nix"; : > "$fx/calls.log"; levels "$nixr" dependencies >/dev/null; rm "$fx/answers/nix"
check "a Nix repo's dependency watch runs vulnix alone" 'grep -q "^vulnix" "$fx/calls.log" && ! grep -q "^scorecard" "$fx/calls.log"'
git -C "$all4" update-ref refs/remotes/origin/trunk HEAD; git -C "$all4" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
: > "$fx/calls.log"; out=$( (cd "$all4" && bash "$kit/review.sh" 2>&1) )
check "a review with no base starts from origin's default branch" 'grep -q "^gitleaks git --log-opts=origin/trunk..HEAD" "$fx/calls.log" && grep -q "fp-check is not installed" <<<"$out"'
git -C "$all4" symbolic-ref --delete refs/remotes/origin/HEAD; : > "$fx/calls.log"; (cd "$all4" && bash "$kit/review.sh" >/dev/null 2>&1)
check "a review with no origin default starts from main" 'grep -q "^gitleaks git --log-opts=main..HEAD" "$fx/calls.log"'
installed fp-check; (cd "$all4" && bash "$kit/review.sh" >/dev/null 2>&1); code=$?
check "a review handed to fp-check exits 0" '[ "$code" = 0 ]'

# cve and publish: an unknown id, forge refusals, the file route on a GitHub remote, and the state after.
kit_run() { (cd "$1" && shift && bash "$kit/advisory.sh" "$@" 2>&1); }
out=$(kit_run "$gh_repo" publish GHSA-none); code=$?
check "an unknown draft id is named" '[ "$code" != 0 ] && grep -q "no draft advisory GHSA-none" <<<"$out"'
out=$(kit_run "$gh_repo" cve); code=$?
check "cve with no id shows its usage" '[ "$code" != 0 ] && grep -q "usage: advisory.sh cve <id>" <<<"$out"'
out=$(kit_run "$gh_repo" publish); code=$?
check "publish with no id shows its usage" '[ "$code" != 0 ] && grep -q "usage: advisory.sh publish <id>" <<<"$out"'
cat > "$fx/answers/gh.sh" <<EOF
case "\$*" in
  *visibility*) echo PUBLIC; exit 0 ;;
  *"/cve"*|*state=published*|"release create"*) echo "HTTP 403: refused for the test" >&2; exit 1 ;;
esac
EOF
out=$(kit_run "$gh_repo" cve GHSA-1111-2222-3333); code=$?
check "a refused CVE request says so" '[ "$code" != 0 ] && grep -q "GitHub refused the CVE request: HTTP 403" <<<"$out"'
out=$(kit_run "$gh_repo" publish GHSA-1111-2222-3333); code=$?
st=$(find "$CLAUDE_PLUGIN_DATA" -path "*/acme-widget/GHSA-1111-2222-3333/state.json")
check "a refused publish keeps the draft a draft" '[ "$code" != 0 ] && grep -q "GitHub refused to publish" <<<"$out" && [ "$(jq -r .state "$st")" = draft ]'
echo '{"version":2,"plugins":{}}' > "$fx/config/plugins/installed_plugins.json"
fg=$(repo fg https://github.com/acme/fg.git); line "$fg" "Advisories: file"
fid=$(draft "$fg" "$fx/r.json" | sed -n 's/^draft id: //p')
out=$(kit_run "$fg" publish "$fid"); code=$?
check "a refused release note keeps the draft a draft" '[ "$code" != 0 ] && grep -q "refused the release note" <<<"$out"'
echo 'case "$*" in *visibility*) echo PUBLIC ;; esac' > "$fx/answers/gh.sh"; : > "$fx/calls.log"
out=$(kit_run "$fg" publish "$fid"); fst=$(find "$CLAUDE_PLUGIN_DATA" -path "*$fid/state.json" | head -1)
check "the file route on a GitHub remote publishes a GitHub release" 'grep -q "^gh release create $fid --title Security advisory $fid" "$fx/calls.log" && ! grep -q "^tea" "$fx/calls.log" && [ "$(jq -r .state "$fst")" = published ]'
out=$(kit_run "$gh_repo" publish GHSA-1111-2222-3333)
check "a published draft is marked published" '[ "$(jq -r .state "$st")" = published ] && grep -q "public Security tab" <<<"$out"'
check "a published release note says so" 'grep -q "published as the release note" <<<"$(kit_run "$fg" publish "$fid")"'
out=$(kit_run "$fg" cve "$fid")
check "the MITRE form text names the weakness and the fix, and sends nothing" 'grep -q "^Fixed version: 2.4.1$" <<<"$out" && grep -q "^Vendor and product: acme/fg$" <<<"$out" && grep -q "^Vulnerability type: CWE-22$" <<<"$out" && grep -q "^Weakness: CWE-22" <<<"$out" && grep -q "^Fix: https://example.invalid" <<<"$out" && grep -q "sends nothing" <<<"$out"'
echo 'case "$*" in *visibility*) echo PUBLIC ;; *) echo "{}" ;; esac' > "$fx/answers/gh.sh"
check "a sent CVE request says the advisory stays a draft" 'grep -q "CVE requested for GHSA-1111-2222-3333.*stays a draft" <<<"$(kit_run "$gh_repo" cve GHSA-1111-2222-3333)"'
exit $fail
