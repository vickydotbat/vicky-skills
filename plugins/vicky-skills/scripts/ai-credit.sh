# shellcheck shell=bash
# Sourced by git-guard and pr-guard, so both read AI credit the same way: a
# Co-Authored-By line or a "Generated with Claude" footer.
credits_ai() { grep -Eqi 'co-authored-by|generated with.*claude' <<<"$1"; }
