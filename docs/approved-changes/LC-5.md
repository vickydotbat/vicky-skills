# Drafts: warp-loop-closing LC-5

Press Done to send the text back.

## LC-5 E3, reworded: the record names the head commit
tests/pr_guard_state_approved_examples.test.sh:56
- [x] approve

```text
Given deathmatch ran on this branch this session, at the head commit
When the agent marks the pull request ready with a body that says "Skipped: review"
Then the call goes through, since the run record decides and not the body text
```

## LC-5 E7, new: a record for an older commit does not count
tests/pr_guard_state_approved_examples.test.sh:new
- [x] approve

```text
Given deathmatch ran on this branch this session, at an older commit
When the agent marks the pull request ready
Then it is refused, and the agent reads to ask the user to type /make-it-so
```
