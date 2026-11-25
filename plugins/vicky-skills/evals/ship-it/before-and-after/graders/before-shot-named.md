---
type: regex
target: { source: file, path: pr-body.md }
pattern: '\n[-*] [^\n]*(screenshot|picture|shot)[^\n]*\bbefore\b|\n[-*] [^\n]*\bbefore\b[^\n]*(screenshot|picture|shot)|(screenshot|picture|shot)[^\n]*(\n[^\n]*){0,3}\n\s*\|\s*before\b'
flags: i
---
