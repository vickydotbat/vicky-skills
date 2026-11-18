#!/usr/bin/env bash
# approved-spec: sup finds a handoff posted from the default branch. conn's half
# runs the commands conn names; sup's half runs the finder.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
plugin="$root/plugins/vicky-skills"
todo="$plugin/skills/housekeeping/standing-orders/scripts/todo.sh"
finder="$plugin/skills/housekeeping/sup/scripts/find-handoff.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
r="$dir/repo"; git init -q -b main "$r"; git -C "$r" remote add origin git@forge.example:o/r.git
git -C "$r" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mkdir -p "$r/docs/agents" "$dir/bin" "$dir/projects"
echo "| Read, whole | \`cat $dir/ticket-<key>\` |" > "$r/docs/agents/issue-tracker.md"
printf '#!/usr/bin/env bash\necho "[]"\n' > "$dir/bin/tea"; chmod +x "$dir/bin/tea"
sup() { (cd "$r" && PATH="$dir/bin:$PATH" FIND_HANDOFF_PROJECTS_DIR="$dir/projects" CLAUDE_CODE_SESSION_ID=now bash "$finder" 2>&1); }
# The two commands conn names, run as conn runs them, for a handoff posted at $1.
point() { (cd "$r" && bash "$todo" done "Handoff:" >/dev/null 2>&1; bash "$todo" add "Handoff: $1 (2026-11-17)" >/dev/null); }

# Given a session that posts a handoff on a ticket or pull request
# When you type /conn
# Then the repo's .todo holds one line, - Handoff: <the ticket key or pull request link> (<date>)
check "E1 conn leaves a pointer in .todo" \
  'point GAME-2882 && grep -qx -- "- Handoff: GAME-2882 (2026-11-17)" "$r/.todo"'

# Given a .todo that already holds a Handoff line
# When you type /conn again and it posts somewhere else
# Then .todo holds only the new Handoff line
check "E2 a newer handoff replaces the older pointer" \
  'echo "- Finish the parser (GAME-1)" >> "$r/.todo" && point GAME-2883 && [ "$(grep -c "Handoff:" "$r/.todo")" = 1 ] && grep -qx -- "- Handoff: GAME-2883 (2026-11-17)" "$r/.todo" && grep -qF "Finish the parser" "$r/.todo"'

# Given a checkout on main with no open pull request and no ticket key in its name
# And its .todo names a ticket whose thread holds a Handoff comment
# When you type /sup
# Then sup reports that handoff
printf -- '- Audit CI for cost and time cuts (GAME-2882)\n' > "$r/.todo"
echo '- 2026-11-17: **Handoff** pick up the CI audit' > "$dir/ticket-GAME-2882"
out=$(sup)
check "E3 sup on the default branch finds the handoff through .todo" \
  'grep -qF "found: ticket GAME-2882: - 2026-11-17: **Handoff** pick up the CI audit" <<<"$out"'

# Given a checkout on main whose .todo names a ticket with no Handoff comment
# When you type /sup
# Then sup says it found none, and names that ticket among the places it searched
echo '- 2026-11-17: plain note' > "$dir/ticket-GAME-2882"
out=$(sup)
check "E4 a .todo ticket with no handoff reports none" \
  'grep -q "^none found in: .*ticket GAME-2882" <<<"$out"'

# Given a checkout on main whose .todo holds - Handoff: <a pull request comment link> (<date>)
# When you type /sup
# Then sup reports that link as the handoff
printf -- '- Handoff: https://forge.example/o/r/pulls/1608#issuecomment-9 (2026-11-17)\n' > "$r/.todo"
out=$(sup)
check "E5 a pointer to a pull request link is reported" \
  'grep -qF "found: .todo Handoff line: https://forge.example/o/r/pulls/1608#issuecomment-9" <<<"$out"'
exit $fail
