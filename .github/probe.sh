#!/usr/bin/env bash
# Temporary: checks the Windows port in Git Bash on the Windows runner.
# Removed before the branch is merged.
set -u

say() { printf '\n=== %s ===\n' "$*"; }
yn() { if "$@"; then echo yes; else echo no; fi; }
# bytes <file or nothing for stdin>: the bytes on one line.
bytes() { od -An -c "$@" | tr -s ' \n' ' '; }

repo="$PWD"
t="$(mktemp -d)"
t="$(cd "$t" && pwd -P)"
echo "t=$t OSTYPE=${OSTYPE:-}"

# ------------------------------------------------------------------ the other suites, in the background
for s in test test-doctor test-snapshot; do
  (bash "scripts/$s.sh" >"$t/$s.log" 2>&1; echo "rc=$?" >>"$t/$s.log") &
done

# ------------------------------------------------------------------ grep and sed
say "grep and sed on a CRLF file"
f="$t/crlf.txt"
printf 'a\r\nb\r\n' >"$f"
cr="$(printf '\r')"
echo "grep -c CR at end: file=$(grep -c "$cr\$" "$f") stdin=$(grep -c "$cr\$" <"$f") pipe=$(cat "$f" | grep -c "$cr\$")"
echo "grep -U -c CR at end: file=$(grep -U -c "$cr\$" "$f") pipe=$(cat "$f" | grep -U -c "$cr\$")"
echo "grep a:    $(grep a "$f" | bytes)"
echo "grep -U a: $(grep -U a "$f" | bytes)"
echo "grep -c . on a piped string with CR: $(printf 'a\r\n' | grep -c "a$cr")"
echo "sed s:     $(sed 's/a/x/' "$f" | bytes)"
echo "sed -b s:  $(sed -b 's/a/x/' "$f" | bytes) pipe: $(cat "$f" | sed -b 's/a/x/' | bytes)"
echo "sed --version: $(sed --version | head -1) grep: $(grep --version | head -1)"

# ------------------------------------------------------------------ sb_mklink
say "sb_mklink over awkward folder names"
SB_ROOT=""
. scripts/lib/platform.sh
echo "sb_is_windows: $(yn sb_is_windows)"
u1="$(printf '\303\261and\303\272')"
u2="$(printf '\346\227\245\346\234\254')"
n=0
for name in 'plain' 'with space' 'amp&nospace' 'amp & space' 'paren(x86)' 'paren (x86)' 'caret^hat' \
  'caret ^ hat' 'pct%PATH%x' '100% sure' '%OS% and %PATH%' 'bang!x' 'bang ! x' 'comma,semi;eq=x' "quote'single" \
  'mix $#@~+{}[]' 'mix$#@~+{}[]' "$u1" "$u1 e" "$u2 $u1" 'trail dot.d' 'a=b&c|d' '-dash' '@at'; do
  n=$((n + 1))
  d="$t/mk/$n-$name"
  mkdir -p "$d/target" 2>/dev/null || { echo "$name | cannot mkdir"; continue; }
  echo hi >"$d/target/f.md"
  l="$d/link"
  out="$(sb_mklink "$d/target" "$l" 2>&1)"
  rc=$?
  printf '%s | rc=%s L=%s ef=%s read=%s same=%s out=[%s]\n' "$name" "$rc" "$(yn test -L "$l")" \
    "$(yn test "$l" -ef "$d/target")" "$(yn test "$(cat "$l/f.md" 2>/dev/null)" = hi)" \
    "$(yn test "$(readlink "$l" 2>/dev/null)" = "$d/target")" "$(printf '%s' "$out" | tr '\r\n' '  ' | cut -c1-100)"
  sb_rmlink "$l"
  printf '    rmlink rc=%s gone=%s kept=%s\n' "$?" "$(yn test ! -L "$l")" "$(ls "$d/target" | tr '\n' ' ')"
done
mkdir -p "$t/mk/x/target"
echo "onto an existing name: $(sb_mklink "$t/mk/x/target" "$t/mk/x" 2>&1 | tr '\r\n' '  '); rc=$(sb_mklink "$t/mk/x/target" "$t/mk/x" >/dev/null 2>&1; echo $?)"
echo keep >"$t/mk/x/file.md"
echo "to a file: rc=$(sb_mklink "$t/mk/x/file.md" "$t/mk/x/l1" >/dev/null 2>&1; echo $?) made=$(yn test -L "$t/mk/x/l1")"
echo "to a missing folder: rc=$(sb_mklink "$t/mk/x/none" "$t/mk/x/l2" >/dev/null 2>&1; echo $?) made=$(yn test -L "$t/mk/x/l2")"
echo "in a missing folder: rc=$(sb_mklink "$t/mk/x/target" "$t/mk/x/no/l3" >/dev/null 2>&1; echo $?)"
echo "rmlink on a real folder: rc=$(sb_rmlink "$t/mk/x/target"; echo $?) kept=$(yn test -d "$t/mk/x/target")"
(cd "$t/mk/x" && sb_mklink "$t/mk/x/target" "rel-link" && echo "relative link place: made=$(yn test -L "$t/mk/x/rel-link")")
echo "path in:  $(sb_path_in 'C:\Users\x y') $(sb_path_in 'c:/Users') $(sb_path_in '/C/Users') $(sb_path_in 'D:\') $(sb_path_in '\\server\share\x')"
echo "path out: $(sb_path_out '/c/Users/x y') $(sb_path_out /c) $(sb_path_out /tmp) $(sb_path_out /usr/bin) $(sb_path_out rel/x)"
echo "stray files in the checkout: $(ls "$repo" | tr '\n' ' ')"
unset -f awk

# ------------------------------------------------------------------ the awk seam in the helper
say "awk seam: the helper keeps CRLF byte for byte"
crlf() { command awk '{ printf "%s\r\n", $0 }' "$1"; }
edit() { # edit <second-brain> <vault>: the same three writes on task EX-1
  SECOND_BRAIN_VAULT="$2" bash "$1" task set EX-1 status=in-progress next="check the seam" >/dev/null
  SECOND_BRAIN_VAULT="$2" bash "$1" task note EX-1 "a note on this file" --session s1 >/dev/null
  SECOND_BRAIN_VAULT="$2" bash "$1" task tag EX-1 add docs/billing >/dev/null
}
export SECOND_BRAIN_TODAY=2026-01-05 SECOND_BRAIN_OBSIDIAN=none SECOND_BRAIN_CLAUDE_HOME="$t/seam home"
mkdir -p "$t/noseam"
cp -r bin scripts templates .claude-plugin "$t/noseam/"
command awk '/^if sb_is_windows; then$/ { skip = 1 } !skip { print } skip && /^fi$/ { skip = 0 }' scripts/lib/platform.sh >"$t/noseam/scripts/lib/platform.sh"
echo "the copy without the seam defines awk: $(grep -c '^  awk()' "$t/noseam/scripts/lib/platform.sh")"
for v in lf crlf crlf-noseam; do
  mkdir -p "$t/$v/.obsidian"
  SECOND_BRAIN_VAULT="$t/$v" bash bin/second-brain scaffold vault >/dev/null
  SECOND_BRAIN_VAULT="$t/$v" bash bin/second-brain scaffold project Example --path projects/example --keys EX >/dev/null
  SECOND_BRAIN_VAULT="$t/$v" bash bin/second-brain task new EX-1 --title "Seam" >/dev/null
done
task="projects/example/tasks/EX-1/README.md"
for v in crlf crlf-noseam; do
  crlf "$t/lf/$task" >"$t/$v/$task"
done
echo "before the edits: lf $(wc -l <"$t/lf/$task" | tr -d ' ') lines, $(tr -cd '\r' <"$t/lf/$task" | wc -c | tr -d ' ') CR; crlf $(wc -l <"$t/crlf/$task" | tr -d ' ') lines, $(tr -cd '\r' <"$t/crlf/$task" | wc -c | tr -d ' ') CR"
edit bin/second-brain "$t/lf"
edit bin/second-brain "$t/crlf"
edit "$t/noseam/bin/second-brain" "$t/crlf-noseam"
crlf "$t/lf/$task" >"$t/expected.md"
echo "after, with the seam:    $(wc -l <"$t/crlf/$task" | tr -d ' ') lines, $(tr -cd '\r' <"$t/crlf/$task" | wc -c | tr -d ' ') CR; same bytes as the LF result with CRLF endings: $(yn cmp "$t/expected.md" "$t/crlf/$task")"
echo "after, without the seam: $(wc -l <"$t/crlf-noseam/$task" | tr -d ' ') lines, $(tr -cd '\r' <"$t/crlf-noseam/$task" | wc -c | tr -d ' ') CR; same bytes: $(yn cmp -s "$t/expected.md" "$t/crlf-noseam/$task")"
echo "first lines with the seam:"
head -8 "$t/crlf/$task" | od -c | head -12
printf 'a line with LF only\n' >>"$t/crlf/$task"
echo "doctor line-endings, mixed file, with the seam:    $(SECOND_BRAIN_VAULT="$t/crlf" bash bin/second-brain doctor Example | grep 'line-endings')"
printf 'a line with LF only\n' >>"$t/crlf-noseam/$task"
echo "doctor line-endings, mixed file, without the seam: $(SECOND_BRAIN_VAULT="$t/crlf-noseam" bash "$t/noseam/bin/second-brain" doctor Example | grep 'line-endings')"

# ------------------------------------------------------------------ how the helper is started
say "starting the helper"
echo "bash + POSIX path:        $(bash "$repo/bin/second-brain" version)"
echo "bash + root\\..\\bin/name:  $(bash "$(cygpath -w "$repo")/bin/second-brain" version 2>&1)"
echo "bash + all backslashes:   $(bash "$(cygpath -w "$repo/bin/second-brain")" version 2>&1 | head -2 | tr '\n' ' ')"
echo "bash + drive form:        $(bash "$(cygpath -m "$repo/bin/second-brain")" version 2>&1 | head -2 | tr '\n' ' ')"
echo "direct, by PATH:          $(PATH="$repo/bin:$PATH" second-brain version 2>&1)"
echo "session-check, no vault:  $(SECOND_BRAIN_VAULT="$t/none" bash "$repo/bin/second-brain" session-check)"

# ------------------------------------------------------------------ the link suite
say "scripts/test-link.sh"
bash scripts/test-link.sh >"$t/test-link.log" 2>&1
echo "rc=$?"
grep -v '^ok ' "$t/test-link.log"

# ------------------------------------------------------------------ the other suites
wait
for s in test test-doctor test-snapshot; do
  say "scripts/$s.sh with the port so far"
  grep -c '^ok ' "$t/$s.log"
  grep -A4 '^FAIL' "$t/$s.log" | head -150
  tail -3 "$t/$s.log"
done

# ------------------------------------------------------------------ timing, with nothing else running
say "timing"
echo "session-check: $( { time SECOND_BRAIN_VAULT="$t/none" bash "$repo/bin/second-brain" session-check >/dev/null; } 2>&1 | tr '\n' ' ')"
echo "version:       $( { time bash "$repo/bin/second-brain" version >/dev/null; } 2>&1 | tr '\n' ' ')"
echo "test-link.sh:  $( { time bash scripts/test-link.sh >/dev/null 2>&1; } 2>&1 | tr '\n' ' ')"

say "link on eight skills and eight agents"
v="$t/big vault"
mkdir -p "$v/.obsidian"
export SECOND_BRAIN_VAULT="$v" SECOND_BRAIN_CLAUDE_HOME="$t/big home"
bash bin/second-brain scaffold vault >/dev/null
for i in 1 2 3 4 5 6 7 8; do
  mkdir -p "$v/claude/skills/s$i" "$v/claude/agents"
  printf -- '---\nname: s%s\ndescription: A skill.\n---\n' "$i" >"$v/claude/skills/s$i/SKILL.md"
  printf -- '---\nname: a%s\ndescription: An agent.\n---\n' "$i" >"$v/claude/agents/a$i.md"
done
echo "apply: $( { time bash bin/second-brain link --apply >/dev/null 2>&1; } 2>&1 | tr '\n' ' ')"
echo "check: $( { time bash bin/second-brain link --check >"$t/big.out"; } 2>&1 | tr '\n' ' ')"
head -3 "$t/big.out"
tail -2 "$t/big.out"
ls -l "$t/big home/agents"
exit 0
