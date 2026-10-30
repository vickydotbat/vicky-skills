---
name: human-voice
description: Writing that reads as a person wrote it, for every piece of human-facing prose — wiki articles, docs, READMEs, runbooks, dev journal posts, announcements, in-game text, PR and ticket bodies, commit messages, code comments, emails. Also when text "sounds like AI". Agent-facing text (CLAUDE.md, AGENTS.md, skills, prompts) is out of scope. A personal voice skill the writer keeps for themselves wins over this one.
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

The register decides how much explaining and how much personality the piece
gets. Ask the user for one when the request does not make it plain, and offer
these three as a start:

| Register | Voice |
| --- | --- |
| Clinical | The present state and what the reader does about it. Imperatives, "must" for a hard rule, no history, no asides, no jokes. Fits reference docs, runbooks, PR and ticket bodies, commit messages and code comments. |
| Conversational | "We" for the team and "you" for the reader. The old way, the new way, then why, in plain words. At most one aside per piece, and none is the default. Fits player guides, FAQs and explainers. |
| Eccentric | The writer's personality up front: "I", opinions, jokes, questions to the reader. Fits blog posts, dev journals and announcements. |

The user may name a register of their own. A document that declares its own
voice keeps it.

## Behaviour is three lines

A rule, a spec or an acceptance criterion that says what a system does is written as one example, one line each, in any register:

```
Given a creature charmed by another
When its charmer hits it
Then the charm ends
```

Use the reader's words, never code names. A second outcome is a second example.

## Steps

1. **Pick the register.** Ask the user for it, and for a piece of their own
   writing in that register if they have one. Read that writing whole. Done
   when you know the register and can say what their writing sounds like.
2. **Gather the substance**: names, numbers, commands, the actual reason. The
   record is the source: the ADR, the ticket thread, the commit, the code.
   Done when every claim in your notes is one you could source.
3. **Draft** in the register's voice.
4. **Cut.** Walk the draft one sentence at a time against the four cut rules
   below. Done when every sentence adds a fact or an action no other sentence
   gives, and no sentence joins two independent facts.
5. **Sweep.** Read [`TELLS.md`](TELLS.md) with the Read tool, the whole file,
   every time. Done when you have checked the draft against every heading in
   it and rewritten each hit.
6. **Read it aloud as the user.** Done when every paragraph passes "would
   they have written this sentence?" against their writing.
7. **Show the draft.** A person reads every draft a player or the public will
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
sentence: "Re-reviews cost time." In the conversational and eccentric
registers the premise and the why are the content itself, so they stay.

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
