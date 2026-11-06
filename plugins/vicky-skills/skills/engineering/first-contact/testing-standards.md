# Testing standards

How testing is done in this repo. Every testing skill reads this file first, and it wins over their defaults. A line left as `ask` means the agent asks the user before it acts on it.

Test surface: <where tests and live checks run, such as a test module or a staging stack>
Boot command: <the one command that starts the test surface>
Test props: <where test props and throwaway scripts go>
Dev stack: <any checkout, when the repo's dev entry point runs from any checkout; leave the line out otherwise>
Drop worktree: <repo-relative script that removes a worktree with its data, when the repo has one; leave the line out otherwise>
Never holds test props: <what ships, such as the live module or the content folder>
Commit test cruft: no
Test kinds: <unit, integration, live, visual: how to run each, and its limits>
Mutation: <the mutation tool and the command that runs it on changed lines, or by hand, against which tests>
Metrics: none <or what reports a rule's metrics against its target once the change is green and mutated, before QA; where the targets are written; and whether a person runs it. A metric is a report and never a gate>
Live checks: <how a person runs one, step by step, so people and agents read the same steps>
