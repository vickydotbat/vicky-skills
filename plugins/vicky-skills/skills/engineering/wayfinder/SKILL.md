---
name: wayfinder
description: Plan work too big for one session as a map on the tracker. Decision tickets are resolved one at a time, then build tickets carry approved examples as their spec. Use with a loose idea to chart, or with a map to work through.
disable-model-invocation: true
---

# Wayfinder

A **map** is one tracker issue for an effort too big for one session. It finds the way from a loose idea to a **destination**: decisions first, then the builds they make possible. Every ticket the effort needs is a direct child of the map: decision tickets, builds, and whatever the work turns up. The map closes when the effort ships.

The tracker is named in `docs/agents/issue-tracker.md`. Its "Wayfinding operations" section says how this repo expresses children, blocking and the frontier. If the file is missing, tell the user to run `/setup`.

## Write for a tired reader

A person reads every map and ticket before an agent does. Write them with the `human-voice` skill, in the clinical register:

- A body states the present. History goes in comments. A lasting decision goes in a decision record, and the map keeps one line pointing at it.
- Refer to a ticket by its title, with the key inside the link.
- One line per item in every list. Rewrite a line in place when it changes, and delete it when it stops being true.

## The map body

```markdown
## Destination

<at most three sentences: what exists when this map closes>

## Constraints

- <what binds every ticket> (<pointer to its source>)

## Decisions

- [<ticket title>](<link>): <the answer in one line> (<decision record>)

## Not yet specified

- <a question you can't phrase sharply yet>

## Out of scope

- [<closed ticket title>](<link>): <why it is past the destination>
```

## Tickets

Blocking is the tracker's own relation. The **frontier** is the map's open, unblocked, unassigned children.

A **decision ticket** asks one question and carries a `wayfinder:<kind>` label:

- `grilling`: a conversation with the human, and the default. Call the `grilling` and `domain-modeling` skills.
- `research`: a fact a decision waits on. A subagent calls the `research` skill, and the findings land as a comment on this ticket.
- `prototype`: a cheap, rough artifact (an outline, a stub, a sketch) for the human to react to.
- `task`: work that has to happen before a decision can, such as getting access to a service.

```markdown
## Question

<one question>
```

A grilling or prototype ticket resolves only through the human's own answer.

A **build ticket** delivers behaviour and carries no `wayfinder` label. Its body has these parts and nothing else:

```markdown
<one sentence: what this build makes true>

## Examples

Given <situation>
When <event>
Then <result>

## Done when

- <only for work with no behaviour to show: a refactor, infrastructure, speed>

## Pointers

- <decision record, map, the seam the change goes in>
```

The `examples` skill writes the Examples section, and a build ticket is ready once the human approves them. Size a build to one session: a thin slice through every layer that can be shown working on its own. A refactor too wide for one green slice goes in three steps: add the new form beside the old, move callers over in batches, then delete the old form.

## Fog

Ticket a question as soon as you can state it sharply, even when it's blocked. A question you can't state sharply yet goes under **Not yet specified**, as loosely as you see it. Leave fog unsliced: one patch may become several tickets or none.

## Chart a map

The user brings a loose idea.

1. **Name the destination** with the `grilling` and `domain-modeling` skills. Done when the user agrees to a destination of at most three sentences.
2. **Find the frontier.** Grill breadth-first across the whole idea. When no fog shows and the work fits one session, stop: the work needs no map, so offer `examples`, then `implement`. Done when every open question is a ticket or a line of fog.
3. **Create the map** with Destination, Constraints and Not yet specified filled in.
4. **Create the decision tickets** you can state now as children of the map. Wire blocking in a second pass, once every ticket has a key.
5. **Dispatch one research subagent per research ticket.**
6. **Stop.** Charting is one session's work.

## Work the map

The user brings a map, and maybe a ticket. Resolve one decision ticket per session; research tickets are the exception.

1. **Load the map body.** Read other tickets only when the work needs them.
2. **Pick the ticket**: the user's, or the first on the frontier. Assign it to the user before any other work.
3. **Resolve it** with the skills its kind names. Done when the question has an answer the human gave or the evidence supports.
4. **Record it.** Post the answer as a comment and close the ticket. Write a decision record when the answer will outlast the map. Add its line under Decisions.
5. **Move the map forward.** Turn fog that is now sharp into tickets. When a decision makes a build specifiable, file the build ticket and run `examples` for it. Close a ticket the answer puts past the destination, with its line under Out of scope. Update or close any ticket the answer makes wrong. Done when every line of the map body is true.

Other sessions may work the same map, so read the tracker again before each write.
