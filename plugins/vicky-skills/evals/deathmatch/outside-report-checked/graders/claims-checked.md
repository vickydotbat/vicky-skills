---
type: regex
target: { source: file, path: report.md }
pattern: 'fsum[\s\S]{0,800}(claim|hold|checked|unproven|not (yet )?(adopted|fixed|applied))|(claim|hold|checked|unproven)[\s\S]{0,800}fsum'
flags: i
---
