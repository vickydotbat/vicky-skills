# Testing standards

How testing is done in this repo. Every testing skill reads this file first, and it wins over their defaults. A line left as `ask` means the agent asks the user before it acts on it.

Test surface: <where tests and live checks run, such as a test module or a staging stack>
Boot command: <the one command that starts the test surface>
Test props: <where test props and throwaway scripts go>
Never holds test props: <what ships, such as the live module or the content folder>
Commit test cruft: no
Test kinds: <unit, integration, live, visual: how to run each, and its limits>
Mutation: <the mutation tool and the command that runs it on changed lines, or by hand, against which tests>
Live checks: <how a person runs one, step by step, so people and agents read the same steps>
