#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir site
printf '<h1 style="color:teal">Hello</h1>\n' > site/index.html
printf '# Site\n\nStart the dev site with ./dev-server.sh, it serves site/ on port 8080.\n' > AGENTS.md
printf '#!/usr/bin/env bash\nexec python3 -m http.server 8080 --directory site\n' > dev-server.sh
chmod +x dev-server.sh
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
