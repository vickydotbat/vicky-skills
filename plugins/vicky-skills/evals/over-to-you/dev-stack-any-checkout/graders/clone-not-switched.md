---
type: regex
target: last_message
pattern: '(switch|check out)[^.\n]{0,40}(clone|main)|git worktree remove|remove (the|its) worktree'
flags: i
match: not_contains
---
