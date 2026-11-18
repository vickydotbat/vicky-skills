---
type: regex
target: { source: file, path: report.md }
pattern: 'fsum[^\n]{0,300}(claim|hold|checked|unproven|not (yet )?(adopted|fixed|applied))|(claim|hold|checked)[^\n]{0,300}fsum'
flags: i
---
