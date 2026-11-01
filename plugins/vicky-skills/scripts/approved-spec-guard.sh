#!/usr/bin/env bash
# Refuses an agent's edit to a file that holds approved examples, through
# Edit, Write or a Bash command, and steers it to `examples`' "Changing an
# approved example". A command that only runs or reads such a file passes,
# and so does an edit to a file the user re-approved: interactive-page's open-draft.sh
# grants a test file when the user changes its example in a draft.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
# approved-spec: the guard keeps its own script locked, so this line marks it.
# shellcheck source=approved-spec.sh
. "$(dirname "$0")/approved-spec.sh"
# A file the user re-approved in red-pen, listed in the checkout's grants.
granted() {
  top=$(git -C "$(dirname -- "$1")" rev-parse --show-toplevel 2>/dev/null) || return 1
  grants="$(git -C "$top" rev-parse --absolute-git-dir)/approved-spec-grants"
  grep -qsxF "$(realpath -m -- "$1" | sed "s|^$top/||")" "$grants"
}
# refuse <file> [what the edit changed]
refuse() {
  jq -n --arg f "$1" --arg why "${2:-}" '{hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("\($f) holds approved examples, which change only with the user'"'"'s yes.\($why) Take the new wording through the examples skill'"'"'s \"Changing an approved example\": draft it with red-pen, naming the test file on the draft'"'"'s location line. Once the user changes it there and closes the file, the edit goes through.")
  }}'
  exit 0
}
# An approved example's wording: the file's comment lines that start with Given, When, Then or And.
wording() { grep -E '^[[:space:]]*(#|//|--|;|\*)[[:space:]]*(Given|When|Then|And)[[:space:]]' || true; }
# The file as an Edit or Write would leave it, or nothing for a tool whose result can't be read ahead.
after_edit() {
  case "$(jq -r '.tool_name // empty' <<<"$payload")" in
    Write) jq -r '.tool_input.content // empty' <<<"$payload" ;;
    Edit) jq -Rrs --argjson p "$payload" '($p.tool_input.old_string) as $o | ($p.tool_input.new_string) as $n
      | if $p.tool_input.replace_all then split($o) | join($n)
        else split($o) as $parts | if ($parts | length) < 2 then . else $parts[0] + $n + ($parts[1:] | join($o)) end end' <"$1" ;;
  esac
}
# The first wording line an edit changes, adds or removes, or nothing when it keeps them all.
changed_wording() { diff <(wording <"$1") <(after_edit "$1" | wording) | grep -m1 '^[<>]' | cut -c3-; }

if [ "$(jq -r '.tool_name // empty' <<<"$payload")" != Bash ]; then
  file=$(jq -r '.tool_input.file_path // empty' <<<"$payload")
  [ -n "$file" ] && approved "$file" && ! granted "$file" || exit 0
  # A file with no wording lines holds its examples elsewhere, so every line of it stays locked.
  [ -n "$(wording <"$file")" ] || refuse "$file" " It has no Given, When or Then comment lines, so every line of it is locked. To unlock its harness for good, copy its approved examples from its ticket into it as Given, When and Then comments above their tests, and take that edit through red-pen once."
  # An edit whose result can't be read ahead leaves no wording lines, so it reads as changing them.
  line=$(changed_wording "$file")
  [ -z "$line" ] && exit 0
  refuse "$file" "${line:+ This edit changes its wording: \"$line\".}"
fi

command=$(jq -r '.tool_input.command // empty' <<<"$payload")
cwd=$(jq -r '.cwd // empty' <<<"$payload")
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null
# A leading cd, such as into a worktree, sets where the command's files are.
# shortcut: only a plain path at the command's start counts. A later cd,
# pushd, git -C, ~, $VAR or a path with spaces leaves the session's folder;
# upgrade when a refusal or a gap shows up in one of those forms.
if [[ $command =~ ^[[:space:]]*cd[[:space:]]+([^[:space:]\;\&\|]+) ]]; then
  dir=${BASH_REMATCH[1]//[\"\']/}
  cd "$dir" 2>/dev/null
fi
# Each word of the command, quotes and shell punctuation stripped.
words=$(tr -s " \t\n;&|()<>'\"=," '\n' <<<"$command")
target=""
while IFS= read -r word; do
  [ -n "$word" ] && approved "$word" && { target=$word; break; }
done <<<"$words"
if [ -z "$target" ]; then
  # A script the command runs may name the file itself, and write it. Each
  # segment's wrappers (timeout -s KILL 60, sudo -u bob, nix develop -c) are
  # walked: a word after a flag may be the flag's value, so it is a candidate
  # and the walk goes on; the first other word is the command, and the walk
  # stops. After an interpreter, the script it runs is the command. A file
  # the command only names as an argument, such as a workflow it reads, passes.
  while IFS= read -r word; do
    [ -f "$word" ] && [ "$(wc -c < "$word")" -lt 1000000 ] || continue
    grep -qiE 'approved_?examples' "$word" && refuse "$word names an approved-examples file, and"
  done < <(tr ';&|()\n' '\n' <<<"$command" | awk '{
    flag = 0
    for (i = 1; i <= NF; i++) { # mutant-ok: from 0, field 0 is the whole segment, never a file name, so it adds no candidate
      if ($i ~ /^(timeout|run0|sudo|env|nice|nohup|exec|time|command|xargs|stdbuf|systemd-run|nix|develop|shell)$|^[0-9.]+[smhd]?$|^[A-Za-z_][A-Za-z0-9_]*=|#/) { flag = 0; continue }
      if ($i ~ /^-/) { flag = 1; continue }
      if ($i ~ /^(bash|sh|zsh|source|\.|python3?|node|ruby|perl)$/) { i++; while ($i ~ /^-/) i++; print $i; break }
      print $i
      if (!flag) break
      flag = 0
    } }' | tr -d "'\"")
  exit 0
fi

name=$(basename -- "$target")
writes='sed[^|;&]*[[:space:]](-[a-zA-Z]*i|--in-place)|perl[^|;&]*[[:space:]]-[a-zA-Z]*i|'
writes+="(>|>>|tee([[:space:]]+-a)?)[[:space:]]*[^[:space:]|;&]*${name//./\\.}|"
writes+='(^|[[:space:];&|(])(rm|mv|cp|install|ln|truncate|dd)[[:space:]]|'
writes+='git[[:space:]]+([^|;&]*[[:space:]])?(checkout|restore|apply|reset|stash|mv|rm|am|cherry-pick)([[:space:]]|$)'
harness="" # mutant-ok delete: an unset harness reads as empty, the same as this
[ -n "$(wording <"$target")" ] && harness=" A shell command can't be read ahead, so make a harness edit, one that keeps every Given, When and Then line, with the Edit tool, which lets it through."
grep -qE "$writes" <<<"$command" && ! granted "$target" && refuse "$target" "$harness"
# An interpreter running code of its own (-c, a heredoc, another script) that
# names the file may write it. Running the file itself only reads it.
first=$(grep -oE '(^|[[:space:];&|(])(python3?|node|ruby|perl|php|awk)[[:space:]]+[^[:space:]|;&]+' <<<"$command" | head -1 | awk '{print $NF}')
[ -n "$first" ] && [ "$(basename -- "$first")" != "$name" ] && ! granted "$target" && refuse "$target"
exit 0 # mutant-ok delete: the line above leaves status 0, so the script ends the same way
