#!/usr/bin/env bash
# approved-spec: the examples approved on the star "SEC-3 Each security rule
# names the run that proves a break", 2026-11-19. Each runs the security
# kit's levels.sh, review.sh or lines.sh in a fixture repo, against stand-ins
# for gitleaks, zizmor, scorecard, vulnix and nix that answer the way each
# tool's JSON output does.
set -u
. "$(dirname "$0")/lib/security-fixture.sh"
levels() { (cd "$1" && shift && bash "$kit/levels.sh" "$@" 2>&1); }
standards="$plugin/skills/STANDARDS.md"
# rule_named <output> <tool>: the output names the leading word of the rule in
# STANDARDS.md's Security section whose proving run is <tool>.
rule_named() {
  local r; r=$(awk '/^## Security/{s=1;next} /^## /{s=0} s' "$standards" | grep -F "\`$2" | head -1 | grep -o '^- \*\*[^*]*\*\*' | sed 's/^- \*\*//; s/\*\*$//; s/\.$//')
  [ -n "$r" ] && grep -qF "$r" <<<"$1" && grep -q "$2" <<<"$1"
}
leak_key="FAKE-KEY-not-a-real-token-4417"
cat > "$fx/answers/gitleaks.sh" <<EOF
while [ \$# -gt 0 ]; do [ "\$1" = --report-path ] && out=\$2; shift; done
if [ -f "$fx/leak" ]; then
  printf '[{"RuleID":"github-pat","File":"config/app.env","Commit":"4b825dc642cb6eb9a060e54bf8d69288fbee4904","StartLine":3,"Secret":"$leak_key","Match":"TOKEN=$leak_key"}]' > "\$out"; exit 1
fi
echo '[]' > "\$out"; exit 0
EOF
gh=$(repo widget https://github.com/acme/widget.git)
line "$gh" "Security levels: baseline, secrets, ci, dependencies"

# Given a repo with an API key committed in an old commit
# When the maintainer runs the kit's secrets level
# Then the kit reports the file and the commit, and names gitleaks as the run that found it
touch "$fx/leak"; out=$(levels "$gh" secrets)
check "SEC-E19 a leaked key is reported with its run" 'grep -q "config/app.env" <<<"$out" && grep -q "4b825dc" <<<"$out" && grep -q "gitleaks" <<<"$out"'

# Given the same leaked key
# When the kit reports it
# Then the report never shows the key itself
check "SEC-E20 the key is never printed" 'grep -q "config/app.env" <<<"$out" && ! grep -q "FAKE-KEY-not-a-real" <<<"$out"'

secrets_out=$out

# Given a repo with no secret in its history
# When the maintainer runs the kit's secrets level
# Then the kit says gitleaks found nothing
rm "$fx/leak"; out=$(levels "$gh" secrets)
check "SEC-E21 a clean history" 'grep -qi "gitleaks found nothing" <<<"$out"'

# Given a workflow that puts a pull request's title straight into a shell step
# When the maintainer runs the kit's CI hardening level
# Then the kit reports the workflow and its line, and names zizmor as the run that found it
mkdir -p "$gh/.github/workflows"; printf 'on: pull_request_target\njobs:\n  a:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo "${{ github.event.pull_request.title }}"\n' > "$gh/.github/workflows/greet.yml"
cat > "$fx/answers/zizmor" <<'EOF'
[{"ident":"template-injection","desc":"code injection via template expansion","determinations":{"severity":"High"},"locations":[{"symbolic":{"key":{"Local":{"given_path":".github/workflows/greet.yml"}}},"concrete":{"location":{"start_point":{"row":5,"column":14}}}}]}]
EOF
echo 14 > "$fx/answers/zizmor.exit"
out=$(levels "$gh" ci); ci_out=$out
check "SEC-E22 a template injection is reported with its run" 'grep -q "greet.yml" <<<"$out" && grep -qE "greet.yml:6|line 6" <<<"$out" && grep -q "zizmor" <<<"$out"'

# Given a repo with no CI workflows
# When the maintainer runs the kit's CI hardening level
# Then the kit says there is nothing to check, and reports no finding
nowf=$(repo nowf https://github.com/acme/nowf.git); line "$nowf" "Security levels: ci"
: > "$fx/calls.log"; out=$(levels "$nowf" ci)
check "SEC-E23 no workflows, nothing to check" 'grep -qi "nothing to check" <<<"$out" && ! grep -qi "finding" <<<"$out" && ! grep -q "^zizmor" "$fx/calls.log"'

# Given a GitHub repo with no SECURITY.md
# When the maintainer runs the kit's baseline level
# Then the kit reports the missing security policy, and names scorecard's Security-Policy check as the run
cat > "$fx/answers/scorecard.sh" <<'EOF'
case "$*" in
  *Security-Policy*) echo '{"checks":[{"name":"Security-Policy","score":0,"reason":"security policy file not detected","details":["Warn: no security policy file detected"]}]}'; exit 0 ;;
  *Vulnerabilities*) echo '{"checks":[{"name":"Vulnerabilities","score":7,"reason":"1 existing vulnerabilities detected","details":["Warn: Project is vulnerable to: GHSA-jfh8-c2jp-5v3q / CVE-2021-44228"]}]}'; exit 0 ;;
esac
EOF
: > "$fx/calls.log"; out=$(levels "$gh" baseline); base_out=$out
check "SEC-E24 a missing policy is reported with its run" 'grep -qi "security policy" <<<"$out" && grep -q "Security-Policy" <<<"$out" && grep -q "scorecard" <<<"$out" && grep -q "^scorecard .*Security-Policy" "$fx/calls.log"'

# Given a Nix project whose build holds a package with a published CVE
# When the maintainer runs the kit's dependency watch level
# Then the kit reports the package and the CVE id, and names vulnix as the run
echo '{ }' > "$gh/flake.nix"
echo "$fx/store/abc-widget-1.0" > "$fx/answers/nix"
echo '[{"name":"openssl-3.0.1","pname":"openssl","version":"3.0.1","affected_by":["CVE-2026-0001"],"cvssv3_basescore":{"CVE-2026-0001":9.8}}]' > "$fx/answers/vulnix"
echo 2 > "$fx/answers/vulnix.exit"
out=$(levels "$gh" dependencies); dep_out=$out
check "SEC-E25 a vulnerable package is reported with its run" 'grep -q "openssl" <<<"$out" && grep -q "CVE-2026-0001" <<<"$out" && grep -q "vulnix" <<<"$out"'

# Given a finding from any level
# When the kit reports it
# Then the report names the STANDARDS.md security rule it breaks, beside the run that showed it
check "SEC-E57 each finding names its STANDARDS.md rule beside its run" 'rule_named "$secrets_out" gitleaks && rule_named "$ci_out" zizmor && rule_named "$base_out" scorecard && rule_named "$dep_out" vulnix'

# Given a machine without zizmor
# When the maintainer runs the kit's CI hardening level
# Then the kit says zizmor is missing and where to get it, and installs nothing
mv "$fx/bin/zizmor" "$fx/zizmor.off"
: > "$fx/calls.log"; out=$(levels "$gh" ci)
check "SEC-E26 a missing tool is named, never installed" 'grep -qi "zizmor is missing" <<<"$out" && grep -qE "https?://" <<<"$out" && ! grep -qE "^(pip|pipx|cargo|brew|nix-env|apt|apt-get) |^nix (profile|shell|run)" "$fx/calls.log"'

# Given a machine without zizmor
# When the maintainer runs every level
# Then the secrets, baseline and dependency levels still report, and only CI hardening says its tool is missing
out=$(levels "$gh")
check "SEC-E27 the other levels still run" 'grep -qi "gitleaks found nothing" <<<"$out" && grep -q "Security-Policy" <<<"$out" && grep -q "CVE-2026-0001" <<<"$out" && [ "$(grep -ci "is missing" <<<"$out")" = 1 ] && grep -i "is missing" <<<"$out" | grep -q zizmor'
mv "$fx/zizmor.off" "$fx/bin/zizmor"

# Given a machine with /security-review and fp-check installed
# When the maintainer asks the kit for a security review of a branch
# Then the review runs through them, and the kit adds no review of its own
installed fp-check
: > "$fx/calls.log"; out=$( (cd "$gh" && bash "$kit/review.sh" main 2>&1) )
check "SEC-E30 review goes to /security-review and fp-check" 'grep -q "/security-review" <<<"$out" && grep -q "fp-check" <<<"$out" && ! grep -qE "^(gitleaks|zizmor|scorecard|vulnix)" "$fx/calls.log"'

all_ran() { local t; for t in gitleaks zizmor scorecard vulnix; do grep -q "^$t" "$fx/calls.log" || return 1; done; }
# Given a machine with neither installed
# When the maintainer asks the kit for a security review of a branch
# Then the kit runs each security rule's named run on the branch, and reports only what a run showed
echo '{"version":2,"plugins":{}}' > "$fx/config/plugins/installed_plugins.json"
touch "$fx/leak"; : > "$fx/calls.log"; out=$( (cd "$gh" && bash "$kit/review.sh" main 2>&1) )
check "SEC-E31 no tools, the kit's own runs" 'all_ran && grep -q "config/app.env" <<<"$out" && ! grep -q "/security-review" <<<"$out"'
rm -f "$fx/leak"

# Given a repo whose docs/agents line says Security levels: off
# When the maintainer runs the kit's checks
# Then nothing runs, and the kit says the checks are switched off in this repo
off=$(repo off https://github.com/acme/off.git); line "$off" "Security levels: off"
: > "$fx/calls.log"; out=$(levels "$off")
check "SEC-E32 off runs nothing" '[ ! -s "$fx/calls.log" ] && grep -qi "switched off" <<<"$out"'

# Given a repo whose line says Security levels: secrets, ci
# When the maintainer runs every level
# Then only the secrets and CI hardening levels run
some=$(repo some https://github.com/acme/some.git); line "$some" "Security levels: secrets, ci"
mkdir -p "$some/.github/workflows"; cp "$gh/.github/workflows/greet.yml" "$some/.github/workflows/"; echo '{ }' > "$some/flake.nix"
: > "$fx/calls.log"; levels "$some" >/dev/null
check "SEC-E33 only the listed levels run" 'grep -q "^gitleaks" "$fx/calls.log" && grep -q "^zizmor" "$fx/calls.log" && ! grep -qE "^(scorecard|vulnix|nix)" "$fx/calls.log"'

# Given a repo with no Security levels line
# When the maintainer runs /first-contact
# Then docs/agents holds the line Security levels: baseline, secrets, ci, dependencies
fc=$(repo fc https://github.com/acme/fc.git); (cd "$fc" && bash "$kit/lines.sh" >/dev/null 2>&1)
check "SEC-E34 first-contact writes all four" 'grep -qx "Security levels: baseline, secrets, ci, dependencies" "$fc"/docs/agents/*.md 2>/dev/null'

# Given a repo with no Nix build and a dependency with a published CVE
# When the maintainer runs the kit's dependency watch level
# Then the kit reports the dependency and the CVE id from scorecard's Vulnerabilities check, and says vulnix does not apply
nonix=$(repo nonix https://github.com/acme/nonix.git); line "$nonix" "Security levels: dependencies"
: > "$fx/calls.log"; out=$(levels "$nonix" dependencies)
check "SEC-E58 dependency watch without Nix" 'grep -q "CVE-2021-44228" <<<"$out" && grep -q "Vulnerabilities" <<<"$out" && grep -qi "vulnix does not apply" <<<"$out" && ! grep -q "^vulnix" "$fx/calls.log"'

# Given a repo on a forge scorecard does not read, such as Gitea
# When the maintainer runs the kit's baseline level
# Then the kit says scorecard cannot check this forge, and reports neither a finding nor a pass
gitea=$(repo gitea https://gitea.example.invalid/acme/gitea.git); line "$gitea" "Security levels: baseline"
: > "$fx/calls.log"; out=$(levels "$gitea" baseline)
check "SEC-E59 baseline off GitHub" 'grep -qi "scorecard cannot check this forge" <<<"$out" && ! grep -qiE "finding|found nothing|\bpass(ed|es)?\b" <<<"$out" && ! grep -q "^scorecard" "$fx/calls.log"'
exit $fail
