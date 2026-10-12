#!/usr/bin/env bash
# Temporary: prints how Git Bash on the Windows runner behaves, to ground the Windows port.
# Removed before the branch is merged.
set -u

say() { printf '\n=== %s ===\n' "$*"; }
yn() { if "$@"; then echo yes; else echo no; fi; }
# bytes <file or - for stdin>: the bytes on one line.
bytes() { od -An -c "$@" | tr -s ' \n' ' '; }

t="$(mktemp -d)"
t="$(cd "$t" && pwd -P)"
echo "t=$t OSTYPE=${OSTYPE:-} MSYSTEM=${MSYSTEM:-} MSYS=${MSYS:-} HOME=${HOME:-}"
awk --version | head -1

# ------------------------------------------------------------------ awk
say "awk and line endings"
f="$t/crlf.txt"
printf 'a\r\nb\r\n' >"$f"
printf 'a\nb\r\nc\n' >"$t/mixed.txt"
p='{ printf "%s", (/\r$/ ? "CR " : "no ") }'
echo "file bytes:        $(bytes "$f")"
echo "plain file:        $(awk "$p" "$f")"
echo "plain stdin:       $(awk "$p" <"$f")"
echo "plain pipe:        $(cat "$f" | awk "$p")"
echo "-v BINMODE=3 file: $(awk -v BINMODE=3 "$p" "$f")"
echo "-v BINMODE=3 stdin: $(awk -v BINMODE=3 "$p" <"$f")"
echo "-v BINMODE=3 pipe: $(cat "$f" | awk -v BINMODE=3 "$p")"
echo "-v BINMODE=1 file: $(awk -v BINMODE=1 "$p" "$f") pipe: $(cat "$f" | awk -v BINMODE=1 "$p")"
echo "BEGIN BINMODE file: $(awk 'BEGIN { BINMODE = 3 } '"$p" "$f")"
echo "BEGIN BINMODE stdin: $(awk 'BEGIN { BINMODE = 3 } '"$p" <"$f")"
echo "BEGIN BINMODE pipe: $(cat "$f" | awk 'BEGIN { BINMODE = 3 } '"$p")"
echo "-b file:           $(awk -b "$p" "$f")"
echo "--posix file:      $(awk --posix "$p" "$f")"
echo "RS=\\n file:        $(awk -v 'RS=\n' "$p" "$f")"
echo "plain print file:  $(awk '{ print }' "$f" | bytes)"
echo "seam print file:   $(awk -v BINMODE=3 '{ print }' "$f" | bytes)"
echo "plain writes CR:   $(awk 'BEGIN { printf "x\r\ny\n" }' | bytes)"
echo "seam writes CR:    $(awk -v BINMODE=3 'BEGIN { printf "x\r\ny\n" }' | bytes)"
awk '{ print }' "$f" >"$t/o1"
echo "plain round trip same: $(yn cmp -s "$f" "$t/o1") -> $(bytes "$t/o1")"
awk -v BINMODE=3 '{ print }' "$f" >"$t/o2"
echo "seam round trip same:  $(yn cmp -s "$f" "$t/o2") -> $(bytes "$t/o2")"
awk -v BINMODE=3 '{ print }' <"$t/mixed.txt" >"$t/o3"
echo "seam mixed stdin same: $(yn cmp -s "$t/mixed.txt" "$t/o3") -> $(bytes "$t/o3")"
awk -v BINMODE=3 -v out="$t/o4" '{ print > out }' "$f"
echo "seam print > file same: $(yn cmp -s "$f" "$t/o4")"
awk -v out="$t/o5" '{ print > out }' "$f"
echo "plain print > file:    $(bytes "$t/o5")"
echo "seam getline:      $(awk -v BINMODE=3 -v f="$f" 'BEGIN { while ((getline l < f) > 0) printf "%s", (l ~ /\r$/ ? "CR " : "no ") }')"
echo "plain getline:     $(awk -v f="$f" 'BEGIN { while ((getline l < f) > 0) printf "%s", (l ~ /\r$/ ? "CR " : "no ") }')"
echo "seam LF file untouched: $(printf 'a\nb\n' >"$t/lf.txt"; awk -v BINMODE=3 '{ print }' "$t/lf.txt" | bytes)"

say "the awk seam as a shell function"
awk() { command awk -v BINMODE=3 "$@"; }
echo "env prefix: $(LC_ALL=C SB_X="env ok" awk -F'\t' "$p"' END { print ENVIRON["SB_X"], ENVIRON["LC_ALL"] }' "$f")"
echo "pipe:       $(printf 'a\r\nb\r\n' | LC_ALL=C awk '{ print }' | bytes)"
echo "LC_ALL after the call: ${LC_ALL:-unset}"
echo "inside \$( ) and a pipeline: $(printf 'k\tv\r\n' | awk -F'\t' '{ print $2 }' | bytes)"
echo "env awk skips the function: $(env LC_ALL=C awk "$p" "$f")"
unset -f awk

# ------------------------------------------------------------------ other tools
say "other tools and CRLF"
echo "grep -c CR\$ file:  $(grep -c $'\r$' "$f") stdin: $(grep -c $'\r$' <"$f") pipe: $(cat "$f" | grep -c $'\r$')"
echo "grep output:       $(grep a "$f" | bytes)"
echo "grep -x a (no CR): $(grep -cx a "$f")"
echo "sed output file:   $(sed 's/a/x/' "$f" | bytes) stdin: $(sed 's/a/x/' <"$f" | bytes)"
echo "sed -n l:          $(sed -n l "$f" | tr '\n' ' ')"
echo "sed -n 1p:         $(sed -n 1p "$f" | bytes)"
echo "sort:              $(sort "$f" | bytes)"
echo "head -1:           $(head -1 "$f" | bytes)"
echo "tail -1:           $(tail -1 "$f" | bytes)"
echo "tail -c 1:         $(tail -c 1 "$f" | bytes)"
echo "cut -c1-:          $(cut -c1- "$f" | bytes)"
echo "tr a x:            $(tr a x <"$f" | bytes)"
echo "cat:               $(cat "$f" | bytes)"
cat "$f" >"$t/c1"
echo "cat > file same:   $(yn cmp -s "$f" "$t/c1")"
printf 'a\nb\n' >"$t/c2"
echo "cmp CRLF vs LF differ: $(yn cmp -s "$f" "$t/c2")"
echo "wc -c:             $(wc -c <"$f" | tr -d ' ') wc -l: $(wc -l <"$f" | tr -d ' ')"
echo "uniq:              $(uniq "$f" | bytes)"
echo "bash read:         $(while IFS= read -r l; do case "$l" in *$'\r') printf 'CR ' ;; *) printf 'no ' ;; esac; done <"$f")"
x="$(cat "$f")"
echo "bash \$(cat):       $(printf '%s' "$x" | bytes)"
printf 'q\r\n' >"$t/p1"
echo "printf > file:     $(bytes "$t/p1")"
cat >"$t/p2" <<EOF
h
EOF
echo "here-doc > file:   $(bytes "$t/p2")"
echo "bash igncr: $(shopt -o igncr 2>&1 | tr '\t' ' ')"

# ------------------------------------------------------------------ paths
say "path forms"
w="$(cygpath -w "$t")"
m="$(cygpath -m "$t")"
echo "w=$w"
echo "m=$m"
echo "cygpath -u w:       $(cygpath -u "$w")"
echo "cygpath -u -- w:    $(cygpath -u -- "$w" 2>&1)"
echo "cygpath -m -- t:    $(cygpath -m -- "$t" 2>&1)"
echo "cygpath -m /tmp=$(cygpath -m /tmp) /usr/bin=$(cygpath -m /usr/bin) /=$(cygpath -m /) /c=$(cygpath -m /c) /c/=$(cygpath -m /c/)"
echo "cygpath -u C:/Users=$(cygpath -u C:/Users) C:=$(cygpath -u C:) C:/=$(cygpath -u C:/)"
echo "cygpath -u of the short tmp: $(cygpath -u "$(cygpath -m /tmp)")"
echo "cygpath -m //server/share/x: $(cygpath -m //server/share/x 2>&1)"
echo "cygpath -m a/b: $(cygpath -m a/b) -u 'a\\b': $(cygpath -u 'a\b')"
echo "cygpath -m of a missing path with a space: $(cygpath -m "/c/nope/x y")"
echo "cygpath -m trailing slash: $(cygpath -m "$t/")"
up="/$(printf '%s' "${t:1:1}" | tr a-z A-Z)${t:2}"
echo "upper drive $up: -d=$(yn test -d "$up") pwd -P=$(cd "$up" && pwd -P) pwd=$(cd "$up" && pwd)"
echo "-d on w: $(yn test -d "$w") -d on m: $(yn test -d "$m") -ef w t: $(yn test "$w" -ef "$t")"
short="$(cygpath -m /tmp)"
echo "short=$short"
echo "pwd -P on the short mixed form: $(cd "$short" && pwd -P)"
sp="/$(printf '%s' "${short:0:1}" | tr A-Z a-z)${short:2}"
echo "pwd -P on $sp: $(cd "$sp" && pwd -P)"
echo "pwd -P on /tmp: $(cd /tmp && pwd -P) on HOME: $(cd "$HOME" && pwd -P) cygpath -m HOME: $(cygpath -m "$HOME")"
echo "substring and replace: ${t:1:1} ${t:3:5} $(p2='a\b\c'; echo "${p2//\\//}") $(p3='a/b/c'; echo "${p3//\//-}") $(p4='a/b/c'; echo "${p4//\//\\}")"

# ------------------------------------------------------------------ cmd quoting
say "what cmd receives"
cmd //c 'echo A [%CMDCMDLINE%]'
cmd //c echo B "a b" 'c&d' "e f&g" '[%CMDCMDLINE%]'
SB_L='C:\x y\l&m' cmd //c 'echo C "%SB_L%" [%CMDCMDLINE%]'
SB_L='C:\x y\l&m' MSYS_NO_PATHCONV=1 cmd /c 'echo D "%SB_L%" [%CMDCMDLINE%]'
SB_L='C:\x y\l&m' MSYS2_ARG_CONV_EXCL='*' cmd /c 'echo E "%SB_L%" [%CMDCMDLINE%]'
SB_L='C:\x y\l&m' cmd //c echo F '"%SB_L%"' '[%CMDCMDLINE%]'
SB_L="$t" cmd //c 'echo G "%SB_L%"'
SB_L="/c/Users" cmd //c 'echo H "%SB_L%"'
echo "after the echoes rc=$?"

say "mklink variants over awkward folder names"
mk_a() { cmd //c mklink //J "$(cygpath -w "$2")" "$(cygpath -w "$1")"; }
mk_b1() { SB_L="$(cygpath -w "$2")" SB_T="$(cygpath -w "$1")" cmd //c 'mklink /J "%SB_L%" "%SB_T%"'; }
mk_b2() { SB_L="$(cygpath -w "$2")" SB_T="$(cygpath -w "$1")" MSYS_NO_PATHCONV=1 cmd /c 'mklink /J "%SB_L%" "%SB_T%"'; }
mk_b3() { SB_L="$(cygpath -w "$2")" SB_T="$(cygpath -w "$1")" MSYS2_ARG_CONV_EXCL='*' cmd /c 'mklink /J "%SB_L%" "%SB_T%"'; }
mk_b4() { SB_L="$(cygpath -w "$2")" SB_T="$(cygpath -w "$1")" cmd //d //s //c '"mklink /J "%SB_L%" "%SB_T%""'; }
n=0
u1="$(printf '\303\261and\303\272')"
u2="$(printf '\346\227\245\346\234\254')"
for name in 'plain' 'with space' 'amp&nospace' 'amp & space' 'paren(x86)' 'paren (x86)' 'caret^hat' \
  'pct%PATH%x' '100% sure' 'bang!x' 'comma,semi;eq=x' "quote'single" 'mix $#@~+{}[]' 'mix$#@~+{}[]' \
  "$u1" "$u1 e" "$u2 $u1"; do
  n=$((n + 1))
  d="$t/mk/$n-$name"
  mkdir -p "$d/target" 2>/dev/null || { echo "$name | cannot mkdir"; continue; }
  echo hi >"$d/target/f.md"
  for v in a b1 b2 b3 b4; do
    l="$d/link-$v"
    out="$(mk_$v "$d/target" "$l" 2>&1)"
    rc=$?
    rl="$(readlink "$l" 2>/dev/null)"
    printf '%s | %s | rc=%s L=%s ef=%s read=%s same=%s | %s\n' "$name" "$v" "$rc" "$(yn test -L "$l")" \
      "$(yn test "$l" -ef "$d/target")" "$(yn test "$(cat "$l/f.md" 2>/dev/null)" = hi)" \
      "$(yn test "$rl" = "$d/target")" "$(printf '%s' "$out" | tr '\r\n' '  ' | cut -c1-110)"
  done
done
echo "stray files made by a broken command line: $(ls "$PWD" | tr '\n' ' ')"

# ------------------------------------------------------------------ fixtures
say "links as fixtures, readlink forms, removal"
S() { MSYS=winsymlinks:nativestrict ln -s "$@"; }
fx="$t/fx"
mkdir -p "$fx/target dir" "$fx/links"
echo hi >"$fx/target dir/f.md"
S "$fx/target dir" "$fx/links/abs-dir"
echo "abs dir: rc=$? readlink=[$(readlink "$fx/links/abs-dir")] same=$(yn test "$(readlink "$fx/links/abs-dir")" = "$fx/target dir")"
S "$fx/target dir/f.md" "$fx/links/abs-file.md"
echo "abs file: rc=$? readlink=[$(readlink "$fx/links/abs-file.md")]"
S "../target dir/f.md" "$fx/links/rel-file.md"
echo "rel file: rc=$? readlink=[$(readlink "$fx/links/rel-file.md")] cat=$(cat "$fx/links/rel-file.md")"
S "../target dir" "$fx/links/rel-dir"
echo "rel dir: rc=$? readlink=[$(readlink "$fx/links/rel-dir")] -d=$(yn test -d "$fx/links/rel-dir")"
S "$fx/nowhere" "$fx/links/dangling"
echo "dangling: rc=$? readlink=[$(readlink "$fx/links/dangling")] -L=$(yn test -L "$fx/links/dangling") -e=$(yn test -e "$fx/links/dangling")"
S "$fx/nowhere/deeper.md" "$fx/links/dangling2.md"
echo "dangling2: rc=$? readlink=[$(readlink "$fx/links/dangling2.md")]"
S "/tmp/${t##*/}/fx/target dir" "$fx/links/tmp-dir"
echo "via /tmp: rc=$? readlink=[$(readlink "$fx/links/tmp-dir")]"
S "$fx/links/abs-dir" "$fx/links/hop"
echo "hop: rc=$? readlink=[$(readlink "$fx/links/hop")] -ef target: $(yn test "$fx/links/hop" -ef "$fx/target dir")"
cmd //c mklink //J "$(cygpath -w "$fx/links/junc")" "$(cygpath -w "$fx/target dir")" >/dev/null
echo "junction: readlink=[$(readlink "$fx/links/junc")] same=$(yn test "$(readlink "$fx/links/junc")" = "$fx/target dir")"
cmd //c mklink //J "$(cygpath -w "$fx/links/junc-short")" "$(cygpath -w "/tmp/${t##*/}/fx/target dir")" >/dev/null
echo "junction to the short form: readlink=[$(readlink "$fx/links/junc-short")]"
mkdir -p "$fx/gone"
cmd //c mklink //J "$(cygpath -w "$fx/links/junc-dead")" "$(cygpath -w "$fx/gone")" >/dev/null
rmdir "$fx/gone"
echo "dead junction: readlink=[$(readlink "$fx/links/junc-dead")] -L=$(yn test -L "$fx/links/junc-dead") -e=$(yn test -e "$fx/links/junc-dead")"
echo "mklink onto an existing name: $(cmd //c mklink //J "$(cygpath -w "$fx/links/junc")" "$(cygpath -w "$fx/target dir")" 2>&1 | tr '\r\n' '  ') rc=${PIPESTATUS[0]}"
echo "mklink to a file: $(cmd //c mklink //J "$(cygpath -w "$fx/links/junc-file")" "$(cygpath -w "$fx/target dir/f.md")" 2>&1 | tr '\r\n' '  ') -L=$(yn test -L "$fx/links/junc-file") -e=$(yn test -e "$fx/links/junc-file")"
echo "mklink to a missing folder: $(cmd //c mklink //J "$(cygpath -w "$fx/links/junc-none")" "$(cygpath -w "$fx/none")" 2>&1 | tr '\r\n' '  ') -L=$(yn test -L "$fx/links/junc-none")"
ls -l "$fx/links"
cmd //c dir //AL "$(cygpath -w "$fx/links")"
fsutil reparsepoint query "$(cygpath -w "$fx/links/junc")" 2>&1 | head -4
before="$(ls -l "$fx/links")"
sleep 1
echo "ls -l is stable: $(yn test "$(ls -l "$fx/links")" = "$before")"
for l in junc abs-dir abs-file.md rel-dir dangling junc-dead hop; do
  rm "$fx/links/$l"
  echo "rm $l: rc=$? gone=$(yn test ! -L "$fx/links/$l") target kept: $(ls "$fx/target dir" | tr '\n' ' ')"
done
rm -f "$fx/links/junc-short" "$fx/links/rel-file.md" "$fx/links/tmp-dir" "$fx/links/dangling2.md"
echo "rm -f the rest: rc=$? left: $(ls "$fx/links" | tr '\n' ' ') target kept: $(ls "$fx/target dir" | tr '\n' ' ')"
cmd //c mklink //J "$(cygpath -w "$fx/links/j2")" "$(cygpath -w "$fx/target dir")" >/dev/null
rm -rf "$fx/links"
echo "rm -rf a folder that holds a junction: rc=$? target kept: $(ls "$fx/target dir" | tr '\n' ' ')"
echo "env -u works: $(SB_Q=1 env -u SB_Q bash -c 'echo "${SB_Q:-unset}"')"

# ------------------------------------------------------------------ timing
say "timing"
r20="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20"
echo "20 forks:     $( { time (for i in $r20; do x="$(:)"; done); } 2>&1 | tr '\n' ' ')"
echo "20 true:      $( { time (for i in $r20; do /usr/bin/true; done); } 2>&1 | tr '\n' ' ')"
echo "20 cygpath:   $( { time (for i in $r20; do x="$(cygpath -m /c/x)"; done); } 2>&1 | tr '\n' ' ')"
echo "20 awk:       $( { time (for i in $r20; do awk 'BEGIN { }'; done); } 2>&1 | tr '\n' ' ')"
echo "20 cmd:       $( { time (for i in $r20; do cmd //c ver >/dev/null; done); } 2>&1 | tr '\n' ' ')"
exit 0
