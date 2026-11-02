---
name: by-eye
description: Check a page by eye in a windowless browser — boot the dev site, look at it in light, dark, narrow and keyboard-only use, and keep the screenshots for the user. Use when a build needs to see a page it changed, when `do` turns an example the user sees on a page green, and when the user asks to "look at it" or "check it by eye".
---

# By eye

> _Seeing is believing. Leave the pictures where the user can see them too._

A **by-eye check** is the agent looking at a page it changed, the way the user would, in a browser with no window: the headless Playwright MCP server, whose tools are `mcp__playwright-headless__*`. The agent grades the page on what it sees and goes on without waiting for the user. The user can look at the same screenshots afterwards. A look only a person can judge, such as whether a page feels right, is no by-eye check: it goes to the user as an `over-to-you` item.

## Steps

1. **Boot the dev site** the way the repo's agent guide says, under a memory cap: `systemd-run --user --scope -p MemoryMax=4G -p MemorySwapMax=0 <start command>`, as a background command. Save its id. Done when the site answers on its address.
2. **Open the page.** Use the headless server. With no `mcp__playwright-headless__*` tools, say the headless server is missing and stop: never fall back to the windowed one. Use the windowed `playwright` server only for a page that shows after the user signs in, and say first that it needs the user to sign in. Done when the browser shows the page.
3. **Look four ways**: light mode, dark mode, a narrow screen (390 pixels wide), and the keyboard alone (Tab through every control, Enter on each action). Take a screenshot of each, saved in the repo's ignored `.playwright-mcp` folder, since the server refuses a path outside the repo. Fix what looks wrong and look again. Done when each of the four has a screenshot and a verdict.
4. **Keep the pictures.** Copy the screenshots to your scratch folder, and attach them to the report. Done when the report names that folder.
5. **Stop the dev site** by the id you saved. Done when its address no longer answers.
6. **Report** each look with its verdict and its screenshot, and what you fixed. Done when the report is sent.
