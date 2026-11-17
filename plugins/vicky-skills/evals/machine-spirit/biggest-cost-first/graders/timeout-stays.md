---
type: regex
target: last_message
pattern: '\btimeout\b[^\n]{0,160}(crash guard|not the (fix|bar)|\bkeep\b|\bleave\b|\blower\b|stays? at)|\b(keep|leave|lower)\b[^\n]{0,30}\btimeout|(don.t|do not|not|never|no need to) rais[^\n]{0,40}\btimeout'
flags: i
---
