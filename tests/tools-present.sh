#!/usr/bin/env bash
# Exits 1 naming each tool in tests/tools that this machine lacks, so a test
# never fails later with a bare "command not found" that reads like a bug.
set -u
missing=0
while read -r tool; do
  case $tool in ''|'#'*) continue ;; esac
  command -v "$tool" >/dev/null || { echo "missing tool: $tool (install it, or run under nix shell nixpkgs#$tool)" >&2; missing=1; }
done <"${1:-$(dirname "$0")/tools}"
exit $missing
