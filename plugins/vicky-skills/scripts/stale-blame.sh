#!/usr/bin/env bash
# Stop hook (guard_stale_blame, on by default): an agent that can't find a bug
# tends to blame the user's copy ("your build is stale", "restart your client"),
# and the user's builds are nearly always current. When the agent's last reply
# names the user's copy (your build, client, cache, package, plugin, asset pack) in the
# same sentence as a stale word or an update-it fix, and quotes no hash or
# logged version, the stop is blocked once with a steer: keep tracing the code,
# or quote the failing run's hash or version beside the expected one. A file's
# modified time is no proof, so a time alone never lets it through. A restart
# stated as the engine's rule ("needs a restart") is no blame. It steers
# once per turn: with stop_hook_active set, the reply goes through.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_STALE_BLAME:-true}" in false|0) exit 0 ;; esac
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
copy='(you(.re|[[:space:]]+are)[[:space:]]+running|on[[:space:]]+your[[:space:]]+(machine|end|side)|\bthe[[:space:]]+client\b|\byou(.ve|[[:space:]]+have)?[[:space:]]+(re-?)?(update|pull|pulled|download|reload|restart|relaunch|clear)|the[[:space:]]+[a-z-]+[[:space:]]+you[[:space:]]+(have|run|ran|are[[:space:]]+on)|you[[:space:]]+(were|are)[[:space:]]+on|your([[:space:]]+[a-z-]+){0,2}[[:space:]]+(haks?|clients?|builds?|cache|install|copy|files?|game|checkout|modules?|assets?|artefacts?|artifacts?|packages?|dependencies|binary|binaries|image|container|app|extensions?|plugins?|browser|environment))\b'
blame='\b(stale|old|older|outdated|out[ -]of[ -]date|update|updated|redownload|re-download|reinstall|restart|refresh|rebuild|reload|reloading|latest|previous|newer|behind|pull|pulled|re-pull|re-pulling|relaunch|caching|newest|refreshed)\b'
# A restart the engine needs ("a shader change needs a restart") is a rule the
# step follows, never blame, so that phrase is dropped before the blame match,
# unless the sentence names "your" copy as the thing needing it.
rule='\b(needs?|requires?|takes?)[[:space:]]+(a[[:space:]]+)?(full[[:space:]]+|fresh[[:space:]]+|client[[:space:]]+)?(restart|reload|rebuild|refresh|relaunch)\b'
blamed=$(prose | sed -E 's/"[^"]*"//g; s/“[^”]*”//g' | tr '\n' ' ' | sed 's/\([.?!]\) /\1\n/g' | grep -iE "$copy" | sed -E "/\b[Yy]our\b/!s/$rule/RULE/Ig" | grep -iE "$blame" | grep -viE "\b(not|no|nothing|never|nor)\b")
[ -n "$blamed" ] || exit 0
# Proof: a hash (six or more hex characters, digits and letters both, so
# a date or a clock time is none) or a logged version (the word version, then
# a number).
grep -oiE '\b[0-9a-f]{6,}\b' <<<"$said" | grep '[0-9]' | grep -qi '[a-f]' && exit 0
grep -qiE 'version[[:space:]:=]+v?[0-9]' <<<"$said" && exit 0
jq -n --arg q "$blamed" '{decision:"block", reason:("You blamed the user'"'"'s copy as stale, with no proof. Their builds, assets and data are current unless a hash or logged version from the failing run says otherwise; a file'"'"'s modified time, or the time of some other event, proves nothing about what the failing run loaded. Keep tracing the bug in the code. Only when you hold that proof, quote the failing run'"'"'s hash or logged version beside the expected one in the same reply. The sentence:\n" + $q)}'
