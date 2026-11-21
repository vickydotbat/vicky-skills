---
type: regex
target: { source: file, path: design.md }
pattern: '^(?![^\n]*\b(no|not|never|without|skip|doesn''t|isn''t|nor)\b)[^\n]*(confirmation (dialog|prompt|box|step|modal)|confirm (dialog|prompt|modal)|are you sure)'
flags: mi
match: not_contains
---
