#!/usr/bin/env bash
# An empty repo: the download already ran, and the prompt gives its output
# The eval harness leaves plugin options unfilled.
set -eu
git init -q -b main .
git -c user.name=eval -c user.email=eval@example.invalid commit -q --allow-empty -m start
