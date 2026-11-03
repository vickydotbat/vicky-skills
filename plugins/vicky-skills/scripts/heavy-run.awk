# Reads a shell command on stdin. Prints the command with a memory cap put in
# front of every heavy command that runs without one, or nothing when none
# does. The caller only checks whether anything printed.
#
# A command is heavy when its first word (after env assignments and the
# wrappers timeout, nice, env and exec) is an image, video, render or build
# tool, `nix develop|shell -c` running anything but a short read or a script
# the repo declares self-capping (-v decl, a regex of paths), or a shell's -c
# string that holds a heavy command. A command run under `systemd-run` with a
# MemoryMax= property is capped, and so is everything inside it.
# shortcut: a script run by path (`tools/render.sh`), a `$( )` substitution and
# `xargs` are not looked into; read the script when one runs away.

BEGIN {
  RS = "^$"; ORS = ""
  CAP = "systemd-run --user --scope -p MemoryMax=4G -p MemorySwapMax=0 "
}

{ ALL = ("HEAVY_RAW" in ENVIRON) ? ENVIRON["HEAVY_RAW"] : $0; out = scan($0, 1); if (changed) print out }

# words(s, W, P): splits s into words with quotes removed. W[k] is word k,
# P[k] the offset in s where it starts. Returns the count.
function words(s, W, P,   L, n, i, c, j, w, inw) {
  L = length(s); n = 0; w = ""; inw = 0
  for (i = 1; i <= L; i++) {
    c = substr(s, i, 1)
    if (c ~ /[ \t\n]/) {
      if (inw) { W[++n] = w; w = ""; inw = 0 }
      continue
    }
    if (!inw) { inw = 1; P[n + 1] = i }
    if (c == "\\") {
      w = w substr(s, ++i, 1)
    } else if (c == "\047") {
      j = index(substr(s, i + 1), "\047")
      if (j == 0) j = L - i + 1
      w = w substr(s, i + 1, j - 1); i += j
    } else if (c == "\"") {
      for (j = i + 1; j <= L && substr(s, j, 1) != "\""; j++) if (substr(s, j, 1) == "\\") j++
      w = w substr(s, i + 1, j - i - 1); i = j
    } else {
      w = w c
    }
  }
  if (inw) W[++n] = w
  return n
}

# A script the repo declares self-capping, run directly or by a shell or python.
function declared(W, k,   path) {
  path = W[k]
  if (path ~ /^((ba|z|da)?sh|python[0-9.]*)$/) path = W[k + 1]
  sub(/^\.\//, "", path)
  return decl != "" && path ~ ("^(" decl ")$")
}

# classify(seg): "heavy", "capped", "read" (a short read) or "other".
function classify(seg,   W, P, n, k, h, cap, v) {
  n = words(seg, W, P)
  for (k = 1; k <= n && W[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/; k++) ;
  for (; k <= n; k++) {
    if (W[k] == "timeout") {
      for (k++; k < n && W[k] ~ /^-/; k++) if (W[k] ~ /^(-[sk]|--signal|--kill-after)$/) k++
    } else if (W[k] == "nice") {
      if (W[k + 1] == "-n") k += 2
      else if (W[k + 1] ~ /^-/) k++
    } else if (W[k] == "env") {
      while (k < n && W[k + 1] ~ /^-|=/) k++
    } else if (W[k] == "systemd-run") {
      while (k < n && W[k + 1] ~ /^-/) {
        k++
        if (W[k] ~ /^(-p|--property|-E|--setenv)$/) k++
        if (W[k] ~ /MemoryMax=/) cap = 1
      }
    } else if (W[k] != "exec") {
      break
    }
  }
  if (cap) return "capped"
  if (k > n) return "other"
  h = W[k]; sub(/.*\//, "", h)
  if (n == k + 1 && W[n] ~ /^--?(version|help)$/) return "read"
  if (h == "magick" && W[k + 1] ~ /^(identify|-version|-list)$/) return "read"
  if (h ~ /^(magick|convert|montage|composite|mogrify|ffmpeg|blender|sd-cli|realesrgan.*)$/) return "heavy"
  if (h == "dotnet" && W[k + 1] ~ /^(test|build)$/) return "heavy"
  # Python whose code is in the command (-c, or a heredoc or pipe on stdin) is
  # image work only when that code imports an image or array library.
  # The caller passes the command before its heredocs were stripped as HEAVY_RAW.
# shortcut: stdin code is looked for in the whole command, not just its heredoc.
  if (h ~ /^python[0-9.]*$/ && W[k + 1] == "-c") return imports(W[k + 2]) ? "heavy" : "other"
  if (h ~ /^python[0-9.]*$/ && (k == n || W[k + 1] == "-" || W[k + 1] ~ /^<</)) return imports(ALL) ? "heavy" : "other"
  if (h ~ /^python[0-9.]*$/ && tolower(seg) ~ /\.(png|jpe?g|webp|gif|bmp|tga|dds|tiff?|exr|mp4|mkv|webm)([^a-z0-9]|$)|image|icon|sprite|atlas|texture|render|upscale|montage|build/) return "heavy"
  if (h ~ /^(ba|z|da)?sh$/ && W[k + 1] ~ /^-[a-z]*c[a-z]*$/) return scan(W[k + 2], 0) ? "heavy" : "other"
  if (h == "nix" && W[k + 1] ~ /^(develop|shell)$/) {
    for (v = k + 2; v <= n && W[v] !~ /^(-c|--command)$/; v++) ;
    if (v >= n) return "other"
    if (classify(substr(seg, P[v + 1])) ~ /^(read|capped)$/ || declared(W, v + 1)) return "other"
    return "heavy"
  }
  if (h ~ /^(identify|ffprobe|echo|printf|true|which|ls|cat|head|tail|printenv|pwd|git|test)$/) return "read"
  return "other"
}

# imports(code): 1 when the python code imports an image or array library.
function imports(code) {
  return code ~ /(^|[^A-Za-z0-9_])(import|from)[ \t]+([A-Za-z0-9_.]+[ \t]*,[ \t]*)*(PIL|imageio|cv2|numpy|torch)([^A-Za-z0-9_]|$)/
}

# The cap goes in front of the first word after the env assignments. A timeout
# already there keeps its own limit.
function capped(seg,   W, P, n, k) {
  n = words(seg, W, P)
  for (k = 1; k <= n && W[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/; k++) ;
  return substr(seg, 1, P[k] - 1) CAP (W[k] == "timeout" ? "" : "timeout 300 ") substr(seg, P[k])
}

# scan(s, fix): splits s into simple commands, outside quotes and $( ).
# With fix, returns s with each heavy command capped and sets changed.
# Without, returns 1 when any command is heavy.
function scan(s, fix,   L, i, c, j, start, out, depth, seg, hit) {
  L = length(s); start = 1; out = ""; depth = 0; hit = 0
  for (i = 1; i <= L + 1; i++) {
    c = substr(s, i, 1)
    if (c == "\\") {
      i++
    } else if (c == "\047") {
      j = index(substr(s, i + 1), "\047")
      i = j ? i + j : L
    } else if (c == "\"") {
      for (i++; i <= L && substr(s, i, 1) != "\""; i++) if (substr(s, i, 1) == "\\") i++
    } else if (c == "$" && substr(s, i + 1, 1) == "(") {
      depth++; i++
    } else if (c == ")" && depth > 0) {
      depth--
    } else if (c == "#" && (i == 1 || substr(s, i - 1, 1) ~ /[ \t\n;&|(]/)) {
      j = index(substr(s, i), "\n")
      i = j ? i + j - 2 : L
    } else if (i > L || (depth == 0 && c ~ /[;|&\n()]/ && !(c == "&" && (substr(s, i - 1, 2) ~ /[<>]&/ || substr(s, i, 2) == "&>")))) {
      seg = substr(s, start, i - start)
      if (classify(seg) == "heavy") { hit = 1; if (fix) seg = capped(seg) }
      out = out seg c; start = i + 1
    }
  }
  if (fix) { changed = hit; return out }
  return hit
}
