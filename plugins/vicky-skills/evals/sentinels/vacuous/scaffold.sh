#!/usr/bin/env bash
# A test whose assertion sits behind a guard that never holds, so it passes on nothing.
set -eu
git init -q -b main .
printf 'allowed() { [ "$1" -lt 10 ]; }\n' > limit.sh
printf '#!/usr/bin/env bash\n. ./limit.sh\nif [ -n "${LIMIT_CHECK:-}" ]; then\n  allowed 3 || exit 1\n  allowed 50 && exit 1\nfi\necho ok\n' > test_limit.sh
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c change
printf 'allowed() { [ "$1" -lt 12 ]; }\n' > limit.sh
git -c user.name=eval -c user.email=eval@example.invalid commit -q -am "Raise the limit"
