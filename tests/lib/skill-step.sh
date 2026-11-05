# Sourced by the skill tests. skill_step <file> <n> prints numbered step <n>
# of a skill, from its "<n>. " line to the next numbered step or heading.
skill_step() { awk -v n="$2" '$0 ~ "^"n"\\. "{on=1; print; next} /^[0-9]+\. /{on=0} /^## /{on=0} on' "$1" 2>/dev/null; }
