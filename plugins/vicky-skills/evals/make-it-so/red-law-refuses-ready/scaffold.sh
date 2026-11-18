#!/usr/bin/env bash
# A small repo with an AGENTS.md law, its test and a branch that changes code.
set -eu
git init -q -b main .
mkdir -p src tests
printf -- '- Rule A: a.sh prints a.\n  Proven by: tests/a.test.sh\n- Rule B: b.sh prints b.\n  Proven by: tests/b.test.sh\n' > AGENTS.md
echo 'echo a' > src/a.sh; echo 'echo b' > src/b.sh
printf '#!/usr/bin/env bash\n[ "$(bash src/a.sh)" = a ]\n' > tests/a.test.sh
printf '#!/usr/bin/env bash\nbash src/b.sh >/dev/null\n' > tests/b.test.sh
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
echo 'echo A' > src/a.sh; echo 'echo B' > src/b.sh
git -c user.name=eval -c user.email=eval@example.invalid commit -qam "Change a and b"
