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
| List a chart's frontier | |
| Attach a file | |

A pull request closes a work item when its body has a line such as `Closes GAME-12` and the forge-to-Plane link is set up.

## Star chart operations

- **Star chart**: a work item labelled `starchart:chart`.
- **Ticket**: a direct child of the chart through Plane's parent field, labelled `starchart:<kind>` unless it is a star. Keep tickets one level deep: a frontier query reads children only, so a grandchild sits in no frontier. A ticket has one parent, and a chart and its tickets share one project.
- **Blocking**: Plane's `blocked_by` relation. Write one only when the work can't start before the blocker closes; a softer order is a line in the body. Plane's public API can add a relation but not remove one, so removing is a person's job in the interface.
- **Frontier**: the chart's open, unassigned children with no open blocker.
- **Chart**: Plane shows a Mermaid block as code, so render it to an image and attach it with the table's attach command.
- **Claim**: assign the work item to yourself before any other write.
