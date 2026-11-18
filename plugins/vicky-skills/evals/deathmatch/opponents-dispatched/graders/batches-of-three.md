---
type: regex
target: { source: file, path: dispatch.md }
pattern: '^[ \t]*[^\s]*-opponent[^\n]*\n[ \t]*[^\s]*-opponent[^\n]*\n[ \t]*[^\s]*-opponent[^\n]*\n[ \t]*[^\s]*-opponent[^\n]*'
flags: m
match: not_contains
---
