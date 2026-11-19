# shellcheck shell=bash
# Sourced by the security kit's tests. Builds a throwaway repo, a data folder
# and stand-ins for every outside tool the kit calls (gh, tea, gitleaks,
# zizmor, scorecard, vulnix, nix), so no test reaches a real forge or network.
# Each stand-in logs its arguments to $fx/calls.log and answers from files the
# test writes into $fx/answers/<tool>, or from the env vars named below.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
plugin="$root/plugins/vicky-skills"
kit="$plugin/skills/shipping/security/scripts"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/bin" "$fx/data" "$fx/answers" "$fx/config/plugins"
echo '{"version":2,"plugins":{}}' > "$fx/config/plugins/installed_plugins.json"
export CLAUDE_PLUGIN_DATA="$fx/data" CLAUDE_CONFIG_DIR="$fx/config" GIT_CONFIG_GLOBAL="$fx/gitconfig"
git config --global user.name tester; git config --global user.email tester@example.invalid
git config --global init.defaultBranch main
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# stub <tool>: a stand-in that logs its call, prints $fx/answers/<tool> when it
# exists, and exits with the number in $fx/answers/<tool>.exit (0 otherwise).
stub() {
  cat > "$fx/bin/$1" <<EOF
#!/usr/bin/env bash
echo "$1 \$*" >> "$fx/calls.log"
[ -f "$fx/answers/$1.sh" ] && { . "$fx/answers/$1.sh"; }
[ -f "$fx/answers/$1" ] && cat "$fx/answers/$1"
exit \$(cat "$fx/answers/$1.exit" 2>/dev/null || echo 0)
EOF
  chmod +x "$fx/bin/$1"
}
# The bare tool names the kit looks for. A test deletes one to make it missing.
for t in gh tea gitleaks zizmor scorecard vulnix nix pip pipx cargo brew nix-env apt apt-get; do stub "$t"; done
# The kit sees the stand-ins and a fixed set of real tools, never the host's own
# copy of a tool a test has taken away.
mkdir -p "$fx/sys"
for t in bash sh env git jq sed awk grep date cat ls mkdir rm mv cp ln find sort head tail tr cut wc sha256sum mktemp xargs basename dirname printf test tee touch timeout python3 check-jsonschema realpath readlink stat uname id chmod sleep seq comm uniq diff; do
  p=$(command -v "$t") && [ -x "$p" ] && ln -sf "$p" "$fx/sys/$t"
done
export PATH="$fx/bin:$fx/sys"

# repo <name> <remote url>: a git repo whose origin says <remote url> and
# pushes to a local bare repo, so a push lands where the test can look.
repo() {
  local r="$fx/$1"
  git init -q "$r"; git init -q --bare "$fx/$1-public.git"
  git -C "$r" commit -q --allow-empty -m start
  git -C "$r" remote add origin "$2"
  git config --global "url.$fx/$1-public.git.pushInsteadOf" "$2"
  mkdir -p "$r/docs/agents"
  echo "$r"
}
# line <repo> <text>: one line in the repo's docs/agents/security.md.
line() { echo "$2" >> "$1/docs/agents/security.md"; }
# report <file> <jq filter>: a report file, the base fields changed by the filter.
report() {
  jq -n '{summary:"A crafted file name lets a guest read other users'"'"' uploads",
    affected:"< 2.4.1", fixed:"2.4.1", cwe:"CWE-22",
    cvss:"CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:N/VA:N/SC:N/SI:N/SA:N",
    credit:"Rin Okabe", fix_link:"https://example.invalid/widget/commit/abc123",
    steps:"Upload a file named ../../etc/shadow-probe and fetch it back",
    payload:"GET /files/..%2f..%2fsecret-probe-7731",
    run:"true", received:"2026-11-01", fix_branch:"fix-upload-path"} | '"$2" > "$1"
}
# installed <name>: marks a Claude Code plugin as installed.
installed() { jq --arg k "$1@trailofbits" '.plugins[$k]=[{"version":"1.0.5"}]' "$fx/config/plugins/installed_plugins.json" > "$fx/i.json" && mv "$fx/i.json" "$fx/config/plugins/installed_plugins.json"; }
# drafts <repo>: every file the kit keeps for that repo's drafts.
drafts() { find "$CLAUDE_PLUGIN_DATA/advisories" -type f 2>/dev/null | sort; }
