---
type: regex
target: { source: file, path: design.md }
pattern: '^(?![^\n]*\b(no|not|never|without|instead of)\b)[^\n]*(each|every|per) (post|item|row)[^\n]*confirm'
flags: mi
match: not_contains
---
