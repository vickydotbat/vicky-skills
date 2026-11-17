---
type: regex
target: last_message
pattern: '\b(retry|retries)\b[^\n]{0,120}\b(patch|hides|masks|delays|symptom|stopgap|not (the|a) (fix|cure))|\b(patch|hides|masks|symptom|stopgap)\b[^\n]{0,120}\b(retry|retries)\b'
flags: i
---
