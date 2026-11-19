#!/usr/bin/env bash
# PreToolUse hook (Bash; guard_publish, on by default): a CVE request and a
# published advisory can't be taken back, so each is the user's call, never
# an agent's "Going with" pick. Each has its own gate, opened only by its own
# word in the user's last message: CVE for a request, publish for a publish,
# and a message holding "not", "n't", "never" or "no" opens neither. It reads
# the security kit's advisory.sh cve and publish, gh api calls to a repository
# advisory's cve endpoint or with state=published, any call to an advisory
# whose body it cannot read (gh api --input, curl), and a release created
# with an advisory's text. The kit's early publish, before the fix ships,
# waits for a second publish message sent after the kit's warning.
case "${CLAUDE_PLUGIN_OPTION_GUARD_PUBLISH:-true}" in false|0) exit 0 ;; esac
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null | sed -e ':a' -e '/\\$/{N;s/\\\n//;ba' -e '}')
adv='security-advisories/[A-Za-z0-9_-]+'
cve=0; pub=0
grep -qE "advisory\.sh[[:space:]]+cve([[:space:]]|$)|$adv/cve" <<<"$cmd" && cve=1
grep -qE "advisory\.sh[[:space:]]+publish([[:space:]]|\$)|$adv[^;&|]*state=published|state=published[^;&|]*$adv|(gh|tea)[[:space:]]+releases?[[:space:]]+(create|c)[[:space:]][^;&|]*[Aa]dvisor" <<<"$cmd" && pub=1
# A body the guard cannot read may publish: --input, or curl's data, sent to an advisory.
# Making a draft names no advisory id, so it never matches.
unread=0 # mutant-ok delete: an unset flag reads the same as 0 below
if grep -qE "gh[[:space:]]+api[^;&|]*$adv[^;&|]*--input|gh[[:space:]]+api[^;&|]*--input[^;&|]*$adv|curl[^;&|]*$adv" <<<"$cmd" &&
  ! grep -qE "$adv/cve" <<<"$cmd"; then unread=1; pub=1; fi
[ "$cve$pub" = 00 ] && exit 0
here=$(dirname "$0")
# shellcheck source=since-user.sh
. "$here/since-user.sh"
transcript=$(jq -r '.transcript_path // empty' <<<"$payload" 2>/dev/null)
asked=$(last_user_message "$transcript")
deny() {
  jq -n --arg r "advisory-guard: refused. $1 Nothing ran." '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
grep -qiE "\b(not|never|no)\b|n't" <<<"$asked" && deny "The user's last message says no, so neither a CVE request nor a publish may go. Ask the user in one line what they want, and wait for their answer."
[ "$cve" = 1 ] && ! grep -qiw 'cve' <<<"$asked" &&
  deny "A CVE request cannot be taken back, so only the user decides it, with the word CVE in their own last message. Ask the user in one line whether to request the CVE, wait for their answer, and run this again once their message says CVE."
if [ "$pub" = 1 ]; then
  grep -qiw 'publish' <<<"$asked" ||
    deny "Publishing an advisory cannot be taken back, so only the user decides it, with the word publish in their own last message. Ask the user in one line whether to publish it, wait for their answer, and run this again once their message says publish.$([ "$unread" = 1 ] && echo " This call's body is out of the guard's sight: pass the fields with -f so it can read them.")"
  # The kit warned that the fix has not shipped: only a publish sent after that warning opens it.
  id=$(grep -oE "advisory\.sh[[:space:]]+publish[[:space:]]+[^[:space:];&|]+" <<<"$cmd" | awk '{print $3}')
  state=$(ls "${CLAUDE_PLUGIN_DATA:-/nonexistent}"/advisories/*/"${id:-/}"/state.json 2>/dev/null | head -n1)
  warned=$([ -n "$state" ] && jq -r '.warned_at // empty' "$state" 2>/dev/null)
  if [ -n "$warned" ]; then
    said=$(last_user_time "$transcript")
    [ -n "$said" ] && [ "$said" -gt "$warned" ] ||
      deny "The kit warned that this advisory's fix has not shipped. Only a message sent after that warning that says publish opens it. Ask the user in one line whether to publish before the fix, and wait for their answer."
  fi
fi
exit 0 # mutant-ok delete: the last test above already ends with status 0
