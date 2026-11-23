---
type: regex
target: { source: file, path: soapbox.md }
pattern: '\n\s*[-*][^\n]{120,}'
match: not_contains
---
