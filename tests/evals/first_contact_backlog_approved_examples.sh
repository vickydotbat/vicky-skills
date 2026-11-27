#!/usr/bin/env bash
# approved-spec: the BK-1 examples ticked on 2026-11-27, first-contact offers
# Backlog.md as a tracker. Each runs its eval case under evals/first-contact
# once against the plugin. BK1-E6, picking another tracker, already held before
# BK-1, so its case is a plain regression run at the end. Each run is a full
# Claude session on your own credential, so CI never runs this file: run it by
# hand. It caps every run at --max-cost-usd. The cases need `backlog` on PATH.
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
command -v backlog >/dev/null || { echo "first-contact-backlog: these cases run the backlog CLI; put it on PATH first"; exit 2; }
fail=0

# BK1-E1 Backlog.md is on the menu
# Given a repo with no tracker set up
# When the user runs first-contact and says they want tickets in Backlog.md
# Then first-contact writes docs/agents/issue-tracker.md for Backlog.md
# BK1-E2 The backlog lives outside the checkout
# Given the user picked Backlog.md in first-contact
# When first-contact finishes
# Then a Backlog.md folder exists outside the checkout, made with backlog init --no-git
# And the checkout holds no backlog folder
run first-contact/backlog-tracker "BK1-E1,E2" "first-contact writes a Backlog.md tracker outside the checkout"

# BK1-E3 Every operation is one backlog command
# Given a repo whose tracker file names Backlog.md
# When an agent files, comments on, parks and closes a ticket by that file
# Then each change shows in backlog task view for that ticket
# And no task file was edited except by a backlog command
# BK1-E4 A chart is a parent task
# Given a repo whose tracker file names Backlog.md
# When an agent files a chart and two stars on it by that file
# Then backlog task list --parent with the chart's ID lists both stars
# BK1-E5 Waiting work is listed
# Given a Backlog.md tracker with one parked ticket and one open one
# When an agent lists waiting tickets by the tracker file
# Then it names the parked ticket and its Waits on line, and not the open one
run first-contact/backlog-tracker-works "BK1-E3,E4,E5" "an agent works the Backlog.md tracker by its file"

# Regression, held before BK-1: picking Obsidian still writes the Obsidian file.
run first-contact/obsidian-tracker "BK1-E6" "another pick still gets its own template"
exit $fail
