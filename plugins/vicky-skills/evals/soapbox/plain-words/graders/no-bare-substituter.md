---
type: regex
target: { source: file, path: soapbox.md }
pattern: '^(?:(?!\bsubstituters?\b)[\s\S])*\bsubstituters?\b(?![^\n]{0,4}(\(|—| - |:|,? which means| means ))'
flags: i
match: not_contains
---
