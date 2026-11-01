---
name: loose-ends
description: Settle every ticket an effort touched, make the pull request body true of the final diff, and engrave each snag the effort hit. Use before calling an effort done, after every push to an open pull request, and after a merge.
---

# Loose ends

> _Every ticket you touched tells the truth before you leave._

New developers pick work from the tracker and trust what a ticket says. So an effort isn't done until every ticket it touched says the truth. A **touched** ticket is one the branch name, a commit or the pull request body names, or one the work proved wrong.

## Steps

1. **List the touched tickets** from the branch name, `git log <base>..HEAD`, the pull request body, and any ticket the work proved wrong. Read the tracker again now: other sessions edit it too. Done when you have the list.
2. **Give each ticket a verdict**, one of four:
   - **Closes**: the diff does all of it. Add a `Closes <ticket>` line to the pull request body, one ticket per line.
   - **Narrowed**: the diff does part of it. Rewrite the ticket's body with `human-voice` to state only what remains.
   - **Excluded**: nothing ships for it. Remove its reference from the pull request body and commits to come.
   - **Waits**: the rest can't be done now, because it waits on the user's decision, another person, a deploy or release, or a repo out of reach. Park it as "Waiting work" in `docs/agents/issue-tracker.md` says: assign it to the user, move it to the not-started state where the tracker has one, and add a `Waits on: <who or what>` line to its body, naming a ticket, pull request, tag or person `gamma-shift` can check. Narrow the body first when part of it ships.

   The repo's `.todo` keeps work moving between sessions. Each line sits outside the springboard block and is one sentence of at most 80 characters that points at the star, chart or ticket it moves, such as `Finish the inventory 2.0 star chart (GAME-12)`. Small waiting work starts as a line. When it grows past one line it becomes a star, and the line then points at the star. A line goes when what it points at closes. Work with real impact always gets a ticket or a star. The agent writes and deletes these lines itself, and the user never has to edit `.todo`. The limit binds agents: a line the user wrote may run longer.

   A ticket blocked by a ticket its body never names as a hard dependency holds a link only a person can remove where the tracker can't (Plane): name it in the report and ask the user to remove the link.

   A comment settles nothing. Done when every ticket on the list has a verdict in the tracker or the body.
3. **Make the body true.** Read the pull request body against `git diff <base>...HEAD` sentence by sentence. Rewrite a superseded sentence in place with `human-voice`, never under an "update" heading. Done when every sentence matches the diff.
4. **Engrave the snags**, once, before you call the effort done. List each snag the effort hit: a red check, a crash, a retry, or a correction from the user. Run `engrave` on each one. Done when the report names each snag with the law built for it, or says why it needs none.
5. **After the merge**, close by hand any ticket still open that the pull request named, with a comment naming the pull request. Done when the tracker shows each one closed.

A ticket whose state lags the work moves now: one the pull request names moves to the started state while the pull request is open, a parked one to the not-started state, and the report names each move.

Repeat step 3 after every push.
