---
type: regex
target: { source: file, path: pr-body.md }
pattern: '## Risk[\s\S]*(dependenc|actions/checkout|outside action)'
flags: i
---
