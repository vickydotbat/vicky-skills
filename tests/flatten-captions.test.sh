#!/usr/bin/env bash
# The video-captions flatten script turns a .vtt caption file into prose:
# no header, no timings, no tags, and each repeated caption line once.
set -u
script="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/video-captions/scripts/flatten-captions.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
cat > "$dir/in.vtt" <<'VTT'
WEBVTT
Kind: captions
Language: en

00:00:00.000 --> 00:00:02.000
Example mapping comes

00:00:02.000 --> 00:00:04.000
Example mapping comes
<00:00:03.000><c>before</c> the code.

00:00:04.000 --> 00:00:06.000
before the code.
VTT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got [$2], want [$3]"; fail=1; fi; }
out=$(bash "$script" "$dir/in.vtt" 2>"$dir/err"); code=$?
check "flattens captions to prose, each repeated line once" "$out" "Example mapping comes before the code."
check "exits 0 on a caption file" "$code" 0
check "writes nothing to stderr on a caption file" "$(cat "$dir/err")" ""
{ echo WEBVTT; echo; for i in $(seq 1 60); do echo "00:00:0$((i % 10)).000 --> 00:00:09.000"; echo "caption line $i"; echo; done; } > "$dir/long.vtt"
widest=$(bash "$script" "$dir/long.vtt" | awk '{ if (length($0) > w) w = length($0) } END { print w + 0 }')
check "wraps a long transcript at 200 characters or fewer" "$([ "$widest" -gt 0 ] && [ "$widest" -le 200 ] && echo yes)" yes
bash "$script" "$dir/missing.vtt" >/dev/null 2>"$dir/err"; code=$?
check "exits non-zero on a missing file" "$code" 1
check "names the missing file on stderr" "$(grep -c 'missing.vtt' "$dir/err")" 1
exit $fail
