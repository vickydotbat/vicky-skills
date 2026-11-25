---
type: regex
target: { source: file, path: pr-body.md }
pattern: 'test_unit_(0[4-9]|[1-3][0-9])'
match: not_contains
---
