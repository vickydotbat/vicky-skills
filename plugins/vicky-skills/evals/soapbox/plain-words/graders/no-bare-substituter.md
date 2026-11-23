---
type: regex
target: { source: file, path: soapbox.md }
pattern: '^(?:(?!\bsubstituters?\b)[\s\S])*\bsubstituters?\b(?![^\n]{0,4}(\(|—| - |:|,? which means| means )\s*\w+(\s+\w+){2,})'
flags: i
match: not_contains
---
