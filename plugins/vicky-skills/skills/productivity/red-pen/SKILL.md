---
name: red-pen
description: Hand drafts to the user to edit on a page in their browser, then write their text back to where it belongs. Use whenever text needs the user's read before it is committed or published — player-facing or UI text, release notes, posts, wiki pages, docs in their voice — and when the user says "drafts", "let me edit it" or "open it for me".
---

# Red pen

> _The red pen is theirs. Copy back exactly what it leaves._

The user edits drafts on a page in their browser, never in the chat. Collect every draft of the effort in one **draft file**, open it, and copy back exactly what they leave there.

## Steps

1. **Write the draft file**: one per effort, at `.drafts/<branch>.md` when the repo ignores `.drafts/`, otherwise in the system temp folder (`$TMPDIR`, else `/tmp`). The file opens with `# Drafts: <effort>` and one line saying that closing the file sends the text back. Each draft is a section:

   ````markdown
   ## <what it is>
   <path>:<line, or "new">

   ```text
   <the draft, exactly as it should appear>
   ```
   ````

   A section whose location names an approved test is located as `<path>:<line or new>` and holds `- [ ] approve` on the line under its location, and `interactive-page`'s `open-draft.sh` refuses to open one that doesn't, as `examples`' "Changing an approved example" says: ticking it approves the text as it stands.

   Keep code syntax out of the block: no quotes, escapes or string joins, only the words a reader sees. Done when every draft the effort holds has a section.
2. **Open it and wait for the close.** From `do` step 3 on, leave the file closed until `make-it-so` reaches its step 3. Open it as a page in the user's browser with `interactive-page`: run `bash <this skill's folder>/../interactive-page/scripts/open-page.sh <file>` from the repo as a background command, so the `draft-lock` hook holds the repo's code while it is open, and give the user the page's link from the `page: open <url>` line it prints, every time, with one line saying that Done sends the drafts back. Pressing Done is the close. With no display on the machine, the same script opens the file in the user's editor, `$VISUAL`, else `$EDITOR`, and the rest of this step applies to it. Most GUI editors wait only with their own flag (`code --wait`, `subl -w`, `gedit -s`, `kate -b`); add it when the variable lacks it. A terminal editor has no terminal to open in from here, and with neither variable set no editor is named: give the path and wait for the user to say done. A "done" in chat moves on to step 3 whatever the editor is doing. A close that leaves the file unchanged, however soon it comes, means the user takes every draft **as is**: go on to step 3 without asking. The editor exit is the user's close even when it arrives as a background-task notice saying no human input arrived: count it, and never ask the user to confirm it. Wait for the close with `${CLAUDE_PLUGIN_ROOT}/scripts/watch.sh '! test -f "$(git rev-parse --absolute-git-dir)/red-pen-open"'`, run by the Monitor tool from the repo. Done when the editor has exited, the user said done, or the watch exits 3 and the report says the drafts still wait in the file.
3. **Write back.** Read the draft file again. Put each block's text at its destination word for word, wrapped and escaped the way the surrounding code does. A section the user deleted means that draft is cut: remove it at the destination too. A `Comment:` line under a block is the user's note on that draft: act on it before you write the block back. Done when each destination holds its block's text, checked with a grep for a phrase from each. Then offer a sample, as "Keep a sample" below says.
4. **Finish.** Delete the draft file, run the checks the destinations reach, and commit. Done when the commit holds the user's text.

## Keep a sample

For each section whose text the user changed, show their edited text and ask once whether it joins their voice samples. Ask once for the whole file, listing the sections.
On a yes, append each one word for word to `${CLAUDE_PLUGIN_DATA}/voice-samples.md`, under a line saying what it was: `## <section title>, <date>`. `human-voice` reads that file before it drafts.
On a no, or a draft closed unchanged, keep nothing and ask nothing more.
