---
type: regex
target: { source: file, path: verdict.md }
pattern: 'candidate[\s\S]{0,400}(sum\(xs or \[\]\)|pull request|the branch|\bPR\b)|(sum\(xs or \[\]\)|pull request.s fix|the branch)[\s\S]{0,400}candidate'
flags: i
---
