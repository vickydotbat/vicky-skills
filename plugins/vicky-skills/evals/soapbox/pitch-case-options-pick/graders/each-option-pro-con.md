---
type: regex
target: { source: file, path: soapbox.md }
pattern: '(\n#+[^\n]*(?:\n(?!#)[^\n]*)*?\n\s*[-*]?\s*\**pros?\b[^\n]*(?:\n(?!#)[^\n]*)*?\n\s*[-*]?\s*\**cons?\b[\s\S]*?){3}'
flags: i
---
