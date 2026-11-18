---
type: regex
target: { source: file, path: drafts.md }
pattern: '^[\s>*-]*(When|Then)\b[^\n]*(greet\.md|the doc\b|documentation)'
flags: m
match: not_contains
---
