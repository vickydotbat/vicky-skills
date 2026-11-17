---
type: regex
target: { source: file, path: plan.md }
pattern: '(not|never|no|drop|instead of|rather than|without)[^\n]{0,80}(checked by hand|hand check|over-to-you)|(checked by hand|over-to-you)[^\n]{0,80}(not needed|isn.t needed|dropped|removed|only (if|when|for))'
flags: i
---
