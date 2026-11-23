---
type: regex
target: { source: file, path: soapbox.md }
pattern: '\boption\s*(2|two|b|a|1)\b|\balternatives?\s*:|\balternatively\b|instead,? (you|we) could|another (option|approach|way)'
flags: i
match: not_contains
---
