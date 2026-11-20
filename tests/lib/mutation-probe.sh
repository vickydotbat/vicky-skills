# Sourced by the mutation load tests: a copy of the repo whose runner mutates a
# small probe script, set up per check.
scratch=$(mktemp -d); busy=()
trap 'kill "${busy[@]}" 2>/dev/null; rm -rf "$scratch"' EXIT
# setup <name> <script line> <test body>: a copy of the repo whose test map runs
# a probe test against the probe script. The test body sees $hook and $calls.
probe_dir=skills/testing/probe/scripts; probe=$probe_dir/probe.sh
setup() {
  dir="$scratch/$1"; mkdir -p "$dir"; cp -r "$root/plugins" "$root/tests" "$dir/"
  # A skill script, since the map adds the slow shared exit-code test to every hook script.
  mkdir -p "$dir/plugins/vicky-skills/$probe_dir"
  printf '#!/usr/bin/env bash\nx=1\n%s\n' "$2" > "$dir/plugins/vicky-skills/$probe"
  chmod +x "$dir/plugins/vicky-skills/$probe"
  { echo '#!/usr/bin/env bash'; echo "hook=\"\$(dirname \"\$0\")/../plugins/vicky-skills/$probe\""; echo "calls='$dir/calls'"
    echo 'n=$(( $(cat "$calls" 2>/dev/null || echo 0) + 1 )); echo $n > "$calls"'; echo "$3"; } > "$dir/tests/probe.test.sh"
  chmod +x "$dir/tests/probe.test.sh"
  sed -i "s|    \"publickey-hint.sh\": \\[\"publickey-hint\"\\],|&\\n    \"$probe\": [\"probe\"],|" "$dir/tests/mutate-hooks.py"
  grep -qF "\"$probe\": [\"probe\"]" "$dir/tests/mutate-hooks.py" || { echo "FAIL the test map has no publickey-hint.sh line to put the probe after"; exit 1; }
}
pass() { timeout 300 python3 "$dir/tests/mutate-hooks.py" --jobs 1 "$probe" 2>&1; }
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; echo "$out"; fail=1; fi; }
