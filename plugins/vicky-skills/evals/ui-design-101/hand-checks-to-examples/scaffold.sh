#!/usr/bin/env bash
set -eu
git init -q -b main .
cat > admin.html <<'HTML'
<table id="pages">
 <tr><td>Old page 1</td><td><button onclick="if(confirm('Sure?')) purge(1)">Purge</button></td></tr>
 <tr><td>Old page 2</td><td><button onclick="if(confirm('Sure?')) purge(2)">Purge</button></td></tr>
</table>
HTML
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
