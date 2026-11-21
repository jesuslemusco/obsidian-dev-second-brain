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
# max_jobs: how many areas run at once. SECOND_BRAIN_TEST_JOBS=1 runs them one at a time.
max_jobs="${SECOND_BRAIN_TEST_JOBS:-}"
# With none, it is the number of processors, or 2 where no command tells it. A command that is
# missing would count as an undefined one, so each is looked for first.
if [ -z "$max_jobs" ]; then
  if command -v nproc >/dev/null 2>&1; then
    max_jobs="$(nproc)"
  elif command -v getconf >/dev/null 2>&1; then
    max_jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null)"
  else
    max_jobs="${NUMBER_OF_PROCESSORS:-}"
  fi
  case "$max_jobs" in "" | *[!0-9]* | 0) max_jobs=2 ;; esac
fi
case "$max_jobs" in
  "" | *[!0-9]* | 0)
    printf 'SECOND_BRAIN_TEST_JOBS is a whole number above 0, not %s\n' "$max_jobs" >&2
    exit 2
    ;;
esac
# start_area <area>: run it in the background; its output, errors and exit code go to files.
start_area() {
  ( "$BASH" "$here/scripts/tests/$1.sh" </dev/null >"$tmp/areas/$1.out" 2>"$tmp/areas/$1.err"
    printf '%s\n' "$?" >"$tmp/areas/$1.rc.part" && mv "$tmp/areas/$1.rc.part" "$tmp/areas/$1.rc" ) &
}
# show_area <area>: print its output, add its total to this one, and count a crash as a failure.
# Its own total line is left out of the output.
show_area() {
  local a="$1" out="$tmp/areas/$1.out" rc counts
  rc="$(cat "$tmp/areas/$a.rc")"
  printf '== %s\n' "$a"
  awk '/^$/ { blank++; next } /^[0-9]+ passed, [0-9]+ failed$/ { blank = 0; next }
    { for (; blank > 0; blank--) print ""; print }' "$out"
  cat "$tmp/areas/$a.err" >&2
  counts="$(tail -1 "$out" | sed -n 's/^\([0-9][0-9]*\) passed, \([0-9][0-9]*\) failed$/\1 \2/p')"
  if [ -z "$counts" ]; then
    # It stopped before its total: count the checks it printed, and the stop as one more failure.
    n_pass=$((n_pass + $(grep -c '^ok    ' "$out")))
    n_fail=$((n_fail + $(grep -c '^FAIL  ' "$out")))
    fail "area $a: exit $rc before its total"
    return
  fi
  n_pass=$((n_pass + ${counts% *}))
  n_fail=$((n_fail + ${counts#* }))
  if [ "$rc" -ne 0 ] && [ "${counts#* }" -eq 0 ]; then fail "area $a: exit $rc with no check failed"; fi
}
# Start an area while fewer than max_jobs run, and print each one, in area order, once it is done.
mkdir -p "$tmp/areas"
list=($areas)
started=0
printed=0
while [ "$printed" -lt "${#list[@]}" ]; do
  done_n=0
  for ((i = 0; i < started; i++)); do [ -f "$tmp/areas/${list[$i]}.rc" ] && done_n=$((done_n + 1)); done
  if [ "$started" -lt "${#list[@]}" ] && [ $((started - done_n)) -lt "$max_jobs" ]; then
    start_area "${list[$started]}"
    started=$((started + 1))
  elif [ "$printed" -lt "$started" ] && [ -f "$tmp/areas/${list[$printed]}.rc" ]; then
    show_area "${list[$printed]}"
    printed=$((printed + 1))
  else
    sleep 0.1 2>/dev/null || sleep 1
  fi
done
wait

# ---------------------------------------------------------------- result
result
