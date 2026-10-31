# Testing

Mutation proof check: python3 tests/mutate-hooks.py --check
Mutation proof refresh: python3 tests/mutate-hooks.py --record

A hook script changes only with its mutation proof: run the refresh command, which mutates what changed, and commit `tests/mutation-proof.tsv` with the change.
