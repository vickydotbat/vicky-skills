---
type: regex
target: last_message
pattern: '(gap|mismatch|drift)[^.]{0,40}(local|tooling|harness)|tooling[^.]{0,20}(gap|fault|failed)|failed the developer|not the developer'
flags: i
---
