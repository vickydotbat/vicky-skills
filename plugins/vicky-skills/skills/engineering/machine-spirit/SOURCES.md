# Machine spirit: doctrine sources

The primary source behind each doctrine rule in [SKILL.md](SKILL.md), quoted, with its date or version. Read on 2026-11-17. A rule with no row here comes from this repo's own experience, recorded in the step that holds it.

| Rule | Source | Quote |
| --- | --- | --- |
| Feedback in minutes (step 6) | Martin Fowler, "Continuous Integration", revised 18 January 2024 | "For most projects, however, the XP guideline of a ten minute build is perfectly within reason." |
| Feedback in minutes (step 6) | DORA, Test automation capability, updated 17 July 2025 | "Developers should be able to get feedback from automated tests in less than ten minutes." |
| Cheap and likely-to-fail first (the clean gate) | Martin Fowler, "Deployment Pipeline", 30 May 2013 | "Early stages can find most problems yielding faster feedback" |
| Run only what the change reaches (step 3) | Software Engineering at Google, chapter 23, web edition | TAP uses "an analysis of the downstream dependency graph for every change" to "run the minimal set to be sure the change is safe." |
| Presubmit holds fast, reliable checks (gate rules) | Software Engineering at Google, chapter 23, web edition | Presubmit holds "only fast, reliable ones." "On post-submit, you can accept longer times and some instability." |
| A retry is a patch (step 7, Flaky is red) | Software Engineering at Google, chapter 11, web edition | "rerunning a test is only delaying the need to address the root cause of flakiness." |
| Flaky is red | DORA, Test automation capability, updated 17 July 2025 | "don't tolerate flaky tests" |
| Flaky is red | Software Engineering at Google, chapter 11, web edition | "as you approach 1% flakiness, the tests begin to lose value." |
| Tools come from the declared shell (step 2) | Bazel docs, remote caching | "two users with different compilers installed will wrongly share cache hits." |
| Cache keys from declared inputs (step 2) | Bazel docs, remote caching | "If your build is reproducible, the outputs from one machine can be safely reused on another machine." |
| The CI shell is the dev shell (step 5) | Nix manual, `nix develop` | "nearly identical to what Nix would use to build" |
| Tests carry their own environment (step 2, harness row) | Software Engineering at Google, chapter 11, web edition | "a test should contain all of the information necessary to set up, execute, and tear down its environment." |
| Fix a broken build at once (step 7) | Martin Fowler, "Continuous Integration", revised 18 January 2024 | "Should the integration build fail, then it needs to be fixed right away." |
| Confirm a feature exists on the server (step 1) | Gitea docs, Actions comparison with GitHub, current on 2026-11-17 | "`jobs.<job_id>.environment` is ignored." |
| A path-skipped required check blocks the merge (the clean gate) | GitHub Actions docs, workflow syntax, current on 2026-11-17 | A pull request that requires checks from a path-skipped workflow "will be blocked from merging." |

Left out until a primary source settles them: passing one build's artifact to later jobs, Gitea's handling of `concurrency` and `timeout-minutes`, and quarantine as a flaky-test policy (it conflicts with `make-it-so`'s "a test that fails only some runs is red").
