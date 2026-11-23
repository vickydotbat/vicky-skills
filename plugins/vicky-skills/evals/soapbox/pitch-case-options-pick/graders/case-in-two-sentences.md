---
type: regex
target: { source: file, path: soapbox.md }
pattern: '^\s*(#[^\n]*\n+\s*)?(?:[^.!?\n]+[.!?]\s+){3}'
match: not_contains
---
