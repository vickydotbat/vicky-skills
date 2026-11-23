---
type: regex
target: { source: file, path: soapbox.md }
pattern: '^(?:(?!\bclosures?\b)[\s\S])*\bclosures?\b(?![^\n]{0,4}(\(|—| - |:|,? which means| means ))'
flags: i
match: not_contains
---
