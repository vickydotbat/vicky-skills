---
name: case-file
description: Build a case file, one self-contained HTML page and its zip, that shows another team what an effort did, with every claim marked by the evidence behind it. Use when the user asks for a case file, a write-up of an effort for another team or project, or a page that shows how something was built and proven.
---

# Case file

> _Every claim on the stand brings its evidence._

A **case file** shows readers outside the effort what it did, from the tickets to the files, so they can judge it and reproduce it. It states what worked for the writers, never what the readers should do: they make their own path. It ships as one zip that holds a README, the page and every file the page shows. The scripts in `scripts/` build, check and bundle it, each run with `python3`.

Each claim carries one **label**, the strongest its evidence holds:

| Label | Its evidence |
| --- | --- |
| stock | Seen on the unmodified product, by a run you can name. |
| test client only | Seen only on a modified client, rig or harness. Never upgrade it to stock. |
| estimate | Reasoned or measured indirectly, with nothing run end to end. |
| failed | Tried, and it did not work. Keep it: a failure saves the readers a try. |
| not tested | No run checked it. |

## Steps

1. **Read every source whole**: each ticket, body and comments, and each file, log and screenshot the effort names. Done when you hold every source the case file will cite.
2. **List the claims.** Write each claim on one line with the ticket line or run that backs it and its label from the table. A check that never ran goes under a `Not proven` heading, by its own name. A result seen only on a modified client carries `test client only`, whatever the ticket's wording. Done when every claim has a source and a label, and the `Not proven` list holds every check with no run behind it.
3. **Pick the user's words.** A quote from a session transcript goes in only once the user approves it. Put each quote you mean to use in one `red-pen` draft file, one section per quote with its own approve box, written with `interactive-page`'s `write-page.py`. Open it when the user is at the machine, and otherwise leave it for their return and build on without the quotes. Done when every quote on the page is one the user ticked, and the rest are out.
4. **Gather the evidence.** View every image before it goes in, and cut one that shows nothing the text needs. Compile each code sample where a compiler is to hand, and label one you could not compile `not tested`. Done when every image is one you looked at and every code sample has a result.
5. **Write the template**: the page body as HTML, written with `human-voice`, in the effort's words, for the audience the user named. Put each file in with a marker on its own line, the path relative to the template: `<!-- IMG <path> | <caption> -->` for an image, `<!-- FILE <path> -->` for a text file, `<!-- BIN <path> -->` for a binary. Give each claim its label beside it, and end with the `Not proven` section and the steps that reproduce the effort from the start. Done when every claim from step 2 is on the page with its label.
6. **Build it**: `python3 scripts/build.py <template.html> <page.html>`. It shrinks each image to 720 pixels wide, inlines every file with a download link, and stops naming the marker of a missing file, a file outside the template's folder, a file over 20 MB, or an image ImageMagick can't shrink within its limits. Done when it prints `built:`.
7. **Check it**: `python3 scripts/check.py <page.html>`, which refuses a home folder, scratch path, a path from `~` or climbing out with `..`, the user name or the host name, in the text or inside any download, and a download that won't decode. Rename each hit by its role, as `loose-lips` says, and build again. Done when it prints `case-file check: clean`.
8. **Look at it** with `by-eye`, served over a loopback server, since the headless browser refuses `file:` pages. Done when you have seen every section and image render.
9. **Bundle it**: `python3 scripts/bundle.py <page.html> <files folder> <out folder> --readme <README.md>`, with a README that says what the case file is and how to open it. Save it in a folder that lasts past the session. The script writes a new zip beside any earlier one and deletes nothing. Done when it prints `bundled:`.
10. **Hand it over.** Attach the zip, not the bare page, to the effort's ticket, since a tracker may refuse an `.html` upload, and give the user the zip's path. Done when the zip is on the ticket and the user has its path.

Charter: C2, C3, C7, C8 ([CHARTER.md](../../CHARTER.md)).
