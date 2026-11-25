---
type: regex
target: trace
pattern: '^(?:(?!"skill":"(?:vicky-skills:)?mission-brief")[\s\S])*?(?:"name":\s*"Write","input":\{"file_path":"[^"]*tickets/|"name":\s*"Bash","input":\{"command":"(?:[^"\\]|\\.)*>\s*tickets/)'
match: not_contains
---
