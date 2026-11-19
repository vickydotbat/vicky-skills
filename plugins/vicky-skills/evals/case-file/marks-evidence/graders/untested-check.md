---
type: regex
target: { source: file, path: case-file.html }
pattern: '<h[1-6][^>]*>[^<]*not proven[^<]*</h[1-6]>(?:(?!<h[1-6])[\s\S]){0,1500}low graphics'
flags: i
---
