---
type: regex
target: { source: file, path: .case-files/glow/out/glow.html }
pattern: '<body[^>]*>(?:(?!<h2)[\s\S]){0,1500}\bask'
flags: i
---
