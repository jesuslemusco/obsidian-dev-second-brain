#!/usr/bin/env bash
# Scratch-vault tests for snapshot, compare and probe.
# Usage: bash scripts/test-snapshot.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
SB="$here/bin/second-brain"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-snap-test.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

vault="$tmp/vault"
links="$tmp/claude-home"
mkdir -p "$vault/.obsidian" "$links/skills" "$links/agents" "$tmp/userdir"
export HOME="$tmp/userdir"
export SECOND_BRAIN_VAULT="$vault"
export SECOND_BRAIN_CLAUDE_HOME="$links"
export SECOND_BRAIN_TODAY="2026-01-10"
export SECOND_BRAIN_OBSIDIAN="none"
unset CLAUDE_SESSION_ID SECOND_BRAIN_OB_TIMEOUT SECOND_BRAIN_NOW

P="projects/example"
SNAPS=".second-brain/snapshots"
CONV="$vault/obsidian-conventions.md"
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
is "snapshot: unresolved.txt says unavailable without the app" "$(cat "$vault/$SNAPS/base/unresolved.txt")" "unavailable"
is "snapshot: aliases.txt says unavailable without the app" "$(cat "$vault/$SNAPS/base/aliases.txt")" "unavailable"
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
HEAD="snapshot: $SNAPS/base${NL}not compared: unresolved.txt${NL}not compared: aliases.txt"
sb compare
rc_is "compare: exit 0 right after a snapshot" 0
out_is "compare: no differences, and names the two files not compared" "$HEAD${NL}no differences"
sb task set EX-2 status=in-progress
sb task new EX-4 --project Example --title "Task EX-4"
sb compare
rc_is "compare: exit 1 when something differs" 1
out_is "compare: reports the new task and the changed status, nothing else" \
  "$HEAD${NL}tasks added:${NL}  Example | EX-4 | planned${NL}tasks changed:${NL}  Example | EX-2 | planned -> in-progress"
rm -rf "$vault/$P/tasks/EX-3"
sb compare
rc_is "compare: exit 1 after a task folder is removed" 1
out_has "compare: reports the removed task" "tasks removed:${NL}  Example | EX-3 | planned"
is "compare: sections in the order added, removed, changed" \
  "$(printf '%s\n' "$OUT" | grep '^tasks ' | tr '\n' ' ')" "tasks added: tasks removed: tasks changed: "
sb snapshot later
sb compare
out_is "compare: takes the newest snapshot by name" \
  "snapshot: $SNAPS/later${NL}not compared: unresolved.txt${NL}not compared: aliases.txt${NL}no differences"
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
SB_OB_STATE=""
SB_OB_VAULT_ARG=""
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
printf 'unavailable\n' >"$a/unresolved.txt"
cp "$a/aliases.txt" "$b/aliases.txt"
cp "$a/links.txt" "$b/links.txt"
OUT="$(sb_snap_diff "$a" "$b")"
is "diff: a view unavailable on one side is no difference" "$?" "0"
out_is "diff: it is named as not compared" "not compared: unresolved.txt"
: >"$a/unresolved.txt"
OUT="$(sb_snap_diff "$a" "$b")"
out_is "diff: an empty view is compared" "unresolved added:${NL}  kept link${NL}  new link"
rm -f "$b/links.txt"
OUT="$(sb_snap_diff "$a" "$b")"
out_has "diff: a missing file is named as not compared" "not compared: links.txt"

# ---------------------------------------------------------------- the links and doctor views
links2="$tmp/claude-home-2"
mkdir -p "$links2/skills" "$links2/agents" "$tmp/src/zeta"
ln -s "$tmp/src/zeta" "$links2/skills/zeta"
ln -s "../elsewhere/alpha.md" "$links2/agents/alpha.md"
mkdir "$links2/skills/a-real-folder"
unset -f sb_link_scan cmd_doctor
SB_ROOT="$vault"
is "links view: with no link library, the symlinks as name and target" \
  "$(SECOND_BRAIN_CLAUDE_HOME="$links2" sb_snap_links)" "alpha.md${TAB}../elsewhere/alpha.md${NL}zeta${TAB}$tmp/src/zeta"
is "links view: an empty link directory gives no rows" "$(SECOND_BRAIN_CLAUDE_HOME="$tmp/nowhere" sb_snap_links)" ""
is "doctor view: unavailable with no doctor" "$(sb_snap_doctor)" "unavailable"
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

# ---------------------------------------------------------------- probe, no app
cp "$CONV" "$tmp/conv.orig"
sb probe
rc_is "probe: exit 3 with the app disabled" 3
same "probe: the conventions note is byte-identical" "$tmp/conv.orig" "$CONV"
sb probe extra
rc_is "probe: an argument gives exit 5" 5
sb context
out_has "context: no verdict before a probe" "search: unknown"

# ---------------------------------------------------------------- the limits block
# outside <file>: print the file without the body of the limits block.
outside() {
  awk '{ l = $0; sub(/\r$/, "", l) }
    l ~ /^## / { skip = (l == "## Limits on this install"); print; next }
    !skip { print }' "$1"
}
# body <file>: print the non-blank lines of the limits block, without carriage returns.
body() {
  awk '{ sub(/\r$/, "") }
    /^## / { inb = ($0 == "## Limits on this install"); next }
    inb && NF { print }' "$1"
}
OK_LINE="- search: ok (6 of 6 scoped searches consistent, 2026-01-10)"
BAD_LINE="- search: unreliable (counts 9 9 0 9 9 9, 2026-01-10)"
ADVICE='- Scoped searches pass `path=` and are retried once when they come back empty.'
sb_snap_write_limits "$OK_LINE" "1.9.14"
is "limits: returns 0" "$?" "0"
is "limits: the body is the verdict, the version and the advice" "$(body "$CONV")" "$OK_LINE${NL}- obsidian: 1.9.14${NL}$ADVICE"
outside "$tmp/conv.orig" >"$tmp/out.before"
outside "$CONV" >"$tmp/out.after"
same "limits: every other section is unchanged" "$tmp/out.before" "$tmp/out.after"
n="$(grep -n '^## Limits on this install$' "$CONV" | cut -d: -f1)"
is "limits: one blank line on each side of the body" "$(sed -n "${n},$((n + 6))p" "$CONV")" \
  "## Limits on this install${NL}${NL}$OK_LINE${NL}- obsidian: 1.9.14${NL}$ADVICE${NL}${NL}## Searching"
is "limits: line count grows by the two added lines" "$(($(grep -c '' "$CONV") - $(grep -c '' "$tmp/conv.orig")))" "2"
sb context
out_has "context: reads the ok verdict" "search: ok"
cp "$CONV" "$tmp/conv.ok"
sb_snap_write_limits "$OK_LINE" "1.9.14"
same "limits: writing the same verdict again changes nothing" "$tmp/conv.ok" "$CONV"
sb_snap_write_limits "$BAD_LINE" ""
is "limits: a new verdict replaces the old body" "$(body "$CONV")" "$BAD_LINE${NL}- obsidian: unknown${NL}$ADVICE"
sb context
out_has "context: reads the unreliable verdict" "search: unreliable"

# ---------------------------------------------------------------- the limits block, other shapes
awk '{ printf "%s\r\n", $0 }' "$tmp/conv.orig" >"$CONV"
cp "$CONV" "$tmp/conv.crlf"
sb_snap_write_limits "$OK_LINE" "1.9.14"
is "limits, CRLF: every line still ends with a carriage return" "$(grep -c -v "$CR\$" "$CONV")" "0"
is "limits, CRLF: the body is rewritten" "$(body "$CONV")" "$OK_LINE${NL}- obsidian: 1.9.14${NL}$ADVICE"
outside "$tmp/conv.crlf" >"$tmp/out.before"
outside "$CONV" >"$tmp/out.after"
same "limits, CRLF: every other section is unchanged" "$tmp/out.before" "$tmp/out.after"
sb context
out_has "context: reads the verdict from a CRLF note" "search: ok"
printf '# Notes\n\nSome text.\n' >"$CONV"
sb_snap_write_limits "$BAD_LINE" "1.9.14" "- tags: an extra line"
is "limits: with no heading the block is appended after a blank line" "$(cat "$CONV"; printf x)" \
  "$(printf '# Notes\n\nSome text.\n\n## Limits on this install\n\n%s\n- obsidian: 1.9.14\n%s\n- tags: an extra line\nx' "$BAD_LINE" "$ADVICE")"
sb context
out_has "context: reads the verdict from an appended block" "search: unreliable"
printf '# Notes\n\n## Limits on this install\n- old line\n- search: ok, an old verdict' >"$CONV"
sb_snap_write_limits "search: unreliable (counts 0 0 0 0 0 0, 2026-01-10)" "1.9.14"
is "limits: a block at the end of a file with no final newline" "$(cat "$CONV"; printf x)" \
  "$(printf '# Notes\n\n## Limits on this install\n\n- search: unreliable (counts 0 0 0 0 0 0, 2026-01-10)\n- obsidian: 1.9.14\n%sx' "$ADVICE")"
rm -f "$CONV"
sb_snap_write_limits "$OK_LINE" "1.9.14"
is "limits: returns 1 when the note is missing, and does not create it" "$? $([ -e "$CONV" ] && printf there)" "1 "
cp "$tmp/conv.orig" "$CONV"
SB_ROOT=""

# ---------------------------------------------------------------- Obsidian CLI, a stand-in
stub="$tmp/stub"
mkdir -p "$stub"
cat >"$stub/obsidian" <<'EOF'
#!/usr/bin/env bash
# Stand-in for the Obsidian CLI: answers from files in STUB_DIR.
printf '%s\n' "$*" >>"$STUB_DIR/calls.log"
case "$1" in
  vault) cat "$STUB_DIR/vault.txt" ;;
  version) printf '1.9.14 (installer 1.8.10)\n' ;;
  unresolved) cat "$STUB_DIR/unresolved.txt" ;;
  aliases) cat "$STUB_DIR/aliases.txt" ;;
  search)
    n="$(cat "$STUB_DIR/search.count" 2>/dev/null || printf 0)"
    n=$((n + 1))
    printf '%s\n' "$n" >"$STUB_DIR/search.count"
    if [ "$n" -eq "$(cat "$STUB_DIR/search.empty")" ]; then printf 'No matches found.\n'; else cat "$STUB_DIR/search.txt"; fi
    ;;
  tag) [ "$2" = "name=type/onboarding" ] && printf 'obsidian-conventions.md\n' ;;
  *) printf 'Error: Command "%s" not found.\n' "$1" ;;
esac
exit 0
EOF
chmod +x "$stub/obsidian"
export STUB_DIR="$stub"
export SECOND_BRAIN_OBSIDIAN="$stub/obsidian"
printf '%s\n' "$vault" >"$stub/vault.txt"
printf '%s\n' 'zebra' 'apple' 'mango' >"$stub/unresolved.txt"
printf 'Example Tasks Hub\t%s\nExample\t%s\n' "$P/tasks/README.md" "$P/README.md" >"$stub/aliases.txt"
printf '%s\n' "$P/README.md" "$P/claude/profile.md" "$P/tasks/README.md" >"$stub/search.txt"
printf '0\n' >"$stub/search.empty"
sb context
out_has "stand-in: the CLI answers for this vault" "obsidian: up"

# ---------------------------------------------------------------- probe, with the stand-in
outside "$CONV" >"$tmp/out.before"
: >"$stub/calls.log"
sb probe
rc_is "probe: exit 0 with the app up" 0
out_is "probe: prints the ok verdict" "search: ok (6 of 6 scoped searches consistent, 2026-01-10)"
is "probe: six searches scoped to the first project" "$(grep -c -x "search query=ticket_keys path=$P" "$stub/calls.log")" "6"
is "probe: writes the verdict, the version, the advice and the tag line" "$(body "$CONV")" \
  "$OK_LINE${NL}- obsidian: 1.9.14 (installer 1.8.10)${NL}$ADVICE${NL}"'- tags: `tag name=<tag>` matches the exact tag only, not its sub-tags.'
outside "$CONV" >"$tmp/out.after"
same "probe: every other section is unchanged" "$tmp/out.before" "$tmp/out.after"
sb context
out_has "context: reads what probe wrote" "search: ok"
printf '3\n' >"$stub/search.empty"
rm -f "$stub/search.count"
sb probe
rc_is "probe: exit 0 for an unreliable search too" 0
out_is "probe: one empty answer in six is unreliable" "search: unreliable (counts 3 3 0 3 3 3, 2026-01-10)"
is "probe: the old verdict is replaced" "$(body "$CONV" | grep -c 'search:')" "1"
sb context
out_has "context: reads the unreliable verdict probe wrote" "search: unreliable"
printf '0\n' >"$stub/search.empty"
: >"$stub/search.txt"
sb probe
out_is "probe: six equal counts of zero are unreliable" "search: unreliable (counts 0 0 0 0 0 0, 2026-01-10)"
printf '%s\n' "$tmp/another-vault" >"$stub/vault.txt"
cp "$CONV" "$tmp/conv.probed"
sb probe
rc_is "probe: exit 3 when the app has another vault open" 3
same "probe: and the conventions note is byte-identical" "$tmp/conv.probed" "$CONV"
printf '%s\n' "$vault" >"$stub/vault.txt"

# ---------------------------------------------------------------- snapshot and compare, with the stand-in
sb snapshot with-app
rc_is "snapshot: exit 0 with the app up" 0
is "snapshot: unresolved.txt holds the CLI's rows, sorted" "$(cat "$vault/$SNAPS/with-app/unresolved.txt")" "apple${NL}mango${NL}zebra"
is "snapshot: aliases.txt holds the CLI's rows, sorted" "$(cut -f1 "$vault/$SNAPS/with-app/aliases.txt" | tr '\n' '|')" "Example|Example Tasks Hub|"
grep -q -x 'aliases verbose' "$stub/calls.log"
is "snapshot: asks for the verbose alias list" "$?" "0"
sb compare with-app
rc_is "compare: exit 0 with the app up and nothing changed" 0
out_is "compare: every view compared" "snapshot: $SNAPS/with-app${NL}no differences"
printf '%s\n' 'mango' 'zebra' 'cherry' >"$stub/unresolved.txt"
printf 'Example Tasks Hub\t%s\nExample\t%s\nNew Hub\t%s\n' "$P/tasks/README.md" "$P/README.md" "$P/docs/README.md" >"$stub/aliases.txt"
sb compare with-app
rc_is "compare: exit 1 when the CLI views differ" 1
out_is "compare: unresolved and alias changes" \
  "snapshot: $SNAPS/with-app${NL}unresolved added:${NL}  cherry${NL}unresolved removed:${NL}  apple${NL}aliases added:${NL}  New Hub${TAB}$P/docs/README.md"
sb compare base
out_has "compare: a view the snapshot lacks is not compared" "not compared: unresolved.txt"
out_lacks "compare: and is not reported as added" "unresolved added:"
: >"$stub/unresolved.txt"
sb snapshot none-unresolved
is "snapshot: an empty CLI answer is an empty file, not unavailable" "$(wc -c <"$vault/$SNAPS/none-unresolved/unresolved.txt" | tr -d ' ')" "0"
printf 'Error: Command "unresolved" not found.\n' >"$stub/unresolved.txt"
sb snapshot cli-error
is "snapshot: a CLI error is recorded as unavailable" "$(cat "$vault/$SNAPS/cli-error/unresolved.txt")" "unavailable"

# ---------------------------------------------------------------- result
printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
