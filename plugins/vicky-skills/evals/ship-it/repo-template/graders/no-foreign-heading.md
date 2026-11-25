---
type: regex
target: { source: file, path: pr-body.md }
pattern: '^## (Status|Summary|Risk|Examples)\b'
flags: m
match: not_contains
---
