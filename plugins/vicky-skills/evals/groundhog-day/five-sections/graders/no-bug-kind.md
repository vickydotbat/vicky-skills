---
type: regex
target: trace
pattern: '"name":\s*"Write","input":\{"file_path":"[^"]*tickets/[^"]*","content":"(?:[^"\\]|\\.)*(kind: *bug|labels?: *\[?bug)'
flags: i
match: not_contains
---
