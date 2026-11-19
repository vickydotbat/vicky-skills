# Sourced by the memory-hog checks. Each kill in a systemd scope raises a desktop
# notice ("memory shortage avoided"), so the hog takes the fallback unless
# CAP_REAL_OOM=1 asks for a real kill. Mutant runs always take the fallback: a
# mutant that flips the scope choice would still kill a real hog.
hog=(python3 -c 'b = bytearray(256 * 1024 * 1024)'); quiet=()
{ [ -n "${MUTATE_HOOKS_INNER:-}" ] || [ "${CAP_REAL_OOM:-}" != 1 ]; } && { quiet=(CAP_NO_SCOPE=1); hog=(bash -c 'echo "Cannot allocate memory" >&2; exit 1'); }
