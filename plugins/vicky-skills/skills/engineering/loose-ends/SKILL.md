---
name: loose-ends
description: Settle every ticket an effort touched and make the pull request body true of the final diff. Use before calling an effort done, after every push to an open pull request, and after a merge.
---

# Loose ends

> _Every ticket you touched tells the truth before you leave._

New developers pick work from the tracker and trust what a ticket says. So an effort isn't done until every ticket it touched says the truth. A **touched** ticket is one the branch name, a commit or the pull request body names, or one the work proved wrong.

## Steps

1. **List the touched tickets** from the branch name, `git log <base>..HEAD`, the pull request body, and any ticket the work proved wrong. Read the tracker again now: other sessions edit it too. Done when you have the list.
2. **Give each ticket a verdict**, one of three:
   - **Closes**: the diff does all of it. Add a `Closes <ticket>` line to the pull request body, one ticket per line.
   - **Narrowed**: the diff does part of it. Rewrite the ticket's body with `human-voice` to state only what remains.
   - **Excluded**: nothing ships for it. Remove its reference from the pull request body and commits to come.

   A comment settles nothing. Done when every ticket on the list has a verdict in the tracker or the body.
3. **Make the body true.** Read the pull request body against `git diff <base>...HEAD` sentence by sentence. Rewrite a superseded sentence in place with `human-voice`, never under an "update" heading. Done when every sentence matches the diff.
4. **After the merge**, close by hand any ticket still open that the pull request named, with a comment naming the pull request. Done when the tracker shows each one closed.

Repeat step 3 after every push.
