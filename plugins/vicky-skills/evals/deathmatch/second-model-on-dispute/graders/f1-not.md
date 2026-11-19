---
type: regex
target: { source: file, path: deathmatch.md }
pattern: '(F1|crash)[\s\S]{0,300}(not|never|no)[^\n]{0,30}second model|F1[\s\S]{0,300}second model\W{0,6}(no|not|never)\b|second model[^\n]{0,80}F1[^\n]{0,60}(doesn.t|not|never|no)\b|undisputed[^\n]{0,80}(not|never|no)[^\n]{0,30}second model'
flags: i
---
