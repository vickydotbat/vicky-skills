#!/usr/bin/env bash
# over-to-you's checklist lint: an item a command could prove never reaches a person.
set -u
lint="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/over-to-you/scripts/lint-checklist.py"
dir="$(mktemp -d)"; trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

cat > "$dir/good.md" <<'MD'
# Over to you, Bob!
proven by: integration.sh --branch, 15 fixtures green
## Pack
1. [ ] Open the hub → the grid draws
   person: look
   notes:
MD
sed 's/^   person: look$//' "$dir/good.md" > "$dir/no-person.md"
sed 's/person: look/person: the merge happens/' "$dir/good.md" > "$dir/bad-reason.md"
grep -v '^proven by:' "$dir/good.md" > "$dir/no-proof.md"

check "a checklist whose items each name a person-only reason passes" 'python3 "$lint" "$dir/good.md" >/dev/null'
check "an item with no person line is refused" '! python3 "$lint" "$dir/no-person.md" >/dev/null && python3 "$lint" "$dir/no-person.md" | grep -q "no \`person:\` line"'
check "a reason a command could prove is refused" '! python3 "$lint" "$dir/bad-reason.md" >/dev/null'
check "a checklist that names nothing the agent ran is refused" '! python3 "$lint" "$dir/no-proof.md" >/dev/null'
sed 's/Open the hub/Spawn the blueprint `i_paper` into your pack/' "$dir/good.md" > "$dir/no-kit.md"
sed 's/^   person: look$/&\n   kit: `\/runscript paper_kit` in the game chat\n   source: the module scripts\/paper_kit.nss/' "$dir/no-kit.md" > "$dir/kit.md"
sed 's/^   person: look$/&\n   kit:/' "$dir/no-kit.md" > "$dir/blank-kit.md"
sed 's/Open the hub → the grid draws/Look at the hub → the paper you were given shows/' "$dir/good.md" > "$dir/give-after.md"
check "an item that spawns a thing with no kit line is refused, even when it names the resref" '! python3 "$lint" "$dir/no-kit.md" >/dev/null && python3 "$lint" "$dir/no-kit.md" | grep -q "^4: .*no \`kit:\` line with its command"'
check "an item that spawns a thing and names its kit passes" 'python3 "$lint" "$dir/kit.md" >/dev/null'
sed 's/^   person: look$/&\n   kit: the paper script/' "$dir/no-kit.md" > "$dir/prose-kit.md"
check "a kit line with no command in backticks is refused" '! python3 "$lint" "$dir/prose-kit.md" >/dev/null'
check "an empty kit line is no kit" '! python3 "$lint" "$dir/blank-kit.md" >/dev/null'
check "a reach verb after the arrow, in what you should see, needs no kit" 'python3 "$lint" "$dir/give-after.md" >/dev/null'
# Terminal reads are the agent's to run (O2)
sed 's/Open the hub/Grep the client log for `failed to compile`/' "$dir/good.md" > "$dir/grep.md"
check "an item that greps a log is refused" 'python3 "$lint" "$dir/grep.md" | grep -q "terminal read the agent can run"'
sed 's/^   person: look$/&\n   kit: `tail -n 50 logs\/client.txt` in your terminal/' "$dir/good.md" > "$dir/tail.md"
check "a kit that tails a file is refused" 'python3 "$lint" "$dir/tail.md" | grep -q "terminal read"'
# A console kit names its source (O1)
sed 's/^   person: look$/&\n   kit: `DebugMode 1` in the game console/' "$dir/good.md" > "$dir/console.md"
check "a console kit with no source line is refused" 'python3 "$lint" "$dir/console.md" | grep -q "no \`source:\` line"'
sed 's/^   person: look$/&\n   kit: `DebugMode 1` in the game console\n   source: the NWN:EE console command list/' "$dir/good.md" > "$dir/console-src.md"
check "a console kit with a source line passes" 'python3 "$lint" "$dir/console-src.md" >/dev/null'
# A toggle gets a later item that turns it off (S6)
cat > "$dir/toggle.md" <<'MD2'
proven by: offline compile clean
## Probe
1. [ ] Turn on the slot view → each layer draws flat
   person: real client
   kit: `dm_runscript rgbprobe_dbg` in the game console
   source: scripts/rgbprobe_dbg.nss in the kit
2. [ ] Run the colour script → the cloth turns red
   person: real client
MD2
check "a toggle with no later off item is refused" 'python3 "$lint" "$dir/toggle.md" | grep -q "no later item turns it off"'
sed 's/^2\. \[ \] Run the colour script/2. [ ] Turn the slot view off with `dm_runscript rgbprobe_dbg`, then run the colour script/' "$dir/toggle.md" > "$dir/toggle-off.md"
check "a toggle with a later off item passes" 'python3 "$lint" "$dir/toggle-off.md" >/dev/null'
# More forms each rule catches
for a in 'Read the log for the compile line' 'Run `rg failed logs`' 'Check with `cat out.txt`'; do
  sed "s/Open the hub/$a/" "$dir/good.md" > "$dir/t.md"
  check "a terminal read in the action is refused: $a" 'python3 "$lint" "$dir/t.md" | grep -q "terminal read"'
done
sed 's/^   person: look$/&\n   kit: `\/dm_spawn x` in the game chat/' "$dir/good.md" > "$dir/chat.md"
check "a chat kit with no source line is refused" 'python3 "$lint" "$dir/chat.md" | grep -q "source:"'
for t in 'Toggle the overlay' 'Turn it on with the debug view' 'Run it again to turn the halo off'; do
  printf 'proven by: x\n## P\n1. [ ] %s → it draws\n   person: look\n   kit: `dm_runscript halo` in the game console\n   source: scripts/halo.nss\n' "$t" > "$dir/t.md"
  check "toggle form: $t" '[ "$(python3 "$lint" "$dir/t.md" | grep -c "turns it off")" = "$(grep -c "off" <<<"$t" | sed "s/1/0/;t;s/0/1/")" ]'
done
sed 's/^2\. \[ \] Run the colour script/2. [ ] Turn the lights off, then run the colour script/' "$dir/toggle.md" > "$dir/other-off.md"
check "an off item for some other thing does not turn the toggle off" 'python3 "$lint" "$dir/other-off.md" | grep -q "turns it off"'
mkdir -p "$dir/optout/docs/agents"; echo "Checklist lint: basic" > "$dir/optout/docs/agents/testing.md"
check "a repo that says Checklist lint: basic keeps only the basic checks" '(cd "$dir/optout" && python3 "$lint" "$dir/grep.md" >/dev/null)'
check "without the line the same file is refused" '(cd "$dir" && python3 "$lint" "$dir/grep.md" | grep -q "terminal read")'
exit $fail
