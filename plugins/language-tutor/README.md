# language-tutor

A language tutor that runs inside Claude Code. It teaches whichever language you name, and keeps your history in a folder you own, so months of reviews outlive the plugin.

```
/plugin install language-tutor@vicky-skills
```

Set two settings when you enable it: `tutor_language` (such as Italian) and `tutor_store` (a folder you own). With either blank, the tutor stores nothing and says which to set.

| Skill | What it does |
| --- | --- |
| **`tutor`** | One session: due words first, then a task at your level. Each mistake is corrected, logged by type and comes back as a review card. |
| **`drill`** | Reviews up to ten due words and schedules each with FSRS, a spaced-repetition model. |
| **`quiz`** | A low-stakes quiz on due words and recent mistakes, recall questions first. You get feedback on each item, and the score comes at the end. |
| **`grade`** | Marks writing or a speaking transcript on one fixed rubric and gives a CEFR level, always as an estimate. Pronunciation isn't graded. |
| **`placement`** | Sets your CEFR level from the can-do lines of the CEFR global scale. |

Your store holds one folder per language: `cards.json`, `reviews.jsonl`, `ledger.jsonl` (mistakes), `profile.json` and `disagreements.jsonl`.
