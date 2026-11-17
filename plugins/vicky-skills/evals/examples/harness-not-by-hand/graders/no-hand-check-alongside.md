---
type: regex
target: { source: file, path: plan.md }
pattern: '\b(not|never|no longer|isn.t|doesn.t|won.t|nothing)\b[^.\n]{0,30}\b(over-to-you|the list)\b|\bonly\b[^.\n]{0,40}\b(if|when) no harness\b'
flags: i
---
