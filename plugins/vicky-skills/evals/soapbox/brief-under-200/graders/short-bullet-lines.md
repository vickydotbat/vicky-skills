---
type: regex
target: { source: file, path: soapbox.md }
pattern: '\n[\s>*\-\d.)]{0,6}\**(pro|con)s?\b[^\n]{100,}'
flags: i
match: not_contains
---
