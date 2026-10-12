#!/usr/bin/env bash
# Temporary: runs the five suites in Git Bash on the Windows runner, side by side, and prints
# what fails. Removed before the branch is merged.
set -u

t="$(mktemp -d)"
t="$(cd "$t" && pwd -P)"
echo "OSTYPE=${OSTYPE:-} $(bash --version | head -1)"
start="$(date +%s)"
for s in test test-link test-graph test-doctor test-snapshot; do
  (
    s0="$(date +%s)"
    bash "scripts/$s.sh" >"$t/$s.log" 2>&1
    echo "rc=$? seconds=$(($(date +%s) - s0))" >>"$t/$s.log"
  ) &
done
wait
echo "all five, side by side: $(($(date +%s) - start)) seconds"
rc=0
for s in test test-link test-graph test-doctor test-snapshot; do
  printf '\n=== scripts/%s.sh ===\n' "$s"
  grep -v '^ok ' "$t/$s.log" | head -"${PROBE_LINES:-220}"
  tail -1 "$t/$s.log" | grep -q '^rc=0 ' || rc=1
done
exit "$rc"
