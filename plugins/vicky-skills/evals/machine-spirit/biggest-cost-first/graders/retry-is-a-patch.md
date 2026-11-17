---
type: regex
target: last_message
pattern: '\b(retry|retries)\b[^\n]{0,160}(is a patch|\bhides|\bmasks|only delays|\bsymptom|\bstopgap|not (the|a) (fix|cure)|treats a flaky test as noise|nobody sees it|never lands)|\bboth changes are patches'
flags: i
---
