---
type: regex
target: { source: file, path: pitch.md }
pattern: '(pro|con)s?\b[^\n]{180,}'
flags: i
match: not_contains
---
