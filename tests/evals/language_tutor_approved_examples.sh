#!/usr/bin/env bash
# approved-spec: the examples the user approved on 2026-11-20 for the Language
# tutor chart's core that only show in the agent's reply: quiz, grade, drill,
# tutor and placement. The script-level examples are in
# tests/language_tutor_approved_examples.test.sh. Run by hand: each run costs a Claude session.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
evals_plugin="$evals_root/plugins/language-tutor"
fail=0
# LT-11: Given the user answers an item, When the agent grades it, Then a wrong
# answer gets the right answer and the rule at once, and no running score is shown.
# Given the quiz ends, When the agent reports, Then it shows right out of total.
run quiz/wrong-answer-gets-the-fix lt-11 "a wrong answer gets the fix, the score comes at the end"
# LT-12: Given the user pastes a paragraph, When /grade, Then each criterion is
# scored, each error named with its fix, an "estimate", one next step, and a confirm ask
run grade/rubric-with-estimate lt-12a "a paragraph gets a rubric, an estimate and a next step"
# LT-12: Given texts in two different languages, When each is graded, Then both use the same criteria
run grade/same-criteria-two-languages lt-12b "two languages share one rubric"
# LT-12: Given a speaking transcript, When graded, Then the same rubric, and pronunciation is not graded
run grade/transcript-says-no-pronunciation lt-12c "a transcript says pronunciation is not graded"
# LT-2: Given six words are due, When /drill, Then each word is asked, graded and recorded
run drill/asks-grades-records lt-2 "the drill asks, grades and records each word"
# LT-3: Given the profile says A2 and three words are due, When /tutor, Then
# those three words first, then a task in the target language at A2
run tutor/opens-with-due-then-task lt-3a "the session opens with due words, then a task"
# LT-3: Given the user makes a mistake during the task, When corrected, Then it
# goes in the error log and becomes a review card
run tutor/mistake-goes-to-ledger lt-3b "a mistake is logged and becomes a card"
# LT-3: Given a sentence with no mistake, When the agent replies, Then no correction and nothing logged
run tutor/no-mistake-no-correction lt-3c "a correct sentence gets no correction"
# LT-4: Given the profile has no level, When /tutor, Then placement runs first
run placement/runs-before-the-session lt-4 "placement runs before the first session"
exit $fail
