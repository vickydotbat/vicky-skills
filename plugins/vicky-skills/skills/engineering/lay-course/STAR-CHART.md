# Star charts

The reference `lay-course` and `warp` both read: the words, the chart body, the ticket forms and the drawing. The tracker's commands are in `docs/agents/issue-tracker.md`, section "Star chart operations".

## Words

| Word | What it is |
| --- | --- |
| **star chart** | One tracker issue for an effort too big for one session. Every ticket the effort needs is a direct child of it. It closes when the effort ships. |
| **mission** | What exists when the chart closes, in three sentences at most. |
| **prime directive** | The rules that bind every ticket on the chart. |
| **sensor log** | The facts the work rests on, each with its source: what the code, the engine or the spec does today. |
| **star** | A ticket that delivers behaviour, specified by its approved examples. |
| **anomaly** | A ticket that asks one question before the stars behind it can go on. A council or an interrogation answers it, picked when the user sits down to it. |
| **away team** | A fact a decision waits on, found by the `away-team` skill. |
| **probe** | A cheap, rough artifact (an outline, a stub, a sketch) for the human to react to. |
| **task** | Work that has to happen before a decision can, such as getting access to a service. |
| **nebula** | A question too loose to ticket yet. It may hold several tickets or none. |
| **black hole** | A part of the work that eats effort without end, which the course steers around. Unlike a nebula, it is plain to see. It is never a ticket: the chart names it under Black holes, with its way around, such as a timebox or a path that skips it. |
| **asteroid belt** | A question found during a build that the target can't ship without. `warp` builds around it and asks once, at the end of the course. |
| **neutral zone** | Tickets closed because they're past the mission. |
| **frontier** | The chart's open, unblocked, unassigned children. |
| **course** | The open blockers from the frontier to each target star, and the targets, in the order they must close. A target on the frontier is its own whole course. |
| **orbit** | The tickets loosely linked to a chart or a ticket, which it touches but doesn't own and doesn't wait on: "in its orbit". The tracker holds them as related links. |

## Write for a tired reader

A person reads every chart and ticket before an agent does. Write them with the `human-voice` skill, in the plain register:

- A body states the present. History goes in comments. A lasting decision goes in a decision record, and the chart keeps one line pointing at it.
- Refer to a ticket by its title, with the key inside the link.
- One line per item in every list. Rewrite a line in place when it changes, and delete it when it stops being true.

## The chart

Title: `Star Chart: <the effort>`. Label: `starchart:chart`.

```markdown
## Mission

<at most three sentences: what exists when this chart closes>

## Chart

<the drawing: see "Drawing the chart">

## Prime directive

- <what binds every ticket> (<pointer to its source>)

## Sensor log

- <a fact the work rests on> (<file, spec line or ticket it comes from>)

## Decisions

- [<ticket title>](<link>): <the answer in one line>, by <council or interrogation> (<decision record>)

## Black holes

- <the black hole>, threatening <links to the tickets it threatens>, and its way around: <a timebox, or a path that skips it>

## Nebulae

- <a question you can't phrase sharply yet>

## Neutral zone

- [<closed ticket title>](<link>): <why it is past the mission>
```

A chart with no black hole seen yet keeps the section, with the one line "None seen yet."

A ticket in the chart's orbit is a related link on the tracker, never a section.

## Tickets

Blocking is the tracker's own relation. Ticket a question as soon as you can state it sharply, even when it's blocked. A question you can't state sharply yet goes under Nebulae, as loosely as you see it. Leave a nebula unsliced.

Every ticket also carries the labels the repo's tracker docs require of any ticket. An anomaly, away team, probe or task asks one question and carries the label `starchart:<kind>`: `starchart:anomaly`, `starchart:away-team`, `starchart:probe` or `starchart:task`.

```markdown
## Question

<one question>
```

An anomaly or a probe resolves only through the human's own answer. Call `true-names` in the council or interrogation that answers an anomaly.

A star carries no `starchart:` label. Its body has these parts and nothing else:

```markdown
<one sentence: what this star makes true>

## Examples

Given <situation>
When <event>
Then <result>

## Done when

- <only for work with no behaviour to show: a refactor, infrastructure, speed>

## Pointers

- <decision record, star chart, the seam the change goes in>
```

The Examples are the star's spec, and the only one: the sentence and the Pointers are for the person reading. "Done when" stands in for Examples only when the work has no behaviour to show. The `examples` skill writes the Examples, and a star is ready once the human approves them. Size a star to one session: a thin slice through every layer that can be shown working on its own. A refactor too wide for one green slice goes in three stars: add the new form beside the old, move callers over in batches, then delete the old form.

## Drawing the chart

Every chart shows how its tickets connect, drawn from the tracker, never by hand. Redraw after every change to the chart's children or blockers.

1. **Use the tracker's draw command** when the tracker file's "Star chart operations" names one (`plane draw <chart>`). Done when the command reports the drawing.
2. **Otherwise, list the tickets** in `<scratch>/tickets.json`, one object per child, read from the tracker this turn:

   ```json
   [{"key": "KEY-1", "kind": "anomaly", "title": "<title>", "open": true,
     "assigned": false, "blocked_by": ["KEY-2"], "related": ["KEY-9"]},
    {"black_hole": "<the black hole>", "threatens": ["KEY-1"]}]
   ```

   `kind` is the `starchart:` kind, or `star`. `blocked_by` holds only open blockers, on this chart or another. `related` holds tickets the chart doesn't own. Each line under Black holes gets a `black_hole` object, with the tickets its line threatens. Done when every child of the chart and every black hole has one object.
3. **Draw it** with `python3 <this skill's folder>/scripts/draw-chart.py <scratch>/tickets.json`. During a warp, add `--course <KEY>,<KEY>` for the course and its targets. Done when it prints a Mermaid flowchart.
4. **Put it under `## Chart`.** When the tracker file says the tracker draws Mermaid, paste the printed block. When it says it can't, add `--png <scratch>/chart.png`, attach the image the way the tracker file says, and show it in the body the way it says. Done when the chart's page shows the drawing.

The drawing shows the course ahead, so closed tickets stay out of it. It marks the frontier with a thick border and the course in yellow, and draws each black hole as a dark circle beside the open tickets it threatens. A ticket with no line to another stacks in a column of its kind.

## Answer pages

A warp's course, a council's open points and a probe's questions open as a page in the user's browser, so they answer without switching windows. The page is `interactive-page`'s.

1. **Write `<scratch>/page.md`**, a planning page as [interactive-page](../../productivity/interactive-page/SKILL.md) says: a title, then each chart as an image line naming its SVG in the same folder, drawn with `draw-chart.py <scratch>/tickets.json --png <scratch>/<chart>.svg` (the output name picks the format), then the course as one ticked box per ticket in order, then one section per question with your pick marked. Done when every chart, ticket and question is in the file.
2. **Open it** with `bash <interactive-page's folder>/scripts/open-page.sh <scratch>/page.md`, run from the repo in the background. Tell the user the page is open in a message that opens with the `🚪 Waiting on you:` line. Done when the script has exited.
3. **Echo each answer in chat** before going on: read the file back, then give each question's key, the option marked `(x)`, and its note. An unticked ticket is dropped from the course. When the script exits with "no answer within", ask the same questions in chat. Done when the chat holds every answer.
