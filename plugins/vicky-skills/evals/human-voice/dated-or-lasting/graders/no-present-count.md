---
type: regex
target: { source: file, path: proof.md }
pattern: '\b(currently|right now|at the moment)\b|\b\d+ of \d+ (windows )?(match|matches|are|pass|passes)\b'
flags: i
match: not_contains
---
