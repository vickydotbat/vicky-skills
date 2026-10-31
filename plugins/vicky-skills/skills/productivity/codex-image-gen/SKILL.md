---
name: codex-image-gen
description: Generate or edit an image by driving the Codex CLI's built-in image tool from another agent. Use whenever a task says "use codex" for an image, art pass, meme, portrait or reference sheet, and whenever a `codex exec` call looks silent or stuck.
---

# Image generation through Codex

> _It's not dead, it's resting. Prove a quiet Codex is alive from its own files before you call it a hang._

`codex exec` is slow and quiet. One image takes about three minutes, and
stdout stays still for most of it. A still stdout is not a hang. Prove
liveness from Codex's own files before you wait, retry or report.

## Run

1. Write the prompt to a file in your scratch folder. Its first line tells
   Codex: generate one image with the built-in image tool, save it to an
   exact path relative to the working directory, write no other files, one
   render, no edits afterwards. Codex edits its own render when it dislikes
   it, and the edit wrecks it. Done when the file holds those instructions.
2. Attach references with `-i <path>` from where they live. Never copy them
   into the workspace. Done when every reference is passed from its own location.
3. Run it in the background, capped, with stdin from the prompt file:

   ```sh
   systemd-run --user --scope -p MemoryMax=4G -p MemorySwapMax=0 \
     timeout 900 codex exec --skip-git-repo-check -s workspace-write \
     -i <ref.png> < <scratch>/prompt.txt > <scratch>/out 2>&1; echo "exit=$?"
   ```

   Stdin must be the prompt file. A `codex exec` with an open stdin and no
   prompt waits forever for input. Done when the command is running and `exit=` is logged at the end; if it fails to start, report the error from `<scratch>/out`.

## Prove it is alive

Check these, newest first, every 30 seconds, at most 60 times:

- `pgrep -af "codex exec"` shows the process.
- The newest `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` belongs to this
  run, and its modification time moves. Reading the image skill and the
  reference images makes it large early. That is input, not output.
- `~/.codex/generated_images/<session id>/` appears when the image lands.
  The session id is the tail of the rollout file name.
- The target path exists.

Silent means none of these moved for five minutes while the process lives.
Then take the last 20 lines of the rollout file and look for a usage limit,
an approval prompt or an error before you stop it.

## Failure modes

- A usage limit prints in `<scratch>/out` with a reset time. Report the time.
  Do not retry before it.
- A sandbox refusal to write the target: the image still sits in
  `~/.codex/generated_images/<session id>/`. Copy it from there.
- `timeout` exit 124 with an image in `generated_images`: the render worked
  and the save step died. Copy it. Without an image, rerun once.
- Run one render at a time against one quota.

## Done

Open the saved PNG and look at it before you report it. Done when the report names the path and the defects you see, or says "none seen".
