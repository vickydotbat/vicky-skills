#!/usr/bin/env bash
# Issue 74: the approved-examples guard reads a command or script that only
# runs an approved-examples file as a read, and a heredoc that only feeds text
# to another file as data. A write onto the file still refuses.
set -u
guard="$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
sh_run() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
printf '# Given a\necho ok\n' > "$dir/foo_approved_examples.sh"
printf 'bash foo_approved_examples.sh\nsh ./foo_approved_examples.sh\n./foo_approved_examples.sh\nsource foo_approved_examples.sh\n. foo_approved_examples.sh\n' > "$dir/build.sh"
printf 'bash foo_approved_examples.sh\nsed -i s/a/b/ foo_approved_examples.sh\n' > "$dir/mixed.sh"
printf 'bash foo_approved_examples.sh > foo_approved_examples.sh\n' > "$dir/clobber.sh"
chmod +x "$dir/build.sh" "$dir/mixed.sh" "$dir/clobber.sh"

check "silent on a build script that only runs approved-examples files" "" "$(sh_run './build.sh')"
check "refuses a script that runs one and also names it to write" deny "$(sh_run './mixed.sh')"
check "refuses a script that runs one and redirects onto it" deny "$(sh_run './clobber.sh')"
check "silent on a command that only runs one: bash" "" "$(sh_run 'bash foo_approved_examples.sh')"
check "silent on a command that only runs one: sh" "" "$(sh_run 'sh foo_approved_examples.sh')"
check "silent on a command that only runs one: ./" "" "$(sh_run './foo_approved_examples.sh | tail -3')"
check "silent on a command that only runs one: source" "" "$(sh_run 'source foo_approved_examples.sh')"
check "silent on an interpreter heredoc, then a run of one" "" "$(sh_run "$(printf 'python3 - <<EOF\nprint(1)\nEOF\nbash foo_approved_examples.sh')")"
check "refuses an interpreter heredoc that names one" deny "$(sh_run "$(printf 'python3 - <<EOF\nopen(\"foo_approved_examples.sh\",\"w\")\nEOF')")"
check "refuses a run that also redirects onto one" deny "$(sh_run 'bash foo_approved_examples.sh > foo_approved_examples.sh')"
check "refuses a run that also copies onto one" deny "$(sh_run 'bash foo_approved_examples.sh; cp x foo_approved_examples.sh')"
check "silent on a cat heredoc that only mentions one in its text" "" "$(sh_run "$(printf "cat > body.md <<'EOF'\nSee foo_approved_examples.sh, then cp it.\nEOF\ngh issue create --body-file body.md")")"
check "refuses a cat heredoc written onto one" deny "$(sh_run "$(printf 'cat > foo_approved_examples.sh <<EOF\nx\nEOF')")"
check "silent on a cat heredoc whose later lines mention one" "" "$(sh_run "$(printf "cat > body.md <<'EOF'\nplain\nfoo_approved_examples.sh, then cp it.\nEOF\necho done")")"
check "refuses a write after a cat heredoc ends" deny "$(sh_run "$(printf "cat > body.md <<'EOF'\nplain\nEOF\nsed -i s/a/b/ foo_approved_examples.sh")")"
check "a command that only runs one exits 0" 0 "$(jq -n --arg c 'bash foo_approved_examples.sh' --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | "$guard" >/dev/null; echo $?)"
for c in '>foo_approved_examples.sh' '>>foo_approved_examples.sh' 'ls;>>foo_approved_examples.sh'; do
  check "refuses an unspaced redirect onto one: $c" deny "$(sh_run "$c")"
done
check "refuses a cat heredoc piped to a shell" deny "$(sh_run "$(printf "cat <<'EOF' | bash\nrm foo_approved_examples.sh\nEOF")")"
check "refuses an unquoted cat heredoc whose body could run code" deny "$(sh_run "$(printf 'cat > body.md <<EOF\n$(rm foo_approved_examples.sh)\nEOF')")"
check "refuses a write after a tab-indented heredoc end" deny "$(sh_run "$(printf "cat > body.md <<-'EOF'\nplain\n\tEOF\nrm foo_approved_examples.sh")")"
check "refuses a write after a heredoc with a double-quoted tag" deny "$(sh_run "$(printf 'cat > body.md <<"EOF"\nplain\nEOF\nrm foo_approved_examples.sh')")"
exit $fail
