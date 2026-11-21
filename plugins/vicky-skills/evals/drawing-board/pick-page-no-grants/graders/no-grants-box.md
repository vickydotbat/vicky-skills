---
type: regex
target: { source: file, path: design.md }
pattern: '^\s*[-*|]\s[^\n]*\d+,\d+[^\n]*\b(skills?|grants?)\b'
flags: mi
match: not_contains
---
