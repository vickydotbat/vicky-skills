#!/usr/bin/env bash
set -eu
git init -q -b main .
# shellcheck disable=SC2016 # greet.sh expands $1 when it runs, not here
printf '#!/usr/bin/env bash\necho "Welcome back, ${1:-traveller}. The fire is warm."\n' > greet.sh
chmod +x greet.sh
printf 'scratch/\n' > .gitignore
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
