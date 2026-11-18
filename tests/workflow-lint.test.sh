#!/usr/bin/env bash
# workflow-lint runs actionlint on each CI workflow an agent writes, and hands
# its findings back (exit 2). A stub actionlint records the arguments it gets,
# so every decision the hook makes runs hermetically: which files it lints,
# the Gitea context ignore, the repo's runner-label list, the refusal, the
# setting off, missing tools and bad input. Where a real actionlint is on
# PATH, the real-lint cases run against it too.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/workflow-lint.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
opt=true
mkdir -p "$fx/bin"
cat > "$fx/bin/actionlint" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STUB_ARGS"; pwd > "$STUB_ARGS.cwd"
[ -n "${STUB_FAIL:-}" ] && { echo "ci.yml:3:5: $STUB_FAIL"; exit 1; }
exit 0
STUB
chmod +x "$fx/bin/actionlint"
export STUB_ARGS="$fx/args"
pl() { jq -nc --arg t "$1" --arg p "$2" '{hook_event_name:"PostToolUse",tool_name:$t,tool_input:{file_path:$p}}'; }
run() { # run <payload> [PATH]
  rm -f "$STUB_ARGS"
  PATH="${2:-$fx/bin:$PATH}" CLAUDE_PLUGIN_OPTION_GUARD_WORKFLOW_LINT=$opt "$BASH" "$hook" <<<"$1" >"$fx/out" 2>"$fx/err"
}
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
r="$fx/repo"; mkdir -p "$r/.gitea/workflows" "$r/.github/workflows" "$r/docs"
for f in .gitea/workflows/a.yml .gitea/workflows/b.yaml .github/workflows/c.yml .github/workflows/d.yaml docs/x.yml; do echo 'jobs: {}' > "$r/$f"; done
check "a Gitea workflow is linted from its repo root, with the gitea context ignored" \
  'run "$(pl Write "$r/.gitea/workflows/a.yml")"; [ $? = 0 ] && grep -qx "$r/.gitea/workflows/a.yml" "$STUB_ARGS" && grep -qx "undefined variable \"gitea\"" "$STUB_ARGS" && grep -qx "$r" "$STUB_ARGS.cwd"'
check "a .yaml Gitea workflow is linted" 'run "$(pl Edit "$r/.gitea/workflows/b.yaml")"; [ -s "$STUB_ARGS" ]'
check "a GitHub workflow is linted" 'run "$(pl MultiEdit "$r/.github/workflows/c.yml")"; [ -s "$STUB_ARGS" ]'
check "a .yaml GitHub workflow is linted" 'run "$(pl Write "$r/.github/workflows/d.yaml")"; [ -s "$STUB_ARGS" ]'
check "with no runner-label list, unknown labels are ignored" 'run "$(pl Write "$r/.github/workflows/c.yml")"; grep -qx "label \".+\" is unknown" "$STUB_ARGS" && ! grep -qx -- "-config-file" "$STUB_ARGS"'
printf 'self-hosted-runner:\n  labels: [own]\n' > "$r/.github/actionlint.yaml"
check "with the repo's actionlint.yaml, labels are judged by it" 'run "$(pl Write "$r/.github/workflows/c.yml")"; grep -qx -- "-config-file" "$STUB_ARGS" && grep -qx "$r/.github/actionlint.yaml" "$STUB_ARGS" && ! grep -q "is unknown" "$STUB_ARGS"'
mv "$r/.github/actionlint.yaml" "$r/.github/actionlint.yml"
check "an actionlint.yml is read too" 'run "$(pl Write "$r/.github/workflows/c.yml")"; grep -qx "$r/.github/actionlint.yml" "$STUB_ARGS"'
rm "$r/.github/actionlint.yml"
check "a finding is handed back with exit 2, naming the file" \
  'STUB_FAIL="property \"runs-on\" is missing" run "$(pl Write "$r/.gitea/workflows/a.yml")"; [ $? = 2 ] && grep -q "workflow-lint: actionlint refused $r/.gitea/workflows/a.yml" "$fx/err" && grep -q "runs-on" "$fx/err"'
check "a file outside the workflow folders is left alone" 'run "$(pl Write "$r/docs/x.yml")"; [ $? = 0 ] && [ ! -e "$STUB_ARGS" ]'
check "a workflow file that is gone is left alone" 'run "$(pl Write "$r/.gitea/workflows/gone.yml")"; [ $? = 0 ] && [ ! -e "$STUB_ARGS" ]'
check "another tool is left alone" 'run "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}"; [ $? = 0 ] && [ ! -e "$STUB_ARGS" ]'
check "input that isn't JSON is left alone" 'run "not json"; [ $? = 0 ] && [ ! -e "$STUB_ARGS" ]'
opt=false; check "setting off lints nothing" 'run "$(pl Write "$r/.gitea/workflows/a.yml")"; [ $? = 0 ] && [ ! -e "$STUB_ARGS" ]'
opt=0; check "setting 0 lints nothing" 'run "$(pl Write "$r/.gitea/workflows/a.yml")"; [ $? = 0 ] && [ ! -e "$STUB_ARGS" ]'; opt=true
mkdir -p "$fx/nolint"; ln -s "$(command -v jq)" "$fx/nolint/jq"
check "without actionlint it says so and passes" 'run "$(pl Write "$r/.gitea/workflows/a.yml")" "$fx/nolint"; [ $? = 0 ] && grep -q "actionlint is missing, so this guard is off" "$fx/err"'
mkdir -p "$fx/nosc"; ln -s "$(command -v jq)" "$fx/nosc/jq"; ln -s "$BASH" "$fx/nosc/bash"; ln -s "$fx/bin/actionlint" "$fx/nosc/actionlint"
check "without shellcheck it still lints, and says run: scripts go unchecked" 'run "$(pl Write "$r/.gitea/workflows/a.yml")" "$fx/nosc"; [ $? = 0 ] && [ -s "$STUB_ARGS" ] && grep -q "shellcheck is missing" "$fx/err"'
mkdir -p "$fx/.gx/repo2/.github/workflows"; echo 'jobs: {}' > "$fx/.gx/repo2/.github/workflows/e.yml"
check "a folder above the repo whose name starts .g does not move the root" 'run "$(pl Write "$fx/.gx/repo2/.github/workflows/e.yml")"; grep -qx "$fx/.gx/repo2" "$STUB_ARGS.cwd"'
check "machine-spirit step 4 names this hook and when to lint by hand" 'awk "/^4\\. /{on=1} /^5\\. /{on=0} on" "$(dirname "$hook")/../skills/building/machine-spirit/SKILL.md" | grep -q "The \`workflow-lint\` hook runs actionlint" && awk "/^4\\. /{on=1} /^5\\. /{on=0} on" "$(dirname "$hook")/../skills/building/machine-spirit/SKILL.md" | grep -q "actionlint not installed, or the hook switched off"'
check "without jq it passes quietly" 'run "$(pl Write "$r/.gitea/workflows/a.yml")" /nonexistent; [ $? = 0 ] && [ ! -e "$STUB_ARGS" ]'
# The real-lint cases, where a real actionlint is installed.
if command -v actionlint >/dev/null 2>&1; then
  real() { mkdir -p "$(dirname "$1")"; printf 'name: ci\non:\n  pull_request:\nconcurrency:\n  group: ci-${{ gitea.ref }}\njobs:\n  build:\n    runs-on: %s\n    steps:\n      - run: %s\n' "$2" "$3" > "$1"; CLAUDE_PLUGIN_OPTION_GUARD_WORKFLOW_LINT=true "$BASH" "$hook" <<<"$(pl Write "$1")" >/dev/null 2>&1; echo $?; }
  q="$fx/real"
  check "real actionlint: a clean Gitea workflow with an unlisted label passes" '[ "$(real "$q/.gitea/workflows/ok.yml" own-runner "echo ok")" = 0 ]'
  check "real actionlint: an apostrophe that ends bash -c early is refused" "[ \"\$(real \"\$q/.gitea/workflows/quote.yml\" own-runner \"bash -c 'it's broken'\")\" = 2 ]"
  check "real actionlint: a broken expression is refused" '[ "$(real "$q/.gitea/workflows/expr.yml" "\${{ matrix. }}" "echo ok")" = 2 ]'
  check "real actionlint: a clean GitHub workflow passes" '[ "$(real "$q/.github/workflows/ok.yaml" ubuntu-24.04 "echo ok")" = 0 ]'
  l="$fx/listed"; mkdir -p "$l/.github"; printf 'self-hosted-runner:\n  labels:\n    - own-runner\n' > "$l/.github/actionlint.yaml"
  check "real actionlint: a label the repo lists passes" '[ "$(real "$l/.gitea/workflows/ok.yml" own-runner "echo ok")" = 0 ]'
  check "real actionlint: a label the repo's list lacks is refused" '[ "$(real "$l/.gitea/workflows/label.yml" other-runner "echo ok")" = 2 ]'
else
  echo "note real-lint cases need actionlint on PATH; the stub cases above cover the hook's decisions"
fi
exit $fail
