#!/usr/bin/env bash
# Runs the mutation pass over the hook scripts. See mutate-hooks.py.
exec python3 "$(dirname "$0")/mutate-hooks.py" "$@"
