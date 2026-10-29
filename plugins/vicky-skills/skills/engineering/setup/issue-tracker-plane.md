# Tickets: Plane

Tickets are Plane work items, named `<PROJECT>-<n>`. Code, pull requests and CI stay on the forge. A repo on Plane ships its own small Plane CLI, or reaches Plane's REST API (developers.plane.so) with a key from the environment. Write the CLI's name and where its key comes from here, then fill the table with its commands.

| Action | Command |
| --- | --- |
| Read, whole (body, comments, relations) | |
| File, with project and labels | |
| Comment | |
| Replace a body, if it is still the one read | |
| Close | |
| Make a child of a map | |
| Add a blocker | |
| Claim | |
| List a map's frontier | |

A pull request closes a work item when its body has a line such as `Closes GAME-12` and the forge-to-Plane link is set up.

## Wayfinding operations

- **Map**: a work item labelled `wayfinder:map`.
- **Ticket**: a direct child of the map through Plane's parent field, labelled `wayfinder:<kind>` for a decision ticket. Keep tickets one level deep: a frontier query reads children only, so a grandchild sits in no frontier. A ticket has one parent, and a map and its tickets share one project.
- **Blocking**: Plane's `blocked_by` relation. Write one only when the work can't start before the blocker closes; a softer order is a line in the body. Plane's public API can add a relation but not remove one, so removing is a person's job in the interface.
- **Frontier**: the map's open, unassigned children with no open blocker.
- **Claim**: assign the work item to yourself before any other write.
