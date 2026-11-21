---
type: regex
target: { source: file, path: next.md }
pattern: '(send|dispatch|resend)[^\n]*(standards-opponent|Standards opponent)[^\n]*(again|once more|third)'
flags: i
match: not_contains
---
