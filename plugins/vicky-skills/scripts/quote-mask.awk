# Prints a shell command with the text inside its quotes masked, so a forge
# command quoted as data (`sed 's/x/gh pr create/'`, `echo "gh pr create"`)
# never reads as one, and a quoted `;`, `&`, `|` or newline never splits it.
# Inside quotes a blank becomes \001, `;` \002, `&` \003, `|` \004 and a
# newline \005; everything else stays. What the shell runs inside double
# quotes, `$(...)` or backticks, stays unmasked. A comment is printed as it
# stands. It exits 1 when a quote never closes, and the caller then reads the
# command unmasked. Needs gawk for its whole-input record. Used by pr-guard.sh.
BEGIN { RS = "^$"; ORS = "" }
function mask(c) {
  if (c == " " || c == "\t") return "\001"
  if (c == ";") return "\002"
  if (c == "&") return "\003"
  if (c == "|") return "\004"
  if (c == "\n") return "\005"
  return c
}
{
  n = length($0); q = ""; depth = 0
  for (i = 1; i <= n; i++) {
    c = substr($0, i, 1); next_c = substr($0, i + 1, 1)
    if (q == "'") {
      if (c == "'") { q = ""; print c } else print mask(c)
    } else if (q == "$'") {
      if (c == "\\") { print c mask(next_c); i++ }
      else if (c == "'") { q = ""; print c }
      else print mask(c)
    } else if (q == "\"") {
      if (c == "\\") { print c mask(next_c); i++ }
      else if (c == "\"") { q = ""; print c }
      else if (c == "$" && next_c == "(") { saved[++depth] = "\""; q = ""; print "$("; i++ }
      else if (c == "`") { saved[++depth] = "\"`"; q = ""; print c }
      else print mask(c)
    } else {
      if (c == "\\") { print c next_c; i++ }
      else if (c == "#" && (i == 1 || substr($0, i - 1, 1) ~ /[[:space:];&|(]/)) {
        while (i <= n && substr($0, i, 1) != "\n") print substr($0, i++, 1)
        i--
      }
      else if (c == "$" && next_c == "'") { q = "$'"; print "$'"; i++ }
      else if (c == "'" || c == "\"") { q = c; print c }
      else if (c == "`" && depth > 0 && saved[depth] == "\"`") { depth--; q = "\""; print c }
      else if (c == "(") { saved[++depth] = ""; print c }
      else if (c == ")" && depth > 0) { q = saved[depth--]; print c }
      else print c
    }
  }
}
END { if (q != "") exit 1 }
