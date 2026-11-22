# shellcheck shell=bash
# Sourced by merged-branch-guard and git-hook-lib: git_subcommands <text> prints
# the subcommand of each git command in <text>, one per line: the first word
# after git and its options, in each segment split at ; & | ( ) and newlines,
# with a # comment dropped. A word commit or push anywhere else is not one.
git_subcommands() {
  awk '{
    n = split($0, segs, /[;&|()]/)
    for (s = 1; s <= n; s++) {
      seg = segs[s]; sub(/(^|[[:space:]])#.*/, "", seg)
      w = split(seg, words, /[[:space:]]+/); i = 1
      while (i <= w && (words[i] == "" || words[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/)) i++
      if (i > w || words[i] !~ /(^|\/)git$/) continue
      for (i++; i <= w; i++) {
        if (words[i] == "") continue
        if (words[i] ~ /^(-C|-c|--git-dir|--work-tree|--namespace|--config-env)$/) { i++; continue }
        if (words[i] ~ /^-/) continue
        print words[i]; break
      }
    }
  }' <<<"$1"
}
