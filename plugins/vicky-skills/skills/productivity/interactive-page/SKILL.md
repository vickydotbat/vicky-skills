---
name: interactive-page
description: Open a Markdown file the user must read, approve or fill in (a red-pen draft file, an over-to-you checklist) as a page in their browser, and write their answers back into the file. Use whenever a skill hands the user a file to edit or tick, in place of opening it in their editor.
---

# Interactive page

> _Click, don't type: the page is the form, the file is the record._

The user answers in the browser, never in a Markdown editor. The file stays the record: the page reads it, and Done writes the answers back into it in its own form, so the skill that wrote the file reads it back the way it always has.

## What the page makes of a file

| In the file | On the page |
| --- | --- |
| a ```` ```text ```` block | editable text |
| `- [ ] approve` | a box to tick |
| `1. [ ] <check>` | one box per mark: `[x]`, `[~]`, `[-]`, `[ ]` |
| `notes:`, `- BUG:` and other `label:` lines | a line of text |
| each ```` ```text ```` block, again | a comment box under it, written back as `Comment: <text>` |

Every other line shows as text. A Done that changes nothing leaves the file byte for byte as it was.

## Steps

1. **Write the file** in the form the calling skill gives: `red-pen`'s draft file or `over-to-you`'s checklist. Done when the file exists.
2. **Open it** with `bash <this skill's folder>/scripts/open-page.sh <file>`, run from the repo as a background command, and tell the user in one line that the page is open and that Done sends it back. It runs `red-pen`'s `open-draft.sh` with the page in the editor's place: the `draft-lock` hook holds the repo's code while the page is open, and a section the user changed or ticked grants its location to the approved-spec guard. With no display on the machine, the file opens in the user's editor instead, the way `red-pen` step 2 says. Done when the background command has exited, or the user said done in chat.
3. **Read it back.** Read the file again and hand it to the calling skill's read-back step. A `Comment:` line is the user's note on the block above it: act on it as that skill says for a note. Done when every answer is acted on.
