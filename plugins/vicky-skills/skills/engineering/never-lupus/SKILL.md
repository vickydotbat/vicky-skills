---
name: never-lupus
description: Find the cause of a hard bug or a slowdown with a loop that goes red on it. Use when something is broken, throwing, failing or slow, or the user says "diagnose" or "debug this".
---

# Never lupus

> _It's never lupus. It's whatever turns the loop red._

A bug is found by a **loop**: one command that goes red on this bug and green once it is fixed. With a loop, finding the cause is mechanical. Without one, reading code is guessing. Trace the bug in the code: "the build is stale" is a diagnosis too, and it needs proof such as an artifact hash or a logged version. Trace the cause in the code before you blame the user's copy: the `stale-blame` hook sends back a "your build is stale" with no quoted proof.

Show commands and output with every secret replaced by `<REDACTED>`. Keep credentials in environment variables, out of the loop's text.

## Steps

1. **Build the loop.** Try these in order and take the first that reaches the bug: a failing test at the seam the bug passes through, an HTTP call against a running server, a CLI run diffed against known-good output, a headless browser script, a captured request or log replayed through the code, a small harness around the failing path, a random-input loop, `git bisect run` between a good and a bad state, or the same input through two versions. When only a person can trigger it, copy [`scripts/ask-the-human.sh`](scripts/ask-the-human.sh) and drive them through it. Put a memory and time limit on anything that can run away. Done when you have run one command that drives the real code path, asserts the user's exact symptom, gives the same verdict every run (or a high, pinned rate for a flaky bug) and takes seconds. When no loop is possible, stop: list what you tried and ask the user for access, a captured artifact or permission to add logging.
2. **Reproduce and shrink.** Run the loop and confirm it fails the way the user described, not some nearby way. Then cut inputs, callers, settings and steps one at a time, rerunning after each cut. Done when removing anything left makes the loop pass.
3. **Rank three to five causes**, each with the prediction it makes: "if X is the cause, changing Y makes the bug go away". Show the list to the user before you test it, since they may rule one in or out at a glance. Done when every cause has a prediction.
4. **Test one prediction at a time.** Use a debugger first, then logs at the boundary that tells two causes apart. Before you compare two timestamps, read each source's time zone: a container or server log often runs on UTC while the desktop runs local time. Tag every log line with one prefix, such as `[DEBUG-a4f2]`. For a slowdown, measure a baseline first and bisect against it. When the cause is a platform limit (a cap, quota or size the platform sets), the report gives the headroom under normal use (how much a typical session spends against the cap), and the limit goes to `engrave` unasked. Report it with the headline `🩺 It's not lupus. It's <the cause>.` Done when one cause is confirmed. When every ranked cause is refuted, go back to step 3 with what the tests showed.
5. **Fix it test-first, at the source.** Pick the fix first: make the bad state impossible, the first design move in [PRINCIPLES.md](../review/PRINCIPLES.md). Find the input or offer that lets it exist (a menu row, a parameter, a call that should never be made) and remove it. A fix that only catches or reports the bad state downstream gives, in the commit or pull request, the reason the source can't be closed. Turn the shrunk loop into a failing test at a seam where the bug really happens, watch it fail, fix, watch it pass, then rerun the original loop. When no seam can hold the bug, say so: that is a design finding. Done when the original loop passes and the fix closes the source, or names why it can't.
6. **Clean up.** Remove every tagged log line (grep the prefix) and every throwaway harness. A comment the fix leaves follows [PRINCIPLES.md](../review/PRINCIPLES.md)'s "A comment is a one-line why". Name the confirmed cause in the commit or pull request. Done when the grep finds nothing.
