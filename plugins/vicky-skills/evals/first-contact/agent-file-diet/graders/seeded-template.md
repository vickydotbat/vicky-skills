---
type: regex
target: { source: file, path: .github/pull_request_template.md }
pattern: '^## Status[\s\S]*^## How to try it[\s\S]*^## Risk'
flags: m
---
