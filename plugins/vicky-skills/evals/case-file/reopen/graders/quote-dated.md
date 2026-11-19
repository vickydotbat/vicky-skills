---
type: regex
target: { source: file, path: .case-files/glow/out/glow.html }
pattern: '<blockquote[^>]*>[\s\S]{0,400}lamplight[\s\S]{0,400}2026-11-18[ T]21:3\d|<blockquote[^>]*>[\s\S]{0,400}2026-11-18[ T]21:3\d[\s\S]{0,400}lamplight'
flags: i
---
