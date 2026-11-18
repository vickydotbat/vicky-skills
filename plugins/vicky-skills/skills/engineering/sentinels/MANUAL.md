# The manual pass

For [SKILL.md](SKILL.md): use it when no tool fits the language, or a tool can't finish one file.

1. Start from a clean tree. Done when `git status --short` lists nothing in the file; otherwise stop and ask the user.
2. List the decision points in the changed lines: comparisons and their boundaries, boolean operators, arithmetic operators, returned constants, calls whose effect matters, early returns. Done when each one is on the list, up to the ten a bug is most likely to hide in.
3. For each point: make one mutation, run the tests that reach the file, write down red or green, and put the line back. Done when `git diff <file>` is empty and every point has a result.
4. A green result is a survivor: answer it as SKILL.md step 6 says. Done when every survivor has its answer.
