---
type: regex
target: { source: file, path: .case-files/glow/out/glow.html }
pattern: 'data-evidence="test-client-only"[^>]*>[\s\S]{0,600}test client only'
flags: i
---
