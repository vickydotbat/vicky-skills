---
name: red-pen
description: Hand drafts to the user to edit in their own editor, then write their text back to where it belongs. Use whenever text needs the user's read before it is committed or published — player-facing or UI text, release notes, posts, wiki pages, docs in their voice — and when the user says "drafts", "let me edit it" or "open it for me".
---

# Red pen

The user edits drafts in their editor, never in the chat. Collect every draft of the effort in one **draft file**, open it, and copy back exactly what they leave there.

## Steps

1. **Write the draft file**: one per effort, at `.drafts/<branch>.md` when the repo ignores `.drafts/`, otherwise in the system temp folder (`$TMPDIR`, else `/tmp`). The file opens with `# Drafts: <effort>` and one line saying that closing the file sends the text back. Each draft is a section:

   ````markdown
   ## <what it is>
   <path>:<line, or "new">

   ```text
   <the draft, exactly as it should appear>
   ```
   ````

   Keep code syntax out of the block: no quotes, escapes or string joins, only the words a reader sees. Done when every draft the effort holds has a section.
2. **Open it and wait for the close.** During a `do` build, leave the file closed until `make-it-so` reaches its step 3. The editor is `$VISUAL`, else `$EDITOR`. Run it on the file as a background command and say in one line that the drafts are open and that closing them sends them back. Most GUI editors wait only with their own flag (`code --wait`, `subl -w`, `gedit -s`, `kate -b`); add it when the variable lacks it. A terminal editor has no terminal to open in from here, and with neither variable set no editor is named: give the path and wait for the user to say done. A "done" in chat moves on to step 3 whatever the editor is doing. Done when the editor has exited or the user said done.
3. **Write back.** Read the draft file again. Put each block's text at its destination word for word, wrapped and escaped the way the surrounding code does. A section the user deleted means that draft is cut: remove it at the destination too. Done when each destination holds its block's text, checked with a grep for a phrase from each.
4. **Finish.** Delete the draft file, run the checks the destinations reach, and commit. Done when the commit holds the user's text.
