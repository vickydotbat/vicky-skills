#!/usr/bin/env bash
# A small app whose tracker is filed through bin/plane, a stand-in that logs
# each title it files to tickets/filed.log. No ticket covers the question.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets src bin
cat > docs/agents/issue-tracker.md <<'MD'
# Tickets: plane

| Action | How |
| --- | --- |
| File | `bin/plane file APP "<title>" --body-file <file>` |
| Comment | `bin/plane comment APP-<n> --body-file <file>` |
| Close | `bin/plane close APP-<n>` |
| Find | `grep -i '<text>' tickets/filed.log` |
MD
cat > bin/plane <<'SH'
#!/usr/bin/env bash
# Stand-in tracker: files, comments and closes by appending to tickets/filed.log.
cd "$(dirname "$0")/.."
case "$1" in
  file) n=$(( $(wc -l < tickets/filed.log 2>/dev/null || echo 0) + 1 )); echo "APP-$n $3" >> tickets/filed.log; echo "filed APP-$n" ;;
  comment) echo "comment $2" >> tickets/filed.log; echo "commented on $2" ;;
  close) echo "close $2" >> tickets/filed.log; echo "closed $2" ;;
  *) echo "usage: plane file|comment|close" >&2; exit 2 ;;
esac
SH
chmod +x bin/plane
: > tickets/filed.log
cat > src/settings.js <<'JS'
export function save(form, store) {
  if (!form.displayName) return;
  store.put("displayName", form.displayName);
  store.put("language", form.language);
}
JS
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
