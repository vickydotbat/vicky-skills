---
type: regex
target: { source: file, path: soapbox.md }
pattern: '\b(option|choice|alternative|approach)\s*(\d+|[a-d]|two|three)\b|\balternatives?\s*:|\balternatively\b|instead,? (you|we) could|\bor (you|we) could\b|another (option|approach|way)'
flags: i
match: not_contains
---
