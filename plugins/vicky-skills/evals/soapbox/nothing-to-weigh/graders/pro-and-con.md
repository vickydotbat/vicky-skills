---
type: regex
target: { source: file, path: soapbox.md }
pattern: '^\s*[-*>]?\s*\**pros?\b[\s\S]*^\s*[-*>]?\s*\**cons?\b|^\s*[-*>]?\s*\**cons?\b[\s\S]*^\s*[-*>]?\s*\**pros?\b'
flags: im
---
