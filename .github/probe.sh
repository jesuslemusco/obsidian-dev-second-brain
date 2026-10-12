#!/usr/bin/env bash
# Temporary: times the common reads against the scratch vault the main suite builds, in Git Bash
# on the Windows runner, with the helper as it is and as it was before it started fewer processes.
# Removed before the branch is merged.
set -u

[ -n "${CI:-}" ] || { echo "probe: it fetches one old commit into the checkout, run it in CI only" >&2; exit 2; }
echo "OSTYPE=${OSTYPE:-} $(bash --version | head -1)"
before="8231b6d5a569eb3aada688ca790e67ece8f2d474"
old="$(mktemp -d)"
git fetch -q --depth=1 origin "$before"
git archive "$before" bin scripts templates .claude-plugin | tar -x -C "$old"
echo "the helper before: $(git log -1 --format='%h %s' "$before") ($(ls "$old" | tr '\n' ' '))"
export SB_OLD="$old/bin/second-brain"

# The main suite as it is, without its cleanup and its result lines, with the timings at its end.
timed="scripts/.timed.sh"
sed '/^trap /d' scripts/test.sh | sed '/^# -* result$/,$d' >"$timed"
cat >>"$timed" <<'EOF'
printf '\n=== timings: %s passed, %s failed before them ===\n' "$n_pass" "$n_fail"
# ms <command...>: the fastest of three runs, in milliseconds.
ms() {
  local best="" i s e t
  for i in 1 2 3; do
    s="$(date +%s%N)"
    "$@" >/dev/null 2>&1
    e="$(date +%s%N)"
    t=$(((e - s) / 1000000))
    if [ -z "$best" ] || [ "$t" -lt "$best" ]; then best="$t"; fi
  done
  printf '%s' "$best"
}
# tm <label> <args...>: time one helper command, now and before.
tm() {
  local label="$1"
  shift
  printf '%-46s %6s ms now %6s ms before\n' "$label" "$(ms "$SB" "$@")" "$(ms bash "$SB_OLD" "$@")"
}
printf 'vault: %s projects, %s task READMEs, %s notes\n' "$("$SB" projects | grep -c .)" \
  "$(find "$vault" -path '*/tasks/*/README.md' | grep -c .)" "$(find "$vault" -name '*.md' | grep -c .)"
printf '%-46s %6s ms\n' "nothing (what the clock itself costs)" "$(ms true)"
tm "version (start-up alone)" version
tm "session-check" session-check
tm "root" root
tm "context, from a folder that is no project" context
tm "context --cwd in a project of the vault" context --cwd "$vault/$P/tasks"
tm "context --cwd in a recorded repository" context --cwd "$tmp/other root/alpha-api"
tm "project --key EX" project --key EX
tm "board Example" board Example
tm "board Example All" board Example All
tm "task head EX-1" task head EX-1
tm "task head EX-1 --project Example" task head EX-1 --project Example
tm "search Example \"status notes\"" search Example "status notes"
tm "unresolved" unresolved
tm "unresolved Example" unresolved Example
tm "doctor Example" doctor Example
tm "link --check" link --check
rm -rf "$tmp"
EOF
bash "$timed" | sed -n '/^=== timings/,$p'
rm -f "$timed"
rm -rf "$old"
exit 0
