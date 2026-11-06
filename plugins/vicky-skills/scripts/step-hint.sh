#!/usr/bin/env bash
# PostToolUse hook (Skill): when `warp` starts, adds one line saying each star
# is built by starting `do`, which runs `sentinels`. When `do` starts, adds one line of context saying
# each step needs its proof, and when `examples` starts, that its drafts open
# in the editor. When `do`, `over-to-you` or `make-it-so` starts, it sends new
# player-facing text to the red-pen draft file. When `do` starts it also asks
# for the plan check, and when `council-of-elrond` starts it keeps every line in
# the seats until Frodo speaks. When `review` starts, it asks for a prevention
# verdict on each finding fixed. Off unless the plugin option
# step_guard is true. When do, warp, examples, away-team or lay-course starts,
# it first says to read the repo's docs before stating a rule. When ship-it
# starts, it says to run human-voice on the body before sending it.
case "${CLAUDE_PLUGIN_OPTION_STEP_GUARD:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
skill=$(jq -r '.tool_input.skill // ""' | sed 's/.*://')
case "$skill" in
  warp) hint='Read the chart whole first: its Prime directive binds every star. Start `do` for each star, and `do` runs sentinels on what it changed, and a pull request missing either step is refused at ready.' ;;
  do) hint='A star chart binds each star on it: read the chart whole first, its Prime directive included. Before the first test or line of code, run the plan check: argue against the plan. In it, name each rule the user stated in this effort that the plan breaks, and the clash, then change the plan or ask the user; and read and quote each file, setting or branch the plan rests on that nobody read this session. A pass that finds nothing asks nothing and builds on. Either way, the pull request body gets one "Plan check:" line saying what it found. Every do step ends with its proof. To skip one, write "Skipped: <step>, because <reason>" with the proof in the pull request body. Each player-facing or UI text the build writes or changes joins the effort'"'"'s red-pen draft file when you write it, never a pull request list of unread text.' ;;
  over-to-you) hint='An outcome a test could assert becomes that test, run green, never an item: each item names its person-only reason on a person: line. Wording is never an over-to-you item. Every player-facing or UI text the branch writes or changes goes in the effort'"'"'s red-pen draft file, opened before this sitting. A repo whose testing doc says `Dev stack: any checkout` runs the sitting in the branch worktree, which stays. Otherwise the user tests in the clone itself, never a worktree: push the branch, remove its worktree with the testing doc'"'"'s `Drop worktree:` script when it has one, never git worktree remove or an editor delete, and switch the clone to it. Every sitting, branch or not, gets its servers started and proven up by a command, and each item that reaches a thing gets a kit: line with the exact command in backticks. Every step the user takes goes on the page, never only in chat.' ;;
  make-it-so) hint='Before the pull request goes ready, every player-facing or UI text the branch adds or changes has passed through the effort'"'"'s red-pen draft file.' ;;
  council-of-elrond) hint='Until Frodo speaks, every line the user sees comes from a seat: each chat message and each SendUserMessage, acks, checkpoints and summaries included, opens with a seat'"'"'s name. Once Frodo has chosen the road, the seats are done: write plain prose from then on.' ;;
  review) hint='Each finding you fix, from a person or a review agent, also gets a prevention verdict: engrave the cheapest check, hook or standard line that makes the mistake impossible, or write one line saying why not.' ;;
  away-team|lay-course) hint='' ;;
  sentinels) hint='Before the pass runs, write its estimate (mutants x the time of the tests that reach them / workers) and the test filter that narrows it to those tests: a pass over the whole suite can time out with nothing written.' ;;
  ship-it) hint='Run human-voice on the body file before the gh or tea command that sends it: pr-guard refuses a body human-voice never saw.' ;;
  examples) hint='The drafts open on a page through red-pen, never in the chat, and nothing is built until the user closes them.' ;;
  *) exit 0 ;;
esac
# The docs come first for every skill that builds, plans or researches.
docs="Read the repo's docs on what you touch before you state a rule about it: its agent guide, glossary, decision records and rules docs. A claim the docs contradict is corrected before it reaches a ticket, a comment or code."
case "$skill" in do|warp|examples|away-team|lay-course) hint="$docs${hint:+ $hint}" ;; esac
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$h}}'
