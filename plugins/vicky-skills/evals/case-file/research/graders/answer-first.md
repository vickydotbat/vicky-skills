---
type: regex
target: { source: file, path: .case-files/glow/out/glow.html }
pattern: '<h[1-6][^>]*>[^<]*answer[^<]*</h[1-6]>[\s\S]*<h[1-6][^>]*>[^<]*sources[^<]*</h[1-6]>'
flags: i
---
