#!/usr/bin/env bash
# approved-spec: the never-lupus peripheral examples, approved 2026-11-07 on a
# drafts page. Each check reads the instruction that drives the agent.
set -u
skill="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/never-lupus/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
steps() { awk '/^## Steps/{f=1;next}/^## /{f=0}f' "$skill" | grep -E '^[0-9]+\. '; }
stepno() { steps | grep -n -m1 -i -- "$1" | cut -d: -f1; }

# NP1
# Given the agent starts never-lupus on a case that fails
# When it follows the Steps in order
# Then, before it reproduces the case, it lists the state the case depends on and reads each one
check "NP1 the agent reads the peripheral before it reproduces" '[ -f "$skill" ] && p=$(stepno "peripheral") && r=$(stepno "reproduce") && [ -n "$p" ] && [ -n "$r" ] && [ "$p" -lt "$r" ] && steps | sed -n "${p}p" | grep -qi "identified" && steps | sed -n "${p}p" | grep -qi "reads\? each"'

# NP2
# Given the agent calls something a bug
# When it writes the diagnosis
# Then the diagnosis names the state each case was seen under
check "NP2 a bug claim names its state" '[ -f "$skill" ] && p=$(stepno "peripheral") && [ -n "$p" ] && steps | sed -n "${p}p" | grep -qi "names the state"'

# NP3
# Given a state the case depends on that the agent cannot read itself
# When the agent lists the peripheral
# Then it asks the user for that state in one line, and calls nothing a bug until the user answers or the state is read
check "NP3 a state the agent cannot read is asked in one line" '[ -f "$skill" ] && p=$(stepno "peripheral") && [ -n "$p" ] && steps | sed -n "${p}p" | grep -qi "one line" && steps | sed -n "${p}p" | grep -qi "calls nothing a bug"'
exit $fail
