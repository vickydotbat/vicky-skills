# Prints a shell command without its heredoc bodies, so text a heredoc feeds
# to a program is never read as a command. Used by git-hook-lib.sh and pr-guard.sh.
# With -v code=1 (poll-pace.sh), a heredoc fed to a shell or an interpreter
# stays, since its body runs.
tag != "" { t = $0; sub(/^\t+/, "", t); if (t == tag) tag = ""; next }
!(code && /(^|[[:space:];&|(])(bash|sh|zsh|python3?|node|ruby|perl)([[:space:]]|$)/) && match($0, /<<-?[[:space:]]*["\047]?[A-Za-z_][A-Za-z0-9_]*/) {
  tag = substr($0, RSTART, RLENGTH); sub(/^<<-?[[:space:]]*["\047]?/, "", tag)
}
{ print }
