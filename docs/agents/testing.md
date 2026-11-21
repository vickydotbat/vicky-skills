# Testing

Check: claude plugin validate . >/dev/null && tests/plugin-layout.test.sh >/dev/null && tests/skill-descriptions.test.sh >/dev/null && tests/skill-steps.test.sh >/dev/null && tests/hook-audit.test.sh
Mutation proof check: python3 tests/mutate-hooks.py --check
Mutation proof refresh: python3 tests/mutate-hooks.py --record

A hook script changes only with its mutation proof: run the refresh command, which mutates what changed, and commit `tests/mutation-proof.tsv` with the change.
