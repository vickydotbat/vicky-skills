---
type: regex
target: { source: file, path: steps.md }
pattern: '^(?![\s\S]*(^|\n)\s*(\d+\.|-)\s*\**\s*(run|start)\s+(a\s+|the\s+)?(deathmatch|review)\b)[\s\S]*\S'
flags: i
---
