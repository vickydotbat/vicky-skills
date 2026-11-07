---
name: screenshot-intake
description: Take in the screenshots a user shows, so each one is read, said back, recorded and compared before any theory. Use when a prompt holds an image path or a screenshot link and when the user says "look at this" or "once again".
---

# Screenshot intake

> _Show, don't tell: the user shows the problem, and the agent must be able to tell it back._

An agent that reads a screenshot and says nothing loses it by the next turn. Intake turns each image into one recorded line.

## Steps

1. **Read each image.** Open every image path in the prompt with the Read tool, and every `file://` link as its path with the `%20` and other escapes decoded. A path with a raw space reaches you split at the space, so look for the rest of the name in the folder. Done when each image has been opened.
2. **Say what it shows.** Write in plain words what the image shows and which part the user points at, before any theory. A thing the user pointed at in words (a "spike", a "black block") is found in the image and named by where it sits. Done when each image has its plain-words line in your reply.
3. **Zoom to the detail.** Crop or zoom to the part the user points at, with a crop or a zoomed render, since a whole-window shot shrinks a small detail away. Read the zoomed view. Done when the pointed-at part has been looked at at full size.
4. **Record one line per image.** Write the image's file name and what it shows in the effort's ticket, or in the journal when the project keeps one, one line each. Done when each image has its line there, found again by `grep` on the file name.
5. **Compare before a theory.** Search the recorded lines and the journals for the same file name, the same thing shown, and an earlier fix. A screenshot whose file name already has a recorded line is the one recorded earlier: quote that line and ask nothing about it. Done when the comparison has its result in your reply, and no theory came before it.

Charter: C1, C3, C5 ([CHARTER.md](../../CHARTER.md)).
