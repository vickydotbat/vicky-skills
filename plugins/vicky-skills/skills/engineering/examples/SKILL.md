---
name: examples
description: Turn a request, ticket, rule or decision into Given / When / Then examples the human approves, then into red tests named after them. Use before a ticket is built, when a decision becomes a build, when acceptance criteria are prose, or when an approved example must change.
---

# Examples

> _Show me the behaviour! Only what the human approves becomes the spec._

An **example** is one behaviour of the system in the language of the problem, told from outside: Given a situation, When something happens, Then a result its **observer** can see. The observer is someone who uses the system without reading its code: a player, a modder, a server admin, a caller of a public API. **The examples are the spec.** A ticket's prose is for the human, and it only feeds your drafts. Once examples are approved, the build is example, red test, green, then mutation proving the test can go red again, and no prose line proves or decides anything. A prose ask that no approved example covers is a **missing example**: draft it and take it back through step 3. You draft them. An example is **approved** once the human has read and edited it, and only an approved example becomes an `approved-spec` test.

**Approval is for intent. Testing is for everything.** The human approves what they ask for or design: a new behaviour, a changed rule, text or a look they see. Everything else is tested without asking, every time: a fix that restores a rule they stated or an example they approved, a regression, an edge case, a limit, a seam the work turns up. Write it red, make it green, and list it in the report under **Tested unasked**. Finding something new to test is always fine. A behaviour change that lands with no test that went red first is the only failure.

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
- In a layout or size example, the Then states a relation (one size, one row, the rows end together) and never the sketch's numbers. A number changes in the sketch only, never in an example.
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

1. **Read the source.** Read the ticket whole, body and comments, and the decision and rule it rests on; `docs/agents/issue-tracker.md` names the tracker. A star's chart binds it: read the chart whole too, body and comments, and treat its Prime directive and Sensor log as premises. A request typed in chat is the whole source. Sort every promise into a **behaviour**, which passes the observer check, or **design**, which fails it. Design gets no test of its own. A ticket with no outside observer (a refactor, an internal library) takes the calling code as its observer and the public interface as its words. Then sort what the examples rest on into the four Rumsfeld boxes, each with its action: **known knowns**, stated in the source, become examples; **known unknowns**, open questions, go to the user as a question page in the same round as the drafts; **unknown knowns**, rules the user holds but never wrote down ("the doll is the draft") and how the feature crosses existing ones, become examples for the user to confirm; **unknown unknowns** can't be listed, so name the riskiest behaviour and probe it with the edge, mode and stillness examples step 2 drafts. Done when every promise of the ticket is on one of the two lists, and each box holds its items or says why it is empty.
2. **Draft** one example per behaviour, coded after the highest example code any ticket of the effort already uses, so no two examples share a code, each naming its observer, with its source and its boundary partner. Draft each limit, error path and odd input the behaviour meets as an example of its own, beside the main ones, so the user approves them in the same round. Draft the crossings too: one example for each existing feature the new one meets on the same screen or data (a colour on a layered outfit, a draft inside a mode), one "must not offer" example for each mode or entry point that should hide something, and one example for what must stay still while the user works (a pane that keeps its place). Check every draft against the rules the user stated in this effort: a draft whose Then contradicts one ("shows at once" where the user ruled that nothing changes before Finish) writes a bug into the spec, so fix it before it reaches the page. Read every value an example names (a limit, a count, a price, a rate) from its source of record this session, such as a table row, a ruleset or a constant, and quote that line beside the draft. A value typed from memory is wrong until read. Then read each example against every other one for a contradiction: a limit of one per slot makes "refills up to its limit" mean several slots. Then check what the drafts would miss. For each entry of a table the feature names (one icon per condition, one price per item) and each rule, ask whether changing it alone would turn a drafted example's test red, and draft one more example for each entry or rule whose change alone would turn no drafted example red. Read the examples under each rule: when they get their results for different reasons, not only different values, a rule is hiding there, so draft that hidden rule as a rule of its own, with its examples moved under it. Done when every behaviour on the list has all three, every crossing, mode and stillness example is drafted, every entry and rule has an example its change turns red, every rule's examples share one reason, every line passes the observer check, every named value has its quoted source, and no two examples contradict.
3. **Hand the drafts to the human** with the `red-pen` skill, with the design list below them so the human can move an item back. When the drafts hold more than six rules, the star is too big to close in one go (EXACT Coding's example-mapping health check): add a section to the page that proposes splitting it, with the rules each part keeps, so the human picks the split with the drafts. A chat reply is never an approval: an example stays a draft until its box comes back ticked from the page. Done when you hold the human's text. Their wording wins, word for word.
4. **Record** the approved examples under an `Examples` heading, exactly as the human left them: on the ticket, or in the pull request body when there is no ticket. When the build has no ticket, file it as a star through `lay-course`'s [STAR-CHART.md](../lay-course/STAR-CHART.md) "Filing a star": its step 1 slices it, and steps 2 and 3 are this skill's steps 2 and 3. Post it the moment the draft page closes, without asking: the user's tick on the page is the approval, so "may I post these?" asks again for what they already gave. Head the post `Examples, ticked on the drafts page`, and leave out any line that says a named person approved them: a permission check reads that as a claim no one can verify. When a check still refuses the post, name the refused command to the user once, with a settings rule that would allow it. When it waits for a later session, stop after this step. Done when that place shows the text once.
5. **Make each example red.** Change a file that holds approved examples with the Edit or Write tool only, since `approved-spec-guard` refuses a shell command that writes one. Write one test per approved example, at the seam the example names: its observer and its words, through the highest public boundary the repo's testing rules allow. Name the test after the example, and mark it `approved-spec` in the form the test framework offers: a category, tag or trait. Write the example's approved Given, When and Then lines, word for word, as comment lines just above its test: they are the wording `approved-spec-guard` locks, and every other line of the file stays free for harness edits. Put approved tests in files of their own, named after the feature with the suffix `ApprovedExamples` (`CharmApprovedExamples.cs`, `charm_approved_examples.py`), so the hook, a code-owner rule and CI all find them by name. Check each one with `placebo` before you run it, and write your prediction for each run: fail, and the line or reason it fails on. A test that passes or fails another way goes to `never-lupus` before any code changes: a check that only searches the source of the code it tests proves nothing, so rewrite it to run that code. An example whose behaviour already holds can't go red: check it against the code before the draft opens, and write its test as a plain regression test, with no mark and no suffix, saying so in its header, since the red-first check fails an approved test that passes where it lands. Run them, then commit them on their own, before any code (the `red-first-guard` hook refuses a commit that adds them with code). Done when every one fails because the behaviour is missing, not because the test is broken.
6. **Hand over.** When `do` called this skill, return to `do` step 2: its tests are written and committed, so push and open the draft. Otherwise start the `do` skill, which builds until every approved test passes. Done when `do` is running.

## Changing an approved example

When the build shows an approved example is wrong, follow [CHANGING.md](CHANGING.md) before any edit to its test.

Charter: C1, C2 ([CHARTER.md](../../CHARTER.md)).
