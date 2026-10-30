---
name: true-names
description: Sharpen a project's domain language and record its decisions while designing. Use when a term is fuzzy or disputed, when writing or editing GLOSSARY.md, or when recording or editing a decision record.
---

# True names

> _Speak its true name: one word, one meaning._

The **glossary** holds the project's words, one meaning each. A **decision record** holds a choice and its reason. Both are written the moment something is settled, never batched, and with `human-voice`.

`docs/agents/domain.md` says where the glossary and decision records live. Without it, assume one `GLOSSARY.md` and one `docs/adr/` at the root, and create each only when it gets its first entry.

## While designing

- **Challenge a clash.** When the user's word means something else in the glossary, say so: "The glossary says a cancellation is X. You seem to mean Y. Which is it?"
- **Sharpen a fuzzy word.** Propose one precise term for an overloaded one: "account" could be the Customer or the User.
- **Test with a scenario.** Invent an edge case that forces the boundary between two concepts into the open, written as Given / When / Then.
- **Check the code.** When the user says how something works, read whether the code agrees, and raise any difference.
- **Write the term** into the glossary as soon as it is settled, in the form of [GLOSSARY-FORMAT.md](GLOSSARY-FORMAT.md). The glossary holds words and meanings only.
- **Record a decision** when it is hard to reverse, would surprise a reader without context, and came from a real trade-off. When any of the three is missing, skip the record. Write it in the form the `ADR format:` line of `docs/agents/domain.md` names: [ADR-FORMAT.md](ADR-FORMAT.md) when the line says `true-names` or is missing, else the repo's own template. A record changes only when its decision does.

Done when every settled term is in the glossary, every decision that meets all three tests has a record, and `scripts/check-adr.sh` beside this file passes on each record you wrote in the ADR-FORMAT.md form.
