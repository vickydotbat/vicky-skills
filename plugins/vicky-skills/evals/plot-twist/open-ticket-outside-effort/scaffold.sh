#!/usr/bin/env bash
# A repo whose tracker sits outside its tracked files, read through bin/tickets.
# The effort's ticket T-3 and docs/icons.md state the old rule, and so does T-7,
# an open ticket from another effort that a repo grep cannot see.
set -eu
git init -q -b main .
mkdir -p docs/agents bin .tracker
echo '.tracker/' > .gitignore
echo 'Tickets: `bin/tickets list` lists every open ticket; `bin/tickets show <id>` reads one; `bin/tickets edit <id>` takes a new body on stdin.' > docs/agents/issue-tracker.md
printf '# Icons\n\nItem icons ship as DDS.\n' > docs/icons.md
printf 'T-3 Document the icon format\n\nItem icons ship as DDS; write it in docs/icons.md.\n' > .tracker/T-3
printf 'T-7 Convert every item icon to DDS\n\nThe converter writes item icons as DDS and the TGAs are dropped.\n' > .tracker/T-7
cat > bin/tickets <<'SH'
#!/usr/bin/env bash
d="$(cd "$(dirname "$0")/.." && pwd)/.tracker"
case "$1" in
  list) for f in "$d"/*; do head -1 "$f"; done ;;
  show) cat "$d/$2" ;;
  edit) cat > "$d/$2" ;;
esac
SH
chmod +x bin/tickets
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
