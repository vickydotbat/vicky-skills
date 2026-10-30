---
name: sentinels
description: Mutation-test changed code, with the repo's tool, a tool pulled down for the run, or by hand, and keep a run alive under a memory cap. Use when `do`, `placebo` or a review asks for a mutation pass, when a mutation run is killed, dies with no results or runs out of memory, and before reporting mutation counts or skipping a pass.
---

# Sentinels

> _Mutant detected. A sentinel that stays silent has failed._

Your tests are the **sentinels**, and a **mutant** is a small deliberate bug: a flipped comparison, a deleted call, a changed constant. A test suite that stays green against a mutant would stay green against the same bug written by a person. A mutation pass makes the mutants, runs the tests against each, and lists the **survivors**.

A pass always ends in counts or in "unrun, because <the log line>". It never ends in silence.

## Steps

1. **Pick the tool.** Use the first that applies:
   - The repo names one: its `AGENTS.md`, testing standards or a script under `scripts/`. Run the repo's wrapper as its docs say, never the raw tool.
   - The ecosystem has one: [TOOLS.md](TOOLS.md) says how to run it without a global install.
   - Neither: the manual pass below.

   Done when you can name the tool, or "manual".
2. **Narrow the target**: the production files with decision logic you changed (rules, limits, parsers), and only the changed lines where the tool can limit to them. Run one file at a time. A tool mutates and compiles everything in a run, and a list of files outgrows a desktop's memory. Done when you have a list of files, each with its line span.
3. **Run it under a cap**, one file at a time, logging to your scratch folder:
   ```bash
   systemd-run --user --scope -p MemoryMax=4G -p MemorySwapMax=0 timeout 1800 <command> > <scratch>/mutate-<file>.log 2>&1; echo "exit=$?"
   ```
   A repo wrapper sizes its own workers. Leave its defaults alone. A raw tool starts with one worker. Done when the run exits.
4. **When a run dies, read why from the system**, before you guess a cause:
   ```bash
   journalctl --user --since "-15min" --no-pager | grep -E "oom-kill|memory peak"
   journalctl -k --since "-15min" --no-pager | grep -E "Killed process|constraint="
   ```
   `exit=137`, `Failed with result 'oom-kill'` or `Killed process` means memory. A message from the tool means the tool. Name the cause only from a line you can quote.
   - **Killed for memory**: list what held it with `ps -eo rss,args --sort=-rss | head -20`. Kill leftover build servers (`dotnet build-server shutdown`), set one worker, and run again. Ask the user before raising the cap.
   - **The tool's own "out of memory"**, with no kill: the tool's coverage data outgrew its heap. Run only the tests that cover the file (the tool's test filter). A narrower set can only add survivors, so check each survivor against the whole suite before you answer it.
   - **Timeout**: narrow the span, or mutate a smaller file first.
   - **The tool**: fix the cause its message names.

   After three failed runs on one file, run the manual pass on it. Done when the file has a result, or "unrun, because <the quoted line>".
5. **Answer every survivor**: a test that kills it; the deletion of the code it lived in, when no input can tell it apart; or the repo's equivalence marker, with the reason no input tells it apart. A mutant no unit test reaches means engine-bound code or a missing test. The repo's docs say which. Done when every survivor has an answer.
6. **Report** one line per file in the pull request:
   ```markdown
   - `<file>`: killed <n>, survived <n> (each answered), no coverage <n>, by <tool or "hand">
   - `<file>`: unrun, because <the quoted log line>
   ```
   Done when every file from step 2 has its line.

## The manual pass

Use it when no tool fits the language, or a tool can't finish one file.

1. Start from a clean tree: `git status --short` lists nothing in the file.
2. List the decision points in the changed lines: comparisons and their boundaries, boolean operators, arithmetic operators, returned constants, calls whose effect matters, early returns. Done when each one is on the list, up to the ten a bug is most likely to hide in.
3. For each point: make one mutation, run the tests that reach the file, write down red or green, and put the line back. Done when `git diff <file>` is empty and every point has a result.
4. A green result is a survivor: answer it as step 5 says.
