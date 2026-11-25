# DR-8 change: a Markdown-only rerun keeps Standards

## DR-8 (changed)
tests/deathmatch_reruns_approved_examples.test.sh:129
- [x] approve

Given an earlier verdict, and new commits that change only Markdown
When deathmatch runs again
Then Intent, Standards and Claims fight, Standards reads only the commits since the verdict, and the report names each opponent left out and why

Source: Vicky's "change" on the soapbox, 2026-11-26. Was: "Then only Intent and Claims fight, and the report names each opponent left out and why".

## DR-8b (new, boundary partner)
tests/deathmatch_reruns_approved_examples.test.sh:new
- [x] approve

Given an earlier verdict, and no commit since it
When deathmatch runs again
Then no opponent but Intent fights, and the report names each opponent left out and why
