---
type: regex
target: { source: file, path: design.md }
pattern: 'purge[^\n]*(\{\s*\w*\s*\}|<\w+>|\b\d+\b|\bN\b)[^\n]*posts?'
flags: mi
---
