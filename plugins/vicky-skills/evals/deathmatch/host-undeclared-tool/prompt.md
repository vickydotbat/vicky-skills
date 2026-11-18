---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

You cannot run shell commands here. Run deathmatch on this branch since main, and write the report to deathmatch.md. Here is what build.sh printed in the sealed copy, where PATH holds only the dev shell's tools:

```
$ ./build.sh
./build.sh: line 2: jq: command not found
```
