#!/usr/bin/env bash
# approved-spec: the examples approved on the star "SEC-2 A CVE is requested
# and an advisory published only on the user's word", 2026-11-19. The guard
# hook reads a fixture transcript; a command it lets through then runs
# against stand-ins for gh and tea, so no test reaches a forge.
set -u
. "$(dirname "$0")/lib/security-fixture.sh"
guard="$plugin/scripts/advisory-guard.sh"
deadline_hook="$plugin/scripts/advisory-deadline.sh"
t="$fx/transcript.jsonl"
# say <text> [seconds from now]: the maintainer's last message, at that time.
say() { jq -nc --arg c "$1" --arg ts "$(date -u -d "${2:-0} seconds" +%Y-%m-%dT%H:%M:%S.000Z)" '{type:"user",timestamp:$ts,message:{content:$c}}' >> "$t"; }
fresh() { : > "$t"; }
# agent <command>: the agent runs <command> in <repo> through the guard. Prints deny, or the command's output.
agent() {
  local repo=$1 cmd=$2
  jq -nc --arg c "$cmd" --arg t "$t" '{tool_name:"Bash",tool_input:{command:$c},transcript_path:$t}' | bash "$guard" > "$fx/guard.out" 2>/dev/null
  if [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' "$fx/guard.out" 2>/dev/null)" = deny ]; then echo deny; return; fi
  (cd "$repo" && bash -c "$cmd" 2>&1)
}
# tea logs the text of a note file it is handed, as a release would show it.
cat > "$fx/answers/tea.sh" <<EOF
a=("\$@"); for i in "\${!a[@]}"; do [ "\${a[\$i]}" = --note-file ] && cat "\${a[\$((i+1))]}" >> "$fx/calls.log"; done
EOF
cat > "$fx/answers/gh.sh" <<EOF
case "\$*" in
  *visibility*) cat "$fx/visibility" 2>/dev/null || echo PUBLIC; exit 0 ;;
  *"/cve"*) echo '{}'; exit 0 ;;
  *"/forks"*) echo '{"clone_url":"$fx/fork.git"}'; exit 0 ;;
  *"-X POST"*security-advisories*) c=\$(( \$(cat "$fx/count" 2>/dev/null || echo 0) + 1 )); echo \$c > "$fx/count"; echo "{\"ghsa_id\":\"GHSA-aaaa-bbbb-000\$c\",\"state\":\"draft\"}"; exit 0 ;;
  *) echo '{}'; exit 0 ;;
esac
EOF
git init -q --bare "$fx/fork.git"
gh_repo=$(repo widget https://github.com/acme/widget.git); line "$gh_repo" "Advisories: github"
git -C "$gh_repo" branch fix-upload-path
file_repo=$(repo gadget https://gitea.example.invalid/acme/gadget.git); line "$file_repo" "Advisories: file"
git -C "$file_repo" branch fix-upload-path
draft() { (cd "$1" && bash "$kit/advisory.sh" draft "$2" 2>&1); }
id_of() { sed -n 's/^draft: //p; s/^draft id: //p' <<<"$1" | head -1 | xargs -r basename; }
report "$fx/shipped.json" '.summary="A shipped flaw"'
ghsa=$(id_of "$(draft "$gh_repo" "$fx/shipped.json")")
cve="bash $kit/advisory.sh cve $ghsa"
pub="bash $kit/advisory.sh publish $ghsa"

# Given a drafted GitHub advisory, and a last message from the maintainer that does not say CVE
# When the agent requests a CVE for it
# Then the request is refused, nothing reaches the forge, and the agent asks in one line
fresh; say "looks good, carry on"; : > "$fx/calls.log"
asks() { jq -r .hookSpecificOutput.permissionDecisionReason "$fx/guard.out" 2>/dev/null | grep -qi "ask the user in one line" && echo yes; }
r1=$(agent "$gh_repo" "$cve"); a1=$(asks); r2=$(agent "$gh_repo" "gh api -X POST repos/acme/widget/security-advisories/$ghsa/cve"); a2=$(asks)
check "SEC-E35 no CVE word, no request" '[ -n "$ghsa" ] && [ "$r1" = deny ] && [ "$r2" = deny ] && ! grep -q "/cve" "$fx/calls.log" && [ "$a1$a2" = yesyes ]'

# Given a drafted GitHub advisory, and a last message that says request the CVE
# When the agent requests a CVE for it
# Then the request reaches GitHub, and the advisory stays a draft
fresh; say "request the CVE"; : > "$fx/calls.log"
r=$(agent "$gh_repo" "$cve")
check "SEC-E36 the CVE word sends the request" '[ -n "$ghsa" ] && [ "$r" != deny ] && grep -qE "^gh api .*-X POST .*security-advisories/$ghsa/cve" "$fx/calls.log" && ! grep -q "published" "$fx/calls.log"'

# Given a last message that says publish it, and nothing about a CVE
# When the agent requests a CVE
# Then the request is refused
fresh; say "publish it"
check "SEC-E37 the publish word opens no CVE gate" '[ "$(agent "$gh_repo" "$cve")" = deny ]'

# Given a last message that says do not request a CVE yet
# When the agent requests a CVE
# Then the request is refused
fresh; say "do not request a CVE yet"
check "SEC-E38 a no refuses" '[ "$(agent "$gh_repo" "$cve")" = deny ]'

# Given a message that said request the CVE, and a later message that does not
# When the agent requests a CVE
# Then the request is refused
fresh; say "request the CVE" -60; say "thanks, now tidy the branch"
check "SEC-E39 only the last message counts" '[ "$(agent "$gh_repo" "$cve")" = deny ]'

# Given a private GitHub repo with a drafted advisory, and a message that says request the CVE
# When the agent requests a CVE
# Then the kit says GitHub requests CVEs only for public repos, and sends nothing
echo PRIVATE > "$fx/visibility"; fresh; say "request the CVE"; : > "$fx/calls.log"
r=$(agent "$gh_repo" "$cve")
check "SEC-E40 a private repo gets no CVE request" '[ "$r" != deny ] && grep -qi "only for public" <<<"$r" && ! grep -q "/cve" "$fx/calls.log" && grep -q visibility "$fx/calls.log"'
rm "$fx/visibility"

# Given a repo with Advisories: file, and a message that says request the CVE
# When the agent prepares the request
# Then the kit gives the maintainer the text for MITRE's CVE ID request form, and sends nothing itself
report "$fx/filed.json" '.summary="A flaw on the file route"'
fid=$(id_of "$(draft "$file_repo" "$fx/filed.json")")
fresh; say "request the CVE"; : > "$fx/calls.log"
r=$(agent "$file_repo" "bash $kit/advisory.sh cve $fid")
check "SEC-E41 the file route gives MITRE form text" '[ -n "$fid" ] && [ "$r" != deny ] && grep -qi "mitre" <<<"$r" && grep -q "A flaw on the file route" <<<"$r" && ! grep -qE "^(gh|tea) " "$fx/calls.log"'

# Given a drafted advisory whose fix has shipped, and a last message that does not say publish
# When the agent publishes it
# Then publishing is refused and the advisory stays a draft
fresh; say "looks good"; : > "$fx/calls.log"
r1=$(agent "$gh_repo" "$pub"); r2=$(agent "$gh_repo" "gh api -X PATCH repos/acme/widget/security-advisories/$ghsa -f state=published")
check "SEC-E42 no publish word, no publish" '[ -n "$ghsa" ] && [ "$r1" = deny ] && [ "$r2" = deny ] && ! grep -q published "$fx/calls.log"'

# Given a drafted advisory whose fix has shipped, and a last message that says publish the advisory
# When the agent publishes it
# Then the advisory appears on the repo's public Security tab
fresh; say "publish the advisory"; : > "$fx/calls.log"
r=$(agent "$gh_repo" "$pub")
check "SEC-E43 the publish word publishes" '[ -n "$ghsa" ] && [ "$r" != deny ] && grep -qE "^gh api .*-X PATCH .*security-advisories/$ghsa .*state=published" "$fx/calls.log"'

# Given a last message that says request the CVE, and nothing about publishing
# When the agent publishes the advisory
# Then publishing is refused
fresh; say "request the CVE"
check "SEC-E44 the CVE word opens no publish gate" '[ "$(agent "$gh_repo" "$pub")" = deny ]'

# Given a repo with Advisories: file, and a last message that does not say publish
# When the agent makes a release note holding the advisory
# Then the release is refused, and no release appears
fresh; say "ship the fix"; : > "$fx/calls.log"
r1=$(agent "$file_repo" "bash $kit/advisory.sh publish $fid")
r2=$(agent "$file_repo" "tea releases create --tag v2.4.1 --title 'Security advisory $fid' --note-file advisory.md")
check "SEC-E45 no publish word, no release" '[ -n "$fid" ] && [ "$r1" = deny ] && [ "$r2" = deny ] && ! grep -q "^tea releases" "$fx/calls.log"'

# Given a repo with Advisories: file, and a last message that says publish the advisory
# When the agent makes the release note
# Then the release appears with the advisory's text
fresh; say "publish the advisory"; : > "$fx/calls.log"
r=$(agent "$file_repo" "bash $kit/advisory.sh publish $fid")
check "SEC-E46 the publish word makes the release" '[ -n "$fid" ] && [ "$r" != deny ] && grep -q "^tea releases create" "$fx/calls.log" && grep -q "A flaw on the file route" "$fx/calls.log"'

# Given a drafted advisory with no fix shipped and its deadline still ahead, and a message that says publish
# When the agent goes to publish it
# Then the kit says the fix has not shipped and names the deadline, and publishes only after a second message that says publish
ahead=$(date -d '+20 days' +%F)
report "$fx/early.json" ".summary=\"An unfixed flaw\" | .fixed=\"\" | .fix_link=\"\" | .deadline=\"$ahead\""
eid=$(id_of "$(draft "$gh_repo" "$fx/early.json")"); early="bash $kit/advisory.sh publish $eid"
fresh; say "publish" -30; : > "$fx/calls.log"
first=$(agent "$gh_repo" "$early"); again=$(agent "$gh_repo" "$early"); before_second=$(grep -c published "$fx/calls.log")
say "publish" 5; second=$(agent "$gh_repo" "$early")
check "SEC-E47 an early publish takes a second publish" '[ -n "$eid" ] && grep -qi "not shipped" <<<"$first" && grep -q "$ahead" <<<"$first" && [ "$before_second" = 0 ] && [ "$again" = deny ] && [ "$second" != deny ] && grep -qE "security-advisories/$eid .*state=published" "$fx/calls.log"'

session() { echo '{"hook_event_name":"SessionStart","source":"startup"}' | CLAUDE_PROJECT_DIR="$1" bash "$deadline_hook" 2>/dev/null; }
soon=$(date -d '+7 days' +%F); far=$(date -d '+30 days' +%F); past=$(date -d '-2 days' +%F)
dl=$(repo deadlines https://gitea.example.invalid/acme/deadlines.git); line "$dl" "Advisories: file"

# Given a drafted advisory with no fix shipped and its reporter's deadline a week away
# When the maintainer starts a session in the repo
# Then the session names the advisory, the deadline's date, and that the fix has not shipped
report "$fx/soon.json" ".summary=\"A flaw due soon\" | .fixed=\"\" | .fix_link=\"\" | .deadline=\"$soon\""
sid=$(id_of "$(draft "$dl" "$fx/soon.json")"); out=$(session "$dl")
check "SEC-E48 a week ahead, the session warns" '[ -n "$sid" ] && grep -q "$sid" <<<"$out" && grep -q "$soon" <<<"$out" && grep -qi "not shipped" <<<"$out"'

# Given the same advisory with its deadline a month away
# When the maintainer starts a session
# Then the session says nothing about it
far_repo=$(repo far https://gitea.example.invalid/acme/far.git); line "$far_repo" "Advisories: file"
report "$fx/far.json" ".summary=\"A flaw due later\" | .fixed=\"\" | .fix_link=\"\" | .deadline=\"$far\""
farid=$(id_of "$(draft "$far_repo" "$fx/far.json")"); out=$(session "$far_repo")
check "SEC-E49 a month ahead, silence" '[ -n "$farid" ] && ! grep -q "$farid" <<<"$out" && ! grep -q "$far" <<<"$out" && [ -x "$deadline_hook" ]'

# Given a drafted advisory whose deadline has passed and that is still unpublished
# When the maintainer starts a session
# Then the session says the deadline passed, and nothing publishes without the maintainer's word
past_repo=$(repo past https://github.com/acme/past.git); line "$past_repo" "Advisories: github"; git -C "$past_repo" branch fix-upload-path
report "$fx/past.json" ".summary=\"A flaw past due\" | .fixed=\"\" | .fix_link=\"\" | .deadline=\"$past\""
pid=$(id_of "$(draft "$past_repo" "$fx/past.json")"); : > "$fx/calls.log"; out=$(session "$past_repo")
check "SEC-E50 a passed deadline is named, nothing publishes" '[ -n "$pid" ] && grep -q "$pid" <<<"$out" && grep -qi "passed" <<<"$out" && ! grep -q published "$fx/calls.log"'

# Given a report whose reporter set no deadline
# When the kit drafts the advisory
# Then the draft's deadline is 90 days after the report arrived
report "$fx/nodl.json" '.summary="A flaw with no deadline" | .received="2026-11-01" | del(.deadline)'
out=$(draft "$file_repo" "$fx/nodl.json")
check "SEC-E51 no deadline means 90 days" 'grep -qi "deadline: 2027-01-30" <<<"$out"'
exit $fail
