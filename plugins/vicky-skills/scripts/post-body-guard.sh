#!/usr/bin/env bash
# PreToolUse hook (Bash; guard_post_body, on by default): refuses a pull
# request or issue post whose body leaks a path into this machine or
# terminal codes, or carries another item's text. The checks live in
# post-body-guard.py. Without python3 a post is refused, since an unread body
# is the gap this guard closes.
case "${CLAUDE_PLUGIN_OPTION_GUARD_POST_BODY:-true}" in false|0) exit 0 ;; esac
payload=$(cat)
if ! command -v python3 >/dev/null; then
  grep -qE '(gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|review)|gh[[:space:]]+api|tea[[:space:]]+[a-z]+[[:space:]]+(create|edit)|tea[[:space:]]+comment)' <<<"$payload" || exit 0
  echo "post-body-guard: refused, python3 is missing, so this post's body can't be checked. Install python3 for the plugin. Nothing ran." >&2
  exit 2
fi
python3 "${0%/*}/post-body-guard.py" <<<"$payload"
