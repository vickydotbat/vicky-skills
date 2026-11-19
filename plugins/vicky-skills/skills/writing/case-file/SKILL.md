---
name: case-file
description: Build a case file, one self-contained HTML page and its zip, that shows another team what an effort did, with every claim marked by the evidence behind it. Use when the user asks for a case file, a write-up of an effort for another team or project, or a page that shows how something was built and proven.
---

# Case file

> _Every claim on the stand brings its evidence._

A **case file** shows readers outside the effort what it did, from the tickets to the files, so they can judge it and reproduce it. It states what worked for the writers, never what the readers should do: they make their own path. It ships as one zip that holds a README, the page and every file the page shows. The scripts in `scripts/` build, check and bundle it, each run with `python3`. The agent never assembles the page by hand: `build.py` writes it, its timeline and its labels from the case folder.

Each claim carries one **label**, the strongest its evidence holds. Write the attribute value in a `CLAIM` marker, and the build shows the words:

| Label | Attribute | Its evidence |
| --- | --- | --- |
| stock | `stock` | Seen on the unmodified product, by a run you can name. |
| test client only | `test-client-only` | Seen only on a modified client, rig or harness. Never upgrade it to stock. |
| estimate | `estimate` | Reasoned or measured indirectly, with nothing run end to end. |
| failed | `failed` | Tried, and it did not work. Keep it: a failure saves the readers a try. |
| not tested | `not-tested` | No run checked it. |

Each case file has one **kind**, picked by what the reader does after reading:

| Kind | The reader ends up | The page, in order |
| --- | --- | --- |
| research | knowing something | the question, the answer in one paragraph, the sources and methods tried, the findings, the dead ends as `failed`, the open questions as `not-tested` |
| demonstration | able to check or repeat something | the claim and its scope, what you need, the steps as `STEP` markers, the evidence, the limits and what was not run |
| pitch | deciding to adopt something | a summary, the reader's problem, how it looks from their side, how it works, Drawbacks, Alternatives, prior art, open questions, and the ask |

## Steps

1. **Open the case folder**: `.case-files/<name>/` at the effort repo's root, where `<name>` is the effort's short name. When it exists, reopen it and build on every file in it: never open a second folder for the same effort. Add one `.case-files/` line to `.gitignore` when no line lists it. The folder holds `sections/`, `files/`, `quotes.md` and `out/`, and lasts across sessions: `build.py` refuses a case file in a scratch folder. When the shell can't write there, make each file with the file tool. Done when the folder exists, `.gitignore` lists `.case-files/` once, and `git status` does not list the folder.
   Proven by: plugins/vicky-skills/evals/case-file/reopen
2. **Pick the kind** from the table. An effort of two kinds gets two case folders, `<name>-<kind>` each, one kind each. Done when each case folder has one kind.
   Proven by: plugins/vicky-skills/evals/case-file/two-kinds
3. **Read every source whole**: each ticket, body and comments, and each file, log and screenshot the effort names. Done when you hold every source the case file will cite.
   Proven by: plugins/vicky-skills/evals/case-file/marks-evidence
4. **List the claims.** Write each claim on one line with the ticket line or run that backs it, its label from the table, and the date and time with its zone that its source gives. A check that never ran goes under a `Not proven` heading, by its own name. A result seen only on a modified client carries `test-client-only`, whatever the ticket's wording. Done when every claim has a source, a label and a time, and the `Not proven` list holds every check with no run behind it.
   Proven by: plugins/vicky-skills/evals/case-file/marks-evidence
5. **Pick the user's words.** A quote from a session transcript goes in only once the user approves it. Put each quote you mean to use in one `red-pen` draft file, one section per quote with its own approve box and the time it was said, written with `interactive-page`'s `write-page.py`. Open it when the user is at the machine, and otherwise leave it for their return and build on without the quotes. Keep the approved ones in `quotes.md`. Done when every quote on the page is one the user ticked, with its time, and the rest are out.
   Proven by: plugins/vicky-skills/evals/case-file/quotes-approved
6. **Gather the evidence** into `files/`. View every image before it goes in, and cut one that shows nothing the text needs. Compile each code sample where a compiler is to hand, and label one you could not compile `not-tested`. Done when every image is one you looked at and every code sample has a result.
   Proven by: plugins/vicky-skills/evals/case-file/marks-evidence
7. **Write the sections**: the page's parts as HTML files in `sections/`, joined in file name order (`1-answer.html`, `2-sources.html`), in the order the kind's row gives, written with `human-voice` in the effort's words for the audience the user named. Tell what was done in the past tense; only a pitch's ask, between `<!-- ASK -->` and `<!-- END ASK -->`, may speak in the present or future. Put each file, claim, event, quote and step in with a marker on its own line, paths relative to the case folder:

   | Marker | Puts in |
   | --- | --- |
   | `<!-- KIND <kind> -->` | the kind, once per case file |
   | `<!-- IMG <path> \| <caption> -->` | an image |
   | `<!-- FILE <path> -->`, `<!-- BIN <path> -->` | a text or binary file, with a download link |
   | `<!-- CLAIM <attribute> \| <time> \| <source> \| <text> -->` | a claim with its label |
   | `<!-- EVENT <time> \| <text> -->` | an event |
   | `<!-- QUOTE <time> \| <who> \| <text> -->` | an approved quote |
   | `<!-- STEP <command> \| <expected result> -->` | a step that reproduces the effort |

   Write each time as `2026-11-19T14:05+00:00`. End with the `Not proven` section and the steps that reproduce the effort from the start. Done when every claim from step 4 and every approved quote has its marker.
   Proven by: plugins/vicky-skills/evals/case-file/research
8. **Build it**: `python3 scripts/build.py .case-files/<name> .case-files/<name>/out/<name>.html --formats html,pdf,md`. It writes the page with its kind, labels and a timeline of every claim, event and quote, oldest first, then the PDF printed from it by a headless browser, and the Markdown. It stops, writing nothing, on a scratch folder, a missing or unknown kind, an undated claim, event or quote, an unknown label or format, a missing browser, a missing or oversized file, an image ImageMagick can't shrink, and a page that names this machine, uses the future tense outside a pitch's ask, or shows a label its attribute contradicts. Fix what it names and build again. With no headless browser on the machine, build `--formats html,md` and list the PDF under `Not proven`. When the shell can't write the folder, build each format to `/dev/stdout` and save it with the file tool, and do the same for every other file this skill writes. Done when it prints `built:` for each format, or each file is saved from its build.
   Proven by: tests/case_file_kinds_approved_examples.test.sh
9. **Check each file**: `python3 scripts/check.py <file>` on the HTML, the PDF and the Markdown. It refuses a home folder, scratch path, a path from `~` or climbing out with `..`, the user name or the host name, in the text or inside any download, a download that won't decode, and on the page a label or tense the build would refuse. Rename each hit by its role, as `loose-lips` says, and build again. Done when it prints `case-file check: clean` for each.
   Proven by: tests/case-file.test.sh
10. **Look at it** with `by-eye`, served over a loopback server, since the headless browser refuses `file:` pages. Done when you have seen every section and image render.
    Proven by: plugins/vicky-skills/evals/case-file/marks-evidence
11. **Bundle it**: `python3 scripts/bundle.py .case-files/<name>/out/<name>.html .case-files/<name>/files .case-files/<name>/out --readme <README.md>`, with a README that says what the case file is and how to open it. The script writes a new zip beside any earlier one and deletes nothing. Done when it prints `bundled:`.
    Proven by: tests/case_file_approved_examples.test.sh
12. **Hand it over.** Attach the zip, not the bare page, to the effort's ticket, since a tracker may refuse an `.html` upload, and give the user the zip's path. Done when the zip is on the ticket and the user has its path.
    Proven by: plugins/vicky-skills/evals/case-file/marks-evidence

Charter: C2, C3, C7, C8 ([CHARTER.md](../../CHARTER.md)).
