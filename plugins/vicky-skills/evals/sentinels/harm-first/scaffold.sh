#!/usr/bin/env bash
# Two changed files and no laws: a banner with many easy decisions and fast tests,
# and a charge retry with one decision and a slow test.
set -eu
git init -q -b main .
mkdir -p src tests
printf 'colour() { if [ "$1" -gt 5 ]; then echo red; elif [ "$1" -gt 2 ]; then echo amber; else echo green; fi; }\n' > src/banner.sh
printf 'charge() { curl -s -X POST "$PAY/charge" -d "card=$1"; }\n' > src/charge.sh
printf '#!/usr/bin/env bash\n. src/banner.sh; [ "$(colour 9)" = red ]; [ "$(colour 3)" = amber ]; [ "$(colour 0)" = green ]\n' > tests/banner.test.sh
printf '#!/usr/bin/env bash\n# starts a fake payment server, about 40 s\n. src/charge.sh\n' > tests/charge.test.sh
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'colour() { if [ "$1" -ge 5 ]; then echo red; elif [ "$1" -ge 2 ]; then echo amber; else echo green; fi; }\n' > src/banner.sh
printf 'charge() { curl -s -X POST "$PAY/charge" -d "card=$1" || { sleep 2; curl -s -X POST "$PAY/charge" -d "card=$1"; }; }\n' > src/charge.sh
git -c user.name=eval -c user.email=eval@example.invalid commit -q -am "Retry a failed charge, and move the banner thresholds"
