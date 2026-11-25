#!/usr/bin/env bash
# The commit message names only the checker, so the nightly schedule shows only in the workflow.
set -eu
git init -q -b main .
c() { git -c user.name=eval -c user.email=eval@example.invalid commit -q "$@"; }
mkdir -p docs tools .github/workflows
printf '# Docs\n\nSee [the guide](guide.md).\n' > docs/index.md
printf '# Guide\n\nStart here.\n' > docs/guide.md
git add -A && c -m start
git switch -q -c link-check
cat > tools/check-links.sh <<'SH'
#!/usr/bin/env bash
# Fails when a relative Markdown link in docs/ names a missing file.
set -eu
fail=0
for f in docs/*.md; do
  for l in $(grep -o "](\([^)]*\))" "$f" | sed "s/^](//; s/)$//"); do
    [ -e "docs/$l" ] || { echo "$f: $l missing"; fail=1; }
  done
done
exit $fail
SH
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
