---
name: soapbox
description: When the user types /soapbox or "soapbox it", argue for or against each option of a choice in plain words, with its pros and cons and the agent's pick, so the user can check the agent's opinion before work goes on. Use when the user types /soapbox.
argument-hint: "What choice should I pitch?"
disable-model-invocation: true
---

# Soapbox

> _Step up, make the case, step down. The reader decides._

A **soapbox** is a short pitch for one choice: the agent's opinion, an argument for or against each option, and the agent's pick. It exists so the user can check that opinion before any work goes on. The reader is tired, non-technical or needs extra help, so **plain words** rule: a word they would look up is replaced, or explained in a few words the first time.

## Steps

1. **Find the choice**: the decision in the user's arguments, or else the one your last reply weighed. Collect every option on the table. Weigh each option, as the output style's Decisions allows a soapbox, and invent none. One recommendation with no rival is weighed alone. Done when you can name the choice and list its options, or the one recommendation.
   Proven by: plugins/vicky-skills/evals/soapbox/nothing-to-weigh
   Proven by: plugins/vicky-skills/evals/soapbox/pitch-case-options-pick
2. **Write the case** first, in one or two plain sentences: your opinion, what you would do and why. Done when the first paragraph holds the case and at most two sentences.
   Proven by: plugins/vicky-skills/evals/soapbox/pitch-case-options-pick
3. **Argue each option** under its own short heading in plain words. Its first line takes a side, "I'm for it" or "I'm against it", with the reason. Then at least one line labelled `Pro:` and one labelled `Con:`. Brief: each line is one short sentence, under about 15 words. Done when every option has its for or against line, a `Pro:` and a `Con:` line, and no line runs past one sentence.
   Proven by: plugins/vicky-skills/evals/soapbox/pitch-case-options-pick
   Proven by: plugins/vicky-skills/evals/soapbox/brief-under-200
4. **Strip the jargon.** Read every line as the tired reader. Replace each technical term with what it does ("a store of ready-built parts" for a binary cache). A term that must stay gets its plain meaning in brackets the first time. Done when no line holds an unexplained term a non-technical reader would look up.
   Proven by: plugins/vicky-skills/evals/soapbox/plain-words
5. **End on the pick**: one line naming the option you pick and why, then one line saying how to answer (a word to reply with). Keep the whole soapbox under 200 words. Done when the last two lines are the pick and the answer, and the word count is under 200.
   Proven by: plugins/vicky-skills/evals/soapbox/pitch-case-options-pick
   Proven by: plugins/vicky-skills/evals/soapbox/brief-under-200
6. **Stop.** Send the soapbox and do nothing more for the task: change no file and run no command until the user answers. Done when the turn ends on the soapbox.
   Proven by: plugins/vicky-skills/evals/soapbox/opinion-before-work

Charter: C1, C5 ([CHARTER.md](../../CHARTER.md)).
