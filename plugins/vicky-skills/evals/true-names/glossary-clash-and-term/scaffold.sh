#!/usr/bin/env bash
set -eu
git init -q -b main .
cat > GLOSSARY.md <<'MD'
# Booking

Cancellation: a guest ends a booking ahead of the stay and gets the deposit back.
MD
cat > booking.py <<'PY'
def cancel(booking):
    booking.refund_deposit()
    booking.status = "cancelled"
PY
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
