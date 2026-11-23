---
type: regex
target: { source: file, path: soapbox.md }
pattern: '^(?:(?!\bderivations?\b)[\s\S])*\bderivations?\b(?![^\n]{0,4}(\(|—| - |:|,? which means| means ))'
flags: i
match: not_contains
---
