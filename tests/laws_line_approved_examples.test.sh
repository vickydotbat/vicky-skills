#!/usr/bin/env bash
# approved-spec: the examples approved for "review and make-it-so report a Laws
# line". The lint's prove and reach modes run on a scratch repo. What review
# and make-it-so do with its output is proven by their eval cases.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
lint="$root/skills/shipping/engrave/scripts/law-lint.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
proof() { # proof <name> <covered file> <exit>
  printf '#!/usr/bin/env bash\n# covers src/%s\ntouch "%s/ran-%s"\nexit %s\n' "$2" "$t" "$1" "$3" > "tests/$1.test.sh"; chmod +x "tests/$1.test.sh"; }
repo() { rm -rf "$t/r" "$t"/ran-*; mkdir -p "$t/r/tests" "$t/r/src" "$t/r/evals/s/c" && cd "$t/r" && git init -q && git config user.email t@t && git config user.name t
  for f in a b c; do echo 1 > "src/$f.sh"; done
  proof pa a.sh "${1:-0}"; proof pb b.sh 0; proof pc c.sh 0
  printf -- '- Law A.\n  Proven by: tests/pa.test.sh\n- Law B.\n  Proven by: tests/pb.test.sh\n- Law C.\n  Proven by: tests/pc.test.sh\n- Law E.\n  Proven by: evals/s/c\n' > AGENTS.md
  git add -A; git commit -qm base; base=$(git rev-parse HEAD); git switch -qc b; }

repo; echo 2 > src/a.sh; echo 2 > src/b.sh; git commit -qam two
out=$("$lint" prove "$base" 2>&1); rc=$?
check "given a diff that touches code two laws cover, when review or make-it-so reports, then it gives one Laws line naming each law, the proof that ran, and its result, and it runs only the proofs the diff reaches" \
  '[ $rc = 0 ] && [ "$(grep -c "^Laws: " <<<"$out")" = 1 ] && grep -q "Law A.*tests/pa.test.sh: passed" <<<"$out" && grep -q "Law B.*tests/pb.test.sh: passed" <<<"$out" && [ -e "$t/ran-pa" ] && [ ! -e "$t/ran-pc" ]'

repo 1; echo 2 > src/a.sh; git commit -qam red
out=$("$lint" prove "$base" 2>&1); rc=$?
check "given a covered law whose proof went red, when make-it-so tries to mark the pull request ready, then it refuses, naming the law" \
  '[ $rc -ne 0 ] && grep -q "Law A.*failed" <<<"$out"'

repo; sed -i "1s/.*/- Law A, reworded./" AGENTS.md; git commit -qam own
out=$("$lint" reach "$base" 2>&1)
repo; echo "# more" >> tests/pb.test.sh; git commit -qam proof
out2=$("$lint" reach "$base" 2>&1)
repo; echo 2 > unrelated.txt; git add -A; git commit -qm none
out3=$("$lint" prove "$base" 2>&1)
repo; echo 2 > src/c.sh; git commit -qam code
out4=$("$lint" reach "$base" 2>&1)
check "given a law with a Proven by line, when a diff changes the law's own file, its proof file, or a file the proof names, then that law is reached and its proof runs, and a law reached none of those ways runs nothing" \
  'grep -q "Law A" <<<"$out" && grep -q "Law B" <<<"$out2" && ! grep -qE "Law (A|B|E)" <<<"$out4" && grep -q "Law C" <<<"$out4" && ! grep -q "Law A" <<<"$out2" && grep -q "^Laws: none touched" <<<"$out3" && [ ! -e "$t/ran-pa" ]'

repo; printf -- '\n- Law N.\n  Proven by: tests/noexec.txt\n' >> AGENTS.md; echo x > tests/noexec.txt; mkdir -p evals/s/c; echo 2 > evals/s/c/prompt; git add -A; git commit -qm e
out=$("$lint" prove "$base" 2>&1); rc=$?
check "given a reached law whose proof is an eval case folder or is not executable, when the Laws line is built, then it reports that proof as not run, never as passed, and never starts an eval" \
  'grep -q "Law E.*evals/s/c: not run" <<<"$out" && grep -q "Law N.*tests/noexec.txt: not run" <<<"$out" && ! grep -qE "(evals/s/c|noexec.txt): passed" <<<"$out"'


repo; printf -- '- Old wish.\n' >> AGENTS.md; git commit -qam old; base=$(git rev-parse HEAD)
echo 2 > src/c.sh; git commit -qam c
out=$("$lint" prove "$base" 2>&1); rc=$?
printf -- '- New wish.\n' >> AGENTS.md; git commit -qam new
out2=$("$lint" prove "$base" 2>&1); rc2=$?
check "given a reached law whose proof is red, or an unproven law the branch added, when make-it-so reaches its ready step, then it runs law-lint.sh prove first and on non-zero does not mark ready, naming the law, while an old unproven law is listed, never a refusal" \
  '[ $rc = 0 ] && [ $rc2 -ne 0 ] && grep -q "New wish" <<<"$out2" && grep -q "^backlog .*Old wish" <<<"$out" && ! grep -q "^unproven.*Old wish" <<<"$out2"'
exit $fail
