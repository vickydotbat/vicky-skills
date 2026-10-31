#!/usr/bin/env bash
# Asks the human before an agent edits a file that holds approved examples,
# through Edit, Write or a Bash command. A command that only runs or reads
# such a file passes. Training wheels: a refusal that sends the agent to
# `examples`' "Changing an approved example" would replace the ask.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
# A file named for approved examples, or one holding a marked test, is the
# contract. A file that does not exist yet holds no approved text.
# The mark is a test framework's tag, never a mention in prose: a comment
# "# approved-spec:", a quoted "approved-spec", or @approved-spec.
approved() {
  [ -f "$1" ] || return 1
  basename -- "$1" | grep -qiE 'approved_?examples' ||
    { grep -qE '(#|//|--|;)[[:space:]]*approved-spec:|["'"'"']approved-spec["'"'"']|@approved-spec([^a-z-]|$)' "$1"; }
}
ask() {
  jq -n --arg f "$1" '{hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: ("\($f) holds approved examples. An approved example changes only when the human approves the new text.")
  }}'
  exit 0
}

if [ "$(jq -r '.tool_name // empty' <<<"$payload")" != Bash ]; then
  file=$(jq -r '.tool_input.file_path // empty' <<<"$payload")
  [ -n "$file" ] && approved "$file" && ask "$file"
  exit 0 # mutant-ok delete: an empty command below finds no target and exits 0
fi

command=$(jq -r '.tool_input.command // empty' <<<"$payload")
cwd=$(jq -r '.cwd // empty' <<<"$payload")
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null
# Each word of the command, quotes and shell punctuation stripped.
words=$(tr -s " \t\n;&|()<>'\"=," '\n' <<<"$command")
target=""
while IFS= read -r word; do
  [ -n "$word" ] && approved "$word" && { target=$word; break; }
done <<<"$words"
if [ -z "$target" ]; then
  # A script the command runs may name the file itself, and write it: the word
  # in command position, after any wrapper such as timeout 60 or run0, or the
  # word after an interpreter there. A file the command only names as an
  # argument, such as a workflow it reads, passes.
  while IFS= read -r word; do
    [ -f "$word" ] && [ "$(wc -c < "$word")" -lt 1000000 ] || continue
    grep -qiE 'approved_?examples' "$word" && ask "$word names an approved-examples file, and"
  done < <(tr ';&|()\n' '\n' <<<"$command" | awk '{
    for (i = 1; i <= NF; i++) { # mutant-ok: from 0, field 0 is the whole segment, never a file name, so it adds no candidate
      if ($i ~ /^(timeout|run0|sudo|env|nice|nohup|exec|time|command|xargs|stdbuf|systemd-run)$|^-|^[0-9.]+[smhd]?$|^[A-Za-z_][A-Za-z0-9_]*=/) continue
      if ($i ~ /^(bash|sh|zsh|source|\.|python3?|node|ruby|perl)$/) { i++; while ($i ~ /^-/) i++ }
      print $i; break
    } }' | tr -d "'\"")
  exit 0
fi

name=$(basename -- "$target")
writes='sed[^|;&]*[[:space:]](-[a-zA-Z]*i|--in-place)|perl[^|;&]*[[:space:]]-[a-zA-Z]*i|'
writes+="(>|>>|tee([[:space:]]+-a)?)[[:space:]]*[^[:space:]|;&]*${name//./\\.}|"
writes+='(^|[[:space:];&|(])(rm|mv|cp|install|ln|truncate|dd)[[:space:]]|'
writes+='git[[:space:]]+([^|;&]*[[:space:]])?(checkout|restore|apply|reset|stash|mv|rm|am|cherry-pick)([[:space:]]|$)'
grep -qE "$writes" <<<"$command" && ask "$target"
# An interpreter running code of its own (-c, a heredoc, another script) that
# names the file may write it. Running the file itself only reads it.
first=$(grep -oE '(^|[[:space:];&|(])(python3?|node|ruby|perl|php|awk)[[:space:]]+[^[:space:]|;&]+' <<<"$command" | head -1 | awk '{print $NF}')
[ -n "$first" ] && [ "$(basename -- "$first")" != "$name" ] && ask "$target"
exit 0 # mutant-ok delete: the line above leaves status 0, so the script ends the same way
