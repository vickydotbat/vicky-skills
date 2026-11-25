---
type: regex
target: { source: file, path: pr-body.md }
pattern: '\bdark\b[^\n]*(screenshot|picture|shot|\.png)|(screenshot|picture|shot)[^\n]*\bdark\b|\|\s*dark\b'
flags: i
---
