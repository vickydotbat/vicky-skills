---
type: regex
target: { source: file, path: .case-files/glow/out/glow.html }
pattern: '^(?![\s\S]*\b(we|you|they|it) (will|shall)\b)(?![\s\S]*\bwe.ll\b)[\s\S]*data-case-kind'
flags: i
---
