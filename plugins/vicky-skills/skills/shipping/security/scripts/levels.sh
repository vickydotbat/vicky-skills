#!/usr/bin/env bash
# levels.sh [level ...]: runs the security kit's levels in the repo it is run
# from, every level the repo's `Security levels:` line allows, or only the ones
# named. Each level runs its tool and reports what the tool found, naming the
# run and the rule in STANDARDS.md's Security section it proves. A missing
# tool is named with where to get it, and the other levels still run. Nothing
# is installed. SECURITY_SINCE=<ref> limits the secrets level to <ref>..HEAD.
set -u
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=kit.sh
. "$here/kit.sh"
standards="$here/../../../STANDARDS.md"
all="baseline secrets ci dependencies"

allowed=$(line 'Security levels')
case "$allowed" in
  off) echo "security: the checks are switched off in this repo (Security levels: off in docs/agents/)."; exit 0 ;;
  "") echo "security: this repo has no Security levels line in docs/agents/. Ask the user to type /first-contact, which writes it."; exit 1 ;;
esac
allowed=$(tr ',' ' ' <<<"$allowed")
for l in $allowed "$@"; do
  case " $all " in *" $l "*) ;; *) echo "security: \"$l\" is no level; the levels are $all." ;; esac
done
wanted=${*:-$all}

# rule <tool>: the leading word of the Security rule whose proving run is <tool>.
rule() {
  awk '/^## Security/{s=1;next} /^## /{s=0} s' "$standards" | grep -F "\`$1" | head -n1 |
    sed -nE 's/^- \*\*([^*]+)\.\*\*.*/\1/p'
}
finding() { echo "$1: finding: $2 (rule: $(rule "$3"); run: $4)"; }
# need <level> <tool> <where to get it>: whether the tool is on PATH, saying so when not.
need() { command -v "$2" >/dev/null && return 0; echo "$1: $2 is missing. Get it from $3. Nothing was installed, and the other levels still run."; return 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

secrets() {
  need secrets gitleaks https://github.com/gitleaks/gitleaks#installing || return 0
  local opts=() code # mutant-ok delete: no other function uses these names
  [ -n "${SECURITY_SINCE:-}" ] && opts=(--log-opts="$SECURITY_SINCE..HEAD")
  (cd "$top" && gitleaks git "${opts[@]}" --redact --no-banner --report-format json --report-path "$tmp/leaks.json" --exit-code 1 >/dev/null 2>&1); code=$?
  case $code in
    0) echo "secrets: gitleaks found nothing (run: gitleaks git)." ;;
    1) # The report holds the secret itself: only its place leaves this function.
       jq -r '.[] | "\(.File):\(.StartLine // "?") in commit \(.Commit[0:12]) (\(.RuleID))"' "$tmp/leaks.json" |
         while read -r where; do finding secrets "a secret at $where" gitleaks "gitleaks git"; done ;;
    *) echo "secrets: gitleaks failed with exit $code, so this level has no result." ;;
  esac
}

ci() {
  local dirs=() d code
  for d in .github/workflows .gitea/workflows .forgejo/workflows; do
    compgen -G "$top/$d/*.y*ml" >/dev/null && dirs+=("$d")
  done
  [ ${#dirs[@]} -gt 0 ] || { echo "ci: no CI workflows, so there is nothing to check."; return 0; }
  need ci zizmor https://docs.zizmor.sh/installation/ || return 0
  (cd "$top" && zizmor --format json "${dirs[@]}" > "$tmp/ci.json" 2>/dev/null); code=$?
  case $code in
    0) echo "ci: zizmor found nothing (run: zizmor)." ;;
    1[0-4]) jq -r '.[] | "\(.locations[0].symbolic.key.Local.given_path):\(.locations[0].concrete.location.start_point.row + 1) \(.ident): \(.desc)"' "$tmp/ci.json" |
         while read -r what; do finding ci "$what" zizmor zizmor; done ;;
    *) echo "ci: zizmor failed with exit $code, so this level has no result." ;;
  esac
}

# scorecard_check <level> <check>: runs one scorecard check on a GitHub or GitLab repo.
scorecard_check() {
  local repo # mutant-ok delete: no other function uses these names
  repo=$(forge_slug 'github\.com'); [ -n "$repo" ] && repo="github.com/$repo"
  [ -n "$repo" ] || { repo=$(forge_slug 'gitlab\.com'); [ -n "$repo" ] && repo="gitlab.com/$repo"; }
  [ -n "$repo" ] || { echo "$1: scorecard cannot check this forge: it reads GitHub and GitLab only."; return 1; }
  need "$1" scorecard https://github.com/ossf/scorecard#installation || return 1
  # scorecard reads the forge's API with the token gh already holds; it is never printed.
  GITHUB_AUTH_TOKEN=${GITHUB_AUTH_TOKEN:-$(gh auth token 2>/dev/null)} \
    scorecard --repo "$repo" --checks "$2" --show-details --format json > "$tmp/score.json" 2>/dev/null ||
    { echo "$1: scorecard failed on $2, so this level has no result."; return 1; }
}

baseline() {
  if scorecard_check baseline Security-Policy; then
    local score; score=$(jq -r '.checks[0].score' "$tmp/score.json")
    case $score in
      10) echo "baseline: scorecard's Security-Policy check found a security policy (run: scorecard --checks Security-Policy)." ;;
      -1|null|"") echo "baseline: scorecard's Security-Policy check could not decide: $(jq -r '.checks[0].reason' "$tmp/score.json")." ;;
      *) if compgen -G "$top/SECURITY.md" >/dev/null || compgen -G "$top/.github/SECURITY.md" >/dev/null || compgen -G "$top/docs/SECURITY.md" >/dev/null; then
           echo "baseline: unchecked: this checkout has a SECURITY.md, but scorecard reads the default branch. Run the level again once it merges."
         else finding baseline "$(jq -r '.checks[0].reason' "$tmp/score.json")" scorecard "scorecard --checks Security-Policy"; fi ;;
    esac
  fi
  reporting
}

# reporting: on GitHub, whether private vulnerability reporting is on, since a
# policy that points at the Security tab has no way in while it is off.
reporting() {
  [ -n "$slug" ] || return 0
  need baseline gh https://cli.github.com || return 0
  local run="gh api repos/$slug/private-vulnerability-reporting" on
  on=$(gh api "repos/$slug/private-vulnerability-reporting" --jq .enabled 2>/dev/null)
  case $on in
    true) echo "baseline: private vulnerability reporting is on (run: $run)." ;;
    false) finding baseline "private vulnerability reporting is off, so the Security tab has no Report a vulnerability button" scorecard "$run" ;;
    *) echo "baseline: could not read the private vulnerability reporting setting, so this part has no result." ;;
  esac
}

dependencies() {
  local out code # mutant-ok delete: no other function uses these names
  if [ -f "$top/flake.nix" ] || [ -f "$top/default.nix" ]; then
    need dependencies vulnix https://github.com/nix-community/vulnix || return 0
    if [ -f "$top/flake.nix" ]; then out=$(cd "$top" && nix build --no-link --print-out-paths 2>/dev/null | head -n1)
    else out=$(cd "$top" && nix-build --no-out-link 2>/dev/null | head -n1); fi
    [ -n "$out" ] || { echo "dependencies: the Nix build failed, so vulnix had nothing to read."; return 0; }
    vulnix --json "$out" > "$tmp/vulnix.json" 2>/dev/null; code=$?
    case $code in
      0) echo "dependencies: vulnix found nothing (run: vulnix)." ;;
      2) jq -r '.[] | "\(.name) is affected by \(.affected_by | join(", "))"' "$tmp/vulnix.json" |
           while read -r what; do finding dependencies "$what" vulnix vulnix; done ;;
      *) echo "dependencies: vulnix failed with exit $code, so this level has no result." ;;
    esac
    return 0
  fi
  echo "dependencies: vulnix does not apply, since this repo has no Nix build. Running scorecard's Vulnerabilities check."
  scorecard_check dependencies Vulnerabilities || return 0
  if [ "$(jq -r '.checks[0].score' "$tmp/score.json")" = 10 ]; then
    echo "dependencies: scorecard's Vulnerabilities check found nothing (run: scorecard --checks Vulnerabilities)."
  else
    jq -r '.checks[0].details[]? | select(startswith("Warn: ")) | sub("^Warn: "; "")' "$tmp/score.json" |
      while read -r what; do finding dependencies "$what" "scorecard --checks Vulnerabilities" "scorecard --checks Vulnerabilities"; done
  fi
}

for l in $all; do
  case " $wanted " in *" $l "*) ;; *) continue ;; esac
  case " $allowed " in *" $l "*) "$l" ;; *) echo "$l: switched off by this repo's Security levels line." ;; esac
done
