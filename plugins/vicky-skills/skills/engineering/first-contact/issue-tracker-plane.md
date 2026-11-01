# Tickets: Plane

Tickets are Plane work items, named `<PROJECT>-<n>`. Code, pull requests and CI stay on the forge. A repo on Plane ships its own small Plane CLI, or reaches Plane's REST API (developers.plane.so) with a key from the environment. Write the CLI's name and where its key comes from here, then fill the table with its commands.

| Action | Command |
| --- | --- |
| Read, whole (body, comments, relations) | |
| File, with project and labels | |
| Comment | |
| Replace a body, if it is still the one read | |
| Close | |
| Make a child of a star chart | |
| Add a blocker | |
| Claim | |
| Move to a named state | |
| List tickets waiting on you | |
| List a chart's frontier | |
| Attach a file | |
| Draw a star chart, if the CLI can | |

A pull request closes a work item when its body has a line such as `Closes GAME-12` and the forge-to-Plane link is set up.

## Star chart operations

- **Star chart**: a work item labelled `starchart:chart`.
- **Ticket**: a direct child of the chart through Plane's parent field, labelled `starchart:<kind>` unless it is a star. Keep tickets one level deep: a frontier query reads children only, so a grandchild sits in no frontier. A ticket has one parent, and a chart and its tickets share one project.
- **Blocking**: Write the order as a `Waits on: <KEY> (<why>)` line in the later ticket's body: `loose-ends` and the waiting list read it. Plane's `blocked_by` relation is the exception, because its public API can add one but never remove one, so removing is a person's job in the interface. Write one only when the work calls code or needs an answer the blocker produces, and end the command with `# hard: <what of the blocker's work it needs>`. The `plane-block-guard` hook refuses a block without it.
- **Frontier**: the chart's open, unassigned children with no open blocker.
- **Chart**: Plane shows a Mermaid block as code, so the drawing is a PNG. Use the table's draw command when the CLI has one. Otherwise render it with lay-course's `--png`, attach it, and show it in the body as Plane's image block, `<image-component src="<attachment id>" width="<width>px" status="uploaded"></image-component>`. A plain attachment only downloads on a click.
- **Claim**: assign the work item to yourself before any other write.

## Waiting work

A waiting ticket can't go on until the thing its `Waits on:` line names is done. It waits on you when that line names you: your decision, answer or merge. Every agent acts as your account, so the assignee can't tell your move from an agent's. `loose-ends` parks one, and `gamma-shift` works through them.

- **List waiting tickets**: the open work items whose body has a `Waits on:` line.
- **List tickets waiting on you**: the open work items whose `Waits on:` line names you: your decision, answer or merge.
- **Move a ticket to <state>**: the table's "Move to a named state" command with the state's name, such as `Todo` for not-started or `In Progress` for started.
- **List items created or changed since <time>**: `plane since <PROJECT> <time>` when the repo's CLI has it: one line per item, newest first, marked `new` or `edited`. `<time>` is a bare date or ISO 8601 with an offset. Otherwise the CLI's list command filtered on each item's created and updated times. Show at most five, then a count of the rest.
- **Park a ticket**: assign it to the user, move it to the not-started state, and add a `Waits on: <who or what>` line to the body.
- **Claim a waiting ticket**: move it to In Progress, before any other write.

## Ticket drift

Ticket drift: on

Change `on` to `off` to stop the `ticket-drift` check in this repo.
