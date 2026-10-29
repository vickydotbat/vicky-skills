---
name: examples
description: Turn a ticket, rule or decision into Given / When / Then examples the human approves, then into red tests named after them. Use before a ticket is built, when a decision becomes a build, when acceptance criteria are prose, or when an approved example must change.
---

# Examples

An **example** is one behaviour of the system in the language of the problem: Given a situation, When something happens, Then a result someone can see. The examples for a build are its spec. You draft them. An example is **approved** once the human has read and edited it, and only an approved example becomes a test.

## A good example

- Uses the domain's words. Class, method, hook, table and file names are design, and stay out.
- Uses concrete values: a level, an item, a number.
- Holds one behaviour. A second outcome is a second example.
- Cites its source: the rule, the ADR or the ticket line.
- Has a boundary partner: the case just outside the rule.

## Steps

1. **Read the source.** Read the ticket whole, body and comments, and the decision and rule it rests on. The repo's agent docs name the tracker (`docs/agents/issue-tracker.md` in a repo set up for Matt Pocock's skills). Done when every behaviour the ticket promises is on your list.
2. **Draft** one example per behaviour, each with its source and its boundary partner. Done when every behaviour on the list has both.
3. **Hand the drafts to the human.** Use the repo's `draft-review` skill where it has one. Otherwise write the drafts to one scratch file, open it with `$VISUAL` (or `$EDITOR`), wait for the editor to close, and read the file back. Done when you hold the human's text. Their wording wins, word for word.
4. **Record** the approved examples on the ticket, under an `Examples` heading, exactly as the human left them. Done when the ticket shows that text once.
5. **Make each example red.** Write one test per approved example, at the seam the repo's testing rules pick (the highest seam where they say nothing). Name the test after the example. Mark it `approved-spec` in the form the test framework offers: a category, tag or trait. Keep approved tests in files of their own. Run them. Done when every one fails because the behaviour is missing, not because the test is broken.
6. **Build to green** with the `tdd` skill, or test-first by the repo's own rules where that skill is absent. Done when every approved test passes.

## Changing an approved example

An approved test is the contract. When the build shows an example is wrong, take the new wording back through step 3, then update the ticket and the test together. The plugin's hook asks the human before any edit to a file marked `approved-spec`.
