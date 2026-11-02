#!/usr/bin/env bash
# A mutant that allocates without end dies at the runner's per-process memory
# limit, so one runaway mutant can't fill the machine's memory. The check runs
# under its own looser limit, so a runner without one fails it instead of
# freezing the machine.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
log=$(mktemp); trap 'rm -f "$log"' EXIT
out=$( (ulimit -d 1048576; HOG_LOG="$log" timeout 120 python3 - "$root/tests/mutate-hooks.py" <<'PY'
import importlib.util, os, shutil, sys
spec = importlib.util.spec_from_file_location("mutate_hooks", sys.argv[1])
mh = importlib.util.module_from_spec(spec); spec.loader.exec_module(mh)
# A lower limit than a pass uses, so the check stays small.
mh.MUTANT_MEMORY = 256 * 2**20
worker = mh.Worker()
try:
    with open(os.path.join(worker.root, "tests", "hog.test.sh"), "w") as f:
        f.write('s=x; while :; do s=$s$s; echo ${#s} > "$HOG_LOG"; done\n')
    with open(os.path.join(mh.SCRIPTS, "gamma-shift.sh")) as f:
        original = f.read()
    print("killed" if worker.run("gamma-shift.sh", original, [("hog", 60)]) else "survived")
finally:
    shutil.rmtree(worker.root)
PY
) 2>&1)
grown=$(cat "$log")
if [ "$out" = killed ] && [ "${grown:-0}" -lt $((256 * 1024 * 1024)) ]; then
  echo "ok   a memory hog dies at the limit, at $grown bytes"
else
  echo "FAIL a memory hog grew to ${grown:-?} bytes: $out"; exit 1
fi
