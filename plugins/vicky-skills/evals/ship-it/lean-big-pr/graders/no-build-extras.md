---
type: regex
target: { source: file, path: pr-body.md }
pattern: '^## Check these|Plan check:'
flags: m
match: not_contains
---
