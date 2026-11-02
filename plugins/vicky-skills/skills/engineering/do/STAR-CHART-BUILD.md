# Build a whole star chart

The frontier is every open, unblocked star on the chart.

1. Create one **integration branch** for the chart, from the default branch. It exists only for this whole-chart run with parallel implementers: their branches merge into it locally, and it reaches the default branch through one pull request. A single star built on its own never bases its pull request on an integration branch. Open its draft pull request after the first merge, closing every star. Done when the branch exists and its draft pull request is open.
2. Give each frontier ticket to its own implementer subagent, in its own worktree, on a branch from the integration branch. Each one runs `do` steps 1 to 5 with no stops, reports its drafts and Check these lines, then brings the integration branch into its own before it reports. Done when each implementer has reported.
3. Merge each finished branch into the integration branch. When that opens new frontier tickets, start their subagents. Done when no open unblocked star is left without a subagent or a merge.
4. Once every ticket is done, run `do` step 6 on the integration branch and fix its findings in one more subagent. Done when the review has no open finding on the integration branch.
5. Remove every worktree the build made, then finish with `make-it-so`. Done when `git worktree list` shows none of them and `make-it-so` reports green.
