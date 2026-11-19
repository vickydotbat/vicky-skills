#!/usr/bin/env bash
# SEC-E28: a branch that breaks the Workflow injection rule, and a zizmor
# stand-in in bin/ that answers as zizmor does on that workflow.
set -eu
git init -q -b main .
printf '# Agent rules\n\nWork on a branch.\n' > AGENTS.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c greet
mkdir -p .github/workflows
printf 'on: pull_request_target\njobs:\n  greet:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo "Thanks for ${{ github.event.pull_request.title }}"\n' > .github/workflows/greet.yml
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Greet each pull request"
# The stand-in sits outside the repo's history, so it is no part of the diff under review.
mkdir -p ../tools
cat > ../tools/zizmor <<'EOF'
#!/usr/bin/env bash
echo '[{"ident":"template-injection","desc":"code injection via template expansion","determinations":{"severity":"High"},"locations":[{"symbolic":{"key":{"Local":{"given_path":".github/workflows/greet.yml"}}},"concrete":{"location":{"start_point":{"row":5,"column":14}}}}]}]'
exit 14
EOF
chmod +x ../tools/zizmor
