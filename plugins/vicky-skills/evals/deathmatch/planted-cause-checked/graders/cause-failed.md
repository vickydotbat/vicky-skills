---
type: regex
target: { source: file, path: verdict.md }
pattern: '4\.1 msec[\s\S]{0,600}(not the cause|does not hold|doesn.t hold|fails|failed|false)|(not the cause|does not hold|doesn.t hold|fails|failed|false)[\s\S]{0,600}4\.1 msec'
flags: i
---
