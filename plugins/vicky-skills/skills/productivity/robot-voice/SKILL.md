---
name: robot-voice
description: Write text an agent runs — a skill, an AGENTS.md or CLAUDE.md line, a subagent or reviewer prompt, a doc behind a pointer — for maximum agentic ergonomics. Use when creating, editing or debugging any of them, or when an agent keeps skipping, misreading or overdoing an instruction.
---

# Robot voice

> _Resistance is futile. Every run takes the same path, and every step knows when it is done._

An agent document is a program the model runs. Good ergonomics means the agent takes the **same path every run**, reaches the material **only when it needs it**, and knows **when each step is done**, for the fewest tokens of always-loaded text. Text a person reads uses `human-voice` instead.

## Steps

1. **Pick the cheapest container that holds.** Go down this list and stop at the first that works:
   1. **A check**: a linter rule, type, test or CI job. A mechanical rule (a banned call, a file location, a name pattern) always lands here.
   2. **A hook**: a guard that fires on a tool call.
   3. **A skill**: steps or reference reached through its description.
   4. **An always-loaded line** in `AGENTS.md` or `CLAUDE.md`, ideally a pointer to one of the above.

   A hook beats more context: when a rule could be a hook or a line of text, write the hook, and let the text shrink to a pointer at it. Done when you can say why each container above yours can't hold the rule.
2. **List the branches**: each distinct case the document handles, which sends different runs down different paths. Done when every case you have seen in a real session is on the list.
3. **Write the pointer** (the description, or the `AGENTS.md` line). Lead with the trigger word. Give one trigger per branch. Done when it would fire on every branch and on nothing else.
4. **Write the steps**, each ending in **Done when** plus a condition the agent can see. Done when no step ends on a feeling ("understood", "thorough").
5. **Push reference down.** Inline what every branch needs. Move what only some branches need into a sibling file behind a pointer. Done when the steps fit on one screen.
6. **Lint it** against the checklist below. Done when every item passes.
7. **Run it.** Start a fresh agent on two different branches and read its transcript. A wrong path is fixed by sharpening the wording first, and by inlining material only when sharpening fails. Done when both runs take the path you meant.

## Lint checklist

- [ ] The pointer's first words are the trigger.
- [ ] Every step ends in "Done when" with a visible condition.
- [ ] The demanding steps are exhaustive ("every changed file has a verdict"), not countable ("list some files").
- [ ] Every instruction says what to do. A ban stays only as a guardrail with no positive form, paired with its target.
- [ ] Each meaning has one home. Other places point at it.
- [ ] A value that changes (a count, a version, a limit) is given by where to read it.
- [ ] Every command is exact and ready to paste, with placeholders in `<angle brackets>`.
- [ ] Where the output matters, a template shows its form.
- [ ] Every step says what to do when it can't finish (stop and ask, file a ticket, say "unchecked").
- [ ] A leading word is repeated, never re-explained.
- [ ] No sentence states what the model does by default. Delete each one that fails the test of changing behaviour. A line marked `<!-- kept` stays: `captains-log` saw it cause a high point.
- [ ] Nothing restates what the environment already says: `package.json`, `--help`, the directory listing.

## Reference

### Two costs

- **Context cost**: always-loaded text (a description, an `AGENTS.md` line) costs tokens and attention every turn.
- **Human cost**: what the person has to remember exists. Spend it where their judgement matters.

A skill an agent should reach on its own keeps its description and pays context cost. A skill only a person starts gets `disable-model-invocation: true` and costs no context, and its description becomes a one-line summary for the person. Reference two hand-started skills both need goes in a plain file both point at.

### Leading words

A word the model already knows (_red_, _frontier_, _seam_, _tracer bullet_, _fog of war_) anchors a whole behaviour in one token. Hunt for a passage that spells out an idea at length and collapse it into one such word. Coin a new word only when none fits, and define it once.

Every skill opens with an **epigraph**: one italic quote line under its title that bends a famous line from film, TV, games or books to state the skill's rule (`> _It's never lupus. It's whatever turns the loop red._`). The reference is the leading word, and the rule after it pins down what the reference means. Pick a line the model surely knows, whose shape matches the rule. A quote that states no rule is decoration: cut it.

A skill whose report marks a key moment opens it with one **headline** carrying one emote: `🧠 Cerebro`, `🖖 Dropped out of warp.` One per report, at its top, and never in a commit, pull request, ticket or code.

### Splitting

Split a document when it sprawls past one screen of steps, when its branches share little, or when the steps after one tempt the agent to rush it. Steps hidden behind a hand-off or a subagent stay out of sight. An inline call keeps them in view.

### Debugging an instruction the agent ignores

1. Read the transcript, and find where the path left yours.
2. Is the instruction in context at that moment? If not, the pointer didn't fire: sharpen its trigger.
3. Is it in context and outranked? Find what outranks it: a default, a louder line, an example that contradicts it.
4. Is it a ban? Rewrite it as the target behaviour.
5. Is it mechanical? Move it to a check, and let the check say no.
