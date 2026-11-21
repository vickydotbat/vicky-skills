---
type: regex
target: { source: file, path: design.md }
pattern: '^(?![^\n]*\b(no|not|never|without|none|nothing)\b)[^\n]*(pre-?selected|selected by default|checked by default|defaults? to (sune|tempus|oghma))'
flags: mi
match: not_contains
---
