#!/usr/bin/env bash
# A game repo with unit tests that can't reach the first-login chain, and a
# simulated-player harness, documented only in its own folder, that can.
set -eu
git init -q -b main .
mkdir -p tests/unit tests/integration src docs/agents
printf '# Unit tests\n\nRun with `make unit`. They load scripts in isolation; nothing here starts the engine.\n' > tests/unit/README.md
printf '# Simulated players\n\n`tests/integration/sim.py` starts the dev server and connects headless player clients.\nA test creates characters, logs them in, and reads what the client was sent: windows opened, messages, area changes.\nRun with `make sim`.\n' > tests/integration/README.md
printf 'def login(name, new=False): ...\ndef windows_opened(client): ...\n' > tests/integration/sim.py
printf '// first-login chain: engine event -> on_client_enter -> region picker\n' > src/on_client_enter.nss
printf '# Testing\n\nApproved tests go in files ending `_approved_examples`.\n' > docs/agents/testing.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
