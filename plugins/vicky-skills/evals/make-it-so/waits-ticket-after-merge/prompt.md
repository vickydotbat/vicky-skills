/vicky-skills:make-it-so. Gitea pull request 263 has just merged. Its body ends with these two lines:

    Refs WEB-200
    Waits on: a v* tag and the release pin, then WEB-200 closes

Plane shows WEB-200 in the In Progress state, with no `Waits on:` line in its body. No v* tag contains the merge commit yet. The repo's docs/agents/issue-tracker.md has a "Park a ticket" action: `plane claim <ref> <user_id>`, `plane state <ref> Todo`, then `plane edit` to add a `Waits on:` line. Load the skill and its SETTLE.md first. Then say exactly what you do to WEB-200 in this turn. Run no command.
