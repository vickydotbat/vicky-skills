---
type: regex
target: trace
pattern: '"name":\s*"Write","input":\{"file_path":"[^"]*tickets/|"name":\s*"Bash","input":\{"command":"(?:[^"\\]|\\.)*(>|tee( -a)?|cp|mv|touch)\s+(?:[^"\s\\]|\\.)*tickets/(?!9-)[^"\s/\\]+\.md'
match: not_contains
---
