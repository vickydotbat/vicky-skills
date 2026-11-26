# shellcheck shell=bash
# Sourced by the fork tests: the auto-tidy fixture, plus a fork of origin on a
# second remote, both behind github.com URLs that git rewrites to local bare
# repos, and a fake gh that also answers repo view, repo list, api user, run
# list and run delete from files under $dir.
. "$(dirname "${BASH_SOURCE[0]}")/auto-tidy-fixture.sh"
sweep="$root/plugins/vicky-skills/scripts/fork-sweep.sh"
export GIT_CONFIG_GLOBAL="$dir/gitconfig"
cat > "$dir/gh/gh" <<EOF
#!/usr/bin/env bash
# $dir/repos: <slug> <owner> <parent slug or ->. $dir/runs: <slug> <branch> <id>.
arg() { local f=\$1; shift; while [ \$# -gt 0 ]; do [ "\$1" = "\$f" ] && { echo "\$2"; return; }; shift; done; }
case "\$1 \$2" in
  "pr list") [ -f "$dir/prs" ] && [ ! -f "$dir/prs-fail" ] || exit 1
    jq -Rn '[inputs | split(" ") | {headRefName: .[0], state: .[1], headRefOid: .[2]}]' "$dir/prs" ;;
  "repo view") s=\$(sed -E 's#^https://github.com/##; s#\.git\$##' <<<"\$3")
    read -r _ o p < <(grep "^\$s " "$dir/repos") || exit 1
    jq -n --arg o "\$o" --arg p "\$p" '{owner: {login: \$o}, parent: (if \$p == "-" then null else {owner: {login: (\$p | split("/")[0])}, name: (\$p | split("/")[1])} end)}' ;;
  "repo list") awk '\$2 == "me" && \$3 != "-"' "$dir/repos" | jq -Rn '[inputs | split(" ") | {nameWithOwner: .[0], parent: {owner: {login: (.[2] | split("/")[0])}, name: (.[2] | split("/")[1])}}]' ;;
  "api user") echo me ;;
  "run list") r=\$(arg -R "\$@"); b=\$(arg --branch "\$@")
    awk -v r="\$r" -v b="\$b" '\$1 == r && \$2 == b {print \$3}' "$dir/runs" 2>/dev/null | jq -Rn '[inputs | {databaseId: (. | tonumber)}]' ;;
  "run delete") r=\$(arg -R "\$@"); awk -v r="\$r" -v i="\$3" '!(\$1 == r && \$3 == i)' "$dir/runs" > "$dir/runs.new"; mv "$dir/runs.new" "$dir/runs" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$dir/gh/gh"
# fsetup: origin is up/proj, your fork me/proj holds the same main, and the clone has both remotes.
fsetup() {
  setup; rm -rf "$dir/fork.git" "$dir/other.git" "$dir/runs" "$dir/prs-fail"; : > "$dir/prs"
  git clone -q --bare "$dir/origin.git" "$dir/fork.git"
  printf '[url "%s/origin.git"]\n\tinsteadOf = https://github.com/up/proj.git\n[url "%s/fork.git"]\n\tinsteadOf = https://github.com/me/proj.git\n[url "%s/other.git"]\n\tinsteadOf = https://github.com/someone/proj.git\n' "$dir" "$dir" "$dir" > "$dir/gitconfig"
  printf 'up/proj up -\nme/proj me up/proj\nsomeone/proj someone up/proj\n' > "$dir/repos"
  git -C "$dir/repo" remote set-url origin https://github.com/up/proj.git
  git -C "$dir/repo" remote add fork https://github.com/me/proj.git
  git -C "$dir/repo" fetch -q fork
}
# fbranch <bare repo> <name>: a branch with one commit of its own, from main, pushed only to that bare repo.
fbranch() {
  rm -rf "$dir/w"; git clone -q "$dir/$1" "$dir/w" 2>/dev/null
  git -C "$dir/w" switch -q -c "$2" origin/main; echo "$2" > "$dir/w/$2.txt"; git -C "$dir/w" add "$2.txt"; git -C "$dir/w" commit -q -m "$2"
  git -C "$dir/w" push -q origin "$2" 2>/dev/null; rm -rf "$dir/w"
}
# land <name>: squash the fork branch onto origin's main, and record its pull request merged at the fork's head.
land() {
  local sha; sha=$(git -C "$dir/fork.git" rev-parse "$1")
  rm -rf "$dir/w"; git clone -q "$dir/origin.git" "$dir/w" 2>/dev/null
  git -C "$dir/w" fetch -q "$dir/fork.git" "$1"; git -C "$dir/w" merge -q --squash FETCH_HEAD >/dev/null 2>&1; git -C "$dir/w" commit -q -m "$1 (#1)"
  git -C "$dir/w" push -q origin main 2>/dev/null; rm -rf "$dir/w"
  echo "$1 MERGED $sha" >> "$dir/prs"
}
# on <bare repo> <branch>: the branch exists there.
on() { git -C "$dir/$1" rev-parse -q --verify "refs/heads/$2" >/dev/null; }
runsweep() { env PATH="$dir/gh:$PATH" bash "$sweep" 2>&1; }
