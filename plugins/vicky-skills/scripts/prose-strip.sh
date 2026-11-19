# shellcheck shell=bash
# Sourced by guards that read a Bash command for a call. prose_strip <command>
# prints the command with the quoted value of each title, message or body flag
# emptied, so words in a pull request title or commit message never read as a
# call. A double-quoted value holding $( or a backtick runs, so it stays.
prose_strip() {
  sed -E \
    -e "s/(^|[[:space:]])(--title|-t|-m|--message|--body|--notes|-n)([[:space:]]+|=)'[^']*'/\\1\\2\\3''/g" \
    -e "s/(^|[[:space:]])(--title|-t|-m|--message|--body|--notes|-n)([[:space:]]+|=)\"[^\"\$\`]*\"/\\1\\2\\3\"\"/g" <<<"$1"
}
