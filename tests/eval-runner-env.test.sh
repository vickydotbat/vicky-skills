#!/usr/bin/env bash
# The eval runners must give the agent a writable shell, keep each run's trace,
# and carry only grader regexes the eval harness (JavaScript) can compile.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
fail=0; no() { echo "FAIL: $*"; fail=1; }
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/run"
cat > "$work/bin/claude" <<'C'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TMPDIR/args"; echo "$TMPDIR" > "$TMPDIR/tmpdir"; exit 1
C
chmod +x "$work/bin/claude"
# Source the runner as a paid run would, from a shell whose TMPDIR is /tmp.
out=$(cd "$root" && PATH="$work/bin:$PATH" TMPDIR=/tmp XDG_RUNTIME_DIR="$work/run" EVAL_SPEND=yes EVAL_MODEL=test bash -c '
  . tests/evals/lib.sh 2>/dev/null; eval_case "$evals_plugin" none r; echo "$evals_out"; cat "$TMPDIR/args"' )
dir=$(echo "$out" | head -1)
case "$dir" in "$work/run/"?*) ;; *) no "lib.sh puts eval results under a sandbox-denied folder: $dir; set TMPDIR outside /tmp in tests/evals/lib.sh";; esac
echo "$out" | grep -qx -- --keep-temp || no "eval_case drops each run's trace: pass --keep-temp in tests/evals/lib.sh"
# Every regex grader compiles in JavaScript with its flags.
bad=$(find "$root/plugins/vicky-skills/evals" -path '*/graders/*.md' -not -path '*/results/*' -print0 | xargs -0 node -e '
  const fs=require("fs"); let bad=[];
  for (const f of process.argv.slice(1)) {
    const t=fs.readFileSync(f,"utf8"); if (!/^type: regex$/m.test(t)) continue;
    const p=t.match(/^pattern: \x27(.*)\x27$/m); const fl=(t.match(/^flags: (\w+)$/m)||[])[1]||"";
    if (!p) continue;
    try { new RegExp(p[1].replace(/\x27\x27/g,"\x27"), fl); } catch (e) { bad.push(f+": "+e.message); }
  }
  console.log(bad.join("\n"));' )
[ -z "$bad" ] || no "a grader regex JavaScript cannot compile (use flags: m, not (?m)): $bad"
[ $fail = 0 ] && echo "eval-runner-env: ok"
exit $fail
