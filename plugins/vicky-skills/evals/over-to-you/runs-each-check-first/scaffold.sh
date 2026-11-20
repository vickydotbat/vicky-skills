#!/usr/bin/env bash
set -eu
git init -q -b main .
printf '#!/usr/bin/env bash\necho "Welcome back, traveller. The fire is warm."\n' > greet.sh
chmod +x greet.sh
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
