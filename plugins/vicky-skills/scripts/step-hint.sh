#!/usr/bin/env bash
# PostToolUse hook (Skill): when a skill in the case below starts, adds one line
# of context naming what its steps need. Off unless the plugin option step_guard
# is true; the option keeps that name, from when it also drove step-guard, so
# settings that already turn it on keep working.
case "${CLAUDE_PLUGIN_OPTION_STEP_GUARD:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
skill=$(jq -r '.tool_input.skill // ""' | sed 's/.*://')
case "$skill" in
  warp) hint='Read the chart whole first: its Prime directive binds every star. Start `do` for each star, and `do` runs sentinels on what it changed.' ;;
  do) hint='A star chart binds each star on it: read the chart whole first, its Prime directive included. Before the first test or line of code, run the plan check: argue against the plan. In it, name each rule the user stated in this effort that the plan breaks, and the clash, then change the plan or ask the user; and read and quote each file, setting or branch the plan rests on that nobody read this session. A pass that finds nothing asks nothing and builds on. Either way, the pull request body gets one "Plan check:" line saying what it found. Every do step ends with its proof. To skip one, write "Skipped: <step>, because <reason>" with the proof in the pull request body. Each player-facing or UI text the build writes or changes joins the effort'"'"'s red-pen draft file when you write it, never a pull request list of unread text.' ;;
  over-to-you) hint='An outcome a test could assert becomes that test, run green, never an item: each item names its person-only reason on a person: line. Wording is never an over-to-you item. Every player-facing or UI text the branch writes or changes goes in the effort'"'"'s red-pen draft file, opened before this sitting. Stage the sitting as step 2 says: in the worktree when the testing doc says `Dev stack: any checkout`, else push the branch, switch the clone to it and remove its worktree with the doc'"'"'s `Drop worktree:` script, never git worktree remove or an editor delete. Every sitting, branch or not, gets its servers started and proven up by a command, and each item that reaches a thing gets a kit: line with the exact command in backticks. Every step the user takes goes on the page, never only in chat.' ;;
  make-it-so) hint='Before the pull request goes ready, every player-facing or UI text the branch adds or changes has passed through the effort'"'"'s red-pen draft file.' ;;
  council-of-elrond) hint='Until Frodo speaks, every line the user sees comes from a seat: each chat message and each SendUserMessage, acks, checkpoints and summaries included, opens with a seat'"'"'s name. Once Frodo has chosen the road, the seats are done: write plain prose from then on.' ;;
  review) hint='Each finding you fix, from a person or a review agent, also gets a prevention verdict: engrave the cheapest check, hook or standard line that makes the mistake impossible, or write one line saying why not.' ;;
  away-team|lay-course) hint='' ;;
  gamma-shift) hint='' ;;
  sentinels) hint='Before the pass runs, write its estimate (mutants x the time of the tests that reach them / workers) and the test filter that narrows it to those tests: a pass over the whole suite can time out with nothing written.' ;;
  examples) hint='The drafts open on a page through red-pen, never in the chat, and nothing is built until the user closes them.' ;;
  *) exit 0 ;;
esac
# A ticket is read whole, body and comments, through the repo's own tracker doc.
case "$skill" in do|warp|gamma-shift) hint="Read each ticket whole with \${CLAUDE_PLUGIN_ROOT}/scripts/read-item.sh <id>, which runs the repo's Read, whole operation.${hint:+ $hint}" ;; esac
# The docs come first for every skill that builds, plans or researches.
docs="Read the repo's docs on what you touch before you state a rule about it: its agent guide, glossary, decision records and rules docs. A claim the docs contradict is corrected before it reaches a ticket, a comment or code."
case "$skill" in do|warp|examples|away-team|lay-course) hint="$docs${hint:+ $hint}" ;; esac
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$h}}'
