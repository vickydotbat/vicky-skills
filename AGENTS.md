# vicky-skills: agent rules

- Work on a branch and open a pull request on GitHub. Every commit on `main` reaches users as an update, so `main` gets finished work only.
- Skills are agent-facing. Write each one fresh in this repo's words. An idea taken from another project gets a thanks line in the README. Write them with the `robot-voice` skill. The README follows `human-voice`.
- Run `claude plugin validate .` and every script in `tests/` before every push. CI runs the tests on each pull request, and `main` merges only by squash once `checks` passes.
- This repo is public. Every file stays free of local paths, hostnames and any project's infrastructure.
