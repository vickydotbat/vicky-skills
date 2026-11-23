---
type: regex
target: { source: file, path: report.md }
pattern: 'limit\.sh(?![^\n]*\b(?:not|no|non-|isn.t|never)\s*\**vacuous)[^\n]*\bvacuous'
flags: i
---
