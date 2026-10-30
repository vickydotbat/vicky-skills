---
name: examples
description: Turn a request, ticket, rule or decision into Given / When / Then examples the human approves, then into red tests named after them. Use before a ticket is built, when a decision becomes a build, when acceptance criteria are prose, or when an approved example must change.
---

# Examples

> _Show me the behaviour! Only what the human approves becomes a test._

An **example** is one behaviour of the system in the language of the problem, told from outside: Given a situation, When something happens, Then a result its **observer** can see. The observer is someone who uses the system without reading its code: a player, a modder, a server admin, a caller of a public API. The examples for a build are its spec. You draft them. An example is **approved** once the human has read and edited it, and only an approved example becomes a test.

## A good example

Three lines, one each, in the reader's words:

```
Given a creature charmed by another
When its charmer hits it
Then the charm ends
```

- Names its observer, and holds only what that observer can set up, do and see: the screen, a sound, a setting, a reply, a log line. The **observer check**: could the observer verify each line with the product and its settings alone? A line that needs a debugger, a profiler or the source is design.
- Uses the domain's words. The mechanism (a class, method, hook, table, file, pass, buffer or queue) is design.
- Uses concrete values the observer sets or sees: a level, an item, a distance, a GPU. A Then measures against a case the observer can set up (the setting off, a clear view, the previous build) in place of a tuning constant (a threshold, a tile size, a filter cutoff), which is design.
- Holds one behaviour. A second outcome is a second example.
- Cites its source: the rule, the ADR or the ticket line.
- Has a boundary partner: the case just outside the rule.

A detailed spec pulls its mechanism into the example. This one fails the observer check on every line:

```
Given a tile of stripes whose brightness step is 0.01
When the next frame draws the G-buffer
Then that tile shades once per 2x2 pixels
```

The same behaviour, as the player sees it:

```
Given a plain plaster wall filling the screen
When variable-rate shading is switched on
Then the frame draws faster than with it switched off
```

## Steps

1. **Read the source.** Read the ticket whole, body and comments, and the decision and rule it rests on; `docs/agents/issue-tracker.md` names the tracker. A request typed in chat is the whole source. Sort every promise into a **behaviour**, which passes the observer check, or **design**, which fails it. Design goes to `do` as tests at its seams. A ticket with no outside observer (a refactor, an internal library) takes the calling code as its observer and the public interface as its words. Done when every promise of the ticket is on one of the two lists.
2. **Draft** one example per behaviour, each naming its observer, with its source and its boundary partner. Done when every behaviour on the list has all three and every line passes the observer check.
3. **Hand the drafts to the human** with the `red-pen` skill, with the design list below them so the human can move an item back. Done when you hold the human's text. Their wording wins, word for word.
4. **Record** the approved examples under an `Examples` heading, exactly as the human left them: on the ticket, or in the pull request body when there is no ticket. When the build has no ticket, file it as a star, in the form `lay-course`'s [STAR-CHART.md](../lay-course/STAR-CHART.md) gives. When it waits for a later session, stop after this step. Done when that place shows the text once.
5. **Make each example red.** Write one test per approved example, at the seam the repo's testing rules pick (the highest seam where they say nothing). Name the test after the example, and mark it `approved-spec` in the form the test framework offers: a category, tag or trait. Put approved tests in files of their own, named after the feature with the suffix `ApprovedExamples` (`CharmApprovedExamples.cs`, `charm_approved_examples.py`), so the hook, a code-owner rule and CI all find them by name. Run them. Done when every one fails because the behaviour is missing, not because the test is broken.
6. **Hand over** to the `do` skill, which builds until every approved test passes. Done when `do` is running.

## Changing an approved example

An approved test is the contract. When the build shows an example is wrong, take the new wording back through step 3, then update the ticket and the test together. The plugin's hook asks the human before any edit to a file marked `approved-spec`.
