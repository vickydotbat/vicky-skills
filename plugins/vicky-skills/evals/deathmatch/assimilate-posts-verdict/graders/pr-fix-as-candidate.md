---
type: regex
target: { source: file, path: verdict.md }
pattern: '(sum\(xs or \[\]\)|pull request.s fix|the PR.s fix|branch.s fix)[^\n]{0,200}candidate|candidate[^\n]{0,200}(sum\(xs or \[\]\)|pull request.s fix|branch)'
flags: i
---
