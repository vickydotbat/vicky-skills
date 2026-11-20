---
type: regex
target: { source: file, path: answer.md }
pattern: 'yt-dlp --cookies-from-browser (firefox|chrom)'
match: not_contains
flags: i
---
