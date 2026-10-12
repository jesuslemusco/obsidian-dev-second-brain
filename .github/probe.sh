#!/usr/bin/env bash
# Temporary: prints how Git Bash on the Windows runner behaves, to ground the Windows port.
# Removed before the branch is merged.
set -u

say() { printf '\n=== %s ===\n' "$*"; }
yn() { if "$@"; then echo yes; else echo no; fi; }

say "shell and tools"
echo "OSTYPE=${OSTYPE:-}"
uname -a
echo "HOME=${HOME:-}"
echo "USERPROFILE=${USERPROFILE:-}"
echo "MSYS=${MSYS:-}"
bash --version | head -1
awk --version 2>/dev/null | head -1
for c in perl timeout readlink cygpath pgrep tasklist cmd find sort mktemp cmp od xargs; do
  printf '%s -> %s\n' "$c" "$(command -v "$c" 2>/dev/null || echo MISSING)"
done
echo "core.autocrlf=$(git config --get core.autocrlf)"
echo "core.symlinks=$(git config --get core.symlinks)"
echo "first bytes of bin/second-brain:"
head -c 24 bin/second-brain | od -c | head -2
echo "git mode: $(git ls-files -s bin/second-brain)"
echo "executable in bash: $(yn test -x bin/second-brain)"

t="$(mktemp -d)"
say "path forms"
echo "posix: $t"
echo "win:   $(cygpath -w "$t")"
echo "mixed: $(cygpath -m "$t")"
echo "back:  $(cygpath -u "$(cygpath -w "$t")")"
echo "mixed to posix: $(cygpath -u "$(cygpath -m "$t")")"
echo "cd to win form: $(cd "$(cygpath -w "$t")" && pwd -P)"
echo "cd to mixed form: $(cd "$(cygpath -m "$t")" && pwd -P)"
echo "-d on mixed form: $(yn test -d "$(cygpath -m "$t")")"
echo "pwd -W: $(cd "$t" && pwd -W 2>&1)"

mkdir -p "$t/target/sub" "$t/links"
echo hi >"$t/target/f.md"
echo a >"$t/file.md"

say "default ln -s on a folder"
ln -s "$t/target" "$t/links/default-dir"
echo "rc=$? -L=$(yn test -L "$t/links/default-dir") -d=$(yn test -d "$t/links/default-dir")"
say "default ln -s on a file"
ln -s "$t/file.md" "$t/links/default-file.md"
echo "rc=$? -L=$(yn test -L "$t/links/default-file.md") -f=$(yn test -f "$t/links/default-file.md")"

say "junction made with cmd mklink"
cmd //c mklink //J "$(cygpath -w "$t/links/junc")" "$(cygpath -w "$t/target")"
echo "mklink rc=$?"
echo "-L=$(yn test -L "$t/links/junc") -d=$(yn test -d "$t/links/junc") -e=$(yn test -e "$t/links/junc")"
echo "readlink: $(readlink "$t/links/junc"; echo " rc=$?")"
echo "-ef target: $(yn test "$t/links/junc" -ef "$t/target")"
echo "cd -P: $(cd -P "$t/links/junc" && pwd -P)"
echo "ls through it: $(ls "$t/links/junc" | tr '\n' ' ')"
echo "file through it: $(cat "$t/links/junc/f.md")"

say "remove a junction with rm -f"
rm -f "$t/links/junc"
echo "rc=$? still there=$(yn test -e "$t/links/junc") target kept: $(ls "$t/target" | tr '\n' ' ')"

say "remove a junction with bash rmdir"
cmd //c mklink //J "$(cygpath -w "$t/links/junc2")" "$(cygpath -w "$t/target")" >/dev/null
rmdir "$t/links/junc2"
echo "rc=$? still there=$(yn test -e "$t/links/junc2") target kept: $(ls "$t/target" | tr '\n' ' ')"

say "remove a junction with cmd rmdir"
cmd //c mklink //J "$(cygpath -w "$t/links/junc3")" "$(cygpath -w "$t/target")" >/dev/null
cmd //c rmdir "$(cygpath -w "$t/links/junc3")"
echo "rc=$? still there=$(yn test -e "$t/links/junc3") target kept: $(ls "$t/target" | tr '\n' ' ')"

say "dangling junction"
mkdir -p "$t/gone"
cmd //c mklink //J "$(cygpath -w "$t/links/dangling")" "$(cygpath -w "$t/gone")" >/dev/null
rmdir "$t/gone"
echo "-L=$(yn test -L "$t/links/dangling") -e=$(yn test -e "$t/links/dangling")"
echo "readlink: $(readlink "$t/links/dangling"; echo " rc=$?")"
rm -f "$t/links/dangling"
echo "rm -f rc=$? still listed=$(yn test -L "$t/links/dangling")"

say "junction made with a relative or mixed-form target"
cmd //c mklink //J "$(cygpath -w "$t/links/junc-mixed")" "$(cygpath -m "$t/target")"
echo "mixed target rc=$? -L=$(yn test -L "$t/links/junc-mixed")"

say "native symlinks (winsymlinks:nativestrict)"
MSYS=winsymlinks:nativestrict ln -s "$t/file.md" "$t/links/sym-file.md"
echo "file rc=$? -L=$(yn test -L "$t/links/sym-file.md") readlink=$(readlink "$t/links/sym-file.md")"
MSYS=winsymlinks:nativestrict ln -s "$t/target" "$t/links/sym-dir"
echo "dir rc=$? -L=$(yn test -L "$t/links/sym-dir") readlink=$(readlink "$t/links/sym-dir")"
MSYS=winsymlinks:nativestrict ln -s "../target/f.md" "$t/links/sym-rel.md"
echo "relative rc=$? -L=$(yn test -L "$t/links/sym-rel.md") readlink=$(readlink "$t/links/sym-rel.md") cat=$(cat "$t/links/sym-rel.md")"
MSYS=winsymlinks:nativestrict ln -s "$t/nowhere" "$t/links/sym-dangling"
echo "dangling rc=$? -L=$(yn test -L "$t/links/sym-dangling") -e=$(yn test -e "$t/links/sym-dangling")"
ls -la "$t/links"

say "time limits"
perl -e 'alarm shift; exec @ARGV' 2 sleep 5
echo "perl alarm rc=$?"
timeout 2 sleep 5
echo "timeout rc=$?"

say "awk and line endings"
printf 'a\r\nb\r\n' >"$t/crlf.txt"
echo "awk sees CR: $(awk '{ print (/\r$/ ? "yes" : "no") }' "$t/crlf.txt" | tr '\n' ' ')"
echo "awk writes: $(printf 'x\n' | awk '{ print }' | od -c | head -1)"
echo "date: $(date +%Y-%m-%d)"
echo "cost of 20 spawns: $( { time (for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do /usr/bin/true; done); } 2>&1 | tr '\n' ' ')"

rm -rf "$t/links" 2>/dev/null
echo "target after cleanup of links: $(ls "$t/target" 2>&1 | tr '\n' ' ')"

for s in test.sh test-link.sh test-doctor.sh test-snapshot.sh; do
  say "scripts/$s as it is today"
  bash "scripts/$s" 2>&1 | tail -40
  echo "rc=${PIPESTATUS[0]}"
done
exit 0
