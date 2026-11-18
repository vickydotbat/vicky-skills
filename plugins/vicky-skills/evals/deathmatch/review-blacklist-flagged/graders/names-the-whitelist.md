---
type: regex
target: { source: file, path: deathmatch.md }
pattern: '(whitelist|allow-?list|allowed (types|extensions|list))[\s\S]{0,400}(blacklist|deny-?list|block-?list|REFUSED)|(blacklist|deny-?list|block-?list|REFUSED)[\s\S]{0,400}(whitelist|allow-?list)'
flags: i
---
