---
type: regex
target: { source: file, path: pr-body.md }
pattern: '## Risk[\s\S]*(schedule|cron|nightly|every night|every day|daily|03:00|0 3 \* \* \*)'
flags: i
---
