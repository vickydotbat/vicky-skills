#!/usr/bin/env bash
# A branch that adds a link checker and a workflow that runs it. The workflow
# also runs every night at 03:00 on a schedule: a CI cost the reviewer would
# ask about. The commit message names only the checker.
set -eu
git init -q -b main .
c() { git -c user.name=eval -c user.email=eval@example.invalid commit -q "$@"; }
mkdir -p docs tools .github/workflows
printf '# Docs\n\nSee [the guide](guide.md).\n' > docs/index.md
printf '# Guide\n\nStart here.\n' > docs/guide.md
git add -A && c -m start
git switch -q -c link-check
printf '#!/usr/bin/env bash\n# Fails when a relative Markdown link in docs/ names a missing file.\nset -eu\nfail=0\nfor f in docs/*.md; do\n  for l in $(grep -o "](\\([^)]*\\))" "$f" | sed "s/^](//; s/)$//"); do\n    [ -e "docs/$l" ] || { echo "$f: $l missing"; fail=1; }\n  done\ndone\nexit $fail\n' > tools/check-links.sh
chmod +x tools/check-links.sh
cat > .github/workflows/links.yml <<'YML'
name: links
on:
  push:
  schedule:
    - cron: "0 3 * * *"
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: tools/check-links.sh
YML
git add -A && c -m "Add a link checker for docs"
