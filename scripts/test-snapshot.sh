#!/usr/bin/env bash
# Scratch-vault tests for snapshot and compare.
# Usage: bash scripts/test-snapshot.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
SB="$here/bin/second-brain"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-snap-test.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# The suite compares bytes. On Windows, in Git Bash, the platform library gives it the awk, grep
# and sed that keep every CR, as the helper has them.
. "$here/scripts/lib/platform.sh"

vault="$tmp/vault"
links="$tmp/claude-home"
mkdir -p "$vault/.obsidian" "$links/skills" "$links/agents" "$tmp/userdir"
export HOME="$tmp/userdir"
export SECOND_BRAIN_VAULT="$vault"
export SECOND_BRAIN_CLAUDE_HOME="$links"
export SECOND_BRAIN_TODAY="2026-01-10"
unset CLAUDE_SESSION_ID SECOND_BRAIN_NOW

P="projects/example"
SNAPS=".second-brain/snapshots"
TAB="$(printf '\t')"
CR="$(printf '\r')"
NL='
'
n_pass=0
n_fail=0
OUT=""
ERR=""
RC=0

pass() {
  n_pass=$((n_pass + 1))
  printf 'ok    %s\n' "$1"
}
fail() {
  n_fail=$((n_fail + 1))
  printf 'FAIL  %s\n' "$1"
  shift
  while [ $# -gt 0 ]; do
    printf '      %s\n' "$1"
    shift
  done
}
# run <command...>: capture stdout, stderr and the exit code.
run() {
  OUT="$("$@" 2>"$tmp/stderr")"
  RC=$?
  ERR="$(cat "$tmp/stderr")"
}
sb() { run "$SB" "$@"; }
rc_is() {
  if [ "$RC" -eq "$2" ]; then pass "$1"; else fail "$1" "exit $RC, wanted $2" "stdout: $OUT" "stderr: $ERR"; fi
}
is() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "got:    $2" "wanted: $3"; fi
}
out_is() { is "$1" "$OUT" "$2"; }
out_has() {
  case "$OUT" in *"$2"*) pass "$1" ;; *) fail "$1" "missing: $2" "in: $OUT" ;; esac
}
out_lacks() {
  case "$OUT" in *"$2"*) fail "$1" "unwanted: $2" "in: $OUT" ;; *) pass "$1" ;; esac
}
err_has() {
  case "$ERR" in *"$2"*) pass "$1" ;; *) fail "$1" "missing: $2" "in stderr: $ERR" ;; esac
}
exists() {
  if [ -e "$2" ]; then pass "$1"; else fail "$1" "missing: $2"; fi
}
same() { # same <desc> <file> <file>
  if cmp -s "$2" "$3"; then pass "$1"; else fail "$1" "$2 and $3 differ"; fi
}
# shown <path>: the path as the helper prints it; on Windows that is the drive form.
shown() {
  if sb_is_windows; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}
# symlink <target> <link>: a real symlink on every system; on Windows a plain ln -s makes a copy.
symlink() {
  if sb_is_windows; then MSYS=winsymlinks:nativestrict ln -s "$1" "$2"; else ln -s "$1" "$2"; fi
}

# ---------------------------------------------------------------- syntax
for f in "$here/scripts/lib/snapshot.sh" "$here/scripts/test-snapshot.sh"; do
  if bash -n "$f" 2>"$tmp/stderr"; then pass "syntax: ${f#"$here"/}"; else fail "syntax: ${f#"$here"/}" "$(cat "$tmp/stderr")"; fi
done

# ---------------------------------------------------------------- a scratch vault
sb scaffold vault
rc_is "setup: scaffold vault" 0
sb scaffold project Example --path "$P" --keys EX
rc_is "setup: scaffold project" 0
for id in EX-1 EX-2 EX-3; do
  sb task new "$id" --project Example --title "Task $id"
done
rc_is "setup: three tasks" 0

# ---------------------------------------------------------------- snapshot
find "$vault" -type f ! -path "$vault/.second-brain/*" | sort >"$tmp/files.before"
sb snapshot base
rc_is "snapshot: exit 0" 0
out_is "snapshot: prints the folder, vault-relative" "$SNAPS/base"
for f in unresolved.txt aliases.txt tasks.tsv links.txt doctor.txt; do
  exists "snapshot: writes $f" "$vault/$SNAPS/base/$f"
done
is "snapshot: five files, no more" "$(ls "$vault/$SNAPS/base" | grep -c '')" "5"
is "snapshot: tasks.tsv lists project, id and status" "$(cat "$vault/$SNAPS/base/tasks.tsv")" \
  "Example${TAB}EX-1${TAB}planned${NL}Example${TAB}EX-2${TAB}planned${NL}Example${TAB}EX-3${TAB}planned"
is "snapshot: unresolved.txt is empty on a scaffolded vault" "$(wc -c <"$vault/$SNAPS/base/unresolved.txt" | tr -d ' ')" "0"
is "snapshot: aliases.txt lists alias and vault path for the tasks" "$(grep '^EX-' "$vault/$SNAPS/base/aliases.txt")" \
  "EX-1${TAB}$P/tasks/EX-1/README.md${NL}EX-2${TAB}$P/tasks/EX-2/README.md${NL}EX-3${TAB}$P/tasks/EX-3/README.md"
is "snapshot: aliases.txt covers the notes outside the projects" "$(grep -c "^Obsidian Conventions${TAB}obsidian-conventions.md\$" "$vault/$SNAPS/base/aliases.txt")" "1"
is "snapshot: no file says unavailable" "$(cat "$vault/$SNAPS/base"/* | grep -c '^unavailable$' || true)" "0"
find "$vault" -type f ! -path "$vault/.second-brain/*" | sort >"$tmp/files.after"
same "snapshot: writes nothing outside its folder" "$tmp/files.before" "$tmp/files.after"
cp "$vault/$SNAPS/base/tasks.tsv" "$tmp/tasks.before"
sb snapshot base
rc_is "snapshot: an existing name gives exit 6" 6
err_has "snapshot: says it exists" "already exists"
same "snapshot: the existing one is left alone" "$tmp/tasks.before" "$vault/$SNAPS/base/tasks.tsv"
run env SECOND_BRAIN_NOW=2026-01-10-153000 "$SB" snapshot
out_is "snapshot: no name takes SECOND_BRAIN_NOW" "$SNAPS/2026-01-10-153000"
run env SECOND_BRAIN_NOW=07:08:09 "$SB" snapshot
out_is "snapshot: a bare time is joined to today's date" "$SNAPS/2026-01-10-070809"
sb snapshot
case "$OUT" in
  "$SNAPS"/2026-01-10-[0-9][0-9][0-9][0-9][0-9][0-9]) pass "snapshot: no name gives a date and time that sorts" ;;
  *) fail "snapshot: no name gives a date and time that sorts" "got: $OUT" ;;
esac
rm -rf "$vault/$SNAPS/${OUT##*/}" "$vault/$SNAPS/2026-01-10-153000" "$vault/$SNAPS/2026-01-10-070809"
sb snapshot ../escape
rc_is "snapshot: a name with a slash gives exit 5" 5
sb snapshot one two
rc_is "snapshot: two names give exit 5" 5

# ---------------------------------------------------------------- compare
HEAD="snapshot: $SNAPS/base"
sb compare
rc_is "compare: exit 0 right after a snapshot" 0
out_is "compare: no differences, every view compared" "$HEAD${NL}no differences"
sb task set EX-2 status=in-progress
sb task new EX-4 --project Example --title "Task EX-4"
sb compare
rc_is "compare: exit 1 when something differs" 1
out_is "compare: reports the new task, its alias and the changed status, nothing else" \
  "$HEAD${NL}aliases added:${NL}  EX-4${TAB}$P/tasks/EX-4/README.md${NL}tasks added:${NL}  Example | EX-4 | planned${NL}tasks changed:${NL}  Example | EX-2 | planned -> in-progress"
rm -rf "$vault/$P/tasks/EX-3"
sb compare
rc_is "compare: exit 1 after a task folder is removed" 1
out_has "compare: reports the removed task" "tasks removed:${NL}  Example | EX-3 | planned"
out_has "compare: reports the removed alias" "aliases removed:${NL}  EX-3${TAB}$P/tasks/EX-3/README.md"
is "compare: sections in the order added, removed, changed" \
  "$(printf '%s\n' "$OUT" | grep '^tasks ' | tr '\n' ' ')" "tasks added: tasks removed: tasks changed: "
sb snapshot later
sb compare
out_is "compare: takes the newest snapshot by name" "snapshot: $SNAPS/later${NL}no differences"
sb compare base
rc_is "compare <name>: exit 1, the named snapshot differs" 1
out_has "compare <name>: uses the named snapshot" "snapshot: $SNAPS/base"
out_has "compare <name>: still sees the changes" "Example | EX-2 | planned -> in-progress"
sb compare no-such
rc_is "compare: an unknown name gives exit 1" 1
err_has "compare: says which name is missing" "no snapshot named no-such"
is "compare: leaves the snapshots alone" "$(ls "$vault/$SNAPS" | tr '\n' ' ')" "base later "
same "compare: leaves the snapshot files alone" "$tmp/tasks.before" "$vault/$SNAPS/base/tasks.tsv"
mv "$vault/.second-brain" "$tmp/second-brain.aside"
sb compare
rc_is "compare: no snapshot gives exit 1" 1
err_has "compare: says there is no snapshot" "no snapshot to compare with"
out_is "compare: no snapshot prints nothing on stdout" ""
mv "$tmp/second-brain.aside" "$vault/.second-brain"

# ---------------------------------------------------------------- the diff, on two view folders
SB_PLUGIN_ROOT="$here"
SB_ROOT=""
for lib in "$here"/scripts/lib/*.sh; do . "$lib"; done
a="$tmp/a"
b="$tmp/b"
mkdir -p "$a" "$b"
printf '%s\n' 'kept link' 'gone link' >"$a/unresolved.txt"
printf '%s\n' 'new link' 'kept link' >"$b/unresolved.txt"
printf 'Alpha\tx.md\nBeta\ty.md\n' >"$a/aliases.txt"
printf 'Alpha\tx.md\nGamma\tz.md\n' >"$b/aliases.txt"
printf 'Example\tEX-1\tplanned\n' >"$a/tasks.tsv"
cp "$a/tasks.tsv" "$b/tasks.tsv"
printf '%s\n' 'one | skill | linked | src/one' 'two | agent | linked | src/two' >"$a/links.txt"
printf '%s\n' 'one | skill | missing | src/one' 'two | agent | linked | src/two' >"$b/links.txt"
printf 'ok | pointer | vault | 0 | - | -\n' >"$a/doctor.txt"
printf 'fail | pointer | vault | 1 | - | -\n' >"$b/doctor.txt"
OUT="$(sb_snap_diff "$a" "$b")"
is "diff: returns 1 when a view differs" "$?" "1"
out_is "diff: unresolved, aliases and links sections" \
  "unresolved added:${NL}  new link${NL}unresolved removed:${NL}  gone link${NL}aliases added:${NL}  Gamma${TAB}z.md${NL}aliases removed:${NL}  Beta${TAB}y.md${NL}links changed:${NL}  was: one | skill | linked | src/one${NL}  now: one | skill | missing | src/one"
out_lacks "diff: doctor.txt is not diffed" "pointer"
is "diff: writes nothing into the folders" "$(ls "$a" | grep -c '') $(ls "$b" | grep -c '')" "5 5"
cp "$a/aliases.txt" "$b/aliases.txt"
cp "$a/links.txt" "$b/links.txt"
: >"$a/unresolved.txt"
OUT="$(sb_snap_diff "$a" "$b")"
out_is "diff: an empty view is compared" "unresolved added:${NL}  kept link${NL}  new link"
cp "$b/unresolved.txt" "$a/unresolved.txt"
rm -f "$b/links.txt"
OUT="$(sb_snap_diff "$a" "$b")"
is "diff: a missing file is no difference" "$?" "0"
out_is "diff: a missing file is named as not compared" "not compared: links.txt"

# ---------------------------------------------------------------- the links and doctor views
SB_ROOT="$vault"
is "links view: an empty link directory gives no rows" "$(SECOND_BRAIN_CLAUDE_HOME="$tmp/nowhere" sb_snap_links)" ""
sb_link_scan() {
  printf '%s\n' 'zeta | skill | linked | src/zeta' 'alpha | agent | missing | src/alpha'
  exit 4
}
cmd_doctor() {
  printf 'fail | pointer | vault | 1 | - | run vault-setup\n'
  exit 1
}
is "links view: the link library's rows, sorted" "$(sb_snap_links)" \
  "alpha | agent | missing | src/alpha${NL}zeta | skill | linked | src/zeta"
sb_snap_build "$b" doctor
is "build: an exit inside the link scan or the doctor does not end it" "$?" "0"
is "doctor view: holds the doctor's rows" "$(cat "$b/doctor.txt")" "fail | pointer | vault | 1 | - | run vault-setup"
is "build: tasks read from the files" "$(cut -f2,3 "$b/tasks.tsv" | tr '\t\n' ': ')" "EX-1:planned EX-2:in-progress EX-4:planned "
unset -f sb_link_scan cmd_doctor
SB_ROOT=""

# ---------------------------------------------------------------- unresolved links and aliases, read from the files
printf '%s\n' '# Notes' '' 'See [[zebra]] and [[apple|an apple]], and [[zebra]] again.' '`[[in-code]]`' >"$vault/$P/docs/notes.md"
printf -- '---\naliases: [Mango Notes, "Second: name"]\n---\n\n[[papaya]]\n' >"$vault/$P/docs/mango.md"
mkdir -p "$vault/.trash"
printf -- '---\naliases:\n  - Thrown away\n---\n\n[[in-the-trash]]\n' >"$vault/.trash/old.md"
sb snapshot with-links
rc_is "snapshot: exit 0 with unresolved links in the vault" 0
is "snapshot: unresolved.txt holds note and link, sorted, once each, with no line number" "$(cat "$vault/$SNAPS/with-links/unresolved.txt")" \
  "$P/docs/mango.md: [[papaya]]${NL}$P/docs/notes.md: [[apple|an apple]]${NL}$P/docs/notes.md: [[zebra]]"
is "snapshot: aliases.txt holds the aliases of a note, inline list and quotes read" "$(grep 'docs/mango.md$' "$vault/$SNAPS/with-links/aliases.txt")" \
  "Mango Notes${TAB}$P/docs/mango.md${NL}Second: name${TAB}$P/docs/mango.md"
is "snapshot: a dot folder is not read" "$(cat "$vault/$SNAPS/with-links"/*.txt | grep -c -e 'in-the-trash' -e 'Thrown away' || true)" "0"
sb compare with-links
rc_is "compare: exit 0 when nothing changed" 0
out_is "compare: every view compared" "snapshot: $SNAPS/with-links${NL}no differences"
printf '%s\n' '# Notes' '' 'A new first paragraph.' '' 'See [[zebra]] and [[apple|an apple]], and [[zebra]] again.' >"$vault/$P/docs/notes.md"
sb compare with-links
out_is "compare: a link that only moved down a line is no difference" "snapshot: $SNAPS/with-links${NL}no differences"
printf '%s\n' '# Zebra' >"$vault/$P/docs/zebra.md"
printf '%s\n' '' '[[cherry]]' >>"$vault/$P/docs/notes.md"
sb task alias EX-1 add "New name"
sb compare with-links
rc_is "compare: exit 1 when links and aliases differ" 1
out_is "compare: unresolved and alias changes" \
  "snapshot: $SNAPS/with-links${NL}unresolved added:${NL}  $P/docs/notes.md: [[cherry]]${NL}unresolved removed:${NL}  $P/docs/notes.md: [[zebra]]${NL}aliases added:${NL}  New name${TAB}$P/tasks/EX-1/README.md"
is "snapshot: doctor.txt holds the unresolved-links row" "$(grep -c "^warn | unresolved-links | Example | 2 | " "$vault/$SNAPS/with-links/doctor.txt")" "1"

# ---------------------------------------------------------------- an archived task
sb snapshot before-archive
sed 's/^task_layout: flat$/task_layout: archive/' "$vault/$P/claude/profile.md" >"$tmp/profile.tmp" && cat "$tmp/profile.tmp" >"$vault/$P/claude/profile.md"
sb task set EX-4 status=done
sb task archive EX-4
rc_is "archive: a done task is archived" 0
sb snapshot after-archive
is "snapshot: tasks.tsv keeps an archived task" "$(grep "${TAB}EX-4${TAB}" "$vault/$SNAPS/after-archive/tasks.tsv")" "Example${TAB}EX-4${TAB}done"
sb compare before-archive
out_has "compare: an archived task is the same task, with its new status" "tasks changed:${NL}  Example | EX-4 | planned -> done"
out_lacks "compare: an archived task is not removed" "tasks removed:"
out_has "compare: its alias moved with it" "aliases added:${NL}  EX-4${TAB}$P/tasks/archive/2026/EX-4/README.md"

# ---------------------------------------------------------------- doctor --fix archives, compare proves it
sb task new EX-5 --project Example --title "Task EX-5"
sb task set EX-5 status=done
printf '%s\n' '' "Links to [[$P/tasks/EX-5/README|EX-5]]." >>"$vault/$P/docs/notes.md"
sb snapshot before-fix
sb doctor Example --fix
out_has "doctor --fix: archives the done task" "fixed: EX-5 -> $P/tasks/archive/2026/EX-5/README.md (Example)"
sb compare before-fix
rc_is "compare after doctor --fix: exit 1, the task moved" 1
out_is "compare after doctor --fix: only the archived task's alias moved; no link broke, no task changed" \
  "snapshot: $SNAPS/before-fix${NL}aliases added:${NL}  EX-5${TAB}$P/tasks/archive/2026/EX-5/README.md${NL}aliases removed:${NL}  EX-5${TAB}$P/tasks/EX-5/README.md"
is "doctor --fix: the link to the task follows it" "$(grep -c -F "[[$P/tasks/archive/2026/EX-5/README|EX-5]]" "$vault/$P/docs/notes.md")" "1"

# ---------------------------------------------------------------- result
printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
