---
name: interactive-page
description: Open what the user must read, approve, tick or choose (a red-pen draft file, an over-to-you checklist, a question with options) as a page in their browser, and write their answers back into the file. Use whenever a skill hands the user a file to edit or tick, and whenever you would ask the user a question with options.
---

# Interactive page

> _Click, don't type: the page is the form, the file is the record._

The user answers in the browser, never in a Markdown editor. The file stays the record: the page reads it, and Done writes the answers back into it in its own form, so the skill that wrote the file reads it back the way it always has.

## What the page makes of a file

| In the file | On the page |
| --- | --- |
| a ```` ```text ```` block | editable text |
| `- [ ] approve` | a box to tick |
| `- [x] <label>` | a box to tick, with its label |
| `![<name>](<file>.svg)`, the file in the same folder | the chart, drawn full width; a click zooms in |
| `1. [ ] <check> → <expected>`, with its indented `person:`, `kit:` and `notes:` lines | a card: the action, the expected result, one choice per mark labelled from the `Mark each item:` legend line (which then leaves the page), and the notes |
| `signed off:` and `proven by:` lines | one collapsed header |
| `quick notes:` and its `- TAG:` lines | one collapsed block, open when a note is filled |
| `` `code` ``, `**bold**` and `*italics*` in any line | drawn as Markdown |
| `notes:`, `- BUG:` and other `label:` lines | a line of text |
| each ```` ```text ```` block, again | a comment box under it, written back as `Comment: <text>` |
| a run of `- ( ) <option>` lines, `(x)` on your pick | one choice: the user clicks an option, written back as `(x)` |
| the end of every page | a comment box, written back under a closing `## Anything else` heading |
| two or more `- [ ] approve` lines | an "approve all" box beside Done, which ticks every one |

Every other line shows as text. A Done that changes nothing leaves the file byte for byte as it was.

## A question with options

A question you would ask in chat with two or more options goes on a page instead. During a `council-of-elrond`, before Frodo chooses the road, the question stays in the round. Write it as one section per question, your pick marked `(x)`:

```markdown
# A question for you

## Q1: <the question, in one line>
- (x) <your pick>
- ( ) <the other option>
```

Open it as the steps below say. A Done the user leaves unchanged takes your pick.

For a planning page, such as a warp's pre-flight or a council's open points, add what the caller names above the questions: each chart as an image line, and the course as one ticked box per ticket, `- [x] <key> <kind>: <title>. Needs: <what it needs from the user, or nothing>`. A question the user may answer in their own words ends its options with `- ( ) Other` and a `notes:` line.

## Steps

1. **Write the file** in the form the calling skill gives: `red-pen`'s draft file, `over-to-you`'s checklist, or a question as above, in the system temp folder for a question. Done when the file exists.
2. **Open it** with `bash <this skill's folder>/scripts/open-page.sh <file>`, run from the repo as a background command. It prints `page: open <url>` first: read that line from the command's output and give the user the link in the same message, every time, since a desktop opener can fail without a word, and say that Done sends it back. It runs `open-draft.sh`, beside it, with the page in the editor's place: the `draft-lock` hook holds the repo's code while the page is open, and a section the user changed or ticked grants its location to the approved-spec guard. With no display on the machine, the file opens in the user's editor instead, the way `red-pen` step 2 says. When the command exits with status 2 and says `no answer within`, nobody answered: the file is as it was, so ask the same questions in chat instead of taking your picks. Done when the background command has exited, or the user said done in chat.
3. **Read it back.** Read the file again and hand it to the calling skill's read-back step; for a question, the `(x)` option is the answer. A `Comment:` line is the user's note on the block above it, and one under `## Anything else` is a note on the whole page: act on each as the calling skill says for a note, before anything else. Done when every answer is acted on.
