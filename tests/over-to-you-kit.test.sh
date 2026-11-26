#!/usr/bin/env bash
# kit.sh records each over-to-you kit before it is written and removes only
# what it recorded; checklist.py refuses a kit item whose kits_made is missing
# or names a path kit.sh never recorded.
# shellcheck disable=SC2016,SC2034,SC2181,SC2329 # check() evals its single-quoted condition later, which uses these
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root/plugins/vicky-skills/skills/building/over-to-you/scripts"
fx=$(mktemp -d); trap 'chmod -R u+w "$fx"; rm -rf "$fx"' EXIT
export TMPDIR="$fx/tmp" CLAUDE_CODE_SESSION_ID=s1
mkdir -p "$TMPDIR/s1"
rec="$TMPDIR/s1/over-to-you-kits"
repo="$fx/repo"; mkdir -p "$repo"
git -C "$repo" init -q; git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
printf 'scratch/\n' >"$repo/.gitignore"; echo a >"$repo/a.txt"; git -C "$repo" add -A; git -C "$repo" commit -qm init
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
kit() { bash "$skill/kit.sh" "$@"; }

check "no arguments prints usage and exits 2" 'kit >/dev/null 2>&1; [ $? = 2 ]'
check "an unknown verb exits 2" 'kit sweep >/dev/null 2>&1; [ $? = 2 ]'
check "add with no path exits 2" 'kit add >/dev/null 2>&1; [ $? = 2 ]'
check "no session id exits 2" 'env -u CLAUDE_CODE_SESSION_ID bash "$skill/kit.sh" left >/dev/null 2>&1; [ $? = 2 ]'
check "clean with nothing recorded exits 0" 'kit clean >/dev/null 2>&1'
check "left with nothing recorded prints nothing" '[ -z "$(kit left)" ]'
check "a path that already exists is refused, so clean never takes a file the session did not make" 'out=$(kit add "$repo/a.txt" 2>&1); [ $? = 1 ] && grep -q "before you write it" <<<"$out" && [ ! -s "$rec" ]'
check "a kit folder recorded before it is written is recorded" 'kit add "$repo/scratch/ot12" && grep -qF "$repo/scratch/ot12" "$rec"'
mkdir -p "$repo/scratch/ot12/deep"; echo k >"$repo/scratch/ot12/paper.lua"; echo k >"$repo/scratch/ot12/deep/out.log"
check "a file under a recorded folder may be recorded after it exists" 'kit add "$repo/scratch/ot12/paper.lua"'
check "a relative path is recorded whole" '(cd "$repo" && kit add loose.lua) && grep -qF "$repo/loose.lua" "$rec"'
echo k >"$repo/loose.lua"
check "left names each recorded path still in place" '[ "$(kit left | cut -f2 | sort)" = "$(printf "%s\n" "$repo/loose.lua" "$repo/scratch/ot12" "$repo/scratch/ot12/paper.lua" | sort)" ]'
kit add "$repo/committed.lua"; echo k >"$repo/committed.lua"; git -C "$repo" add committed.lua; git -C "$repo" commit -qm kit
out=$(kit clean 2>&1); rc=$?
check "clean removes every recorded kit, folders with what the kits wrote in them" '[ ! -e "$repo/scratch/ot12" ] && [ ! -e "$repo/loose.lua" ]'
check "clean leaves a kit git tracks, says why and exits 1" '[ $rc = 1 ] && [ -f "$repo/committed.lua" ] && grep -q "git tracks" <<<"$out"'
check "clean leaves the files around its kits" '[ -f "$repo/a.txt" ] && [ -f "$repo/.gitignore" ] && [ -d "$repo/scratch" ]'
check "the record keeps only what is still in place" '[ "$(cut -f2 "$rec")" = "$repo/committed.lua" ]'
git -C "$repo" rm -q committed.lua; git -C "$repo" commit -qm unkit
check "clean exits 0 once nothing recorded is left" 'kit clean >/dev/null 2>&1 && [ -z "$(kit left)" ]'

# checklist.py and kits_made
receipts="$TMPDIR/s1/over-to-you-receipts"; mkdir -p "$receipts"
jq -n '{id:"r", command:"harness.sh /runscript paper", exit:0, at:"2026-01-01T00:00:00Z", head:"", cwd:"/", tail:""}' >"$receipts/r.json"
spec() { jq -n --argjson extra "$1" '{name:"Bob", open:"Open the client.", signed_off:"nothing yet", proven_by:"no server",
  sections:[{title:"Pack", items:[{do:"Spawn the paper", see:"the sheet shows", person:"real client", kit:"`/runscript paper`", ran:"r"}]}]} + $extra' >"$fx/spec.json"; }
write() { rm -f "$TMPDIR/s1/over-to-you-x.md"; python3 -I "$skill/checklist.py" "$fx/spec.json" "$TMPDIR/s1/over-to-you-x.md"; }
spec '{}'
check "a kit item with no kits_made is refused" 'out=$(write); [ $? = 1 ] && grep -q "kits_made" <<<"$out"'
spec '{"kits_made": "none"}'
check "kits_made none writes the checklist" 'write >/dev/null'
spec "{\"kits_made\": [\"$repo/scratch/ot13/paper.lua\"]}"
check "a kits_made path kit.sh never recorded is refused, naming kit.sh add" 'out=$(write); [ $? = 1 ] && grep -q "kit.sh add" <<<"$out"'
kit add "$repo/scratch/ot13/paper.lua"
check "a recorded kits_made path writes the checklist" 'write >/dev/null'
kit add "$repo/scratch/ot14"; mkdir -p "$repo/scratch/ot14"; echo k >"$repo/scratch/ot14/paper.lua"
spec "{\"kits_made\": [\"$repo/scratch/ot14\"]}"
manifest="$repo/.git/over-to-you-kits/$(git -C "$repo" symbolic-ref --short HEAD)"
check "a written checklist seals each kit with its sha256 for auto-tidy, and each kit folder as dir" 'write >/dev/null && grep -qxF "$(printf "dir\t%s" "$repo/scratch/ot14")" "$manifest" && grep -qxF "$(sha256sum "$repo/scratch/ot14/paper.lua" | cut -d" " -f1)$(printf "\t")$repo/scratch/ot14/paper.lua" "$manifest"'
check "writing it again keeps one line per path" 'write >/dev/null && [ "$(wc -l <"$manifest")" = 2 ]'
kit add "$repo/one.lua"; echo k >"$repo/one.lua"; ln -s ../../a.txt "$repo/scratch/ot14/link"
spec '{"kits_made": ["scratch/ot14", "one.lua"]}'
check "a relative kit path and a single-file kit are sealed by their full path, and a link is not hashed" '(cd "$repo" && write >/dev/null) && grep -qF "$(printf "\t")$repo/one.lua" "$manifest" && ! grep -q "link" "$manifest" && ! grep -q "$(printf "\t")scratch" "$manifest"'
kit add "$repo/big.bin"; truncate -s 600M "$repo/big.bin"
spec '{"kits_made": ["big.bin"]}'
check "a kit larger than the memory limit is sealed by streaming its hash" '(cd "$repo" && ulimit -v 300000 && write >/dev/null 2>&1) && grep -qF "$(printf "\t")$repo/big.bin" "$manifest"'
rm -f "$repo/big.bin"
spec '{"kits_made": []}'
check "an empty kits_made is refused" 'out=$(write); [ $? = 1 ] && grep -q "kits_made" <<<"$out"'
exit "$fail"
