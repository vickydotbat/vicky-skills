---
type: regex
target: { source: file, path: design.md }
pattern: '^(?![^\n]*\b(no|not|never|without|skip|skips|ignore|ignores)\b)\s*[-*|]\s[^\n]*\d+,\d+[^\n]*\b(swim|rope use|lore|heal|pick pocket)\b'
flags: mi
---
