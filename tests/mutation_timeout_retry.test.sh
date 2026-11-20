#!/usr/bin/env bash
# A mutant whose test stalls once past its timeout, then passes, is no kill.
# Under a niced run on a busy machine a 0.07 s test can stall past its 5 s
# limit once, and mutation_speed_approved_examples lost its one survivor so.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
cp -r "$root/plugins" "$root/tests" "$dir/"
printf '#!/usr/bin/env bash\nx=1\n: "$x"\n' > "$dir/plugins/vicky-skills/scripts/stall.sh"
chmod +x "$dir/plugins/vicky-skills/scripts/stall.sh"
# Call 1 is the baseline. Call 2, the first mutant's, stalls past its limit.
cat > "$dir/tests/stall.test.sh" <<EOF
#!/usr/bin/env bash
n=\$(( \$(cat "$dir/calls" 2>/dev/null || echo 0) + 1 )); echo \$n > "$dir/calls"
[ \$n = 2 ] && sleep 8
exit 0
EOF
chmod +x "$dir/tests/stall.test.sh"
sed -i 's|    "gamma-shift.sh": \["gamma-shift"\],|&\n    "stall.sh": ["stall"],|' "$dir/tests/mutate-hooks.py"
out=$(timeout 120 python3 "$dir/tests/mutate-hooks.py" --jobs 1 stall.sh 2>&1)
if grep -q "^script stall.sh: 0/2$" <<<"$out"; then
  echo "ok   a mutant whose test times out once and then passes survives"
else
  echo "FAIL a mutant whose test times out once and then passes survives"; echo "$out"; exit 1
fi
