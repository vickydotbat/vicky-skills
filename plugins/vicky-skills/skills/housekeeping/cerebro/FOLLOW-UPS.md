# Reading follow-ups

A **follow-up** is a user message that adds to work the agent had just reported done: "also...", "btw...", "what about...", "do we...", a risk the report didn't raise, or a reversal of what the report shipped. Each one marks something the agent could have proposed and didn't. `captains-log` reads them backwards, for what to fix in the setup. `cerebro` reads them forwards, for what the user will ask next.

1. List each follow-up in the session, with the report it came after.
2. Write the **need** behind each in one line, as a behaviour the user wants from every agent ("every check that runs on a user's repo can be switched off").
3. Group follow-ups by need. A need seen twice is a **trend**.

A trend is the strongest signal of the next ask: the user will raise it again on the next piece of work.
