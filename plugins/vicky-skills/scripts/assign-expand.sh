# shellcheck shell=bash
# Sourced by hooks that read a path out of a command (pr-guard, worktree-place).
# expand_assigns <text> <command> prints <text> with each simple NAME=value the
# command sets, such as W=/tmp/x before git worktree add $W, put in for $NAME
# and ${NAME}.
expand_assigns() {
  local text=$1 var value
  while IFS='=' read -r var value; do
    text=${text//\$\{$var\}/$value}
    text=${text//\$$var/$value}
  done < <(grep -oE '(^|[;&|[:space:]])[A-Za-z_][A-Za-z0-9_]*=("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:];&|]+)' <<<"$2" |
    sed -E 's/^[;&|[:space:]]//; s/=["'"'"']/=/; s/["'"'"']$//')
  printf '%s' "$text"
}
