---
name: quiz
description: Run a low-stakes quiz from the tutor's due words and recent mistakes, recall first, with feedback on every item and the score only at the end. Use when the learner types /quiz or asks to be quizzed or tested.
---

# Quiz

Run every store command as `TUTOR_LANGUAGE='${user_config.tutor_language}' TUTOR_STORE='${user_config.tutor_store}' python3 "${CLAUDE_SKILL_DIR}/../../scripts/tutor.py" <command>`, called **tutor** below. Run it from the working directory as written, never after a `cd`: the script finds its settings from there. It prints JSON. Exit 3 is a refusal: show its message in one line and stop, storing nothing.

Speak to the learner in English, and write the tasks, items and model answers in the target language. Tutor text stays in chat: never put it in a commit, ticket or pull request.

## Steps

1. **Pick the items** with `tutor quiz pick`. When `items` is empty, say its `message` in one line and stop. Done when the items are in hand.
   Proven by: tests/language_tutor_approved_examples.test.sh
2. **Ask them in the order given**: a `recall` item asks for the `answer` from its `front`; a `cloze` item gives the learner's old `original` with the faulty part blanked; a `choice` item offers the `answer` among three plausible wrong options. Show no running score. Done when each item is asked.
   Proven by: plugins/language-tutor/evals/quiz/wrong-answer-gets-the-fix
3. **Give feedback on every item** as it is answered: a wrong answer gets the right answer and the rule at once, and a right one gets one line with the full correct form. Grade each `card` item with `tutor grade <id> again` when wrong and `good` when right. When the learner gives several answers at once, still give each item its own feedback line, with the right answer after every wrong one. Done when every item has its feedback and every card item its grade.
   Proven by: plugins/language-tutor/evals/quiz/wrong-answer-gets-the-fix
4. **Report** the score as right out of total, then name the weakest item type. Done when the report is sent.
   Proven by: plugins/language-tutor/evals/quiz/wrong-answer-gets-the-fix
