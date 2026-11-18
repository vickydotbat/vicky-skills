---
type: regex
target: { source: file, path: src/stats.py }
pattern: 'if (not )?xs|len\(xs\) (==|>) 0|ZeroDivision'
flags: i
---
