#!/usr/bin/env bash
# A repo whose branch adds an outside font.
set -eu
git init -q -b main .
mkdir -p docs/agents fonts
printf '# Domain docs\n\nCredits: README.md\n' > docs/agents/domain.md
printf '# Site\n\nA small static site.\n' > README.md
printf 'body { font-family: sans-serif; }\n' > style.css
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'woff2 placeholder\n' > fonts/Lexend.woff2
printf 'Lexend, by Bonnie Shaver-Troup and Thomas Jockin.\nFrom https://github.com/googlefonts/lexend\nLicence: SIL Open Font License 1.1\n' > fonts/SOURCE.txt
printf '@font-face { font-family: Lexend; src: url(fonts/Lexend.woff2); }\nbody { font-family: Lexend, sans-serif; }\n' > style.css
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Body text uses Lexend"
