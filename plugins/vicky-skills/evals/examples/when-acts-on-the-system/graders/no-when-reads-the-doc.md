---
type: regex
target: { source: file, path: drafts.md }
pattern: '(When|Then)[^\n]*(greet\.md|the doc\b|documentation)'
flags: i
match: not_contains
---
