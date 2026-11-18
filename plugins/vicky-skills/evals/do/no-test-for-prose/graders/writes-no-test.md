---
type: regex
target: trace
pattern: '"name":\s*"(Write|Edit)"[^\n]*tests/[^\n"]*\.test\.sh'
match: not_contains
---
