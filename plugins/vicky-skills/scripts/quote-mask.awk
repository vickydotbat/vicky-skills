# Prints a shell command with the text inside its quotes masked, so a forge
# command quoted as data (`sed 's/x/gh pr create/'`, `echo "gh pr create"`)
# never reads as one, and a quoted `;`, `&`, `|` or newline never splits it.
# Inside quotes a blank becomes \001, `;` \002, `&` \003, `|` \004 and a
# newline \005; everything else stays. A command substitution `$(...)` inside
# double quotes runs, so it stays unmasked. Used by pr-guard.sh.
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
    c = substr($0, i, 1)
    if (q == "'") {
      if (c == "'") { q = ""; print c } else print mask(c)
    } else if (q == "\"") {
      if (c == "\\") { print c mask(substr($0, i + 1, 1)); i++ }
      else if (c == "\"") { q = ""; print c }
      else if (c == "$" && substr($0, i + 1, 1) == "(") { saved[++depth] = "\""; q = ""; print "$("; i++ }
      else print mask(c)
    } else {
      if (c == "\\") { print c substr($0, i + 1, 1); i++ }
      else if (c == "'" || c == "\"") { q = c; print c }
      else if (c == "(") { saved[++depth] = ""; print c }
      else if (c == ")" && depth > 0) { q = saved[depth--]; print c }
      else print c
    }
  }
}
