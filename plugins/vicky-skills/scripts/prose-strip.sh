# shellcheck shell=bash
# Sourced by guards that read a Bash command for a call. prose_strip <command>
# prints the command with the value of each title, message or body flag emptied,
# so words in a pull request title or commit message never read as a call.
# It reads quotes as the shell does, and strips only in a command that carries
# prose (git commit or tag, gh pr or issue create, edit, comment or review, and
# tea's), and the search text of git log --grep and gh pr or issue list --search, so a flag inside another quoted string or another tool's -t is left.
# A value holding $( or a backtick runs, so it stays. With unbalanced quotes,
# or any $'..' quoting, the command prints unchanged.
prose_strip() {
  awk -v RS='\001' '
  function carrier(  a, b, c) {
    a = w[1]; b = w[2]; c = w[3]
    if (a == "git" && (b == "commit" || b == "tag")) return 1
    if (a == "gh" && (b == "pr" || b == "issue") && c ~ /^(create|edit|comment|review)$/) return 1
    if (a == "tea" && b ~ /^(pr|pulls|issues?|i)$/ && c ~ /^(create|edit|comment|c|e)$/) return 1
    if (a == "git" && b ~ /^(log|shortlog|rev-list)$/) return 2
    if (a ~ /^(gh|\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)$/ && (b == "pr" || b == "issue") && c == "list") return 3
    return 0
  }
  function flag(v,  k) {
    k = carrier()
    if (k == 1) return v ~ /^(-m|--message|-t|--title|-b|--body)$/ || (w[1] == "git" && v ~ /^-[a-z]+m$/)
    if (k == 2) return v ~ /^(--grep|-S|-G)$/
    return k == 3 && (v == "-S" || v == "--search")
  }
  function done_tok(  out) {
    if (raw == "") return
    out = raw
    if (pend && !sub_) out = "\"\""
    else if (!sub_ && ((val ~ /^(--message|--title|--body)=/ && carrier() == 1) || (val ~ /^--grep=/ && carrier() == 2) || (val ~ /^--search=/ && carrier() == 3))) { sub(/=.*/, "=\"\"", out) }
    else if (!sub_ && ((val ~ /^-[SG]./ && carrier() == 2) || (val ~ /^-S./ && carrier() == 3))) out = substr(val, 1, 2) "\"\""
    pend = 0
    # The flags of git itself, -C <dir> and -c <key=value> among them, come before the subcommand.
    if (skip) skip = 0
    else if (nw == 1 && w[1] == "git" && (val == "-C" || val == "-c")) skip = 1
    else if (nw == 1 && w[1] == "git" && val ~ /^-/) { }
    else if (nw < 3) w[++nw] = val
    if (flag(val)) pend = 1
    res = res out; raw = ""; val = ""; sub_ = 0
  }
  function seg_end() { done_tok(); nw = 0; pend = 0; skip = 0 }
  {
    s = $0; n = length(s)
    # $'..' quoting escapes quotes in a way this reader does not follow: leave it all.
    if (index(s, "$\x27")) { printf "%s", s; exit }
    for (i = 1; i <= n; i++) {
      ch = substr(s, i, 1)
      if (q == "\x27") { raw = raw ch; if (ch == "\x27") q = ""; else val = val ch; continue }
      if (q == "\"") {
        raw = raw ch
        if (ch == "\\" && i < n) { i++; raw = raw substr(s, i, 1); val = val substr(s, i, 1); continue }
        if (ch == "\"") { q = ""; continue }
        if (ch == "`" || (ch == "$" && substr(s, i + 1, 1) == "(")) sub_ = 1
        val = val ch; continue
      }
      if (ch == "\\" && i < n) { i++; raw = raw ch substr(s, i, 1); val = val substr(s, i, 1); continue }
      if (ch == "\x27" || ch == "\"") { q = ch; raw = raw ch; continue }
      if (ch == "`" || (ch == "$" && substr(s, i + 1, 1) == "(")) sub_ = 1
      if (ch ~ /[;&|\n()]/) { seg_end(); res = res ch; continue }
      if (ch ~ /[ \t]/) { done_tok(); res = res ch; continue }
      raw = raw ch; val = val ch
    }
    if (q != "") { printf "%s", s; exit }
    done_tok(); printf "%s", res
  }' <<<"$1"
}
