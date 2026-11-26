# shellcheck shell=bash
# Sourced by the Gitea fork tests: the fork fixture moved to a Gitea host, and a
# fake tea that answers logins list, api user, repo lookups, forks, pull
# requests and workflow runs from files under $dir, and a gh that always fails.
# shellcheck source=fork-fixture.sh
. "$(dirname "${BASH_SOURCE[0]}")/fork-fixture.sh"
G=https://git.example.invalid
cat > "$dir/tea/tea" <<EOF
#!/usr/bin/env bash
# $dir/tea-logins: the logins list JSON. $dir/repos and $dir/runs as for gh.
[ "\$1 \$2" = "logins list" ] && { [ -f "$dir/tea-logins" ] && cat "$dir/tea-logins"; exit \$?; }
[ "\$1" = api ] || exit 1
shift; m=GET ep="" lg=""
while [ \$# -gt 0 ]; do case "\$1" in -l|--login) lg=\$2; shift ;; -X|--method) m=\$2; shift ;; -*) ;; *) ep=\$1 ;; esac; shift; done
[ -f "$dir/tea-down" ] && exit 1
# Outside the repo's own context, as {owner}/{repo} gives it, a call must name its login.
[[ \$ep == *'{owner}'* ]] || [ -n "\$lg" ] || exit 1
url() { printf '%s/%s.git' "$G" "\$1"; }
case "\$m \$ep" in
  "GET user") echo '{"login":"me"}' ;;
  "GET user/repos"*) [[ \$ep == *page=1 ]] || { echo '[]'; exit 0; }; awk '\$2 == "me" && \$3 != "-"' "$dir/repos" | jq -Rn --arg g "$G" '[inputs | split(" ") | {full_name: .[0], fork: true, clone_url: ("\(\$g)/\(.[0]).git"), parent: {full_name: .[2], clone_url: ("\(\$g)/\(.[2]).git")}}]' ;;
  "GET repos/"*"/pulls"*) [ -f "$dir/prs" ] && [ ! -f "$dir/prs-fail" ] || exit 1
    p=\$(grep -o 'page=[0-9]*' <<<"\$ep" | cut -d= -f2); p=\${p:-1}; sed -n "\$(( (p-1)*50+1 )),\$(( p*50 ))p" "$dir/prs" | jq -Rn '[inputs | split(" ") | {head: {ref: .[0], sha: .[2]}, merged: (.[1] == "MERGED"), state: (if .[1] == "OPEN" then "open" else "closed" end)}]' ;;
  "GET repos/"*"/actions/runs?branch="*) s=\${ep#repos/}; s=\${s%%/actions/*}; b=\${ep##*branch=}; b=\${b%%&*}
    awk -v r="\$s" -v b="\$b" '\$1 == r && \$2 == b {print \$3}' "$dir/runs" 2>/dev/null | jq -Rn '{workflow_runs: [inputs | {id: (. | tonumber)}]}' ;;
  "DELETE repos/"*"/actions/runs/"*) s=\${ep#repos/}; s=\${s%%/actions/*}; i=\${ep##*/}
    awk -v r="\$s" -v i="\$i" '!(\$1 == r && \$3 == i)' "$dir/runs" > "$dir/runs.new"; mv "$dir/runs.new" "$dir/runs" ;;
  "GET repos/"*) s=\${ep#repos/}; read -r _ o p < <(grep "^\$s " "$dir/repos") || exit 1
    jq -n --arg o "\$o" --arg p "\$p" '{owner: {login: \$o}, fork: (\$p != "-"), parent: (if \$p == "-" then null else {full_name: \$p} end)}' ;;
  *) exit 1 ;;
esac
EOF
# A gh that always fails sits beside the fake tea, so the real gh never answers.
printf '#!/usr/bin/env bash\nexit 1\n' > "$dir/tea/gh"
chmod +x "$dir/tea/tea" "$dir/tea/gh"
# gsetup: the fork setup, with origin, your fork and someone's fork on the Gitea host.
gsetup() {
  fsetup; rm -f "$dir/tea-down"; FORGE=tea
  printf '[{"name":"gt","url":"%s","user":"me"}]\n' "$G" > "$dir/tea-logins"
  printf '[url "%s/origin.git"]\n\tinsteadOf = %s/up/proj.git\n[url "%s/fork.git"]\n\tinsteadOf = %s/me/proj.git\n[url "%s/other.git"]\n\tinsteadOf = %s/someone/proj.git\n' "$dir" "$G" "$dir" "$G" "$dir" "$G" > "$dir/gitconfig"
  git -C "$dir/repo" remote set-url origin "$G/up/proj.git"
  git -C "$dir/repo" remote set-url fork "$G/me/proj.git"
  git -C "$dir/repo" fetch -q fork
}
# gsweep: the sweep with only the fake tea on PATH.
gsweep() { env PATH="$dir/tea:$PATH" bash "$sweep" 2>&1; }
