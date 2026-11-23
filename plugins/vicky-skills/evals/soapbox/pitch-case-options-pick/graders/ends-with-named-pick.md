---
type: regex
target: { source: file, path: soapbox.md }
pattern: '(pick|recommend|go with)[^\n]*\b(A|B|C|cache|split|parallel|nightly)\b[\s\S]{0,400}$'
flags: i
---
