# Cause questions

Deathmatch's Cause opponent and `assimilate`'s verdict ask these of a change, in this order. Each answer quotes the line, file or run it rests on.

1. **Is the principle met?** Name the principle the change serves: the rule the problem broke, from the ticket, a decision record, the repo's docs or `${CLAUDE_PLUGIN_ROOT}/skills/STANDARDS.md`. Say whether the change holds it everywhere it applies, or only where the problem showed.
2. **Cause or symptom?** A change fixes the cause when the bad state can no longer happen. It fixes a symptom when it catches the bad state after it happens: a check, a retry, a raised timeout, a guard on a flag, a step that asks a person to vouch for something. For a guard, ask whether the design could make illegal states unrepresentable instead, as STANDARDS.md's "Illegal states unrepresentable" says. A change that claims to fix nothing answers "no fix claimed".
3. **Is there a better way?** Reinvent the wheel. First work out your own solution from the problem alone, as if the branch and main as they stand did not exist: what is the simplest design that meets the need from the start? Only then compare it with the change, and say which is better and why. When the bad state can be made impossible, the better way describes that design. When the change is already that design, say so in one line.
