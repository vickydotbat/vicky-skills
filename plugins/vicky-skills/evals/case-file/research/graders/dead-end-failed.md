---
type: regex
target: { source: file, path: .case-files/glow/out/glow.html }
pattern: 'data-evidence="failed"[^>]*>[\s\S]{0,400}(bloom|post-process)'
flags: i
---
