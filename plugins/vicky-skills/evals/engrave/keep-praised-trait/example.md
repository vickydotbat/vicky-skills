# Approved example

The agent never sees this file: a prompt that named the expected line would hand the answer over.

K1, ticked 2026-11-24:
Given the agent wrote an output the user praises for one trait, such as "perfect, keep leading with the pick"
When the agent answers the praise
Then the repo gains an eval case for that trait under the skill that made the output
And the case passes on the skill as it stands
And the reply has a line that starts "📓 Kept:"
