---
name: writing-for-agents
description: How to write text an agent reads — a skill, an AGENTS.md or CLAUDE.md, a reviewer agent, a doc behind a pointer. Use when creating or editing any of them.
---

# Writing for agents

An agent reading the same document should take the same steps every run. The levers below make that happen. Human-facing text uses `human-voice` instead.

## Pointers

A **pointer** is a line the agent always sees that names material it doesn't: a skill's description, a line in `AGENTS.md` naming a doc. The pointer's wording decides when the agent reaches the material.

- Lead with the word that should trigger it.
- Give one trigger per distinct case, and drop synonyms of a case already listed.
- Fix a pointer that misfires by sharpening its wording first. Inline the material only when that fails.

## Two costs

- **Context cost**: anything always loaded (an `AGENTS.md` line, a skill description) costs tokens and attention every turn.
- **Human cost**: what the person must remember exists. Spend it where their judgement matters.

A skill an agent should reach on its own keeps a description and pays context cost. A skill only a person starts gets `disable-model-invocation: true`, costs no context, and its description becomes a one-line summary for the person. Reference two hand-started skills both need goes in a plain file both point at.

## Layout

1. **Steps** first: what the agent does, in order.
2. **Reference** next: rules and facts it consults on demand.
3. **Disclosed reference** last: a separate file behind a pointer, for material only some cases need.

Keep a concept's definition, rules and caveats under one heading. A document too long to hold attention gets split by case or by sequence, with each part behind a pointer.

## Steps end on a check

Every step ends with **Done when**: a condition the agent can see is true. A vague one ("understood") invites stopping early. A demanding one ("every changed file has a verdict") makes the agent do the legwork. The best checks are both visible and exhaustive. When the steps after one tempt the agent to rush it, split the later steps behind a hand-off or a subagent.

## Words

- **Leading words.** A word the model already knows (_red_, _frontier_, _tracer bullet_, _seam_) anchors a whole behaviour in one token. Repeat the word, never the explanation. Coin a word only when no known one fits, and define it once.
- **Say what to do.** "Write one-line comments", not "don't write long comments". A ban names the thing it bans and makes it more likely. Keep a ban only for a hard guardrail with no positive form, and pair it with the target.
- **One home per meaning.** Restating a rule in two places doubles its weight and its upkeep. Point at the home instead.
- **Leave the environment's facts in the environment.** A doc that repeats `package.json` scripts or a directory listing goes stale. Write what no file shows: the reason, the convention, the trap.
- **Delete no-ops.** A sentence the model would follow anyway costs tokens for nothing. Test it by running the document, and delete the whole sentence. A word too weak to change behaviour gets a stronger word.
