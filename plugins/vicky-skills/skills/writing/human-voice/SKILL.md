---
name: human-voice
description: Prose a person will read: docs, READMEs, runbooks, wiki and dev journal posts, announcements, release notes, in-game text, PR and ticket bodies, comments, decision records, commit messages, code comments, emails. Use when writing or editing such prose, and when text "sounds like AI". Text only an agent reads (CLAUDE.md, AGENTS.md, skills, prompts, handoffs) is out of scope.
---

# Human voice

> _I'm a real boy: plain words, one idea a sentence, and every move a person would make._

Ghostwrite: the draft uses the user's words, sentence shapes and sense of what the reader needs. A draft that is true and lint-clean but that they would not have written is unfinished.

## Registers

The audience picks the register. A register the user names wins over this table.

| Audience | Register | Voice |
| --- | --- | --- |
| The public, in a showcase: dev journal, announcement, release notes, feature page, a README's pitch | Showcase | Eccentric, enthusiastic, conversational. "I" for the writer, "we" for the team, "you" for the reader. Opinions, jokes and questions to the reader are welcome. The premise and the why are the content. One pop-culture or tabletop reference per piece at most, where it maps exactly. Contractions. |
| Everyone else: reference docs, player guides, runbooks, PR and ticket bodies, commit messages, code comments, emails | Plain | Lead with the state or the action. End on what the reader does next. One idea per sentence, twenty words at most, active voice, simple tenses. Steps start with the verb. "Must" marks a hard rule. Paths, commands and identifiers stay exact. No history, asides or jokes. An explainer gives the old rule, the new rule, then why. |
| Whoever asked for a "lazy reply" or "lazy comment", and only then | Lazy | Chat typing: no capitals, and a line's last full stop often dropped. Spelling, grammar and apostrophes stay correct. Code names stay exact in backticks. The content is as exact as Plain. Contractions. |

## Behaviour is three lines

Write a rule, spec or acceptance criterion that says what a system does as one example, one line per part, in any register:

```
Given a creature charmed by another
When its charmer hits it
Then the charm ends
```

Use the reader's words, never code names. A second outcome gets a second example.

## Steps

1. **Pick the register** from the table. Ask the user only when the audience is unclear. Read the samples for that register: the user's own samples in `${CLAUDE_PLUGIN_DATA}/voice-samples.md`, kept by `red-pen`, when that file exists, and [SAMPLES.md](SAMPLES.md) when `git config user.name` is `vickydotbat`, whose writing it holds. Read whole any writing of theirs in the repo in that register. Done when you can name the register and the table row that picked it.
2. **Gather the substance**: names, numbers, commands and the real reason, from the record (the ADR, the ticket thread, the commit, the code). Done when you could source every claim in your notes.
3. **Draft** in the register's voice, making the moves in [MOVES.md](MOVES.md). Done when every fact in your notes is in the draft or cut on purpose.
4. **Cut.** Walk the draft one sentence at a time against the cut rules. Done when every sentence adds a fact or an action no other sentence gives, and no sentence joins two independent facts.
5. **Lint.** Write the draft to a scratch file and run `python3 <this skill's folder>/scripts/lint-tells.py <file>`. It prints `<line>: <matched words>: <move to make>` per hit. Rewrite every hit by making its move. Put a hit the text is about, such as an emoji a doc explains, in a code span. Run it again until it prints nothing. Done when it exits 0 on the draft.
6. **Walk the moves.** Read the draft against each move in [MOVES.md](MOVES.md), one at a time. Done when every paragraph makes each move that applies to it.
7. **Seat a reader panel** when the draft runs over about 400 words (`wc -w`). A shorter draft skips this step.
   Pick three to five seats from its audience, the readers who will act on it. A runbook or doc gets a seat that does a dry run, following each step as written.
   Lore gets a canon keeper, who checks it against the setting's other pages. Each seat reads the draft as that reader and lists the questions it is left with.
   The `reader_panel` setting reads `${user_config.reader_panel}`, and `one agent` when it shows no value. At `one agent`, play every seat yourself, one at a time.
   At `agent per seat`, start one subagent per seat, side by side, each briefed with its seat and the draft.
   Answer each question in the draft, from the source. Keep a question the source can't answer for the user. Done when every question is answered in the draft or kept.
8. **Read it aloud as the user.** Done when every paragraph passes "would they have written this sentence?" against their writing.
9. **Show the draft**, with the panel's kept questions beside it. A person reads every draft a player or the public will see before it is committed or published. Done when the user has read it.

## Cut rules

Most of a writer's edits to an agent draft are cuts.

**Each fact once.** The sentence after a full stop adds a new fact or an action. Delete a sentence that restates the one before it (its consequence, a "which means", an example under a clear rule), or turn it into the instruction the reader needs ("Push every change before you ask for a review"). A sentence that turns an unfamiliar term into what it means for the reader adds a fact, and stays.

**One fact per sentence.** A sentence holds one fact, plus at most its own reason or consequence. Two short facts about one event may share an "and". Split a sentence with a third clause, a qualifier on each of two facts, or facts about two events. Split a sentence the reader must reread to parse. Turn a list strung through a sentence with semicolons into bullets, or a pointer to where the list lives.

**Every sentence changes what the reader does.** Ask of each sentence whether the reader acts differently, or understands a rule they must follow, because of it. Cut a sentence that fails:

- history on a page about the present ("new as of October 2026"), which belongs in the commit or the ticket;
- a claim that goes stale: STANDARDS.md's "Dated or lasting" law says what replaces it;
  Proven by: plugins/vicky-skills/evals/human-voice/dated-or-lasting
- mechanism the reader can't act on, which belongs in a code comment or a runbook;
- attribution and reassurance ("that's the forge's rule, not ours");
- a summary of material written down elsewhere, where a pointer does the job;
- a closing line about the future or the outlook, where a plan or a fact belongs.

Keep one reason when it motivates the reader's action, in its own short sentence: "Re-reviews cost time." In Showcase the premise and the why are the content, so they stay.

**A player page describes what the player sees**: the window, the button, the result, what to expect when they act. Machinery the player doesn't act on goes in the technical docs. "Both sets keep their weapons when you log out" says what a player meets. Where the server keeps the other set does not.

**Instructions are imperatives.** "Check it against the ticket."

## Three rules above the moves

**The user's voice wins, then the house style.** Their writing beats every rule here. A document's own conventions (heading case, callout style, a declared voice) beat your defaults.

**Content beats voice.** A sentence with a command, or a measured result dated in the past tense, is hard to mistake for filler. Where a sentence feels empty, find the specific thing the writer knows and say it.

**The human part is the thinking, never the surface.** Spell, punctuate and write grammar correctly, and invent nothing: no planted typo, no anecdote that did not happen, no doubt the user doesn't have.

Charter: C1 ([CHARTER.md](../../CHARTER.md)).
