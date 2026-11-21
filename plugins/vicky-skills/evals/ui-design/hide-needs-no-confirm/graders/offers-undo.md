---
type: regex
target: { source: file, path: design.md }
pattern: '^(?![^\n]*\b(no|not|never|without)\s+(an?\s+)?(undo|unhide)\b)[^\n]*\b(undo|unhide)\b'
flags: mi
---
