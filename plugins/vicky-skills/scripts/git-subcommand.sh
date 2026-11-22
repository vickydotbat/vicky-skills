# shellcheck shell=bash
# Sourced by merged-branch-guard and git-hook-lib: git_subcommands <text> prints
# the subcommand of each git command in <text>, one per line: the first word
# after git and its options, in each segment split at ; & | ( ) and newlines,
# with a # comment dropped. A word commit or push anywhere else is not one. A
# quoted run becomes one word, so it is never a subcommand and still fills an
# option's value, and wrapper words before git (sudo, env, timeout 5, then) are
# skipped.
git_subcommands() {
  awk '{
    gsub(/\047[^\047]*\047/, "Q"); gsub(/"([^"\\]|\\.)*"/, "Q")
    n = split($0, segs, /[;&|(){}]/)
    for (s = 1; s <= n; s++) { # mutant-ok: s != 1 or s == 1 leaves s at 0, and segs[0] is empty, so it is skipped the same way
      seg = segs[s]; sub(/(^|[[:space:]])#.*/, "", seg)
      w = split(seg, words, /[[:space:]]+/); i = 1
      while (i <= w && (words[i] == "" || words[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || words[i] ~ /^-/ || words[i] ~ /^[0-9.]+[smhd]?$/ ||
        words[i] ~ /^(sudo|run0|env|command|exec|time|nice|nohup|timeout|xargs|then|do|else|if|while|until|!)$/)) i++
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
