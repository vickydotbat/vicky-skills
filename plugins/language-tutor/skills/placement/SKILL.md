---
name: placement
description: Set the learner's CEFR level from the CEFR global scale's can-do lines and record it in the tutor's profile. Use when the tutor skill finds no profile, or the learner types /placement or asks to find or reset their level.
---

# Placement

Run every store command as `TUTOR_LANGUAGE='${user_config.tutor_language}' TUTOR_STORE='${user_config.tutor_store}' python3 "${CLAUDE_SKILL_DIR}/../../scripts/tutor.py" <command>`, called **tutor** below. Run it from the working directory as written, never after a `cd`: the script finds its settings from there. It prints JSON. Exit 3 is a refusal: show its message in one line and stop, storing nothing.

Speak to the learner in English, and write the tasks, items and model answers in the target language. Tutor text stays in chat: never put it in a commit, ticket or pull request.

## Can-do lines

From the CEFR Companion Volume global scale (Council of Europe, 2020):

- A1: Can understand and use familiar everyday expressions and very basic phrases aimed at the satisfaction of needs of a concrete type.
- A2: Can communicate in simple and routine tasks requiring a simple and direct exchange of information on familiar and routine matters.
- B1: Can produce simple connected text on topics which are familiar or of personal interest.
- B2: Can interact with a degree of fluency and spontaneity that makes regular interaction with users of the target language quite possible without imposing strain on either party.
- C1: Can express themselves fluently and spontaneously without much obvious searching for expressions.
- C2: Can express themselves spontaneously, very fluently and precisely, differentiating finer shades of meaning.

## Steps

1. **Ask each line** from A1 upward, in English: "Can you do this?" Stop at the first no. Done when a line got a no, or C2 got a yes.
2. **Check the top yes** with one short task at that level in the target language. When the answer fails the line, step one level down. Done when the task is answered.
3. **Record the level** with `tutor profile set-level <level> --line "<each can-do line answered yes>"`, and say the level is an estimate. Done when the profile holds the level.
