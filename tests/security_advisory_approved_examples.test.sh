#!/usr/bin/env bash
# approved-spec: the examples approved on the star "SEC-1 A private report
# becomes a draft advisory only maintainers see", 2026-11-18 and 2026-11-19.
# Each runs the security kit's advisory.sh in a fixture repo against
# stand-ins for gh and tea, so no test drafts a real advisory.
set -u
. "$(dirname "$0")/lib/security-fixture.sh"
draft() { (cd "$1" && bash "$kit/advisory.sh" draft "$2" 2>&1); }
# The GitHub stand-in hands back a draft id and a private fork to push to.
git init -q --bare "$fx/fork.git"
cat > "$fx/answers/gh.sh" <<EOF
case "\$*" in
  *visibility*) echo PUBLIC; exit 0 ;;
  *"/forks"*) echo '{"clone_url":"$fx/fork.git"}'; exit 0 ;;
  *security-advisories*) echo '{"ghsa_id":"GHSA-abcd-efgh-ijkl","state":"draft"}'; exit 0 ;;
esac
EOF
gh_repo=$(repo widget https://github.com/acme/widget.git)
git -C "$gh_repo" switch -q -c fix-upload-path; git -C "$gh_repo" commit -q --allow-empty -m fix; git -C "$gh_repo" switch -q main
line "$gh_repo" "Advisories: github"
file_repo=$(repo gadget https://gitea.example.invalid/acme/gadget.git)
git -C "$file_repo" switch -q -c fix-upload-path; git -C "$file_repo" commit -q --allow-empty -m fix; git -C "$file_repo" switch -q main
line "$file_repo" "Advisories: file"
git -C "$gh_repo" add -A; git -C "$gh_repo" commit -q -m lines; git -C "$file_repo" add -A; git -C "$file_repo" commit -q -m lines
report "$fx/report.json" .

# Given a repo whose docs/agents line says Advisories: github, and a private security report the kit has reproduced
# When the maintainer asks the kit to draft the advisory
# Then a draft advisory appears on the repo's Security tab, in the draft state
: > "$fx/calls.log"; out=$(draft "$gh_repo" "$fx/report.json")
check "SEC-E1 github route drafts on the forge" 'grep "^gh api" "$fx/calls.log" | grep "POST" | grep -qE "repos/acme/widget/security-advisories( |$)" && grep -q "GHSA-abcd-efgh-ijkl" <<<"$out"'

# Given a repo whose line says Advisories: file, and the same report
# When the maintainer asks the kit to draft the advisory
# Then the advisory text and its OSV file appear on the maintainer's machine, and git status shows nothing new
: > "$fx/calls.log"; out=$(draft "$file_repo" "$fx/report.json")
adv=$(sed -n 's/^draft: //p' <<<"$out" | head -1)
check "SEC-E2 file route writes the text and the OSV file" '[ -s "$adv/advisory.md" ] && [ -s "$adv/osv.json" ] && [ -z "$(git -C "$file_repo" status --porcelain)" ]'

# Given a repo whose line says Advisories: off
# When the maintainer asks the kit to draft the advisory
# Then the kit drafts nothing and says advisories are switched off in this repo
off_repo=$(repo off https://github.com/acme/off.git); line "$off_repo" "Advisories: off"
: > "$fx/calls.log"; before=$(drafts); out=$(draft "$off_repo" "$fx/report.json")
check "SEC-E3 off drafts nothing" '[ "$before" = "$(drafts)" ] && ! grep -q security-advisories "$fx/calls.log" && grep -qi "switched off" <<<"$out"'

# Given a repo with no Advisories line
# When the maintainer asks the kit to draft the advisory
# Then the kit drafts nothing and asks the maintainer to type /first-contact
bare_repo=$(repo bare https://github.com/acme/bare.git)
: > "$fx/calls.log"; before=$(drafts); out=$(draft "$bare_repo" "$fx/report.json")
check "SEC-E4 no line asks for first-contact" '[ "$before" = "$(drafts)" ] && ! grep -q security-advisories "$fx/calls.log" && grep -q "/first-contact" <<<"$out"'

# Given a repo whose line says Advisories: github and whose remote is not on GitHub
# When the maintainer asks the kit to draft the advisory
# Then the kit drafts nothing and says the Advisories line and the remote disagree
odd_repo=$(repo odd https://gitea.example.invalid/acme/odd.git); line "$odd_repo" "Advisories: github"
: > "$fx/calls.log"; before=$(drafts); out=$(draft "$odd_repo" "$fx/report.json")
check "SEC-E5 line and remote disagree" '[ "$before" = "$(drafts)" ] && ! grep -q security-advisories "$fx/calls.log" && grep -qi "disagree" <<<"$out"'

# Given a repo with a GitHub remote and no Advisories line
# When the maintainer runs /first-contact
# Then docs/agents holds the line Advisories: github
fc1=$(repo fc1 https://github.com/acme/fc1.git); (cd "$fc1" && bash "$kit/lines.sh" >/dev/null 2>&1)
check "SEC-E6 first-contact writes github" 'grep -qx "Advisories: github" "$fc1"/docs/agents/*.md 2>/dev/null'

# Given a repo with a Gitea remote and no Advisories line
# When the maintainer runs /first-contact
# Then docs/agents holds the line Advisories: file
fc2=$(repo fc2 https://gitea.example.invalid/acme/fc2.git); (cd "$fc2" && bash "$kit/lines.sh" >/dev/null 2>&1)
check "SEC-E7 first-contact writes file" 'grep -qx "Advisories: file" "$fc2"/docs/agents/*.md 2>/dev/null'

# Given a repo whose line already says Advisories: off
# When the maintainer runs /first-contact again
# Then the line still says Advisories: off
fc3=$(repo fc3 https://github.com/acme/fc3.git); line "$fc3" "Advisories: off"; (cd "$fc3" && bash "$kit/lines.sh" >/dev/null 2>&1); ran=$?
check "SEC-E8 first-contact keeps off" '[ "$(cat "$fc3"/docs/agents/*.md | grep -c "^Advisories:")" = 1 ] && grep -qx "Advisories: off" "$fc3/docs/agents/security.md" && [ "$ran" = 0 ]'

# Given a repo with Advisories: github
# When the kit drafts the advisory
# Then no CVE is requested and the advisory stays a draft until the maintainer publishes it
: > "$fx/calls.log"; draft "$gh_repo" "$fx/report.json" >/dev/null
check "SEC-E9 drafting requests no CVE and publishes nothing" 'grep -q security-advisories "$fx/calls.log" && ! grep -qE "/cve|state=published|published" "$fx/calls.log"'

# Given a maintainer whose forge account may not create advisories
# When the kit tries to draft one
# Then the kit says the forge refused and why, and puts the report nowhere else: no issue, no comment, no pull request
cp "$fx/answers/gh.sh" "$fx/gh.ok"
printf 'case "$*" in *security-advisories*) echo "HTTP 403: You must be a security manager or admin (https://api.github.com/...)" >&2; exit 1 ;; esac\n' > "$fx/answers/gh.sh"
: > "$fx/calls.log"; out=$(draft "$gh_repo" "$fx/report.json")
check "SEC-E10 a refusal goes nowhere else" 'grep -qi "refused" <<<"$out" && grep -q "security manager or admin" <<<"$out" && ! grep -qE "gh (issue|pr)|/comments|/issues|/pulls" "$fx/calls.log"'
cp "$fx/gh.ok" "$fx/answers/gh.sh"

# Given a repo with Advisories: github
# When the kit drafts the advisory
# Then the advisory's private fork holds the fix branch, and the public repo gains no branch for it
: > "$fx/calls.log"; draft "$gh_repo" "$fx/report.json" >/dev/null
check "SEC-E11 the fix goes to the private fork only" 'git -C "$fx/fork.git" rev-parse -q --verify refs/heads/fix-upload-path >/dev/null && ! git -C "$fx/widget-public.git" rev-parse -q --verify refs/heads/fix-upload-path >/dev/null'

# Given a repo with Advisories: file
# When the kit drafts the advisory
# Then the fix sits on a local branch that is not pushed
: > "$fx/calls.log"; out=$(draft "$file_repo" "$fx/report.json")
check "SEC-E12 the file route keeps the fix local" 'grep -q "fix-upload-path" <<<"$out" && grep -qi "not pushed" <<<"$out" && [ -z "$(git -C "$file_repo" config branch.fix-upload-path.remote)" ] && ! git -C "$fx/gadget-public.git" rev-parse -q --verify refs/heads/fix-upload-path >/dev/null'

# Given a reproduced report with its fix merged in version 2.4.1
# When the kit drafts the advisory
# Then the draft names a summary, the affected versions, the fixed version 2.4.1, a CWE, a CVSS 4.0 score labelled CVSS-B, the reporter's credit and a link to the fix
adv=$(draft "$file_repo" "$fx/report.json" | sed -n 's/^draft: //p' | head -1); a="$adv/advisory.md"
check "SEC-E13 the draft holds every field" 'grep -q "guest read other users" "$a" && grep -q "< 2.4.1" "$a" && grep -qiE "fixed.*2\.4\.1" "$a" && grep -q "CWE-22" "$a" && grep -q "CVSS-B" "$a" && grep -q "CVSS:4.0/" "$a" && grep -q "Rin Okabe" "$a" && grep -q "example.invalid/widget/commit/abc123" "$a"'

# Given a report holding its reproduction steps and an exploit payload
# When the kit drafts the advisory
# Then the draft holds neither, and loose-lips finds nothing in it
check "SEC-E14 no recipe in the draft" '[ -s "$a" ] && ! grep -rqE "shadow-probe|secret-probe-7731|etc/shadow|%2f" "$adv" && ! grep -rqE "/(home|tmp)/" "$a"'

# Given a reproduced report with no fix yet
# When the kit drafts the advisory
# Then the fixed version is left empty, and the kit says the draft waits on the fix
report "$fx/nofix.json" '.fixed="" | .fix_link="" | .summary="A second flaw with no fix yet"'
out=$(draft "$file_repo" "$fx/nofix.json"); a=$(sed -n 's/^draft: //p' <<<"$out" | head -1)/advisory.md
check "SEC-E15 no fix yet" 'grep -qi "waits on the fix" <<<"$out" && ! grep -q "2.4.1" <(grep -i "fixed" "$a") && jq -e "[.affected[].ranges[]?.events[]? | select(.fixed)] | length == 0" "$(dirname "$a")/osv.json" >/dev/null'

# Given a reporter who asked not to be credited
# When the kit drafts the advisory
# Then the draft credits nobody
report "$fx/anon.json" '.credit="Rin Okabe" | .credit_declined=true | .summary="A third flaw from a reporter who declined credit"'
a=$(draft "$file_repo" "$fx/anon.json" | sed -n 's/^draft: //p' | head -1)
check "SEC-E16 declined credit credits nobody" '[ -n "$a" ] && ! grep -rq "Rin Okabe" "$a" && jq -e "(.credits // []) | length == 0" "$a/osv.json" >/dev/null'

# Given a repo with Advisories: file
# When the kit drafts the advisory
# Then its OSV file passes the OSV schema 1.9.2 check
adv=$(draft "$file_repo" "$fx/report.json" | sed -n 's/^draft: //p' | head -1)
check "SEC-E17 the OSV file passes the 1.9.2 schema" '[ -s "$adv/osv.json" ] && check-jsonschema --schemafile "$root/tests/fixtures/osv-schema-1.9.2.json" "$adv/osv.json" >/dev/null 2>&1 && jq -e ".schema_version == \"1.9.2\"" "$adv/osv.json" >/dev/null'

# Given a report whose weakness the kit's proving run cannot reproduce
# When the maintainer asks the kit to draft the advisory
# Then the kit drafts nothing and says the claim is unproven, naming the run it tried
report "$fx/claim.json" '.run="test -e /nonexistent/proof-of-break" | .summary="A claim no run shows"'
: > "$fx/calls.log"; before=$(drafts); out=$(draft "$gh_repo" "$fx/claim.json")
check "SEC-E18 an unproven claim gets no draft" '[ "$before" = "$(drafts)" ] && ! grep -q security-advisories "$fx/calls.log" && grep -qi "unproven" <<<"$out" && grep -qF "test -e /nonexistent/proof-of-break" <<<"$out"'

# Given a repo with Advisories: file, and a report with no CVE
# When the maintainer asks the kit to draft the advisory
# Then the OSV file's id starts with the repo's own prefix, and names no CVE id
report "$fx/e52.json" '.summary="A flaw for the OSV id"'
adv=$(draft "$file_repo" "$fx/e52.json" | sed -n 's/^draft: //p' | head -1)
check "SEC-E52 the OSV id uses the repo's prefix" 'jq -e "(.id | startswith(\"x_GADGET-\")) and ((.aliases // []) | map(select(startswith(\"CVE-\"))) | length == 0) and (.id | test(\"CVE\") | not)" "$adv/osv.json" >/dev/null'

# Given a reproduced report
# When the kit drafts the advisory
# Then the draft marks its CVSS-B vector as the kit's proposal, for the maintainer to edit
report "$fx/e53.json" '.summary="A flaw for the vector"'
adv=$(draft "$file_repo" "$fx/e53.json" | sed -n 's/^draft: //p' | head -1)
check "SEC-E53 the vector is marked as a proposal" '[ -s "$adv/advisory.md" ] && grep -i "CVSS-B" "$adv/advisory.md" | grep -qi "proposal"'

# Given a draft whose CVSS vector the maintainer edited
# When the kit drafts the advisory again for the same report
# Then the draft keeps the maintainer's vector
report "$fx/e54.json" '.summary="A flaw whose vector is edited"'
adv=$(draft "$file_repo" "$fx/e54.json" | sed -n 's/^draft: //p' | head -1)
edited="CVSS:4.0/AV:N/AC:H/AT:P/PR:L/UI:N/VC:L/VI:N/VA:N/SC:N/SI:N/SA:N"
sed -i "s#CVSS:4.0/[A-Z:/]*#$edited#" "$adv/advisory.md"
again=$(draft "$file_repo" "$fx/e54.json" | sed -n 's/^draft: //p' | head -1)
check "SEC-E54 the maintainer's vector stays" '[ "$again" = "$adv" ] && grep -qF "$edited" "$adv/advisory.md" && ! grep -q "AV:N/AC:L/AT:N/PR:N" "$adv/advisory.md"'

# Given an advisory drafted on the file route in one repo, and then the machine restarted
# When the maintainer drafts an advisory in a second repo
# Then the first repo's draft is still there unchanged, and the second sits apart from it
# A restart empties the temporary folder and ends every process; the next draft is a fresh process.
report "$fx/e55.json" '.summary="A flaw drafted before a restart"'
mkdir -p "$fx/tmp"; adv=$(TMPDIR="$fx/tmp" draft "$file_repo" "$fx/e55.json" | sed -n 's/^draft: //p' | head -1)
first=$(cat "$adv/advisory.md" "$adv/osv.json" 2>/dev/null | sha256sum); rm -rf "$fx/tmp"; mkdir -p "$fx/tmp"
second_repo=$(repo second https://gitea.example.invalid/acme/second.git); line "$second_repo" "Advisories: file"
other=$(TMPDIR="$fx/tmp" draft "$second_repo" "$fx/e55.json" | sed -n 's/^draft: //p' | head -1)
still=$(TMPDIR="$fx/tmp" draft "$file_repo" "$fx/e55.json" | sed -n 's/^draft: //p' | head -1)
check "SEC-E55 drafts survive and stay per repo" '[ -s "$adv/advisory.md" ] && [ "$still" = "$adv" ] && [ "$(cat "$adv/advisory.md" "$adv/osv.json" | sha256sum)" = "$first" ] && [ -s "$other/advisory.md" ] && [ "$(dirname "$other")" != "$(dirname "$adv")" ]'

# Given a machine with fp-check installed, and a private report
# When the maintainer asks the kit to draft the advisory
# Then the kit checks the report's claim with fp-check before drafting, and says so
installed fp-check
report "$fx/fp.json" '.summary="A claim fp-check must weigh first"'
before=$(drafts); out=$(draft "$file_repo" "$fx/fp.json")
unchecked=$([ "$before" = "$(drafts)" ] && grep -q "fp-check" <<<"$out" && echo yes)
report "$fx/fp.json" '.summary="A claim fp-check must weigh first" | .fp_check="TRUE POSITIVE"'
out=$(draft "$file_repo" "$fx/fp.json")
check "SEC-E56 fp-check checks the claim first" '[ "$unchecked" = yes ] && grep -q "^draft: " <<<"$out" && grep -qi "checked by fp-check" <<<"$out"'
exit $fail
