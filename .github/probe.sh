#!/usr/bin/env bash
# Temporary: times the common reads against the scratch vault the main suite builds, in Git Bash
# on the Windows runner. Removed before the branch is merged.
set -u

echo "OSTYPE=${OSTYPE:-} $(bash --version | head -1)"

# Three ways to print the shared awk functions, twenty times each.
SB_ROOT=""
. scripts/lib/core.sh
text="$(sb_awk_lib)"
eval "f_read() { local t; IFS= read -r -d '' t <<'AWK'
$text
AWK
printf '%s' \"\$t\"; }"
esc="$(printf '%s' "$text" | command sed "s/'/'\\\\''/g")"
eval "f_printf() { printf '%s\n' '$esc'; }"
r20="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20"
for f in sb_awk_lib f_read f_printf; do
  [ "$($f)" = "$text" ] || echo "$f prints another text"
  s="$(date +%s%N)"
  for i in $r20; do x="$($f)"; done
  e="$(date +%s%N)"
  printf '%-12s %5s ms for 20 calls, %s bytes\n' "$f" "$(((e - s) / 1000000))" "${#x}"
done

# The main suite as it is, without its cleanup and its result lines, with the timings at its end.
timed="scripts/.timed.sh"
sed '/^trap /d' scripts/test.sh | sed '/^# -* result$/,$d' >"$timed"
cat >>"$timed" <<'EOF'
printf '\n=== timings: %s passed, %s failed before them ===\n' "$n_pass" "$n_fail"
# tm <label> <command...>: the fastest of three runs, in milliseconds.
tm() {
  local label="$1" best="" i s e ms
  shift
  for i in 1 2 3; do
    s="$(date +%s%N)"
    "$@" >/dev/null 2>&1
    e="$(date +%s%N)"
    ms=$(((e - s) / 1000000))
    if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best="$ms"; fi
  done
  printf '%-46s %6s ms\n' "$label" "$best"
}
printf 'vault: %s projects, %s task READMEs, %s notes\n' "$("$SB" projects | grep -c .)" \
  "$(find "$vault" -path '*/tasks/*/README.md' | grep -c .)" "$(find "$vault" -name '*.md' | grep -c .)"
tm "nothing (what the clock itself costs)" true
tm "version (start-up alone)" "$SB" version
tm "session-check" "$SB" session-check
tm "root" "$SB" root
tm "context, from a folder that is no project" "$SB" context
tm "context --cwd in a project of the vault" "$SB" context --cwd "$vault/$P/tasks"
tm "context --cwd in a recorded repository" "$SB" context --cwd "$tmp/other root/alpha-api"
tm "project --key EX" "$SB" project --key EX
tm "board Example" "$SB" board Example
tm "board Example All" "$SB" board Example All
tm "task head EX-1" "$SB" task head EX-1
tm "task head EX-1 --project Example" "$SB" task head EX-1 --project Example
tm "search Example \"status notes\"" "$SB" search Example "status notes"
tm "unresolved" "$SB" unresolved
tm "unresolved Example" "$SB" unresolved Example
tm "doctor Example" "$SB" doctor Example
rm -rf "$tmp"
EOF
bash "$timed" | sed -n '/^=== timings/,$p'
rm -f "$timed"
exit 0
