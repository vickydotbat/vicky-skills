---
name: lay-course
description: Start any effort, whatever its size, from a loose idea. It ends as a map of tickets, one build ticket, or a build this session, reached by a council or an interrogation as the user picks, and every build's spec is its approved examples. Use with a loose idea to start, or with a map to work through.
disable-model-invocation: true
---

# Lay course

> _Decisions first, then the builds. Every stop on the way is a ticket on the map._

`lay-course` is the entry point for an effort of any size. It ends in one of three **endings**: a map, one build ticket, or a build this session.

A **map** is one tracker issue for an effort too big for one session. It finds the way from a loose idea to a **destination**: decisions first, then the builds they make possible. Every ticket the effort needs is a direct child of the map: decision tickets, builds, and whatever the work turns up. The map closes when the effort ships.

The tracker is named in `docs/agents/issue-tracker.md`. Its "Wayfinding operations" section says how this repo expresses children, blocking and the frontier. If the file is missing, tell the user to run `/first-contact`.

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

- `grilling`: a session with the human, and the default. Run it with the method the user picks (Start an effort, step 1), and call `true-names` for either.
- `research`: a fact a decision waits on. A subagent calls the `away-team` skill, and the findings land as a comment on this ticket.
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

The Examples are the build's spec, and the only one: the one sentence and the Pointers are there for the person reading. "Done when" stands in for Examples only when the work has no behaviour to show. The `examples` skill writes the Examples section, and a build ticket is ready once the human approves them. Size a build to one session: a thin slice through every layer that can be shown working on its own. A refactor too wide for one green slice goes in three steps: add the new form beside the old, move callers over in batches, then delete the old form.

## Fog

Ticket a question as soon as you can state it sharply, even when it's blocked. A question you can't state sharply yet goes under **Not yet specified**, as loosely as you see it. Leave fog unsliced: one patch may become several tickets or none.

## Start an effort

The user brings a loose idea. When they bring the result of a council or an interrogation instead, start at step 4.

1. **Pick the method.** Ask once: "Council, where we argue ideas, or interrogation, where you answer questions?" The council is `council-of-elrond`, the easy mode. Interrogation is `interrogation`, the hard mode, which makes the user say what they want. Done when the user has picked one.
2. **Name the destination** with that method and `true-names`. Done when the user agrees to a destination of at most three sentences.
3. **Find the frontier** with that method, breadth-first across the whole idea. Done when every open question can be stated as a ticket or is a line of fog.
4. **Pick the ending**, and wait for the user's yes:
   - **Fog, or more than one session of work**: a map. Go on to step 5.
   - **One build for a later session**: one build ticket, written by `examples` up to its Record step. Stop there.
   - **Fits this session**: `examples`, then `do`. Stop there.

   Done when the user has taken an ending or named another.
5. **Create the map** with Destination, Constraints and Not yet specified filled in.
6. **Create the decision tickets** you can state now as children of the map. Wire blocking in a second pass, once every ticket has a key.
7. **Dispatch one research subagent per research ticket.**
8. **Stop.** Starting a map is one session's work.

## Work the map

The user brings a map, and maybe a ticket. Resolve one decision ticket per session; research tickets are the exception, and so is a council, which may settle several of the map's tickets at once.

1. **Load the map body.** Read other tickets only when the work needs them.
2. **Pick the ticket**: the user's, or the first on the frontier. Assign it to the user before any other work.
3. **Resolve it** with the skills its kind names. For a grilling ticket, ask the user for the method first (Start an effort, step 1). A council resolves every ticket its settled points answer. Done when the question has an answer the human gave or the evidence supports.
4. **Record it.** Post the answer as a comment and close the ticket. Write a decision record when the answer will outlast the map. Add its line under Decisions.
5. **Move the map forward.** Turn fog that is now sharp into tickets. When a decision makes a build specifiable, file the build ticket and run `examples` for it. Close a ticket the answer puts past the destination, with its line under Out of scope. Update or close any ticket the answer makes wrong. Done when every line of the map body is true.

Other sessions may work the same map, so read the tracker again before each write.
