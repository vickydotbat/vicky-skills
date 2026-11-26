#!/usr/bin/env bash
set -eu
git init -q -b main .
printf '#!/usr/bin/env bash\necho "Welcome back, ${1:-traveller}. The fire is warm."\n' > greet.sh
chmod +x greet.sh
printf 'scratch/\n' > .gitignore
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
