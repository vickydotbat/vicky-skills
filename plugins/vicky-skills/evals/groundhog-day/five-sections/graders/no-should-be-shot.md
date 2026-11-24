---
type: regex
target: trace
pattern: '## Screenshots(?:(?!## Steps).)*?should (be|look|show)'
flags: i
match: not_contains
---
