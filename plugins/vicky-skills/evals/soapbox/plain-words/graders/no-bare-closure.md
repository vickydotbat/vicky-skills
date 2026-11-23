---
type: regex
target: { source: file, path: soapbox.md }
pattern: '\bclosures?\b(?![^\n]{0,4}(\(|—| - |:| is | are | means ))'
flags: i
match: not_contains
---
