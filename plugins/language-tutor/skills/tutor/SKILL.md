---
name: tutor
description: Run one tutoring session in the language the tutor_language setting names: due review first, then a task at the learner's level, with each mistake corrected, logged and turned into a review card. Use when the learner types /tutor or asks for a lesson or tutoring session.
---

# Tutor

Run every store command as `TUTOR_LANGUAGE='${user_config.tutor_language}' TUTOR_STORE='${user_config.tutor_store}' python3 "${CLAUDE_SKILL_DIR}/../../scripts/tutor.py" <command>`, called **tutor** below. Run it from the working directory as written, never after a `cd`: the script finds its settings from there. It prints JSON. Exit 3 is a refusal: show its message in one line and stop, storing nothing.

Speak to the learner in English, and write the tasks, items and model answers in the target language. Tutor text stays in chat: never put it in a commit, ticket or pull request.

## Steps

Run steps 1 and 2 at the start of every session, whatever the learner says is due: the store, not the learner, says what is due.

1. **Check the level.** Run `tutor profile show`. When it refuses with "No profile yet", start the `placement` skill with the Skill tool and come back here when it ends. Done when the profile holds a level.
   Proven by: plugins/language-tutor/evals/placement/runs-before-the-session
2. **Review what is due.** Run `tutor due --limit 10`. Ask each item's `front` and wait for the answer. Grade it `again`, `hard`, `good` or `easy` with `tutor grade <id> <rating>`: `hard` is a pass. Done when every item shown is graded, or the list was empty.
   Proven by: plugins/language-tutor/evals/tutor/opens-with-due-then-task
3. **Set one task** at the profile's level: a short piece of writing or a reply to a prompt, written in the target language, on a topic tied to the learner's own reasons for learning. Done when the task is asked.
   Proven by: plugins/language-tutor/evals/tutor/opens-with-due-then-task
4. **Respond to the answer.** Answer what it says first, as a person would. When it has no mistake, give no correction and log nothing. For each mistake, give the fix once: name its type (agreement, tense, article, word order, spelling, word choice) and the rule in one line. Mix a prompt that lets the learner repair it with a plain correction. Then run `tutor ledger add <type> -- <the learner's text> <the fix>` and `tutor add -- <the fixed phrase> <its meaning or rule>`, so the mistake comes back as a review card. Done when every mistake is logged and carded, or none was made.
   Proven by: plugins/language-tutor/evals/tutor/mistake-goes-to-ledger
5. **Close** with one line: how many words were reviewed, the mistakes logged by type, and what the next session starts with. Done when the line is sent.
   Proven by: plugins/language-tutor/evals/tutor/no-mistake-no-correction
