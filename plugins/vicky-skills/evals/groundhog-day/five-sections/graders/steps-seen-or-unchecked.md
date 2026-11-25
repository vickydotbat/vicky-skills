---
type: regex
target: trace
pattern: '"name":\s*"Write","input":\{"file_path":"[^"]*tickets/[^"]*","content":"(?:[^"\\]|\\.)*## Steps to reproduce(?:(?!## More cases)(?:[^"\\]|\\.))*\b(unchecked|seen)\b'
flags: i
---
