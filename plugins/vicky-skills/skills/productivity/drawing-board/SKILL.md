---
name: drawing-board
description: Design a window or screen with the user on a true-scale sketch in their browser, and keep the approved sketch as the build's example. Use before building or resizing a UI layout, when the user says "sketch it", "drawing board" or "let me see it first", and when a built layout came out the wrong size.
---

# Drawing board

> _Measure twice, build once: the sketch is the spec._

A **sketch** is a draw.io drawing of one window at true scale, inside a frame the size of the user's screen. Each box has a label, a position, a size and properties such as `block="IconGrid"` and `cell="32"`. The approved sketch is the build's example: a repo's own test holds the build to it. Nothing generates code from it. <!-- kept 2026-11-03: a sketch approved unchanged led to a build that worked first time -->

The scripts are in this skill's `scripts/` folder. `board.py` makes, reads back and saves sketches. `fetch-drawio.sh` fetches the draw.io web app once, pinned and checked by hash, into the plugin's data folder.

## Steps

1. **Read the real sizes.** Take the window's size, the screen's size and each box from the code that builds the window, or from a screenshot when there is no code. List every control the window's code builds (each button, checkbox, label and line of text), and draw each one or name why it goes. Cover every window and tab the user's brief names, and draw two or three designs when the brief leaves the layout open. Note each rule the design rests on, such as "every slot cell in one window is the same size". Done when every size you draw comes from the code or the screenshot.
2. **Draw it.** Run `python3 -I <scripts>/board.py new --screen <W>x<H> --window <name>=<W>x<H> -o <scratch>/<name>.drawio`, or `--screenshot <name>=<file.png>` in place of `--window`. Add each box as `--box "<label>=<x>,<y>,<w>,<h>[,<key>=<value>...]"`, positioned inside the window, and each rule as `--rule same-size=<kind>`, with `kind=<kind>` on the boxes it binds. Copy the sketch to `<scratch>/<name>.before.drawio`. Done when the file exists.
3. **Open it on the board.** Run `CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bash <scripts>/fetch-drawio.sh` and keep the folder it prints. With no network and no copy fetched before, it fails: the page then shows the sketch's XML as text. Write `<scratch>/<name>.md` with a `# Sketch: <name>` title, one line saying Done sends it back, and the sketch inside a ```` ```drawio ```` block. Open it with `interactive-page`, setting `DRAWIO_HOME` to that folder: `DRAWIO_HOME=<folder> bash <interactive-page's folder>/scripts/open-page.sh <scratch>/<name>.md`, run in the background: it waits for Done, and a timeout that cuts it short leaves the user a tab with no server. Done when the user has the page's link.
4. **Read the changes back.** Once the page closes, copy the drawing block's XML to `<scratch>/<name>.drawio` and run `python3 -I <scripts>/board.py report <scratch>/<name>.before.drawio <scratch>/<name>.drawio`. Give the user its lines as they are: each change as numbers ("pack cell 24 → 32"), each marked box by its block, and each broken rule with its odd cells. Done when the user has the report.
5. **Go round** steps 3 and 4 until the report says nothing changed: that sketch stands approved as it is. A broken rule goes back to the user as a question, with fixing the odd cell as your pick. Done when a round changes nothing.
6. **Save the approved sketch** from the repo root with `python3 -I <scripts>/board.py save <scratch>/<name>.drawio --name <name> --code <path of the window's code>`. It goes in the folder a `Sketches:` line in a `docs/agents/` file names, or beside the window's code when no such line exists. Commit it with the build's approved examples, and name it in each example that rests on it. Done when the sketch is committed.
