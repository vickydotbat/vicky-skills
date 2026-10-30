---
name: interrogation
description: Question the user, round by round, with questions only, until a plan, decision or idea has no open branch left and its answers are written as examples. Use when the user says "grill me" or "interrogate me", wants to work out what they want in their own words, or a decision ticket needs the human's answers. When the user wants ideas argued back at them, use `council-of-elrond` instead.
---

# Interrogation

> _You find yourself in a dark room. A single lamp. A chair._
> _You cannot leave until you answer my questions._

Open the first round with those two lines, then stay plain: the room is the mood, the questions are the work.

An **interrogation** walks a **design tree**: each decision branches into the ones that hang off it. The **frontier** is every decision whose prerequisites are already answered. Nobody leaves the room while the frontier has a question on it.

Every answer comes from the user. You ask questions and give **leads**: facts you read this session, each with its source. You give no options, no recommendation and no guess, so nothing you made up gets into the answers. A user who wants ideas proposed wants `council-of-elrond`.

1. **Ask the frontier in one round**, at most five questions, the sharpest first: a question that exposes a contradiction between two answers, an assumption the user hasn't stated, or a case their plan doesn't cover. A question that depends on another still open waits for a later round. Number each one:

   ```
   Q1. <question title>
   <the question, open, with no options offered>
   Lead: <a fact that bears on it> (<where you read it>)
   ```

   A lead is optional. Done when every question on the frontier is asked or waits on an open one, and every lead names its source.
2. **Look up facts yourself.** A question that needs a fact from the code, the docs or the tools gets a subagent, never the user. Only the questions that depend on that fact wait for it. A fact you can't read stays out of the round. Done when every lead is a fact you read.
3. **When the user asks what you'd pick**, answer "This one is yours." Then give leads and threads: a **thread** is a narrower question that helps them decide. Done when the reply holds no option and no pick.
4. **Wait for the answers**, then recompute the frontier and ask the next round. Done when every answer has its place on the tree, and every branch it opens is on the frontier.
5. **Release the user when the frontier is empty**: every branch visited, nothing assumed. Write the answers as Given / When / Then examples in the user's words, the form `examples` uses, and act only after the user confirms them. Done when the user has confirmed or edited every example.
