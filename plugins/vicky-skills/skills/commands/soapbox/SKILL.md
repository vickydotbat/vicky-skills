---
name: soapbox
description: When the user types /soapbox or "soapbox it", pitch the agent's case for a choice in plain words, with every option's pros and cons and the agent's pick, short enough for a tired or non-technical reader. Use when the user types /soapbox.
argument-hint: "What choice should I pitch?"
disable-model-invocation: true
---

# Soapbox

> _Step up, make the case, step down. The reader decides._

A **soapbox** is a short pitch for one choice: the agent's case, each option weighed, and the agent's pick. The reader is tired, non-technical or needs extra help, so **plain words** rule: a word they would look up is replaced, or explained in a few words the first time.

## Steps

1. **Find the choice**: the decision in the user's arguments, or else the one your last reply weighed. Collect every option on the table. A soapbox lifts the output style's two-option cap: weigh each option, and invent none. One recommendation with no rival is weighed alone. Done when you can name the choice and list its options, or the one recommendation.
2. **Write the case** first, in one or two plain sentences: what you would do and why. Done when the first paragraph holds the case and at most two sentences.
3. **Weigh each option** under its own short heading in plain words, with at least one line labelled `Pro:` and one labelled `Con:`. Brief: each line is one short sentence, under about 15 words. Done when every option has a `Pro:` and a `Con:` line, and no line runs past one sentence.
4. **Strip the jargon.** Read every line as the tired reader. Replace each technical term with what it does ("a store of ready-built parts" for a binary cache). A term that must stay gets its plain meaning in brackets the first time. Done when no line holds an unexplained term a non-technical reader would look up.
5. **End on the pick**: one line naming the option you pick and why, then one line saying how to answer (a word to reply with). Keep the whole soapbox under 200 words. Done when the last two lines are the pick and the answer, and the word count is under 200.

Charter: C1, C5 ([CHARTER.md](../../CHARTER.md)).
