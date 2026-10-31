#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Bring whats-agent-doing
# into the plugin". The band's examples run in Claude Code's mod test kit,
# from plugins/vicky-skills/tests/viewscreen_approved_examples.test.tsx; the
# credit example reads the README and the ported code.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "the band's examples pass in the mod test kit: the step and its time, the marked history, a row per background agent" \
  '[ -f "$plugin/hooks/viewscreen.tsx" ] && out=$(timeout 120 claude plugin test "$plugin" 2>&1) && [ "$(grep -c "^(pass) viewscreen > " <<<"$out")" = 3 ] && grep -q "^ *0 fail" <<<"$out"'
check "the README thanks whats-agent-doing by Tzafrir Rehan, and the ported code keeps its MIT notice" \
  'grep -q "whats-agent-doing" "$root/README.md" && grep -q "Tzafrir Rehan" "$root/README.md" && grep -q "Copyright (c) 2026 Tzafrir Rehan" "$plugin/hooks/viewscreen.tsx" && grep -q "Permission is hereby granted" "$plugin/hooks/viewscreen.tsx"'
exit $fail
