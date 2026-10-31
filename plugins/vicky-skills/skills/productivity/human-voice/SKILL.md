---
name: human-voice
description: Prose a person will read — wiki articles, docs, READMEs, runbooks, dev journal posts, announcements, release notes, in-game text, PR and ticket bodies, comments, decision records, commit messages, code comments, emails. Use when writing or editing such prose, and when text "sounds like AI". It picks the register from the audience, showcase for public showcases and plain for the rest. Text only an agent reads (CLAUDE.md, AGENTS.md, skills, prompts, handoffs) is out of scope.
---

# Human voice

> _I'm a real boy: plain words, one idea a sentence, and no tells._

Everything you write for the user is written **as the user**: their words,
their sentence patterns, their judgement about what a reader needs. A draft
can be correct, free of AI tells and still wrong. If they would not have
written it, it is not done.

The user's own writing outranks every rule in this skill. When a rule and
their writing disagree, follow their writing.

## Registers

The audience picks the register. It decides how much explaining and how much
personality the piece gets.

| Audience | Register | Voice |
| --- | --- | --- |
| The public, in a showcase: dev journal, announcement, release notes, feature page, a README's pitch | Showcase | Eccentric, enthusiastic and conversational. "I" for the writer, "we" for the team, "you" for the reader. Opinions, jokes and questions to the reader. The premise and the why are the content. One pop-culture or tabletop reference per piece at most, and only where it maps exactly. |
| Everyone else: reference docs, player guides, runbooks, PR and ticket bodies, commit messages, code comments, emails | Plain | The `dungeon-master` style's sentences. Lead with the state or the action, and end on what the reader does next. One idea per sentence, twenty words at most, active voice, simple tenses. Steps start with the verb, and "must" marks a hard rule. Paths, commands and identifiers stay exact. No history, no asides, no jokes. An explainer gives the old rule, the new one, then why. |
| Whoever asked for a "lazy reply" or "lazy comment", and only then | Lazy | Chat typing: no capitals, and the full stop at a line's end often left off. Grammar, apostrophes and spelling stay correct, code names stay exact in backticks, and the content is as exact as Plain. |

A register the user names wins over the table. A document that declares its
own voice keeps it.

## Behaviour is three lines

A rule, a spec or an acceptance criterion that says what a system does is written as one example, one line each, in any register:

```
Given a creature charmed by another
When its charmer hits it
Then the charm ends
```

Use the reader's words, never code names. A second outcome is a second example.

## Steps

1. **Pick the register** from the audience table. Ask the user only when the
   audience is unclear. If the user or the repo has writing of theirs in that
   register, read it whole. Done when you can name the register and the
   audience row that picked it.
2. **Gather the substance**: names, numbers, commands, the actual reason. The
   record is the source: the ADR, the ticket thread, the commit, the code.
   Done when every claim in your notes is one you could source.
3. **Draft** in the register's voice. Done when every fact in your notes is in the draft or cut on purpose.
4. **Cut.** Walk the draft one sentence at a time against the four cut rules
   below. Done when every sentence adds a fact or an action no other sentence
   gives, and no sentence joins two independent facts.
5. **Lint.** Write the draft to a scratch file and run
   `python3 <this skill's folder>/scripts/lint-tells.py <file>`. It prints
   `<line>: <tell>: <match>` for each tell a script can catch.
   Rewrite every hit with that tell's fix from `TELLS.md`. A hit the text is
   about, such as an emoji a doc explains, goes in a code span.
   Run the lint again until it prints nothing. Done when it exits 0 on the
   draft.
6. **Sweep.** Read [`TELLS.md`](TELLS.md) with the Read tool, the whole file,
   every time. Done when you have checked the draft against every heading in
   it and rewritten each hit.
7. **Seat a reader panel** when the draft runs over about 400 words (`wc -w`). A shorter draft skips this step.
   Pick three to five seats from its audience, the readers who will act on it. A runbook or doc gets a seat that does a dry run, following each step as written.
   Lore gets a canon keeper, who checks it against the setting's other pages. Each seat reads the draft as that reader and lists the questions it is left with.
   The `reader_panel` setting reads `${user_config.reader_panel}`, and `one agent` when it shows no value. At `one agent`, play every seat yourself, one at a time.
   At `agent per seat`, start one subagent per seat, side by side, each briefed with its seat and the draft.
   Answer each question in the draft, from the source. Keep a question the source can't answer for the user. Done when every question is answered in the draft or kept.
8. **Read it aloud as the user.** Done when every paragraph passes "would
   they have written this sentence?" against their writing.
9. **Show the draft**, with the panel's kept questions beside it. A person reads every draft a player or the public will
   see before it is committed or published. Done when the user has read it.

## Cut rules

A writer's edits to agent drafts are mostly cuts. These four rules predict
them.

**Each fact once.** After a full stop, the next sentence adds a new fact or
an action. An **echo** is a sentence that says the previous one again: the
same rule restated as its consequence, a "which means" that repeats it, an
example piled on a rule that was already clear. Delete the echo, or turn it
into the instruction the reader needs ("Make sure all your changes are pushed
before you ask for a review"). A sentence that turns a term the reader may
not know into what it means for them adds a fact, and stays.

**One fact per sentence.** A sentence has one fact, plus at most its own
reason or consequence ("The pool drains faster during roleplay, which means
roleplay levels you faster than grinding"). Two short facts about the same
event may share an "and". A **run-on** goes further: a third clause, a
qualifier hung on each of two facts, or a second fact about a different
event. Split it. A list strung through a sentence with semicolons becomes
bullets, or a pointer to where the list is written down.

**Every sentence changes what the reader does.** Ask of each one: does the
reader act differently, or understand a rule they must follow, because of it?
Overexplaining fails that test, and it comes in five kinds:

- history on a page about the present ("new as of October 2026", "Before
  it, ..."), which belongs in the commit or the ticket;
- mechanism the reader cannot act on, which belongs in a code comment or a
  runbook;
- attribution and reassurance ("that's the forge's rule, not ours", "that
  review is welcome");
- a summary of material that is written down elsewhere, where a pointer to it
  does the job;
- examples after a rule that was already clear.

Keep one reason when it motivates the reader's action, in its own short
sentence: "Re-reviews cost time." In the showcase register the premise and
the why are the content itself, so they stay.

**A player page describes what the player sees.** Write the window, the
button, the result, and what to expect when they act. The machinery behind it
(where the server keeps a thing, what it tracks out of sight) belongs in the
technical docs, unless the player acts on it. "Both sets keep their weapons
when you log out" says what a player meets; where the other set is kept does
not.

**Instructions are imperatives.** "Check it against the ticket."

## Claude's metaphors

Claude has a stock of figurative words that sound thoughtful and say nothing
a plain word would not. Readers spot them on sight. Write the literal word:

- *shape* (of the problem) → kind, form, layout
- *names*, *naming* → says, calls, is
- *lives in* → is in
- *carries*, *holds*, *hands back* → has, keeps, returns
- *doing the work*, *load-bearing* → say which part matters and why
- *lands*, *hits* → say what it changed
- *points to*, *moves*, *turns on* → shows, depends on
- *surface*, *throughline*, *physics* → find, common thread, rules
- *the trip*, *the journey* (of a change) → the steps

Idioms a person says out loud survive: "rabbit hole", "dirt cheap", "final
nail in the coffin". The test is whether the figure came from the user's
writing or from you.

## Three rules that outrank the tell list

**The user's voice wins, then the house style.** Their writing beats the tell
list. A document's own conventions (heading case, callout style, a declared
voice) beat your defaults.

**Content beats voice.** A sentence with a version number, a command or a
measured result in it is hard to mistake for filler. Most tells appear where
the writer had nothing specific to say, so the fix is usually to find the
specific thing.

**The human part is the thinking, never the surface.** Write spelling,
grammar and punctuation correctly, and invent nothing: no planted typo, no
anecdote that did not happen, no uncertainty the user does not have.
