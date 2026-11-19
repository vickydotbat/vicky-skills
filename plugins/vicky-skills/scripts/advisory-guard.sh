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
# shortcut: a script file or tool config the agent wrote earlier goes unseen,
# until advisory publishing sits behind a credential only the kit holds.
case "${CLAUDE_PLUGIN_OPTION_GUARD_PUBLISH:-true}" in false|0) exit 0 ;; esac
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null | sed -e ':a' -e '/\\$/{N;s/\\\n//;ba' -e '}')
# shellcheck source=prose-strip.sh
. "$(dirname "$0")/prose-strip.sh"
# A title's or message's words are prose, not a call: they go first. Then
# quotes and backslashes go, so state="published" or cv""e reads as written.
plain=$(prose_strip "$cmd" | tr -d "\"'\\\\")
# A named advisory: an id, a variable or a substitution after the collection.
adv='security-advisories/[^[:space:]/;&|]+'
cve=0; pub=0; raw=0
# Each command segment is judged on its own, so one segment's gate never covers another's.
while IFS= read -r seg; do
  if grep -qiE "advisory\.sh[[:space:]]+cve([[:space:]]|$)|$adv/cve" <<<"$seg"; then cve=1; continue; fi
  grep -qiE "advisory\.sh[[:space:]]+publish([[:space:]]|$)" <<<"$seg" && pub=1
  # A release is found in the stripped text, so a title cannot fake one, and
  # its advisory words are read in the whole command, since its title holds them.
  grep -qiE "(gh|tea)[[:space:]]+releases?[[:space:]]+(create|c)[[:space:]]" <<<"$seg" &&
    grep -qiE "(gh|tea)[[:space:]]+releases?[[:space:]]+(create|c)[[:space:]].*(advisor|security)" <<<"$cmd" && pub=1
  # Whitelist: a raw call that writes to a named advisory may set any field, the
  # state included, in a form no pattern reads (a file, a variable, a body).
  # Only a plain read passes; edits go through advisory.sh draft.
  # A write whose target is out of sight (a variable, a substitution, a GraphQL
  # query from a file or naming an advisory) may reach an advisory too.
  grep -qiE "(gh[[:space:]]+api|curl|wget)[[:space:]]" <<<"$seg" &&
    grep -qiE "(-X|--method|--request)[[:space:]=]*(POST|PATCH|PUT|DELETE)|[[:space:]](-f|-F|--field|--raw-field|--input|-d|--data[a-z-]*|--json|-T|--body-[a-z]+)([[:space:]=]|$)" <<<"$seg" &&
    grep -qiE "$adv|graphql.*(advisor|query=@)|[[:space:]][^[:space:]-]*[\$\`]" <<<"$seg" &&
    { pub=1; raw=1; }
done < <(tr ';&|' '\n\n\n' <<<"$plain")
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
    deny "Publishing an advisory cannot be taken back, so only the user decides it, with the word publish in their own last message. Ask the user in one line whether to publish it, wait for their answer, and run this again once their message says publish.$([ "$raw" = 1 ] && echo " A raw write to an advisory can set its state in a form the guard cannot read: edit a draft with the security kit's advisory.sh draft, and publish with advisory.sh publish.")"
  # The kit warned that the fix has not shipped: only a publish sent after that warning opens it.
  id=$(grep -oE "advisory\.sh[[:space:]]+publish[[:space:]]+[^[:space:];&|]+" <<<"$plain" | awk '{print $3}')
  # kit.sh owns where this repo's drafts live.
  state=$( (. "$here/../skills/shipping/security/scripts/kit.sh" >/dev/null 2>&1 && ls "$store/${id:-/}/state.json") 2>/dev/null)
  warned=$([ -n "$state" ] && jq -r '.warned_at // empty' "$state" 2>/dev/null)
  if [ -n "$warned" ]; then
    said=$(last_user_time "$transcript")
    [ -n "$said" ] && [ "$said" -gt "$warned" ] ||
      deny "The kit warned that this advisory's fix has not shipped. Only a message sent after that warning that says publish opens it. Ask the user in one line whether to publish before the fix, and wait for their answer."
  fi
fi
exit 0 # mutant-ok delete: the last test above already ends with status 0
