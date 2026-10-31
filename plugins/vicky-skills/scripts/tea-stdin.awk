# Reads a shell command on stdin. Prints the command with ` </dev/null` added
# to every `tea` command that leaves stdin open, or nothing when none does.
# The caller only checks whether anything printed.
#
# One pass over the characters, outside quotes. A `tea` is a word in command
# position (env assignments may come first). Left alone, on purpose:
#   - a command with a heredoc or a backtick (too easy to misjudge),
#   - a tea command that already redirects input with `<`,
#   - a tea fed by a pipe (`cat f | tea ...`): its stdin is the pipe,
#   - a tea inside quotes (`bash -c 'tea ...'`), which is not seen at all.

function finish_word() {
  if (word == "") return
  if (cmdpos) {
    if (word == "tea") {
      inTea = 1; hasRedir = 0; teaPiped = piped; cmdpos = 0
    } else if (word ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
      cmdpos = 1
    } else {
      cmdpos = 0
    }
    piped = 0
  }
  word = ""
}

function end_segment(   ws) {
  finish_word()
  if (inTea && !hasRedir && !teaPiped) {
    match(out, /[ \t\n]*$/)
    ws = substr(out, RSTART)
    out = substr(out, 1, RSTART - 1) " </dev/null" ws
    changed = 1
  }
  inTea = 0
}

function push_frame() {
  sp++
  fTea[sp] = inTea; fRedir[sp] = hasRedir; fPiped[sp] = teaPiped
  inTea = 0; cmdpos = 1; piped = 0
}

BEGIN { RS = "^$"; ORS = "" }

{
  n = length($0)
  cmdpos = 1; piped = 0; inTea = 0; out = ""; word = ""; sp = 0; changed = 0
  if ($0 ~ /<</) exit 0 # mutant-ok: the hook reads only what this prints, never its exit status
  for (i = 1; i <= n; i++) {
    c = substr($0, i, 1)
    if (c == "\\") {
      out = out c substr($0, i + 1, 1); word = word "x"; i++
    } else if (c == "\047") {
      j = index(substr($0, i + 1), "\047")
      if (j == 0) exit 0 # mutant-ok: the hook reads only what this prints, never its exit status
      out = out substr($0, i, j + 1); word = word "x"; i += j
    } else if (c == "\"") {
      for (j = i + 1; j <= n; j++) {
        d = substr($0, j, 1)
        if (d == "\\") { j++; continue }
        if (d == "\"") break
      }
      if (j > n) exit 0 # mutant-ok: the hook reads only what this prints, never its exit status
      out = out substr($0, i, j - i + 1); word = word "x"; i = j
    } else if (c == "`") {
      exit 0 # mutant-ok: the hook reads only what this prints, never its exit status
    } else if (c == "#" && word == "") {
      # The fix goes before a comment, where the shell still reads it.
      end_segment()
      j = index(substr($0, i), "\n")
      if (j == 0) { out = out substr($0, i); i = n }
      else { out = out substr($0, i, j - 1); i += j - 2 }
    } else if (c == "$" && substr($0, i + 1, 1) == "(") {
      finish_word()
      out = out "$("; i++
      push_frame()
    } else if (c == "(" && cmdpos && word == "") {
      out = out c
      push_frame()
    } else if (c == ")" && sp > 0) {
      end_segment()
      out = out c
      inTea = fTea[sp]; hasRedir = fRedir[sp]; teaPiped = fPiped[sp]; sp--
      cmdpos = 0; word = "x"
    } else if (c == "|" || c == ";" || c == "\n" || c == "&") {
      prev = substr($0, i - 1, 1); nxt = substr($0, i + 1, 1)
      if (c == "&" && (prev == ">" || prev == "<" || nxt == ">")) {
        out = out c; word = word "x"
      } else {
        end_segment()
        out = out c
        dbl = (nxt == c)
        if ((c == "|" || c == "&") && dbl) { out = out c; i++ }
        piped = (c == "|" && !dbl) ? 1 : 0
        cmdpos = 1
      }
    } else if (c == "<") {
      if (inTea) hasRedir = 1
      finish_word(); out = out c
    } else if (c == " " || c == "\t") {
      finish_word(); out = out c
    } else {
      word = word c; out = out c
    }
  }
  end_segment()
  if (changed) print out
}
