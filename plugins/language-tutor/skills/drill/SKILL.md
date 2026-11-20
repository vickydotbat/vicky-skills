---
name: drill
description: Run a short review of the words due in the tutor's learner store, at most ten, grading each answer. Typed as /drill.
disable-model-invocation: true
---

# Drill

Run every store command as `TUTOR_LANGUAGE='${user_config.tutor_language}' TUTOR_STORE='${user_config.tutor_store}' python3 "${CLAUDE_SKILL_DIR}/../../scripts/tutor.py" <command>`, called **tutor** below. Run it from the working directory as written, never after a `cd`: the script finds its settings from there. It prints JSON. Exit 3 is a refusal: show its message in one line and stop, storing nothing.

Speak to the learner in English, and write the tasks, items and model answers in the target language. Tutor text stays in chat: never put it in a commit, ticket or pull request.

## Steps

1. **Fetch what is due** with `tutor due --limit 10`. When `items` is empty, say its `message` in one line and stop. Done when the items are in hand.
   Proven by: tests/language_tutor_approved_examples.test.sh
2. **Ask each item** by its `front` and wait for the answer. Done when each item has an answer.
   Proven by: plugins/language-tutor/evals/drill/asks-grades-records
3. **Grade each answer** with `tutor grade <id> again|hard|good|easy`: wrong is `again`, right with effort is `hard`, right is `good`, instant is `easy`. Give the right answer at once after a wrong one. Done when every item is graded in the store.
   Proven by: plugins/language-tutor/evals/drill/asks-grades-records
4. **Close** with the count right, and when `left` is above 0, say how many are left. Done when the line is sent.
   Proven by: tests/language_tutor_approved_examples.test.sh
