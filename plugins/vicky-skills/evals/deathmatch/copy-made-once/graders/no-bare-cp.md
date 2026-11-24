---
type: regex
target: { source: file, path: next.md }
pattern: '^[ \t`$>]*cp -a'
flags: m
match: not_contains
---
