---
type: regex
target: { source: file, path: docs/agents/security.md }
pattern: '(^|\n)Advisories: file[ \t]*\n(.*\n)*Security levels: baseline, secrets, ci, dependencies|(^|\n)Security levels: baseline, secrets, ci, dependencies[ \t]*\n(.*\n)*Advisories: file'
---
