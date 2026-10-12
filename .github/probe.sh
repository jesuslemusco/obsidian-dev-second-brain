#!/usr/bin/env bash
# Temporary: checks the Windows port in Git Bash on the Windows runner.
# Removed before the branch is merged.
set -u

say() { printf '\n=== %s ===\n' "$*"; }
yn() { if "$@"; then echo yes; else echo no; fi; }
# crs <file>: lines and carriage returns in a file.
crs() { printf '%s lines, %s CR' "$(wc -l <"$1" | tr -d ' ')" "$(tr -cd '\r' <"$1" | wc -c | tr -d ' ')"; }

t="$(mktemp -d)"
t="$(cd "$t" && pwd -P)"
echo "OSTYPE=${OSTYPE:-} $(bash --version | head -1)"
awk --version | head -1

# ------------------------------------------------------------------ the awk seam in the helper
say "awk seam: the helper keeps CRLF byte for byte"
crlf() { awk '{ printf "%s\r\n", $0 }' "$1"; }
edit() { # edit <second-brain> <vault>: the same three writes on task EX-1
  SECOND_BRAIN_VAULT="$2" bash "$1" task set EX-1 status=in-progress next="check the seam" >/dev/null
  SECOND_BRAIN_VAULT="$2" bash "$1" task note EX-1 "a note on this file" --session s1 >/dev/null
  SECOND_BRAIN_VAULT="$2" bash "$1" task tag EX-1 add docs/billing >/dev/null 2>&1
}
export SECOND_BRAIN_TODAY=2026-01-05 SECOND_BRAIN_CLAUDE_HOME="$t/seam home"
# A copy of the helper whose platform library does not define the awk function.
mkdir -p "$t/noseam"
cp -r bin scripts templates .claude-plugin "$t/noseam/"
awk '/^if sb_is_windows; then$/ { skip = 1 } !skip { print } skip && /^fi$/ { skip = 0 }' scripts/lib/platform.sh >"$t/noseam/scripts/lib/platform.sh"
echo "awk functions in the copy without the seam: $(grep -c '^  awk()' "$t/noseam/scripts/lib/platform.sh")"
for v in lf crlf crlf-noseam; do
  mkdir -p "$t/$v/.obsidian"
  SECOND_BRAIN_VAULT="$t/$v" bash bin/second-brain scaffold vault >/dev/null
  SECOND_BRAIN_VAULT="$t/$v" bash bin/second-brain scaffold project Example --path projects/example --keys EX >/dev/null 2>&1
  SECOND_BRAIN_VAULT="$t/$v" bash bin/second-brain task new EX-1 --title "Seam" >/dev/null
done
task="projects/example/tasks/EX-1/README.md"
crlf "$t/lf/$task" >"$t/crlf/$task"
crlf "$t/lf/$task" >"$t/crlf-noseam/$task"
echo "before the edits: LF file $(crs "$t/lf/$task"); CRLF file $(crs "$t/crlf/$task")"
edit bin/second-brain "$t/lf"
edit bin/second-brain "$t/crlf"
edit "$t/noseam/bin/second-brain" "$t/crlf-noseam"
crlf "$t/lf/$task" >"$t/expected.md"
echo "after, with the seam:    $(crs "$t/crlf/$task"); same bytes as the LF result given CRLF endings: $(yn cmp "$t/expected.md" "$t/crlf/$task")"
echo "after, without the seam: $(crs "$t/crlf-noseam/$task"); same bytes: $(yn cmp -s "$t/expected.md" "$t/crlf-noseam/$task")"
printf 'a line with LF only\n' >>"$t/crlf/$task"
printf 'a line with LF only\n' >>"$t/crlf-noseam/$task"
echo "doctor on a mixed file, with the seam:    $(SECOND_BRAIN_VAULT="$t/crlf" bash bin/second-brain doctor Example | grep 'line-endings')"
echo "doctor on a mixed file, without the seam: $(SECOND_BRAIN_VAULT="$t/crlf-noseam" bash "$t/noseam/bin/second-brain" doctor Example | grep 'line-endings')"

# ------------------------------------------------------------------ the link suite
say "scripts/test-link.sh"
bash scripts/test-link.sh >"$t/test-link.log" 2>&1
rc=$?
grep -v '^ok ' "$t/test-link.log"
echo "rc=$rc"
exit "$rc"
