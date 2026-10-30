---
name: placebo
description: Placebo tests — tests that look like proof and prove nothing. Use whenever you write or review a test: it lists the placebo shapes. Run its audit, which deletes, merges or rewrites placebos across a folder, fixture or suite, only when the user asks to audit or trim tests, or a review keeps finding tests that can't fail.
---

# Placebo

> _A test that can't go red cures nothing._

A test earns its run time only through its **red**: the change to production behaviour that turns it red. A **placebo** is a test whose only red is a refactor, a content edit or a library upgrade. It looks like proof, it costs every run, and it catches nothing.

The repo's own testing rules win over this skill. Read its standards files (`AGENTS.md` names them) before the first verdict.

## Placebo shapes

- **Read-back**: the expected value is the input, a constant the code also holds, or the code's own output.
- **Content pin**: a roster, id, count or tunable copied from shipped content. Keep the legal content test: the content parses, every reference resolves, ids are unique.
- **Structure pin**: reflection on a signature, an attribute or a visibility. Test the behaviour the structure exists for.
- **Re-proof**: a result another case already owns.
- **Library proof**: framework or SQL behaviour with no production code on the path.
- **Engine proof**: a case whose red needs the platform underneath to break.
- **Source scan**: a test that greps source text. It belongs in the build: a banned-symbol list, a linter or an analyzer.

Mutation testing catches read-backs and other tests that can never fail. It misses content pins, structure pins, re-proofs and slow tests, because no mutant touches what they assert. Use both.

Checking one test you're writing or reviewing? Match it against the shapes above, then stop. The steps below are the audit.

## Steps

1. **Fix the scope**: a folder, a fixture, a ticket or the whole suite. Ask once when none is named. Done when the scope is a list of test files.
2. **Rank by cost**, with the timings the repo's docs say where to find, then by file size. Done when the files are in cost order.
3. **Give every case a verdict.** Write its red in one line, "turns red when <production behaviour> changes", from the case's body, never its name. Then pick one:
   - **Keep**: a real red, and no other case owns it.
   - **Delete**: name the shape and the **survivor**, the case that still owns the result, or "no result to own".
   - **Merge**: several cases run one setup for one result. One case keeps every assertion.
   - **Rewrite**: a real result asserted badly. Write the case that goes red on it first, as `do` step 4 says.
   - **Move to the build**: a source scan becomes a banned-symbol entry or an analyzer rule.

   A guard that keeps another case or a list honest has a red of its own: keep it. Slow is a cost, never a verdict. Done when every case has a red line and a verdict, and every delete names its shape and survivor.
4. **Act, one fixture per commit.** Each message names the fixture, the verdict and the shape. Run the touched cases as you go. Done when every verdict is applied and each commit builds.
5. **Prove nothing real was lost.** Run the suites the scope reaches once. Run `sentinels` on the production files whose tests you deleted, with the base branch's tests and then the branch's. A mutant killed before and not after means a deleted case had a real red: restore it or replace it. Done when the runs are green and every new survivor is answered.
6. **Report** in the pull request: cases deleted, merged and rewritten per shape, the survivor behind each delete, the time saved, and the mutation counts. Done when the body matches the diff.
