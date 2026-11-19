---
type: regex
target: { source: file, path: verdict.md }
pattern: '4\.1 ms(ec)?[\s\S]{0,600}(not the cause|does not hold|doesn.t hold|fails|failed|false|not supported|isn.t supported|not shown)|(not the cause|does not hold|doesn.t hold|fails|failed|false|not supported|isn.t supported|not shown)[\s\S]{0,600}4\.1 ms(ec)?'
flags: i
---
