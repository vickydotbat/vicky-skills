---
name: case-file
hands-off: [by-eye, human-voice]
description: Build a case file, one zip holding a PDF, its HTML, its source and its files, that shows another team what an effort did, with every claim marked by the evidence behind it. Use when the user asks for a case file, a write-up of an effort for another team or project, or a page that shows how something was built and proven.
disable-model-invocation: true
---

# Case file

> _Every claim on the stand brings its evidence._

A **case file** shows readers outside the effort what it did, from the tickets to the files, so they can judge it and reproduce it. It states what worked for the writers, never what the readers should do: they make their own path. It ships as one zip: a README, the PDF the reader opens first, the same page as HTML and Markdown, the sections it was built from, and every file the page shows. The scripts in `scripts/` build, check and bundle it, each run with `python3`. The agent never assembles the page by hand: `build.py` writes it, its timeline and its labels from the case folder.

Each claim carries one **label**, the strongest its evidence holds. Write the attribute value in a `CLAIM` marker, and the build shows the words:

| Label | Attribute | Its evidence |
| --- | --- | --- |
| stock | `stock` | Seen on the unmodified product, by a run you can name. |
| test client only | `test-client-only` | Seen only on a modified client, rig or harness. Never upgrade it to stock. |
| estimate | `estimate` | Reasoned or measured indirectly, with nothing run end to end. |
| failed | `failed` | Tried, and it did not work. Keep it: a failure saves the readers a try. |
| not tested | `not-tested` | No run checked it. |

The **PDF** is the document of record, the file a reader opens first. The HTML is its supplement, for what a PDF cannot do: folded files and download links.

Each case file has one **kind**, picked by what the reader does after reading:

| Kind | The reader ends up | The page, in order |
| --- | --- | --- |
| research | knowing something | the question, the answer in one paragraph, the sources and methods tried, the findings, the dead ends as `failed`, the open questions as `not-tested` |
| demonstration | able to check or repeat something | the claim and its scope, what you need, the steps as `STEP` markers, the evidence, the limits and what was not run |
| pitch | deciding to adopt something | a summary, the reader's problem, how it looks from their side, how it works, Drawbacks, Alternatives, prior art, open questions, and the ask |

## Steps

1. **Open the case folder**: `.case-files/<name>/` at the root of the effort repo's main checkout, never a worktree's: from a worktree, the root is the folder above `git rev-parse --path-format=absolute --git-common-dir`. `<name>` is the effort's short name. When it exists, reopen it and build on every file in it: never open a second folder for the same effort. Add one `.case-files/` line to `.gitignore` when no line lists it. The folder lasts across sessions: `build.py` refuses a case file in a scratch folder or a linked worktree. When the shell can't write there, make each file with the file tool. Done when the folder exists, `.gitignore` lists `.case-files/` once, and `git status` does not list the folder.

   Fixed layout: the case folder holds these and nothing else, and `build.py` refuses any other entry.

   | Entry | Holds | Ships |
   | --- | --- | --- |
   | `sections/` | the page's parts | as `source/sections/` |
   | `files/` | each file the page shows, in folders by role (`art/`, `scripts/`, `runs/`, `img/`) | yes |
   | `raw/` | working material: full run logs, recordings, superseded drafts, screenshots of the page | never |
   | `quotes.md` | the approved quotes | never |
   | `README.md` | the zip's README | yes |
   | `out/` | the built formats and the one zip | yes |
   Proven by: plugins/vicky-skills/evals/case-file/reopen
   Proven by: tests/case_file_look_approved_examples.test.sh
2. **Pick the kind** from the table. An ask that names two things for the reader to do, each the purpose of a different kind in the table, is two kinds: it gets two case folders, `<name>-<kind>` each, one kind each, even though one page could carry both. Done when each case folder has one kind.
   Proven by: plugins/vicky-skills/evals/case-file/two-kinds
3. **Read every source whole**: each ticket, body and comments, and each file, log and screenshot the effort names. A session the effort ran in is a source too, read from its saved transcript, never from memory: after a compaction, memory holds only the session's tail. Run `python3 scripts/transcripts.py list` (`--dir <folder>` after the subcommand reads another folder, for `digest` too) and show the user its lines as the candidates. Never read a transcript file itself. For each session the user picks, or the one they name by id, run `python3 scripts/transcripts.py digest <id> .case-files/<name>/raw/transcript-<id>.txt`, then read that digest in windows by time with `grep` or `awk`, opening the full message only for a line you cite. Done when you hold every source the case file will cite, and each session the effort ran in has its digest in `raw/`.
   Proven by: plugins/vicky-skills/evals/case-file/whole-transcript
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
8. **Build it**: `python3 scripts/build.py .case-files/<name> .case-files/<name>/out/<name>.html --formats html,pdf,md`. It writes the page with its kind, a legend of the labels it uses, a contents list of its `<h2>` sections, coloured labels, each file folded under its name, and a timeline of every claim, event and quote, oldest first, then the PDF printed from it by a headless browser, and the Markdown. It stops, writing nothing, on a scratch folder or a worktree, a missing or unknown kind, an undated claim, event or quote, an unknown label or format, a missing browser, a missing or oversized file, an image ImageMagick can't shrink, and a case folder entry outside the fixed layout, a page that names this machine, uses the future tense outside a pitch's ask, or shows a label its attribute contradicts. Fix what it names and build again. With no headless browser on the machine, build `--formats html,md` and list the PDF under `Not proven`. When the shell can't write the folder, build each format to `/dev/stdout` and save it with the file tool, and do the same for every other file this skill writes. Done when it prints `built:` for each format, or each file is saved from its build.
   Proven by: tests/case_file_kinds_approved_examples.test.sh
   Proven by: tests/case_file_look_approved_examples.test.sh
9. **Check each file**: `python3 scripts/check.py <file>` on the HTML, the PDF and the Markdown. It refuses a home folder, scratch path, a path from `~` or climbing out with `..`, the user name or the host name, in the text or inside any download, a download that won't decode, and on the page a label or tense the build would refuse. Rename each hit by its role, as `loose-lips` says, and build again. Done when it prints `case-file check: clean` for each.
   Proven by: tests/case-file.test.sh
10. **Look at it** with `by-eye`, served over a loopback server, since the headless browser refuses `file:` pages. Done when you have seen every section and image render.
    Proven by: plugins/vicky-skills/evals/case-file/marks-evidence
11. **Bundle it**: `python3 scripts/bundle.py .case-files/<name>/out/<name>.html .case-files/<name>/files .case-files/<name>/out --readme .case-files/<name>/README.md`. The README names the PDF as the file to open first, the HTML for folded files and downloads, and what each `files/` folder holds. One zip per case: the script names it `<name>-<YYYY-MM-DD>-<HHMM>.zip`, unpacking into one `<name>/` folder, and deletes each earlier zip of the case. Then run `python3 scripts/check.py` on the zip. Done when it prints `bundled:` and the zip's check prints `case-file check: clean`.
    Proven by: tests/case_file_approved_examples.test.sh
    Proven by: plugins/vicky-skills/evals/case-file/rebuild
12. **Hand it over.** Attach the zip, not the bare page, to the effort's ticket, since a tracker may refuse an `.html` upload. On a rebuild, the comment names the zip it supersedes. A tracker that refuses the zip's size gets the run logs moved from `files/` to `raw/`, then a rebuild. Done when the zip is on the ticket and the user has its path.
    Proven by: plugins/vicky-skills/evals/case-file/marks-evidence

Charter: C2, C3, C7, C8 ([CHARTER.md](../../CHARTER.md)).
