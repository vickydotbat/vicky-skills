---
type: regex
target: { source: file, path: design.md }
pattern: '^(?![^\n]*\b(no|not|never|without|skip|skips|ignore|ignores)\b)[^\n]*(target|hit area|click area|tap)[^\n]*24\s*(x|×|by)\s*24|^(?![^\n]*\b(no|not|never|without|skip|skips|ignore|ignores)\b)[^\n]*24\s*(x|×|by)\s*24[^\n]*(target|hit area|click area|tap)'
flags: mi
---
