---
type: regex
target: { source: file, path: notes.md }
pattern: 'oil bug.*(fixed by|was fixed)'
match: not_contains
flags: i
---
