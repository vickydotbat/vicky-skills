# Keeping a pass fast

Each cut, the flags that make it in each tool, and its source. Docs read 2026-10-31.

## Mutate only what changed

Google mutates "only changed code during code review, rather than the entire code base", which "produces orders of magnitude fewer mutants" ([Practical Mutation Testing at Scale](https://arxiv.org/abs/2102.11378), 2021). A full pass runs on a schedule over the lines merged since the last green one.

| Tool | Flag |
| --- | --- |
| Stryker.NET | `--since:<ref>`, or `mutate` globs with spans (`File.cs{10..100}`) |
| StrykerJS | `mutate` globs with line ranges (`src/a.ts:10-20`) |
| cargo-mutants | `--in-diff <diff file>` ([in-diff](https://mutants.rs/in-diff.html)) |
| PIT | `targetClasses` narrowed to the changed classes |
| mutmut | the paths to mutate, given on the command line |

## Reuse the last run

| Tool | Flag |
| --- | --- |
| Stryker.NET | `--with-baseline:<ref>`, which can't be combined with `--since` |
| StrykerJS | `incremental: true`; `--force` reruns every mutant |
| PIT | `historyInputFile` and `historyOutputFile`, or `withHistory` ([incremental analysis](https://pitest.org/quickstart/incremental_analysis/)) |

## Run only the tests that reach the mutant

StrykerJS's default `perTest` coverage runs "only the tests that cover a specific mutant" for each mutant. Stryker.NET's `coverage-analysis` also defaults to `perTest`. Never set it to `off`, which runs every test against every mutant. Narrow further with a filter: Stryker.NET's `test-case-filter`, PIT's `targetTests`, or a test folder per project. Keep bail on, Stryker's default, so the first red test ends the mutant.

## Fewer, better mutants

Google skips "arid lines", such as logging, and limits the mutants "per line and per code review" ([State of Mutation Testing at Google](https://research.google/pubs/state-of-mutation-testing-at-google/), 2018, and the 2021 paper). Keep the tool's default mutator set: PIT's `DEFAULTS`, or Stryker.NET's `mutation-level` at `Standard`. Skip log calls (Stryker.NET's `ignore-methods`), and turn on StrykerJS's `ignoreStatic` for costly static mutants.

## Timeouts

| Tool | Default |
| --- | --- |
| Stryker.NET | baseline x `timeout-ratio` 1.5, plus `additional-timeout` 3000 ms |
| StrykerJS | `timeoutFactor` 1.5 and `timeoutMS` 5000 |
| PIT | `timeoutFactor` 1.25 and `timeoutConstant` 4000 ms |
| cargo-mutants | 5 x the baseline test time, at least 20 s |

Stryker's advice is to lower a timeout only when you are sure the timeouts are endless loops. Never raise one to make a slow pass finish.

## Workers and shards

Stryker.NET's `concurrency` defaults to half the logical cores, and PIT's `threads` to 1. cargo-mutants warns that a high `--jobs` makes a machine "thrash, run out of memory, or overheat", and suggests starting at 2 or 3. Size workers from the memory free, and inside a capped cgroup from the cap. To split a big pass across CI jobs, use cargo-mutants' `--shard k/n`.

## Fixed costs

A tool that builds every project in a run pays that build once per run. Batch the changed projects into one run, over a solution trimmed to them and their tests, instead of one run per file. For Rust, cargo-mutants' [performance notes](https://mutants.rs/performance.html) list skipping doctests (`-- --all-targets`), dropping debug symbols, a ramdisk for the temp folder, and a faster linker.
