---
type: regex
target: { source: file, path: pr-body.md }
pattern: '^## Related|none found'
flags: mi
match: not_contains
---
