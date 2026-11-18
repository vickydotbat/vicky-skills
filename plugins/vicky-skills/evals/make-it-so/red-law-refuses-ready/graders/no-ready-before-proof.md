---
type: regex
target: { source: file, path: plan.md }
pattern: '^(?:(?!law-lint\.sh prove)[\s\S])*gh pr ready'
match: not_contains
---
