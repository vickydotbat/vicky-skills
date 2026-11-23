---
type: regex
target: { source: file, path: soapbox.md }
pattern: '(\n#+[^\n]*(?:\n(?!#)[^\n]*)*?\n[^\n]*\b(I''?m|I am) (for|against) (it|this)\b[\s\S]*?){3}'
flags: i
---
