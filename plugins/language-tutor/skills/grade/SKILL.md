---
name: grade
description: Grade a piece of writing, or a pasted speaking transcript, in the target language on one fixed rubric, with a CEFR level labelled estimate. Use when the learner types /grade, or asks for their writing or speaking to be marked, scored or levelled.
---

# Grade

Run every store command as `TUTOR_LANGUAGE='${user_config.tutor_language}' TUTOR_STORE='${user_config.tutor_store}' python3 "${CLAUDE_SKILL_DIR}/../../scripts/tutor.py" <command>`, called **tutor** below. Run it from the working directory as written, never after a `cd`: the script finds its settings from there. It prints JSON. Exit 3 is a refusal: show its message in one line and stop, storing nothing.

Speak to the learner in English, and write the tasks, items and model answers in the target language. Tutor text stays in chat: never put it in a commit, ticket or pull request.

## Rubric

The same five criteria for every language and for writing and speech alike, each scored 1 to 5: **Task** (does it do what was asked), **Range** (vocabulary and structures used), **Accuracy** (grammar and spelling), **Coherence** (how sentences link), **Register** (fit for the reader). Pronunciation is never graded: a transcript holds no sound.

## Steps

1. **Score each criterion** with one line of reason. Done when all five have a score.
2. **Name each error** with its type and fix. Log each with `tutor ledger add <type> -- <the learner's text> <the fix>`. Done when every error is named and logged.
3. **Give the level** as a CEFR level labelled "estimate", such as "B1 (estimate)", never a bare letter, then one next step. For a transcript, say pronunciation is not graded. Done when the level and the next step are sent.
4. **Ask** whether the estimate matches how the learner sees their level. Done when the question is asked.
5. **Keep a disagreement.** When the learner disputes a grade, run `tutor disagree -- <their text> <what they dispute>` and say it was saved to their tutor_store folder. Done when the disagreement is saved or none came.
