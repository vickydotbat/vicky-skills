---
name: sentinels
description: Mutation-test changed code inside an hour, with the repo's tool, a tool pulled down for the run, or by hand, and keep a run alive under a memory cap. Use when `do`, `placebo` or a review asks for a mutation pass, when a mutation run is killed, dies with no results or runs out of memory, and before reporting mutation counts or skipping a pass.
---

# Sentinels

> _Mutant detected. A sentinel that stays silent has failed._

Your tests are the **sentinels**, and a **mutant** is a small deliberate bug: a flipped comparison, a deleted call, a changed constant. A test suite that stays green against a mutant would stay green against the same bug written by a person. A mutation pass makes the mutants, runs the tests against each, and lists the **survivors**.

A pass always ends in counts or in "unrun, because <the log line>". It never ends in silence.

**A pass ends within an hour, in the worst case, and usually within minutes.** A slow pass means it mutates too much or runs the wrong tests. Fix the scope or the tests, never the budget. The cuts, largest first ([SPEED.md](SPEED.md) has the flags and sources):

- Mutate only the lines the branch changed. A whole-codebase pass runs on a schedule, over the lines merged since the last green one, never in a pull request's gate.
- Reuse the last run: the tool's incremental, baseline or history mode.
- Run only the tests that reach each mutant (per-test coverage, or a test filter by project), fastest first, and stop at the first red.
- Pay a fixed cost once: one tool run over every changed project, not one per file, when a run's build or startup costs more than its tests.
- Skip code no test can see: log calls and messages to a person.
- Time each mutant out at its tests' baseline time x 1.5 plus a few seconds. A higher timeout hides an endless loop as slowness.

Read the repo's `TESTING_STANDARDS.md` first: it wins over this skill's defaults.

## Tests that make a pass fast

Each mutant runs the tests that reach it, so a test's time is paid once per mutant. Hold every test a pass runs to these:

- **It finishes in about a second.** Share a fixture across the suite: one container, one server, one clone. Fake the network and the clock. A test never sleeps to wait: it polls with a cap, or waits on the process it started.
- **A stand-in exits when it's told to.** A stub editor or server `exec`s its command, so the process id the test saves is the one it kills. A child left behind holds the test's output open, and the runner waits for it on every mutant.
- **A fast check runs first.** A small test of exit codes and quiet paths across the code kills most mutants in a fraction of a second. The slow, thorough tests then run only against the mutants that survive it.
- **The runner pays its setup once.** Copy the repo, build, or start a runner once per worker, and put the original back after each mutant, never a fresh copy per mutant.
- **The first red test ends the mutant.** Keep the tool's bail on.

## Steps

1. **Pick the tool.** Use the first that applies:
   - The repo names one: its `AGENTS.md`, testing standards or a script under `scripts/`. Run the repo's wrapper as its docs say, never the raw tool.
   - The ecosystem has one: [TOOLS.md](TOOLS.md) says how to run it without a global install.
   - Neither: the manual pass below.

   Done when you can name the tool, or "manual".
2. **Narrow the target**: the changed lines of the production files with decision logic (rules, limits, parsers), with the tool's diff mode or line spans. Done when you have a list of files, each with its line span.
3. **Estimate before you run**: the mutants in the span x the time of the tests that reach them / the workers. Over 50 minutes, narrow the span or speed up the tests first: a test that sleeps, starts a container or a server per case, or touches the network is the usual cause, and a shared fixture or a fake fixes it. Done when the estimate is under 50 minutes.
4. **Run it under a cap and a timeout**, logging to your scratch folder:
   ```bash
   systemd-run --user --scope -p MemoryMax=4G -p MemorySwapMax=0 timeout 3600 <command> > <scratch>/mutate.log 2>&1; echo "exit=$?"
   ```
   Size the workers from the memory free, about half the cores at most. A repo wrapper sizes its own: leave its defaults alone. When the tool takes a budget (this plugin's `tests/mutate-hooks.sh --budget <seconds>`), set `--budget` below the outer timeout, so the tool stops itself and names what it left unrun, rather than being killed with nothing written. After fixing a survivor, rerun only the survivors first (`--survivors`), then the full pass once. Done when the run exits.
5. **When a run dies, read why from the system**, before you guess a cause:
   ```bash
   journalctl --user --since "-15min" --no-pager | grep -E "oom-kill|memory peak"
   journalctl -k --since "-15min" --no-pager | grep -E "Killed process|constraint="
   ```
   `exit=137`, `Failed with result 'oom-kill'` or `Killed process` means memory. A message from the tool means the tool. Name the cause only from a line you can quote.
   - **Killed for memory**: list what held it with `ps -eo rss,args --sort=-rss | head -20`. Kill leftover build servers (`dotnet build-server shutdown`), set one worker, and run again. Ask the user before raising the cap.
   - **The tool's own "out of memory"**, with no kill: the tool's coverage data outgrew its heap. Run only the tests that cover the file (the tool's test filter). A narrower set can only add survivors, so check each survivor against the whole suite before you answer it.
   - **Timeout**: narrow the span, or speed up the tests step 3 names.
   - **The tool**: fix the cause its message names.

   After three failed runs on one file, run the manual pass on it. Done when the file has a result, or "unrun, because <the quoted line>".
6. **Answer every survivor**: a test that kills it; the deletion of the code it lived in, when no input can tell it apart; or the repo's equivalence marker, with the reason no input tells it apart. A mutant no unit test reaches means engine-bound code or a missing test. The repo's docs say which. A survivor that shows a behaviour no approved example names goes to the user as a drafted example. Done when every survivor has an answer.
7. **Report** one line per file, with the run's time, in the pull request:
   ```markdown
   - `<file>`: killed <n>, survived <n> (each answered), no coverage <n>, by <tool or "hand">
   - `<file>`: unrun, because <the quoted log line>
   ```
   Done when every file from step 2 has its line.

## The manual pass

Use it when no tool fits the language, or a tool can't finish one file.

1. Start from a clean tree. Done when `git status --short` lists nothing in the file; otherwise stop and ask the user.
2. List the decision points in the changed lines: comparisons and their boundaries, boolean operators, arithmetic operators, returned constants, calls whose effect matters, early returns. Done when each one is on the list, up to the ten a bug is most likely to hide in.
3. For each point: make one mutation, run the tests that reach the file, write down red or green, and put the line back. Done when `git diff <file>` is empty and every point has a result.
4. A green result is a survivor: answer it as step 5 says. Done when every survivor has its answer.
