#!/usr/bin/env bash
# PostToolUse hook (Skill): when `warp` starts, adds one line saying each star
# is built by starting `do`, which runs `sentinels`. When `do` starts, adds one line of context saying
# each step needs its proof, and when `examples` starts, that its drafts open
# in the editor. When `do`, `over-to-you` or `make-it-so` starts, it sends new
# player-facing text to the red-pen draft file. When `do` starts it also asks
# for the plan check, and when `council-of-elrond` starts it keeps every line in
# the seats until Frodo speaks. When `review` starts, it asks for a prevention
# verdict on each finding fixed. Off unless the plugin option
# step_guard is true.
case "${CLAUDE_PLUGIN_OPTION_STEP_GUARD:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
skill=$(jq -r '.tool_input.skill // ""' | sed 's/.*://')
case "$skill" in
  warp) hint='Start `do` for each star, and `do` runs sentinels on what it changed, and a pull request missing either step is refused at ready.' ;;
  do) hint='Before the first test or line of code, run the plan check: argue against the plan. In it, name each rule the user stated in this effort that the plan breaks, and the clash, then change the plan or ask the user; and read and quote each file, setting or branch the plan rests on that nobody read this session. A pass that finds nothing asks nothing and builds on. Either way, the pull request body gets one "Plan check:" line saying what it found. Every do step ends with its proof. To skip one, write "Skipped: <step>, because <reason>" with the proof in the pull request body. Each player-facing or UI text the build writes or changes joins the effort'"'"'s red-pen draft file when you write it, never a pull request list of unread text.' ;;
  over-to-you) hint='An outcome a test could assert becomes that test, run green, never an item: each item names its person-only reason on a person: line. Wording is never an over-to-you item. Every player-facing or UI text the branch writes or changes goes in the effort'"'"'s red-pen draft file, opened before this sitting. The user tests in the clone itself, never a worktree: push the branch, remove its worktree, and switch the clone to it. Every sitting, branch or not, gets its servers started and proven up by a command, and each item that reaches a thing gets a kit: line with the exact command in backticks. Every step the user takes goes on the page, never only in chat.' ;;
  make-it-so) hint='Before the pull request goes ready, every player-facing or UI text the branch adds or changes has passed through the effort'"'"'s red-pen draft file.' ;;
  council-of-elrond) hint='Until Frodo speaks, every line the user sees comes from a seat: each chat message and each SendUserMessage, acks, checkpoints and summaries included, opens with a seat'"'"'s name. Once Frodo has chosen the road, the seats are done: write plain prose from then on.' ;;
  review) hint='Each finding you fix, from a person or a review agent, also gets a prevention verdict: engrave the cheapest check, hook or standard line that makes the mistake impossible, or write one line saying why not.' ;;
  examples) hint='The drafts open on a page through red-pen, never in the chat, and nothing is built until the user closes them.' ;;
  *) exit 0 ;;
esac
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$h}}'
