# Placebo shapes

A test earns its run time only through its **red**: the change to production behaviour that turns it red. A **placebo** is a test whose only red is a refactor, a content edit or a library upgrade. It looks like proof, it costs every run, and it catches nothing. Match each test you write or review against these shapes.

- **Read-back**: the expected value is the input, a constant the code also holds, or the code's own output.
- **Content pin**: a roster, id, count or tunable copied from shipped content. Keep the legal content test: the content parses, every reference resolves, ids are unique.
- **Structure pin**: reflection on a signature, an attribute or a visibility. Test the behaviour the structure exists for.
- **Re-proof**: a result another case already owns.
- **Library proof**: framework or SQL behaviour with no production code on the path.
- **Engine proof**: a case whose red needs the platform underneath to break.
- **Self-agreement**: two values from the same source compared with each other, such as a grid's config checked against the same config. Compare what the user sees with what their input does: the drawn box against where a click lands.
- **Bare input**: the test hands the code an input in a form its live caller never sends, such as a name without the prefix the framework adds. Send it through the real caller, or through the same transform.
- **One-way event**: a test of event-driven code sets a value and never models what the framework does back: the change event a value set by the code fires, or a late event from a control the code has since replaced.
- **Number in the name**: a test named after a value that a sketch, a table or a constant sets (`ThePackIs10By6`). The test reads that value from where the code keeps it, so a tweak keeps it green and the name then lies. Name the relation the value serves (`ThePackFillsOnePage`) and read the value where it is kept.
- **Measuring check**: a check written only to measure while building, such as a window's size or a row's width. It is a measurement, so it is not a test. Put its result in the pull request's Proof section and delete the check before the commit.
- **Source scan**: a test that greps source text. It belongs in the build: a banned-symbol list, a linter or an analyzer.

Mutation testing catches read-backs and other tests that can never fail. It misses content pins, structure pins, re-proofs and slow tests, because no mutant touches what they assert. Use both.
