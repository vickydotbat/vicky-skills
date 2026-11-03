#!/usr/bin/env bash
# heavy-run-guard refuses a heavy run without a memory cap, passes capped runs,
# short reads and declared self-capping scripts, and is off by default.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/heavy-run-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"; mkdir -p "$dir/repo/docs/agents" "$dir/plain"
printf '# Domain\n\nBounded scripts: tools/*.sh scripts/render?.py\n' >"$dir/repo/docs/agents/domain.md"
fail=0
cap='systemd-run --user --scope -p MemoryMax=4G -p MemorySwapMax=0'
check() { # want command [option] [cwd]
  jq -n --arg c "$2" --arg d "${4:-$dir/plain}" '{tool_input:{command:$c},cwd:$d}' \
    | CLAUDE_PLUGIN_OPTION_GUARD_HEAVY_RUN="${3-true}" "$hook" >/dev/null 2>&1; got=$?
  if [ "$got" = "$1" ]; then echo "ok   $2 -> $1"; else echo "FAIL $2: got $got, want $1"; fail=1; fi
}
refuse() { check 2 "$1"; }
allow() { check 0 "$1"; }
# The run that froze the desktop: timeout alone caps time, not memory.
refuse "timeout 200 nix develop path:. -c bash -c 'magick montage a.png b.png out.png && python3 check.py'"
refuse 'magick a.png -resize 50% b.png'
refuse 'convert a.png b.jpg'
refuse 'montage *.png -tile 8x out.png'
refuse 'composite a.png b.png c.png'
refuse 'mogrify -resize 64x64 *.png'
refuse '/usr/bin/magick a.png b.png'
refuse 'realesrgan-ncnn-vulkan -i in -o out'
refuse 'ffmpeg -i in.mp4 out.webm'
refuse 'blender -b scene.blend -a'
refuse 'sd-cli -p "a cat"'
refuse 'dotnet test'
refuse 'dotnet build -c Release'
refuse 'python3 tools/upscale.py in out'
refuse 'python3 check.py sheet.PNG'
refuse 'python -m build'
refuse 'nix develop -c just test'
refuse 'nix shell nixpkgs#imagemagick -c magick a.png b.png'
refuse 'nix develop --command bash tools/other/x.sh'
refuse 'nix develop path:. -c bash -c "ls"'
refuse 'cd art && magick a.png b.png'
refuse 'ls; magick a.png b.png'
refuse 'FOO=1 magick a.png b.png'
refuse 'nice -n 10 ffmpeg -i a b'
refuse 'nice -5 ffmpeg -i a b'
refuse 'env -i FOO=1 ffmpeg -i a b'
refuse 'exec ffmpeg -i a b'
refuse 'timeout -s KILL 60 ffmpeg -i a b'
refuse 'timeout --kill-after 5 60 ffmpeg -i a b'
refuse 'sh -c "magick a b"'
refuse 'zsh -lc "magick a b"'
refuse 'bash -c "echo; magick a b"'
refuse '(cd x && magick a b)'
refuse 'systemd-run --user --scope magick a b'
refuse 'systemd-run --user --scope -p CPUWeight=20 magick a b'
refuse "$cap timeout 300 true; magick a b"
refuse 'echo $(true) && magick a b'
refuse 'magick a b 2>&1 | tail'
refuse 'ls & magick a b'
refuse $'ls\nmagick a b'
refuse "bash -c 'x' && magick a b"
refuse 'echo "x" && magick a b'
refuse 'echo a\ b && magick a b'
refuse 'ls # done
magick a b'
refuse 'ffmpeg --version x'
check 2 'nix develop -c tools/a/b.sh' true "$dir/repo"
check 2 'nix develop -c tools/x.sh' true "$dir/plain"
allow "$cap timeout 300 magick montage a.png b.png out.png"
allow "$cap timeout 300 nix develop path:. -c bash -c 'magick montage a.png out.png'"
allow 'systemd-run --user --scope --property=MemoryMax=2G magick a b'
allow 'systemd-run --user --scope -E X=1 -p MemoryMax=2G magick a b'
allow "bash -c '$cap magick a b'"
allow 'magick identify a.png'
allow 'magick identify -format "%w" *.png'
allow 'magick -version'
allow 'magick -list format'
allow 'identify a.png'
allow 'ffprobe in.mp4'
allow 'ffmpeg -version'
allow 'blender --version'
allow 'dotnet --info'
allow 'dotnet restore'
allow 'python3 tests/mutate-hooks.py --check'
allow 'python3 -c "print(1)"'
# Python whose code is in the command counts as image work only when that
# code imports an image or array library, whatever its arguments name.
allow $'python3 - x.tga <<\'PY\'\nimport struct, sys\nprint(struct.unpack("<HH", open(sys.argv[1], "rb").read(16)[12:16]))\nPY'
refuse $'python3 - x.tga <<\'PY\'\nfrom PIL import Image\nImage.open("x.tga").load()\nPY'
allow $'python3 -I - x.tga <<\'PY\'\nimport struct\nPY'
refuse $'python3 -I -u - x.tga <<\'PY\'\nimport numpy\nPY'
allow 'python3 -I -c "print(1)"'
allow 'timeout 60 bin/depot api GET /v1/materials | python3 -c "import json,sys; print([m for m in json.load(sys.stdin) if \"rgbAtlasFlip\" in m])"'
refuse 'python3 -c "import numpy as np; np.zeros(9)"'
refuse 'python3 -c "import json, cv2"'
refuse $'python3 <<\'PY\'\nimport torch\nPY'
allow $'python3 <<\'PY\'\nprint("render the atlas")\nPY'
allow 'nix develop -c echo hi'
allow 'nix develop -c git status'
allow 'nix develop -c magick identify a.png'
allow 'nix develop -c ffmpeg -version'
allow "nix develop -c $cap magick a b"
allow 'nix develop'
allow 'nix build .#x'
allow 'nix shell nixpkgs#jq'
allow 'grep ffmpeg README.md'
allow 'git log --grep convert'
allow 'git commit -m "fix montage"'
allow 'echo "magick a b"'
allow "echo 'magick a b'"
allow 'rg -n magick tools/'
allow 'ls # magick a b'
allow 'ls # x; magick a b'
refuse 'ls a#b; magick a b'
allow 'cat file >&2 && ls'
allow 'ls 2>&1 | head'
allow 'tools/render-all.sh'
allow 'bash tools/x.sh'
allow $'cat <<EOF\nmagick a b\nEOF'
allow 'magickal --spell'
allow 'echo $(magick identify a.png)'
allow 'bash -c "ls"'
allow ''
check 0 'nix develop -c tools/x.sh' true "$dir/repo"
check 0 'nix develop -c ./tools/x.sh --all' true "$dir/repo"
check 0 'nix develop path:. -c bash tools/icons.sh' true "$dir/repo"
check 0 'nix develop -c python3 scripts/render1.py' true "$dir/repo"
check 2 'nix develop -c python3 scripts/render12.py' true "$dir/repo"
check 2 'nix develop -c bash' true "$dir/repo"
refuse "'magick' a b"
refuse '"montage" a b'
refuse 'echo $x; magick a b'
refuse 'ls; (magick a b)'
allow 'foo -c "magick a b"'
allow 'foo develop -c magick a b'
# shortcut in heavy-run.awk: a $( ) substitution is not looked into.
allow 'echo $(ls; magick a b)'
# Without gawk the guard says so and lets the command run.
mkdir "$dir/bin"; for t in bash jq cat dirname git sed tr paste; do ln -s "$(command -v $t)" "$dir/bin/$t"; done
jq -n '{tool_input:{command:"magick a b"}}' | CLAUDE_PLUGIN_OPTION_GUARD_HEAVY_RUN=true PATH="$dir/bin" "$dir/bin/bash" "$hook" >/dev/null 2>&1
if [ $? = 0 ]; then echo "ok   gawk missing -> 0"; else echo "FAIL gawk missing: not 0"; fail=1; fi
check 0 'magick a b' ""
check 0 'magick a b' false
check 2 'magick a b' 1
# A refusal ends with the command rewritten, the cap put in front of each heavy part.
fixes() { # command want
  got=$(jq -n --arg c "$1" '{tool_input:{command:$c}}' | CLAUDE_PLUGIN_OPTION_GUARD_HEAVY_RUN=true "$hook" 2>&1 >/dev/null | sed -n 2p)
  if [ "$got" = "$2" ]; then echo "ok   $1 -> fix $2"; else echo "FAIL $1: fix got '$got', want '$2'"; fail=1; fi
}
fixes "timeout 200 nix develop path:. -c bash -c 'magick a b'" "$cap timeout 200 nix develop path:. -c bash -c 'magick a b'"
fixes 'magick a b' "$cap timeout 300 magick a b"
fixes 'cd art && FOO=1 magick a b | tail' "cd art && FOO=1 $cap timeout 300 magick a b | tail"
fixes 'ls; ffmpeg -i a b; magick identify a' "ls; $cap timeout 300 ffmpeg -i a b; magick identify a"
fixes 'dotnet test && dotnet build' "$cap timeout 300 dotnet test && $cap timeout 300 dotnet build"
# The reason names the cap and why a timeout alone falls short.
# A system without systemd has no cap to steer to, so the guard lets the run through.
mkdir "$dir/nosystemd"
for t in jq gawk bash dirname cat sed grep awk tr head; do ln -s "$(command -v "$t")" "$dir/nosystemd/$t"; done
out=$(jq -n '{tool_input:{command:"magick a b"}}' | PATH="$dir/nosystemd" CLAUDE_PLUGIN_OPTION_GUARD_HEAVY_RUN=true bash "$hook" 2>&1); code=$?
if [ $code = 0 ] && [ -z "$out" ]; then echo "ok   without systemd-run the guard stays out of the way"; else echo "FAIL without systemd-run: $code $out"; fail=1; fi
why=$(jq -n '{tool_input:{command:"magick a b"}}' | CLAUDE_PLUGIN_OPTION_GUARD_HEAVY_RUN=true "$hook" 2>&1 | head -1)
case "$why" in *MemoryMax*timeout*) echo "ok   the reason names the memory cap" ;; *) echo "FAIL reason: $why"; fail=1 ;; esac
exit $fail
