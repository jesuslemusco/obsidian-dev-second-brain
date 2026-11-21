#!/usr/bin/env bash
# Scratch-vault tests for the helper: runs the area files of scripts/tests, each on a vault of its
# own in a temp dir, and prints one total.
# Usage: bash scripts/test.sh [area...], such as bash scripts/test.sh tasks
set -u
. "$(dirname "$0")/tests/lib.sh"

# ---------------------------------------------------------------- areas
# area_names: the name of each area file, in order.
area_names() {
  local f
  for f in "$here"/scripts/tests/*.sh; do
    f="$(basename "$f" .sh)"
    [ "$f" = lib ] || printf '%s\n' "$f"
  done
}
areas="${*:-$(area_names)}"
for a in $areas; do
  case "$a" in
    lib | */* | .*) known=0 ;;
    *) if [ -f "$here/scripts/tests/$a.sh" ]; then known=1; else known=0; fi ;;
  esac
  if [ "$known" -eq 0 ]; then
    names="$(area_names | tr '\n' ' ')"
    printf 'no area %s; the areas are: %s\n' "$a" "${names% }" >&2
    exit 2
  fi
done
# Each area prints its own total last. It is added to this one and left out of the output.
for a in $areas; do
  printf '== %s\n' "$a"
  "$BASH" "$here/scripts/tests/$a.sh" </dev/null | tee "$tmp/area.out" |
    awk '/^$/ { blank++; next } /^[0-9]+ passed, [0-9]+ failed$/ { blank = 0; next }
      { for (; blank > 0; blank--) print ""; print; fflush() }'
  rc="${PIPESTATUS[0]}"
  counts="$(tail -1 "$tmp/area.out" | sed -n 's/^\([0-9][0-9]*\) passed, \([0-9][0-9]*\) failed$/\1 \2/p')"
  if [ -z "$counts" ]; then
    fail "area $a: exit $rc before its total"
    continue
  fi
  n_pass=$((n_pass + ${counts% *}))
  n_fail=$((n_fail + ${counts#* }))
  if [ "$rc" -ne 0 ] && [ "${counts#* }" -eq 0 ]; then fail "area $a: exit $rc with no check failed"; fi
done

# ---------------------------------------------------------------- result
result
