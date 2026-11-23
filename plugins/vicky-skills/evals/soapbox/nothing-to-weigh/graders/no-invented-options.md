---
type: regex
target: { source: file, path: soapbox.md }
pattern: '\boption\s*(2|two|b)\b|\balternatives?\s*:|instead,? (you|we) could|another (option|approach|way)'
flags: i
match: not_contains
---
