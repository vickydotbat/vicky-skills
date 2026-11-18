#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p docs/adr docs/post-mortems docs/agents
printf "# Domain docs\n\nADR format: \`decision-record\`\n" > docs/agents/domain.md
cat > docs/post-mortems/2026-09-04-favourites-after-model-tidy.md <<"PM"
# Post-mortem: DM favourites broke after the model folder tidy

## Impact

By 2026-09-04, stored DM favourites pointed at the wrong creatures.

## Timeline

- 2026-09-03 18:00: the model folder tidy renumbered creature rows.
- 2026-09-04 10:00: favourites were remapped by hand.

## Detection

A DM reported it.

## Causes

- A row renumber broke stored references: favourites held row numbers.

## Earlier incidents

None found: searched docs/post-mortems for renumber and favourite.

## Lessons

- The model folder is data.

## Follow-ups

- Treat the model folder as data: ADR-0002
PM
cat > docs/post-mortems/2026-10-12-server-names-rows.md <<"PM"
# Post-mortem: server names pointed at the wrong rows

## Impact

By 2026-10-12, the server named the wrong items in DM tools.

## Timeline

- 2026-10-11 21:00: a content build renumbered item rows.
- 2026-10-12 09:00: names were remapped.

## Detection

A test in the release check.

## Causes

- A row renumber broke stored references: the server named rows by number.

## Earlier incidents

- docs/post-mortems/2026-09-04-favourites-after-model-tidy.md

## Lessons

- The server must name rows by key.

## Follow-ups

- Server names rows by key: ADR-0003
PM
cat > docs/post-mortems/2026-10-20-broken-portrait-links.md <<"PM"
# Post-mortem: portrait links broke in the forum

## Impact

By 2026-10-20, forum posts showed broken portraits.

## Timeline

- 2026-10-20 12:00: the image host moved its paths.

## Detection

Players reported it.

## Causes

- The image host changed its URL scheme, so stored references broke.

## Earlier incidents

None found: searched docs/post-mortems for portrait and image host.

## Lessons

- Store image keys, not host URLs.

## Follow-ups

- Proxy portraits through the forum: WEB-40
PM
printf "# ADR-0002: Treat the model folder as data\n" > docs/adr/0002-treat-the-model-folder-as-data.md
printf "# ADR-0003: Name server rows by key\n" > docs/adr/0003-name-server-rows-by-key.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
