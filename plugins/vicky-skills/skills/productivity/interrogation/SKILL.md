---
name: interrogation
description: Question the user, round by round, until a plan, decision or idea has no open branch left. Use when the user wants an idea stress-tested, says "grill me" or "interrogate me", or a decision ticket needs the human's answers.
---

# Interrogation

> _You find yourself in a dark room. A single lamp. A chair._
> _You cannot leave until you answer my questions._

Open the first round with those two lines, then stay plain: the room is the mood, the questions are the work.

An **interrogation** walks a **design tree**: each decision branches into the ones that hang off it. The **frontier** is every decision whose prerequisites are already answered. Nobody leaves the room while the frontier has a question on it.

1. **Ask the frontier in one round**, at most five questions. A question that depends on another still open waits for a later round. Number each one, give it at most two options, and lead with your recommendation:

   ```
   Q1. <question title>
   <the question, with option A and option B>
   Recommended: <option> because <reason>
   ```

2. **Look up facts yourself.** A question that needs a fact from the code, the docs or the tools gets a subagent, never the user. Only the questions that depend on that fact wait for it.
3. **Wait for the answers**, then recompute the frontier and ask the next round. A decision is the user's: put it to them, even when you are confident.
4. **Release the user when the frontier is empty**: every branch visited, nothing assumed. Play the shared understanding back in a few lines, and act only after the user confirms it.
