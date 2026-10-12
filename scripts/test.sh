#!/usr/bin/env bash
# Scratch-vault tests for the helper: builds a vault in a temp dir and asserts on it.
# Usage: bash scripts/test.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
SB="$here/bin/second-brain"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-test.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# The suite compares bytes. On Windows, in Git Bash, the platform library gives it the awk, grep
# and sed that keep every CR, as the helper has them.
. "$here/scripts/lib/platform.sh"

vault="$tmp/vault"
mkdir -p "$vault/.obsidian" "$tmp/userdir"
export HOME="$tmp/userdir"
export SECOND_BRAIN_VAULT="$vault"
export SECOND_BRAIN_TODAY="2026-10-08"
unset CLAUDE_SESSION_ID SECOND_BRAIN_CLAUDE_HOME

P="clients/acme/projects/example"
P2="clients/acme/projects/two"
TAB="$(printf '\t')"
CR="$(printf '\r')"
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
file_has() {
  if grep -qF -- "$3" "$2" 2>/dev/null; then pass "$1"; else fail "$1" "missing in $2: $3"; fi
}
file_lacks() {
  if grep -qF -- "$3" "$2" 2>/dev/null; then fail "$1" "unwanted in $2: $3"; else pass "$1"; fi
}
line_is() { # line_is <desc> <file> <exact line>
  if grep -qxF -- "$3" "$2" 2>/dev/null; then pass "$1"; else fail "$1" "no such line in $2: $3"; fi
}
exists() {
  if [ -e "$2" ]; then pass "$1"; else fail "$1" "missing: $2"; fi
}
absent() {
  if [ -e "$2" ]; then fail "$1" "should not exist: $2"; else pass "$1"; fi
}
lines() { printf '%s' "$1" | grep -c '' || true; }
# edit <file> <sed script>: change a file through a temp file.
edit() {
  sed "$2" "$1" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$1"
}
lineno() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }
# shown <path>: the path as the helper prints it; on Windows that is the drive form.
shown() {
  if sb_is_windows; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}
# symlink <target> <link>: a real symlink on every system; on Windows a plain ln -s makes a copy.
symlink() {
  if sb_is_windows; then MSYS=winsymlinks:nativestrict ln -s "$1" "$2"; else ln -s "$1" "$2"; fi
}
oV="$(shown "$vault")"
oT="$(shown "$tmp")"

# check_links <note>: report links outside code that lack a display text or point nowhere.
check_links() {
  local f="$1" link target
  awk '
    /^(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      while ((i = index(line, "[[")) > 0) {
        rest = substr(line, i + 2); j = index(rest, "]]")
        if (j == 0) break
        print substr(rest, 1, j - 1)
        line = substr(rest, j + 2)
      }
    }' "$f" | while IFS= read -r link; do
    target="${link%%|*}"
    target="${target%%#*}"
    case "$link" in
      *"|"*) ;;
      *.base*) ;;
      *) printf 'bare link in %s: %s\n' "${f#"$vault"/}" "$link" ;;
    esac
    if [ ! -e "$vault/$target.md" ] && [ ! -e "$vault/$target" ]; then
      printf 'dead link in %s: %s\n' "${f#"$vault"/}" "$link"
    fi
  done
}

# ---------------------------------------------------------------- syntax
for f in "$here/bin/second-brain" "$here"/scripts/lib/*.sh "$here"/scripts/*.sh; do
  if bash -n "$f" 2>"$tmp/stderr"; then pass "syntax: ${f#"$here"/}"; else fail "syntax: ${f#"$here"/}" "$(cat "$tmp/stderr")"; fi
done
is "awk: every program that loads the shared functions runs in the C locale" \
  "$(grep -n '"$(sb_awk_lib)"' "$here"/scripts/lib/*.sh | grep -v 'LC_ALL=C' || true)" ""

# ---------------------------------------------------------------- dispatcher
sb version
rc_is "version: exit 0" 0
is "version: matches plugin.json" "$OUT" "$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$here/.claude-plugin/plugin.json" | head -1)"
sb no-such-command
rc_is "unknown command: exit 5" 5
err_has "unknown command: prints usage" "usage: second-brain"
sb
rc_is "no command: exit 5" 5
sb help
rc_is "help: exit 0" 0
for c in "task tag" "task alias" "sprint next" "sprint set" "board <project> [view] |" "--tasks-root R" "--topics-root R" "--sprints-root R" \
  "repo <project> [name]" "conventions [section]" "task new <ID> [--project P]" "link [--check | --apply]" "doctor [project] [--json] [--fix]" "snapshot [name]" "compare [name]" "session-check" \
  "outline <path>" "backlinks <path>" "unresolved [project]" "move <from> <to> [--dry-run]" "rename <path> <name> [--dry-run]" "pointer | pointer set <DIR> [--replace]"; do
  out_has "help: lists $c" "$c"
done
for c in "--files" "probe" "ob <" "Obsidian"; do
  out_lacks "help: no longer lists $c" "$c"
done
out_has "help: exit code 3 is retired" "2 setup missing, 4 ambiguous"
sb ob version
rc_is "ob: the command is gone, exit 5" 5
sb probe
rc_is "probe: the command is gone, exit 5" 5
sb 'bad;name'
rc_is "odd command name: exit 5" 5
mkdir -p "$tmp/links/deep"
symlink "$SB" "$tmp/links/real-link"
symlink "../real-link" "$tmp/links/deep/chained-link"
run sh -c "cd '$tmp/links/deep' && ./chained-link version"
rc_is "symlink chain from another directory: exit 0" 0
out_has "symlink chain: finds its libraries" "."
mkdir -p "$tmp/copy/bin" "$tmp/copy/scripts"
cp "$SB" "$tmp/copy/bin/second-brain"
cp -R "$here/scripts/lib" "$tmp/copy/scripts/lib"
printf 'cmd_session_check() { printf "routed %%s\\n" "$#"; }\n' >"$tmp/copy/scripts/lib/zz-extra.sh"
run "$tmp/copy/bin/second-brain" session-check a b
out_is "dispatcher: routes a dashed command to a library added later" "routed 2"

# ---------------------------------------------------------------- frontmatter functions
SB_PLUGIN_ROOT="$here"
SB_ROOT=""
for lib in "$here"/scripts/lib/*.sh; do . "$lib"; done
fm="$tmp/fm.md"
printf '%s\n' '---' 'aliases:' '  - "Alpha: one"   # first' "  - 'it''s'" '  - plain' 'inline: [a, "b, c", d]' \
  'empty: []' 'quoted: "x \"y\" z"   # note' 'bare: value # comment' 'dash: "-"' 'tags:' '- zero/indent' '---' '' 'body: not frontmatter' >"$fm"
is "sb_fm_list: block list, quotes stripped" "$(sb_fm_list "$fm" aliases | tr '\n' '|')" "Alpha: one|it's|plain|"
is "sb_fm_list: inline list with a quoted comma" "$(sb_fm_list "$fm" inline | tr '\n' '|')" "a|b, c|d|"
is "sb_fm_list: empty inline list" "$(sb_fm_list "$fm" empty)" ""
is "sb_fm_list: list items with no indent" "$(sb_fm_list "$fm" tags)" "zero/indent"
is "sb_fm_get: double quotes and escapes" "$(sb_fm_get "$fm" quoted)" 'x "y" z'
is "sb_fm_get: trailing comment dropped" "$(sb_fm_get "$fm" bare)" "value"
is "sb_fm_get: quoted dash" "$(sb_fm_get "$fm" dash)" "-"
sb_fm_get "$fm" body >/dev/null
is "sb_fm_get: a body line is not a key" "$?" "1"
is "sb_yaml_quote: plain stays plain" "$(sb_yaml_quote "feature/EX-1-fix")" "feature/EX-1-fix"
is "sb_yaml_quote: colon and space" "$(sb_yaml_quote "a: b")" '"a: b"'
is "sb_yaml_quote: date shape" "$(sb_yaml_quote "2026-10-14")" '"2026-10-14"'
is "sb_yaml_quote: number" "$(sb_yaml_quote "42")" '"42"'
is "sb_yaml_quote: leading dash and bracket" "$(sb_yaml_quote "-")$(sb_yaml_quote "[x]")" '"-""[x]"'
is "sb_yaml_quote: hash" "$(sb_yaml_quote "fix #3")" '"fix #3"'
is "sb_yaml_quote: quote and backslash escaped" "$(sb_yaml_quote 'say "hi" \ now' 1)" '"say \"hi\" \\ now"'
cp "$fm" "$tmp/fm.before"
sb_fm_set "$fm" bare "new value"
is "sb_fm_set: one line changed" "$(diff "$tmp/fm.before" "$fm" | grep -c '^[<>]')" "2"
is "sb_fm_set: value written" "$(sb_fm_get "$fm" bare)" "new value"
sb_fm_set "$fm" sprint "2026-10-14"
line_is "sb_fm_set: sprint id always quoted" "$fm" 'sprint: "2026-10-14"'
sb_fm_set "$fm" owner "someone"
is "sb_fm_set: an unknown new key goes before tags" "$(($(lineno "$fm" 'tags:') - $(lineno "$fm" 'owner:')))" "1"
sb_fm_set "$fm" aliases ""
is "sb_fm_set: empty value removes the key and its items" "$(grep -c -e '^aliases' -e 'Alpha' -e 'plain' "$fm")" "0"
file_has "sb_fm_set: body untouched" "$fm" "body: not frontmatter"
printf 'no frontmatter here' >"$tmp/nofm.md"
sb_fm_set "$tmp/nofm.md" status planned
is "sb_fm_set: adds a block when there is none, keeps a missing final newline" "$(cat "$tmp/nofm.md"; printf x)" "$(printf -- '---\nstatus: planned\n---\nno frontmatter here'; printf x)"
is "sb_date_add: over a leap day" "$(sb_date_add 2028-02-21 13)" "2028-03-05"
is "sb_date_add: back over a year end" "$(sb_date_add 2027-01-03 -5)" "2026-12-29"
is "sb_date_diff: across years" "$(sb_date_diff 2028-03-05 2027-12-25)" "71"
sb_date_ok 2026-02-30
is "sb_date_ok: rejects an impossible date" "$?" "1"
SB_ROOT=""

# ---------------------------------------------------------------- root
sb root
rc_is "root: exit 0" 0
out_is "root: physical vault path" "$oV"
run env SECOND_BRAIN_VAULT="$tmp/userdir" "$SB" root
rc_is "root: not a vault gives exit 2" 2
run env -u SECOND_BRAIN_VAULT "$SB" root
rc_is "root: no pointer gives exit 2" 2
mkdir -p "$tmp/userdir/.claude"
symlink "$vault" "$tmp/userdir/.claude/second-brain-vault"
run env -u SECOND_BRAIN_VAULT "$SB" root
out_is "root: follows the pointer symlink" "$oV"
mkdir -p "$tmp/other-home"
run env -u SECOND_BRAIN_VAULT SECOND_BRAIN_CLAUDE_HOME="$tmp/other-home" "$SB" root
rc_is "root: the pointer is looked for in the link directory, exit 2 when it has none" 2
run env SECOND_BRAIN_CLAUDE_HOME="$tmp/other-home" "$SB" pointer set "$vault"
run env -u SECOND_BRAIN_VAULT SECOND_BRAIN_CLAUDE_HOME="$tmp/other-home" "$SB" root
out_is "root: follows the pointer of the link directory" "$oV"

# ---------------------------------------------------------------- context, before setup
sb context
rc_is "context: exit 0 on an empty vault" 0
out_is "context: four lines, in the contract's order" "vault: $oV
project: none
project_path: none
sprint: none"
run env SECOND_BRAIN_VAULT="$tmp/nowhere" "$SB" context
rc_is "context: exit 0 with no vault" 0
out_has "context: vault none" "vault: none"

# ---------------------------------------------------------------- scaffold vault
sb scaffold vault
rc_is "scaffold vault: exit 0" 0
out_is "scaffold vault: lists the three files" "CLAUDE.md
obsidian-conventions.md
claude/README.md"
exists "scaffold vault: index" "$vault/CLAUDE.md"
exists "scaffold vault: conventions" "$vault/obsidian-conventions.md"
exists "scaffold vault: vault Claude hub" "$vault/claude/README.md"
line_is "index: table header as in the contract" "$vault/CLAUDE.md" "| Project | Path | Keys | Use when |"
line_is "conventions: version property" "$vault/obsidian-conventions.md" "conventions_version: 2"
is "conventions: no command of the Obsidian CLI is left" "$(grep -c -e 'brain ob ' -e '`obsidian ' -e 'probe' "$vault/obsidian-conventions.md")" "0"
is "conventions: the short version is the first section" "$(grep -m1 '^## ' "$vault/obsidian-conventions.md")" "## The short version"
sb conventions
rc_is "conventions: exit 0" 0
is "conventions: the default is the short version, without its heading" "$(printf '%s\n' "$OUT" | head -1 | cut -c1-17)" "1. Every task is "
is "conventions: one section only" "$(printf '%s\n' "$OUT" | grep -c '^## ' || true)" "0"
if [ "$(lines "$OUT")" -le 30 ]; then pass "conventions: the short version stays within 30 lines"; else fail "conventions: the short version stays within 30 lines" "$(lines "$OUT") lines"; fi
for c in "<project>/tasks/<TICKET-ID>/README.md" "topic tag" "unique **alias**" "Links carry a path" 'bare `[[Alias]]` does not resolve' \
  "second-brain move" "second-brain unresolved <project>" "status/done" "in-review" "Quote a YAML value" 'sprint: "<id>"'; do
  out_has "conventions: the short version covers: $c" "$c"
done
sb conventions "note metadata"
out_has "conventions: a named section, any case" "YAML traps"
out_lacks "conventions: stops at the next section" "A **topic** is a folder"
sb conventions Helper commands
out_has "conventions: a section name of several words" 'second-brain backlinks "<vault path>"'
sb conventions "in the obsidian app"
out_has "conventions: the app is kept as the viewer" "Obsidian is the viewer"
sb conventions tasks
out_has "conventions: a slug gets the id as an alias" 'second-brain task alias <slug> add <ID>'
out_has "conventions: says the folder keeps the slug" "renaming a task folder is not supported yet"
out_lacks "conventions: no advice to rename the folder to the id" "renamed to the id"
sb conventions "no such section"
rc_is "conventions: unknown section gives exit 1" 1
mkdir -p "$tmp/vault0/.obsidian"
run env SECOND_BRAIN_VAULT="$tmp/vault0" "$SB" conventions
rc_is "conventions: no conventions note gives exit 1" 1
printf 'my own line\n' >>"$vault/claude/README.md"
sb scaffold vault
rc_is "scaffold vault again: exit 0" 0
out_is "scaffold vault again: creates nothing" ""
file_has "scaffold vault again: does not overwrite" "$vault/claude/README.md" "my own line"
mkdir -p "$tmp/vault2/.obsidian"
sb scaffold vault "$tmp/vault2"
exists "scaffold vault DIR: writes into that vault" "$tmp/vault2/CLAUDE.md"
sb scaffold vault "$tmp/userdir"
rc_is "scaffold vault DIR: not a vault gives exit 2" 2
sb projects
rc_is "projects: exit 0 with no rows" 0
out_is "projects: empty" ""

# ---------------------------------------------------------------- scaffold project
sb scaffold project Example --path "$P" --keys EX,EXOPS
rc_is "scaffold project: exit 0" 0
out_is "scaffold project: lists what it created" "$P/README.md
$P/claude/README.md
$P/claude/profile.md
$P/tasks/README.md
$P/tasks/tasks.base
$P/docs/README.md
$P/sprints/README.md"
line_is "index: one row for the project" "$vault/CLAUDE.md" "| Example | $P | EX, EXOPS | Anything about Example. |"
line_is "profile: ticket keys" "$vault/$P/claude/profile.md" "ticket_keys: [EX, EXOPS]"
line_is "profile: sprints are on by default" "$vault/$P/claude/profile.md" "uses_sprints: true"
line_is "board: folder filter" "$vault/$P/tasks/tasks.base" "    - file.inFolder(\"$P/tasks\")"
line_is "board: folder depth is the path segments plus one" "$vault/$P/tasks/tasks.base" '    - file.folder.split("/").length == 6'
line_is "board: sprint literal placeholder" "$vault/$P/tasks/tasks.base" '        - sprint == "none"'
for v in Active "Current sprint" "By topic" "Needs a status" All; do
  line_is "board: view $v" "$vault/$P/tasks/tasks.base" "    name: $v"
done
line_is "tasks hub: embedded board" "$vault/$P/tasks/README.md" "![[$P/tasks/tasks.base#Active]]"
line_is "tasks hub: unique alias" "$vault/$P/tasks/README.md" '  - "Example Tasks Hub"'
line_is "tasks hub: up-link in the full-path form" "$vault/$P/tasks/README.md" "> Up: [[$P/README|Example Hub]]"
printf 'kept\n' >>"$vault/$P/README.md"
cp "$vault/$P/claude/profile.md" "$tmp/profile.before"
sb scaffold project Example --path "$P" --keys EX,EXOPS
rc_is "scaffold project again: exit 0" 0
out_is "scaffold project again: creates nothing" ""
file_has "scaffold project again: does not overwrite" "$vault/$P/README.md" "kept"
is "scaffold project again: profile untouched" "$(cmp -s "$tmp/profile.before" "$vault/$P/claude/profile.md"; echo $?)" "0"
is "index: still exactly one row" "$(grep -c '^| Example |' "$vault/CLAUDE.md")" "1"
sb scaffold project Example --path other/place
rc_is "scaffold project: a taken name gives exit 6" 6
absent "scaffold project: nothing created for the refused name" "$vault/other"
sb scaffold project Other --path "$P"
rc_is "scaffold project: a taken path gives exit 6" 6
sb scaffold project NoPath
rc_is "scaffold project: no --path gives exit 5" 5
sb scaffold project "Bad|Name" --path x/y
rc_is "scaffold project: a name with a pipe gives exit 5" 5
sb scaffold project Up --path ../outside
rc_is "scaffold project: a path leaving the vault gives exit 5" 5
sb scaffold
rc_is "scaffold: no subcommand gives exit 5" 5
sb scaffold project "Example Two" --path "$P2" --keys NEW,ex --use-when "The second | service."
rc_is "scaffold project: a key another project owns gives exit 6" 6
err_has "scaffold project: the message names the owner" "already belongs to the project Example"
absent "scaffold project: nothing created for a taken key" "$vault/$P2"
is "scaffold project: no index row for a taken key" "$(grep -c '^| Example Two |' "$vault/CLAUDE.md")" "0"
sb scaffold project "Example Two" --path "$P2" --keys TWO --use-when "The second | service."
rc_is "scaffold project: second project" 0
line_is "index: second row, pipe escaped" "$vault/CLAUDE.md" "| Example Two | $P2 | TWO | The second \\| service. |"
sb scaffold project "Example Two" --path "$P2" --keys TWO
rc_is "scaffold project: a project keeps its own keys on a second run" 0
edit "$vault/CLAUDE.md" 's/^| Example Two | \(.*\) | TWO | /| Example Two | \1 | EX, TWO | /'
sb projects
out_is "projects: one TSV row per project" "Example${TAB}$P${TAB}EX,EXOPS
Example Two${TAB}$P2${TAB}EX,TWO"

# ---------------------------------------------------------------- project
sb project --name example
rc_is "project --name: exit 0" 0
out_is "project --name: case-insensitive, one row" "Example${TAB}$P${TAB}EX,EXOPS"
sb project --name Nope
rc_is "project --name: none gives exit 1" 1
sb project --key EXOPS-12
out_is "project --key: a ticket id gives its prefix" "Example${TAB}$P${TAB}EX,EXOPS"
sb project --key TWO
out_is "project --key: a bare prefix" "Example Two${TAB}$P2${TAB}EX,TWO"
sb project --key EX-5
rc_is "project --key: a shared key gives exit 4" 4
is "project --key: prints the candidates" "$(lines "$OUT")" "2"
sb project --key ZZ-1
rc_is "project --key: none gives exit 1" 1
sb project --cwd "$vault/$P/tasks"
out_is "project --cwd: a folder inside the project" "Example${TAB}$P${TAB}EX,EXOPS"
sb project --cwd "$tmp"
rc_is "project --cwd: outside everything gives exit 1" 1
edit "$vault/$P/claude/profile.md" 's/^repos: \[\]$/repos: [example-api, example-web]/'
mkdir -p "$tmp/code/example-api/src/deep" "$tmp/code/shared-lib"
sb project --cwd "$tmp/code/example-api/src/deep"
out_is "project --cwd: a repo folder named in the profile" "Example${TAB}$P${TAB}EX,EXOPS"
run sh -c "cd '$vault/$P2/docs' && '$SB' project"
out_is "project: no flag uses the working directory" "Example Two${TAB}$P2${TAB}EX,TWO"
edit "$vault/$P/claude/profile.md" 's/^repos: .*$/repos: [example-api, shared-lib]/'
edit "$vault/$P2/claude/profile.md" 's/^repos: \[\]$/repos:\
  - shared-lib/'
sb project --cwd "$tmp/code/shared-lib"
rc_is "project --cwd: a repo in two profiles gives exit 4" 4
sb project --bogus x
rc_is "project: unknown flag gives exit 5" 5
sb project --name
rc_is "project: flag with no value gives exit 5" 5
sb context --cwd "$tmp/code/example-api"
out_has "context: project from the working directory" "project: Example"
out_has "context: project path" "project_path: $P"
out_has "context: no sprint yet" "sprint: none"

# ---------------------------------------------------------------- profile
sb profile Example --keys
rc_is "profile --keys: exit 0" 0
out_has "profile --keys: scalar" "project: Example"
out_has "profile --keys: inline list" "ticket_keys: EX, EXOPS"
out_has "profile --keys: block list" "tags: type/profile"
out_has "profile --keys: roots" "tasks_root: tasks"
out_has "profile --keys: an empty value prints a dash" "persona: -"
out_has "profile --keys: an empty list prints a dash" "environments: -"
is "profile: persona sits right after tracker" "$(($(lineno "$vault/$P/claude/profile.md" 'persona:') - $(lineno "$vault/$P/claude/profile.md" 'tracker:')))" "1"
sb profile Example stories
out_has "profile: the stories section explains the persona" "the role a story's description opens with"
sb profile Example stories
rc_is "profile section: exit 0" 0
out_has "profile section: its body" "Persona"
out_lacks "profile section: stops at the next heading" "Spelling exceptions"
sb profile Example live systems
rc_is "profile section: two words, any case" 0
sb profile Example Docs
out_has "profile section: Docs keeps its level-3 headings" "### Debt file"
is "profile: nine headings under Docs" "$(printf '%s\n' "$OUT" | grep -c '^### ')" "9"
is "profile: seven fixed sections" "$(grep -c '^## ' "$vault/$P/claude/profile.md")" "7"
sb profile Example nosuch
rc_is "profile section: absent gives exit 1" 1
sb profile Nope --keys
rc_is "profile: unknown project gives exit 1" 1
sb profile Example
rc_is "profile: no section gives exit 5" 5
mkdir -p "$vault/misc/three/tasks"
printf '| Three | misc/three | T | A project with no profile. |\n' >>"$vault/CLAUDE.md"
sb profile Three --keys
rc_is "profile: missing profile gives exit 1" 1
err_has "profile: missing profile hints at adopt" "vault-setup adopt"

# ---------------------------------------------------------------- task new
mkdir -p "$vault/$P/docs/billing/Invoices" "$vault/$P/docs/api"
sb task new EX-1 --project Example --title 'Fix: totals "rounded" twice' --topics billing/invoices
rc_is "task new: exit 0" 0
out_is "task new: prints the README path" "$P/tasks/EX-1/README.md"
T1="$vault/$P/tasks/EX-1/README.md"
is "task new: first alias is the folder name" "$(sb_fm_list "$T1" aliases | head -1)" "EX-1"
line_is "task new: title quoted and escaped" "$T1" 'title: "Fix: totals \"rounded\" twice"'
line_is "task new: status planned" "$T1" "status: planned"
line_is "task new: topic tag" "$T1" "  - billing/invoices"
line_is "task new: rollup tag" "$T1" "  - status/active"
line_is "task new: up-link carries the path" "$T1" "> Up: [[$P/tasks/README|Example Tasks Hub]]"
line_is "task new: heading" "$T1" '# EX-1 - Fix: totals "rounded" twice'
file_lacks "task new: never writes jira_id" "$T1" "jira_id"
file_lacks "task new: no sprint key in the backlog" "$T1" "sprint:"
is "task new: body sections in order" "$(grep '^## ' "$T1" | tr '\n' '|')" \
  "## Description|## Findings|## Acceptance criteria|## Approach / Key decisions|## Code verification (read-only)|## Changes|## Verification|## Status notes|## Discovery log|"
cp "$T1" "$tmp/t1.before"
sb task new EX-1 --project Example --title Again
rc_is "task new: existing folder gives exit 6" 6
is "task new: the existing README is untouched" "$(cmp -s "$tmp/t1.before" "$T1"; echo $?)" "0"
sb task new EX-2 --project Example --title Second --topics "docs/API, billing-old"
rc_is "task new: several topics" 0
err_has "task new: warns about a topic with no folder" "billing-old"
T2="$vault/$P/tasks/EX-2/README.md"
line_is "task new: topics root stripped, lowercased" "$T2" "  - api"
sb task new EX-3 --project Example
T3="$vault/$P/tasks/EX-3/README.md"
is "task new: no topics leaves no gap in tags" "$(grep -A1 '^tags:' "$T3" | tail -1)" "  - type/task"
line_is "task new: default title" "$T3" 'title: "Untitled"'
sb task new TWO-1 --title "Other project"
out_is "task new: project found from the key" "$P2/tasks/TWO-1/README.md"
sb task new EX-9
rc_is "task new: a shared key and no --project gives exit 5" 5
sb task new "bad/id" --project Example
rc_is "task new: an id with a slash gives exit 5" 5
sb task new
rc_is "task new: no id gives exit 5" 5
sb task new T-1 --project Three
rc_is "task new: a project with no profile gives exit 1" 1
sb task new EX-7 --project Example --envs
rc_is "task new --envs: no environments in the profile gives exit 5" 5
absent "task new --envs: nothing created on refusal" "$vault/$P/tasks/EX-7"
edit "$vault/$P/claude/profile.md" 's/^environments: \[\]$/environments: [dev, qa]/'
sb task new EX-7 --project Example --envs --title "Per environment"
rc_is "task new --envs: exit 0" 0
T7="$vault/$P/tasks/EX-7/README.md"
line_is "task new --envs: first environment holds the id" "$T7" "  dev: { id: EX-7, status: planned }"
file_lacks "task new --envs: later environments wait for their tickets" "$T7" "  qa:"
is "task new --envs: additions sit before the description" "$(($(lineno "$T7" '## Description') > $(lineno "$T7" '## Environments')))" "1"
file_has "task new --envs: the per-environment heading form" "$T7" '`### <ENV> - <ID> (<status>)`'
file_has "task new --envs: the first environment's heading, with its status" "$T7" '`### DEV - EX-7 (planned)`'
for t in EX-4 EX-5 EX-6; do sb task new "$t" --project Example --title "Task $t"; done

# ---------------------------------------------------------------- task set
sb task set EX-1 status=in-progress
rc_is "task set: exit 0" 0
out_is "task set: prints the changed key" "status: in-progress"
sb task set EX-1 status=done
out_is "task set: status and tag reported together" "status: done
tags: status/done"
line_is "task set: status written" "$T1" "status: done"
line_is "task set: tag follows to status/done" "$T1" "  - status/done"
file_lacks "task set: old tag gone" "$T1" "status/active"
sb task set EX-1 status=in-review
line_is "task set: tag follows back to status/active" "$T1" "  - status/active"
file_lacks "task set: no stale status/done" "$T1" "status/done"
sb task set EX-1 status=abandoned
line_is "task set: abandoned rolls up to status/done" "$T1" "  - status/done"
sb task set EX-1 status=in-review
cp "$T1" "$tmp/t1.before"
sb task set EX-1 "next=Check: the #1 thing"
line_is "task set: a value that needs quotes" "$T1" 'next: "Check: the #1 thing"'
is "task set: only that line changed" "$(diff "$tmp/t1.before" "$T1" | grep -c '^[<>]')" "2"
sb task set EX-1 sprint=2026-10-14 branch=feature/EX-1-fix epic=-
out_is "task set: several keys at once" "sprint: 2026-10-14
branch: feature/EX-1-fix"
line_is "task set: sprint id quoted" "$T1" 'sprint: "2026-10-14"'
line_is "task set: plain value unquoted" "$T1" "branch: feature/EX-1-fix"
line_is "task set: lone dash stays quoted" "$T1" 'epic: "-"'
is "task set: a new sprint key lands after epic" "$(($(lineno "$T1" 'sprint:') - $(lineno "$T1" 'epic:')))" "1"
sb task set EX-1 epic=
out_is "task set: key= removes the key" "epic: (removed)"
file_lacks "task set: key removed from the file" "$T1" "epic:"
sb task set EX-1 status=in-review
out_is "task set: nothing to change" "no change"
sb task set EX-1 status=active
rc_is "task set: a non-standard status gives exit 5" 5
line_is "task set: refused status not written" "$T1" "status: in-review"
sb task set EX-1 jira_id=EX-1
rc_is "task set: jira_id gives exit 5" 5
file_lacks "task set: jira_id never written" "$T1" "jira_id"
sb task set EX-1 tags=x
rc_is "task set: a list key gives exit 5" 5
sb task set EX-1 sprint=next-week
rc_is "task set: a sprint id that is not a date gives exit 5" 5
sb task set EX-1
rc_is "task set: no pair gives exit 5" 5
sb task set EX-404 status=done
rc_is "task set: unknown task gives exit 1" 1
sb task set EX-2 status=planned next="Draft the API change"
sb task set EX-3 status=done
sb task set EX-4 status=abandoned
sb task set EX-5 status=in-progress
T6="$vault/$P/tasks/EX-6/README.md"
awk '{ printf "%s\r\n", $0 }' "$T6" >"$tmp/crlf.tmp" && cat "$tmp/crlf.tmp" >"$T6"
sb task set EX-6 status=in-review "next=a: b" sprint=2026-10-14 epic=
rc_is "task set: CRLF file, exit 0" 0
is "task set: every line still ends in CRLF" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
line_is "task set: CRLF value written" "$T6" "next: \"a: b\"$CR"
line_is "task set: CRLF status written" "$T6" "status: in-review$CR"
line_is "task set: CRLF new key written" "$T6" "sprint: \"2026-10-14\"$CR"
sb task note EX-6 "Note on a CRLF file" --session s9
is "task note: CRLF kept" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
is "sb_fm_get: reads a CRLF file" "$(SB_ROOT="$vault"; sb_fm_get "$T6" status)" "in-review"

# ---------------------------------------------------------------- task note
sb task note EX-1 "First note" --session abc123
rc_is "task note: exit 0" 0
out_is "task note: prints the line it added" '**2026-10-08 (session `abc123`) - First note**'
sb task note EX-1 "Second note" --session abc123
is "task note: newest first" "$(($(lineno "$T1" 'Second note') < $(lineno "$T1" 'First note')))" "1"
is "task note: under the status notes heading" "$(($(lineno "$T1" 'Second note') > $(lineno "$T1" '## Status notes')))" "1"
is "task note: above the discovery log" "$(($(lineno "$T1" 'First note') < $(lineno "$T1" '## Discovery log')))" "1"
sb task note EX-2 "No session here"
out_is "task note: no session id, no session part" '**2026-10-08 - No session here**'
sb task note EX-1
rc_is "task note: no text gives exit 5" 5
sb task note EX-404 "x"
rc_is "task note: unknown task gives exit 1" 1
mkdir -p "$vault/$P/tasks/legacy-task"
printf '# Legacy task\n\nNo frontmatter and no sections.\n' >"$vault/$P/tasks/legacy-task/README.md"
sb task note legacy-task "Picked up again" --project Example
rc_is "task note: a note with no status notes section" 0
file_has "task note: adds the section" "$vault/$P/tasks/legacy-task/README.md" "## Status notes"

# ---------------------------------------------------------------- task head
edit "$T1" 's/^\*\*Summary:\*\* .*$/**Summary:** Totals are rounded per line and again per invoice,\
so large invoices drift by a cent./'
sb task head EX-1
rc_is "task head: exit 0" 0
if [ "$(lines "$OUT")" -le 15 ]; then pass "task head: at most 15 lines"; else fail "task head: at most 15 lines" "$OUT"; fi
out_has "task head: id" "id: EX-1"
out_has "task head: title" 'title: Fix: totals "rounded" twice'
out_has "task head: status" "status: in-review"
out_has "task head: next" "next: Check: the #1 thing"
out_has "task head: sprint" "sprint: 2026-10-14"
out_has "task head: branch" "branch: feature/EX-1-fix"
out_has "task head: topics" "topics: billing/invoices"
out_has "task head: summary joined over its wrapped line" "summary: Totals are rounded per line and again per invoice, so large invoices drift by a cent."
out_has "task head: newest status note" 'last_note: **2026-10-08 (session `abc123`) - Second note**'
out_has "task head: no environment set prints a dash" "envs: -"
sb task head EX-7
out_has "task head: environment set" "envs: dev:EX-7:planned"
sb task head legacy-task --project Example
out_has "task head: a note with no frontmatter" "status: -"
out_has "task head: title from the heading" "title: Legacy task"
edit "$T7" 's/^  - EX-7$/  - EX-7\
  - EX-70/'
edit "$T7" 's/^  dev: .*$/  dev:  { id: EX-7, status: done }\
  qa:   { id: EX-70, status: planned }/'
sb task head EX-7
out_has "task head: every environment of the set, in the note's order" "envs: dev:EX-7:done,qa:EX-70:planned"
sb task head EX-70
out_has "task head: an alias id finds the set" "id: EX-7"
if [ "$(lines "$OUT")" -le 15 ]; then pass "task head: an environment set still fits 15 lines"; else fail "task head: an environment set still fits 15 lines" "$OUT"; fi
sb task head EX-404
rc_is "task head: unknown task gives exit 1" 1
sb task head
rc_is "task head: no id gives exit 5" 5
sb task bogus
rc_is "task: unknown subcommand gives exit 5" 5

# ---------------------------------------------------------------- an alias as the id
sb task set EX-70 "next=Promote to qa"
rc_is "task set: a later environment's id finds the set" 0
line_is "task set: written to the set's README" "$T7" "next: Promote to qa"
sb task note EX-70 "qa: promotion started" --session s2
file_has "task note: an alias id writes to the set" "$T7" '**2026-10-08 (session `s2`) - qa: promotion started**'
sb task tag EX-70 add api
out_is "task tag: an alias id edits the set" "api"
sb task tag EX-70 remove api
out_is "task tag: removed again through the alias" "-"
sb task new EX-70 --project Example --title "A second folder"
rc_is "task new: an id that is an alias of a task gives exit 6" 6
absent "task new: no folder for an alias" "$vault/$P/tasks/EX-70"

# ---------------------------------------------------------------- task tag
T4="$vault/$P/tasks/EX-4/README.md"
sb task tag EX-4 add billing/invoices
rc_is "task tag add: exit 0" 0
out_is "task tag add: prints the resulting topic tags" "billing/invoices"
is "task tag add: the topic goes before the type and status tags" "$(grep -A1 '^tags:' "$T4" | tail -1)" "  - billing/invoices"
sb task tag EX-4 add "docs/API"
out_is "task tag add: topics root stripped, lowercased" "billing/invoices
api"
cp "$T4" "$tmp/t4.before"
sb task tag EX-4 add "#Billing/Invoices"
out_is "task tag add: a tag it has is not added twice" "billing/invoices
api"
is "task tag add: the file is untouched by a duplicate" "$(cmp -s "$tmp/t4.before" "$T4"; echo $?)" "0"
sb task tag EX-4 add "Ops Runbooks"
err_has "task tag add: warns about a topic with no folder" "ops-runbooks"
is "task tag add: one line added" "$(diff "$tmp/t4.before" "$T4" | grep -c '^[<>]')" "1"
sb task tag EX-4 add type/bug
rc_is "task tag: a type/ tag is refused, exit 5" 5
sb task tag EX-4 remove status/done
rc_is "task tag: a status/ tag is refused, exit 5" 5
line_is "task tag: the refused status tag is still there" "$T4" "  - status/done"
file_lacks "task tag: the refused type tag was not written" "$T4" "type/bug"
sb task tag EX-4 remove API
out_is "task tag remove: matches without case" "billing/invoices
ops-runbooks"
sb task tag EX-4 remove nothing-like-it
rc_is "task tag remove: a tag it lacks changes nothing" 0
sb task tag EX-4 remove ops-runbooks
sb task tag EX-4 remove billing/invoices
out_is "task tag remove: no topic left prints a dash" "-"
line_is "task tag remove: the type tag stays" "$T4" "  - type/task"
sb task tag EX-4 rename a
rc_is "task tag: unknown action gives exit 5" 5
sb task tag EX-4 add
rc_is "task tag: no tag gives exit 5" 5
sb task tag EX-404 add api
rc_is "task tag: unknown task gives exit 1" 1
sb task tag EX-6 add api
out_is "task tag: CRLF file, tag added" "api"
is "task tag: CRLF kept after add" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
line_is "task tag: CRLF line written" "$T6" "  - api$CR"
sb task tag EX-6 remove api
is "task tag: CRLF kept after remove" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
file_lacks "task tag: CRLF tag removed" "$T6" "  - api"

# ---------------------------------------------------------------- task alias
sb task alias EX-4 add "Totals: rounding"
rc_is "task alias add: exit 0" 0
out_is "task alias add: prints the resulting aliases" "EX-4
Totals: rounding"
line_is "task alias add: an alias with a colon and a space is quoted" "$T4" '  - "Totals: rounding"'
is "task alias add: the first alias never changes" "$(grep -A1 '^aliases:' "$T4" | tail -1)" "  - EX-4"
cp "$T4" "$tmp/t4.before"
sb task alias EX-4 add "totals: ROUNDING"
is "task alias add: no duplicate, whatever the case" "$(cmp -s "$tmp/t4.before" "$T4"; echo $?)" "0"
sb task alias EX-4 add Rounding twice
out_is "task alias add: unquoted words are one alias, appended last" "EX-4
Totals: rounding
Rounding twice"
line_is "task alias add: a plain alias is not quoted" "$T4" "  - Rounding twice"
sb task alias EX-4 add EX-1
rc_is "task alias add: another task's folder id gives exit 6" 6
sb task alias EX-4 add EX-70
rc_is "task alias add: another task's alias gives exit 6" 6
file_lacks "task alias add: a refused alias is not written" "$T4" "EX-70"
sb task alias EX-4 remove "Rounding twice"
rc_is "task alias: only add is known, exit 5" 5
sb task alias EX-4 add
rc_is "task alias: no alias gives exit 5" 5
sb task alias EX-404 add x
rc_is "task alias: unknown task gives exit 1" 1
sb task alias EX-5 add EX-55
sb task head EX-55
out_has "task alias: the new alias finds the task" "id: EX-5"
sb task alias EX-6 add "Lambda: node summary"
is "task alias: CRLF kept" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
line_is "task alias: CRLF line written, quoted" "$T6" "  - \"Lambda: node summary\"$CR"
mkdir -p "$vault/$P2/tasks/no-alias"
printf -- '---\nstatus: planned\n---\n\n# no-alias - a note with no aliases\n' >"$vault/$P2/tasks/no-alias/README.md"
sb task alias no-alias add "Other name" --project "Example Two"
out_is "task alias: a note with no aliases gets the folder id first" "no-alias
Other name"

# ---------------------------------------------------------------- board
edit "$vault/$P/tasks/EX-7/README.md" 's/^status: planned$/status: active/'
sb board Example
rc_is "board: exit 0" 0
out_lacks "board: no source line" "source:"
out_has "board: row format" 'EX-1 | Fix: totals "rounded" twice | in-review | 2026-10-14 | billing/invoices | feature/EX-1-fix | Check: the #1 thing | -'
is "board Active: planned, in-progress and in-review only" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "EX-5 EX-1 EX-6 EX-2 "
sb board Example All
is "board All: every task folder" "$(lines "$OUT")" "8"
is "board: every row has eight cells" "$(printf '%s\n' "$OUT" | awk -F' [|] ' 'NF != 8' | grep -c . || true)" "0"
out_has "board: envs column for an environment set" "EX-7 | Per environment | active | - | - | none yet | Promote to qa | dev:EX-7:done,qa:EX-70:planned"
out_has "board: title from the heading when the property is absent" "legacy-task | Legacy task | - | - | - | - | - | -"
sb board Example needs a status
is "board Needs a status: missing or non-standard status" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "EX-7 legacy-task "
sb board Example "By topic"
is "board By topic: active tasks by first topic, untagged last" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "EX-2 EX-1 EX-5 EX-6 "
sb board Example "Current sprint"
rc_is "board Current sprint: exit 0 while no sprint is in progress" 0
out_is "board Current sprint: no rows while no sprint is in progress" ""
mv "$vault/$P/tasks/tasks.base" "$tmp/tasks.base.aside"
sb board Example
is "board: the board file is not read" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "EX-5 EX-1 EX-6 EX-2 "
mv "$tmp/tasks.base.aside" "$vault/$P/tasks/tasks.base"
sb board Example all --files
rc_is "board: the --files flag is gone, exit 5" 5
sb board Example bogus
rc_is "board: unknown view gives exit 5" 5
sb board Nope
rc_is "board: unknown project gives exit 1" 1
sb board
rc_is "board: no project gives exit 5" 5

# ---------------------------------------------------------------- topic
sb topic Example billing
rc_is "topic: exit 0" 0
out_is "topic: a tag matches its sub-tags, not its look-alikes" "$P/tasks/EX-1/README.md"
sb topic Example "#API"
out_is "topic: case and a leading hash ignored" "$P/tasks/EX-2/README.md"
sb topic Example nothing-here
rc_is "topic: none gives exit 1" 1
sb topic Example
rc_is "topic: no tag gives exit 5" 5

# ---------------------------------------------------------------- find
sb find EX-2
rc_is "find: exit 0" 0
out_is "find: the task path" "$P/tasks/EX-2/README.md"
sb find EX-70
out_is "find: an id that is only an alias" "$P/tasks/EX-7/README.md"
sb find "example tasks hub"
out_is "find: a hub by alias" "$P/tasks/README.md"
sb find "Obsidian Conventions"
out_is "find: a vault-level note" "obsidian-conventions.md"
printf -- '---\naliases:\n  - "Billing Notes"\n---\n\n# Notes on billing\n' >"$vault/$P/docs/billing/notes.md"
sb find "billing notes"
out_is "find: an alias in the frontmatter of any note of the project" "$P/docs/billing/notes.md"
sb find "billing notes" --project "Example Two"
rc_is "find: an alias of another project's note is not found with --project" 1
sb find TWO-1 --project Example
rc_is "find: --project narrows the search" 1
sb find TWO-1 --project "Example Two"
out_is "find: found in the named project" "$P2/tasks/TWO-1/README.md"
sb find Nothing-Like-This
rc_is "find: none gives exit 1" 1
sb find
rc_is "find: no argument gives exit 5" 5

# ---------------------------------------------------------------- search
i=0
: >"$vault/$P/docs/billing/Invoices/many.md"
while [ "$i" -lt 60 ]; do
  printf 'line %s holds needle-x here\n' "$i" >>"$vault/$P/docs/billing/Invoices/many.md"
  i=$((i + 1))
done
printf 'needle-x in a text file\n' >"$vault/$P/docs/billing/Invoices/data.txt"
sb search Example "ROUNDED"
rc_is "search: exit 0" 0
out_has "search: path, line number, text" "$P/tasks/EX-1/README.md:4: title:"
is "search: every row is path:line: text" "$(printf '%s\n' "$OUT" | grep -vc "^$P/.*\\.md:[0-9][0-9]*: ")" "0"
sb search Example needle-x
out_is "search: a note gives three lines at most, its first for one word" "$P/docs/billing/Invoices/many.md:1: line 0 holds needle-x here
$P/docs/billing/Invoices/many.md:2: line 1 holds needle-x here
$P/docs/billing/Invoices/many.md:3: line 2 holds needle-x here"
out_lacks "search: markdown files only" "data.txt"
i=10
mkdir -p "$vault/$P/docs/cap"
while [ "$i" -lt 55 ]; do
  printf 'first needle-y here\nsecond needle-y here\n' >"$vault/$P/docs/cap/n-$i.md"
  i=$((i + 1))
done
sb search Example needle-y
is "search: at most 40 rows" "$(lines "$OUT")" "40"
is "search: every note keeps its best line before any note keeps a second" "$(printf '%s\n' "$OUT" | grep -c ':1: first needle-y here$')" "40"
rm -r "$vault/$P/docs/cap"
sb search Example rounded --in tasks/EX-1
is "search --in: stays inside the sub-folder" "$(printf '%s\n' "$OUT" | grep -vc "^$P/tasks/EX-1/")" "0"
sb search "Example Two" rounded
rc_is "search: stays inside the project, none gives exit 1" 1
sb search Example rounded --in nowhere
rc_is "search --in: missing folder gives exit 1" 1
sb search Example
rc_is "search: no text gives exit 5" 5
sb search Example "   "
rc_is "search: a text of spaces gives exit 5" 5
W="$P/docs/billing/Invoices"
printf '%s\n' '# Qalpha report' '' 'qalpha only here' 'QBETA and Qalpha together' 'nothing' 'qbeta alone' >"$vault/$W/words.md"
printf '%s\n' 'qbeta qalpha' >"$vault/$W/zz-words.md"
printf '%s\n' 'qalpha without the other word' >"$vault/$W/half.md"
printf '%s\n' 'intro qalpha here' 'filler' 'qalpha again' 'later qbeta shows' 'qbeta again' >"$vault/$W/spread.md"
sb search Example "qbeta  QALPHA"
rc_is "search: several words, exit 0" 0
out_is "search: lines holding two of the words, and for a note with none the first line of each word" "$W/words.md:4: QBETA and Qalpha together
$W/zz-words.md:1: qbeta qalpha
$W/spread.md:1: intro qalpha here
$W/spread.md:4: later qbeta shows"
out_lacks "search: several words leave out a line that holds one of them beside a fuller line" "qalpha only here"
out_lacks "search: several words leave out the later lines of a word in a note with no fuller line" "qalpha again"
sb search Example "qalpha"
out_has "search: one word matches the note that holds it" "$W/half.md:1: qalpha without the other word"
out_has "search: one word lists every line that holds it" "$W/words.md:3: qalpha only here"
sb search Example "qalpha no-such-word"
rc_is "search: a word no note holds gives exit 1" 1
sb search Example '"qalpha only"'
out_is "search: a part in double quotes is a phrase" "$W/words.md:3: qalpha only here"
sb search Example '"QBETA ALONE"'
out_is "search: a phrase matches in any letter case" "$W/words.md:6: qbeta alone"
sb search Example '"qbeta   alone"'
rc_is "search: a phrase keeps the blanks between its words, exit 1 when they differ" 1
sb search Example '"qbeta alone" report'
out_is "search: a phrase beside a word, each on its first line" "$W/words.md:1: # Qalpha report
$W/words.md:6: qbeta alone"
sb search Example '"qalpha qbeta"'
rc_is "search: a phrase in another order matches nothing, exit 1" 1
sb search Example '"qalpha only'
out_is "search: a quote left open runs to the end of the text" "$W/words.md:3: qalpha only here"
sb search Example '""'
rc_is "search: quotes with nothing in them give exit 5" 5
printf '%s\n' 'qone qtwo a' 'qone qtwo b' 'qone qtwo qthree best' 'qone qtwo c' 'qthree alone' >"$vault/$W/rank.md"
sb search Example "qone qtwo qthree"
out_is "search: several words, a note's three best lines, the fullest first" "$W/rank.md:3: qone qtwo qthree best
$W/rank.md:1: qone qtwo a
$W/rank.md:2: qone qtwo b"
rm "$vault/$W/rank.md"
rm "$vault/$W/words.md" "$vault/$W/zz-words.md" "$vault/$W/half.md" "$vault/$W/spread.md"

# ---------------------------------------------------------------- sprint
sb sprint current Example
rc_is "sprint current: none gives exit 1" 1
sb sprint open Example
rc_is "sprint open: no anchor and no --end gives exit 5" 5
sb sprint next Example
rc_is "sprint next: no anchor in the profile gives exit 1" 1
sb sprint set Example goal=x
rc_is "sprint set: no sprint in progress gives exit 1" 1
sb sprint open Example --end 2026-02-30
rc_is "sprint open: an impossible date gives exit 5" 5
sb sprint open Example --end 2026-10-14 --goal "Ship: invoices"
rc_is "sprint open: exit 0" 0
out_is "sprint open: prints the note path" "$P/sprints/2026-10-14.md"
S1="$vault/$P/sprints/2026-10-14.md"
line_is "sprint note: alias" "$S1" '  - "Example Sprint 2026-10-14"'
line_is "sprint note: id quoted" "$S1" 'sprint: "2026-10-14"'
line_is "sprint note: start from the length" "$S1" "start: 2026-10-01"
line_is "sprint note: end" "$S1" "end: 2026-10-14"
line_is "sprint note: in progress" "$S1" "status: in-progress"
line_is "sprint note: goal quoted" "$S1" 'goal: "Ship: invoices"'
line_is "sprint note: up-link" "$S1" "> Up: [[$P/sprints/README|Example Sprints Hub]]"
is "sprint note: body sections" "$(grep '^## ' "$S1" | tr '\n' '|')" "## Goal|## Notes|## Close|"
line_is "sprint open: hub gets one link line" "$vault/$P/sprints/README.md" "- [[$P/sprints/2026-10-14|Example Sprint 2026-10-14]] - 2026-10-01 to 2026-10-14"
line_is "sprint open: board literal rewritten" "$vault/$P/tasks/tasks.base" '        - sprint == "2026-10-14"'
file_lacks "sprint open: old literal gone" "$vault/$P/tasks/tasks.base" 'sprint == "none"'
line_is "sprint open: the first end date becomes the anchor" "$vault/$P/claude/profile.md" 'sprint_anchor_end: "2026-10-14"'
sb sprint open Example --end 2026-10-28
rc_is "sprint open: refused while one is in progress, exit 6" 6
absent "sprint open: nothing created on refusal" "$vault/$P/sprints/2026-10-28.md"
sb sprint current Example
rc_is "sprint current: exit 0" 0
out_is "sprint current: id, start, end, days left, goal" "2026-10-14${TAB}2026-10-01${TAB}2026-10-14${TAB}6${TAB}Ship: invoices"
sb context --cwd "$vault/$P"
out_has "context: sprint in progress" "sprint: 2026-10-14"
sb sprint set Example committed=5 "goal=Ship: invoices and credits"
rc_is "sprint set: exit 0" 0
out_is "sprint set: prints the changed keys" "committed: 5
goal: Ship: invoices and credits"
line_is "sprint set: committed is a number" "$S1" "committed: 5"
line_is "sprint set: goal quoted" "$S1" 'goal: "Ship: invoices and credits"'
sb sprint set Example committed=5
out_is "sprint set: nothing to change" "no change"
sb sprint current Example
out_has "sprint set: sprint current shows the new goal" "Ship: invoices and credits"
sb sprint set Example status=done
rc_is "sprint set: any other key gives exit 5" 5
line_is "sprint set: the refused key is not written" "$S1" "status: in-progress"
sb sprint set Example committed=many
rc_is "sprint set: committed must be a number, exit 5" 5
sb sprint set Example
rc_is "sprint set: no pair gives exit 5" 5
sb sprint set Nope goal=x
rc_is "sprint set: unknown project gives exit 1" 1
for t in EX-2 EX-3 EX-4 EX-5; do sb task set "$t" sprint=2026-10-14; done
sb board Example "Current sprint"
is "board Current sprint: the tasks of the sprint in progress" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | LC_ALL=C sort | tr '\n' ' ')" "EX-1 EX-2 EX-3 EX-4 EX-5 EX-6 "
sb sprint close Example --carry EX-1
rc_is "sprint close: open tasks left unnamed give exit 5" 5
is "sprint close: lists the missing ones" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | LC_ALL=C sort | tr '\n' ' ')" "EX-2 EX-5 EX-6 "
line_is "sprint close: nothing changed on refusal" "$S1" "status: in-progress"
line_is "sprint close: no task touched on refusal" "$T1" "carried_from: []"
sb sprint close Example --carry EX-1,EX-404 --backlog EX-2 --abandon EX-5,EX-6
rc_is "sprint close: an id outside the sprint gives exit 5" 5
sb sprint close Example --carry EX-1,EX-2 --backlog EX-2 --abandon EX-5,EX-6
rc_is "sprint close: an id named twice gives exit 5" 5
sb sprint close Example --carry EX-1 --backlog EX-2 --abandon EX-55 --abandon EX-6
rc_is "sprint close: exit 0, one task named by an alias" 0
out_is "sprint close: summary, six labelled lines in order" "sprint: 2026-10-14
done: EX-3
carried: EX-1
backlog: EX-2
abandoned: EX-4, EX-5, EX-6
next: 2026-10-28"
line_is "sprint close: carried task moves to the next sprint" "$T1" 'sprint: "2026-10-28"'
is "sprint close: carried_from records the old id" "$(SB_ROOT="$vault"; sb_fm_list "$T1" carried_from)" "2026-10-14"
line_is "sprint close: carried id quoted" "$T1" '  - "2026-10-14"'
file_lacks "sprint close: status notes are left to the caller" "$T1" "Carried"
file_lacks "sprint close: backlog task loses its sprint" "$T2" "sprint:"
line_is "sprint close: abandoned task status" "$vault/$P/tasks/EX-5/README.md" "status: abandoned"
line_is "sprint close: abandoned task tag" "$vault/$P/tasks/EX-5/README.md" "  - status/done"
line_is "sprint close: abandoned CRLF task keeps its endings" "$T6" "status: abandoned$CR"
line_is "sprint close: done task keeps its sprint" "$T3" 'sprint: "2026-10-14"'
line_is "sprint close: sprint note done" "$S1" "status: done"
line_is "sprint close: sprint note tag" "$S1" "  - status/done"
line_is "sprint close: completed count" "$S1" "completed: 1"
line_is "sprint close: carried count" "$S1" "carried_over: 1"
line_is "sprint close: committed left as planning froze it" "$S1" "committed: 5"
line_is "sprint close: close section links with a path" "$S1" "- [[$P/tasks/EX-3/README|EX-3]] - Untitled"
line_is "sprint close: close section counts" "$S1" "Counts: done 1, carried over 1, backlog 1, abandoned 3."
sb sprint current Example
rc_is "sprint current: none after the close" 1
sb sprint close Example
rc_is "sprint close: no sprint in progress gives exit 1" 1
ls "$vault/$P/sprints" >"$tmp/sprints.before"
sb sprint next Example
rc_is "sprint next: exit 0" 0
out_is "sprint next: id, start, end from the cadence" "2026-10-28${TAB}2026-10-15${TAB}2026-10-28"
NEXT_ID="$(printf '%s\n' "$OUT" | cut -f1)"
NEXT_START="$(printf '%s\n' "$OUT" | cut -f2)"
ls "$vault/$P/sprints" >"$tmp/sprints.after"
is "sprint next: writes nothing" "$(cmp -s "$tmp/sprints.before" "$tmp/sprints.after"; echo $?)" "0"
sb sprint open Example
rc_is "sprint open: next sprint from the cadence" 0
out_is "sprint open: creates exactly what sprint next printed" "$P/sprints/$NEXT_ID.md"
line_is "sprint open: with the start sprint next printed" "$vault/$P/sprints/$NEXT_ID.md" "start: $NEXT_START"
out_is "sprint open: skips the sprint that already ended" "$P/sprints/2026-10-28.md"
sb sprint next Example
out_is "sprint next: with a sprint in progress, the one after it" "2026-11-11${TAB}2026-10-29${TAB}2026-11-11"
sb sprint next
rc_is "sprint next: no project gives exit 5" 5
line_is "sprint open: start of the next sprint" "$vault/$P/sprints/2026-10-28.md" "start: 2026-10-15"
line_is "sprint open: board literal follows" "$vault/$P/tasks/tasks.base" '        - sprint == "2026-10-28"'
is "sprint open: hub lists the newest sprint first" "$(($(lineno "$vault/$P/sprints/README.md" 'sprints/2026-10-28|') + 1))" "$(lineno "$vault/$P/sprints/README.md" 'sprints/2026-10-14|')"
sb sprint close Example --carry EX-1
out_has "sprint close: next is what sprint next printed" "next: 2026-11-11"
is "sprint close: a second carry appends" "$(SB_ROOT="$vault"; sb_fm_list "$T1" carried_from | tr '\n' ' ')" "2026-10-14 2026-10-28 "
line_is "sprint close: the carried task waits on the computed next id" "$T1" 'sprint: "2026-11-11"'
sb task set EX-2 sprint=2030-01-01
sb task set EX-4 sprint=2031-01-01
sb sprint open Example --end 2026-11-05
out_is "sprint open: off cadence, then one line per task it re-pointed" "$P/sprints/2026-11-05.md
re-pointed: EX-1 from 2026-11-11 to 2026-11-05
re-pointed: EX-2 from 2030-01-01 to 2026-11-05"
line_is "sprint open: a carried task follows the sprint that opened" "$T1" 'sprint: "2026-11-05"'
line_is "sprint open: an open task on a sprint with no note follows too" "$T2" 'sprint: "2026-11-05"'
line_is "sprint open: a closed task is left where it is" "$T4" 'sprint: "2031-01-01"'
line_is "sprint open: a task on a sprint that has a note is left alone" "$T3" 'sprint: "2026-10-14"'
is "sprint open: re-pointing is not a carry" "$(SB_ROOT="$vault"; sb_fm_list "$T1" carried_from | tr '\n' ' ')" "2026-10-14 2026-10-28 "
sb board Example "Current sprint"
is "sprint open: the re-pointed tasks show in the sprint" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | LC_ALL=C sort | tr '\n' ' ')" "EX-1 EX-2 "
line_is "sprint open: an anchor that exists is not moved" "$vault/$P/claude/profile.md" 'sprint_anchor_end: "2026-10-14"'
sb sprint open "Example Two" --end 2028-03-05
line_is "sprint open: start over a leap day" "$vault/$P2/sprints/2028-03-05.md" "start: 2028-02-21"
run env SECOND_BRAIN_TODAY=2027-12-25 "$SB" sprint current "Example Two"
out_is "sprint current: days left across a year end, empty goal" "2028-03-05${TAB}2028-02-21${TAB}2028-03-05${TAB}71${TAB}-"
sb sprint
rc_is "sprint: no subcommand gives exit 5" 5
sb sprint open
rc_is "sprint open: no project gives exit 5" 5
sb sprint current Nope
rc_is "sprint current: unknown project gives exit 1" 1

# ---------------------------------------------------------------- edge cases
mkdir -p "$vault/$P/tasks/EX-20/queries"
printf 'select 1;\n' >"$vault/$P/tasks/EX-20/queries/check.sql"
sb task new EX-20 --project Example --title "Folder came first"
rc_is "task new: a folder with no README gets one" 0
out_is "task new: same output as a new task" "$P/tasks/EX-20/README.md"
line_is "task new: the README is the usual one" "$vault/$P/tasks/EX-20/README.md" 'title: "Folder came first"'
exists "task new: what was in the folder is kept" "$vault/$P/tasks/EX-20/queries/check.sql"
sb task new EX-20 --project Example
rc_is "task new: a second run still gives exit 6" 6
sb task head EX-2
out_has "task head: epic line, dash when it is empty" "epic: -"
sb task set EX-2 epic=EX-900
sb task head EX-2
out_has "task head: epic line" "epic: EX-900"
is "task head: epic comes after branch" "$(printf '%s\n' "$OUT" | grep -A1 '^branch:' | tail -1)" "epic: EX-900"
if [ "$(lines "$OUT")" -le 15 ]; then pass "task head: still at most 15 lines"; else fail "task head: still at most 15 lines" "$OUT"; fi
sb task set EX-3 type=bug
out_is "task set: type and its tag reported together" "type: bug
tags: type/bug"
line_is "task set: type written" "$T3" "type: bug"
line_is "task set: type tag follows" "$T3" "  - type/bug"
file_lacks "task set: the old type tag is replaced" "$T3" "type/task"
sb task set EX-3 type=task
line_is "task set: type tag follows back" "$T3" "  - type/task"
sb task set EX-3 type=
rc_is "task set: type cannot be removed, exit 5" 5
sb task set EX-3 "type=Bad Type"
rc_is "task set: a type that cannot be a tag gives exit 5" 5
line_is "task set: refused type not written" "$T3" "type: task"
mkdir -p "$vault/$P/tasks/bare-readme"
printf '# bare-readme - Bare\n\nText written by hand.\n' >"$vault/$P/tasks/bare-readme/README.md"
BR="$vault/$P/tasks/bare-readme/README.md"
sb task set bare-readme type=task status=planned "title=Bare one" --project Example
rc_is "task set: a bare README gets its frontmatter" 0
sb task alias bare-readme add bare-readme --project Example
is "bare README: frontmatter opens the file" "$(head -1 "$BR")" "---"
line_is "bare README: type" "$BR" "type: task"
line_is "bare README: status" "$BR" "status: planned"
line_is "bare README: title" "$BR" "title: Bare one"
line_is "bare README: type tag" "$BR" "  - type/task"
line_is "bare README: status tag" "$BR" "  - status/active"
is "bare README: the type tag sits before the status tag" "$(($(lineno "$BR" '  - type/task') < $(lineno "$BR" '  - status/active')))" "1"
is "bare README: first alias is the folder name" "$(SB_ROOT="$vault"; sb_fm_list "$BR" aliases | head -1)" "bare-readme"
file_has "bare README: the body is kept" "$BR" "Text written by hand."
sb board Example Active
out_has "bare README: now a board row" "bare-readme | Bare one | planned | - | - | - | - | -"
mkdir -p "$vault/$P2/tasks/legacy-task"
printf -- '---\naliases:\n  - legacy-task\nstatus: planned\n---\n\n# legacy-task - twin\n\n## Discovery log\n\nold finding\n' >"$vault/$P2/tasks/legacy-task/README.md"
sb task head legacy-task
rc_is "task: an id found in two projects gives exit 4" 4
is "task: prints both candidates" "$(lines "$OUT")" "2"
sb task head legacy-task --project "Example Two"
rc_is "task: --project settles it" 0
sb find legacy-task
is "find: prints every match" "$(lines "$OUT")" "2"
sb task note legacy-task "Before the log" --project "Example Two"
L2="$vault/$P2/tasks/legacy-task/README.md"
is "task note: a missing section goes in before the discovery log" "$(($(lineno "$L2" '## Status notes') < $(lineno "$L2" '## Discovery log')))" "1"
file_has "task note: the rest of the note is kept" "$L2" "old finding"
sb task new 2026-cleanup --project Example --title "Slug that looks like a date"
line_is "task new: an alias that needs quotes gets them" "$vault/$P/tasks/2026-cleanup/README.md" '  - "2026-cleanup"'
sb task head 2026-cleanup
out_has "task head: finds the quoted alias task" "id: 2026-cleanup"
sb scaffold project Four --path work/four --keys FOUR
edit "$vault/work/four/tasks/tasks.base" 's/sprint == "none"/sprint == date("none")/'
sb sprint open Four --end 2026-11-11
line_is "sprint open: keeps a date() literal form on the board" "$vault/work/four/tasks/tasks.base" '        - sprint == date("2026-11-11")'
sb scaffold project Five --path work/five
sb projects
out_has "projects: an empty keys cell prints a dash" "Five${TAB}work/five${TAB}-"
sb project --name five
out_is "project: an empty keys cell prints a dash" "Five${TAB}work/five${TAB}-"
edit "$vault/work/five/tasks/tasks.base" 's/name: Current sprint/name: Some other view/'
sb sprint open Five --end 2026-11-11
rc_is "sprint open: a board with no Current sprint view still opens" 0
err_has "sprint open: says the board was not updated" "no Current sprint view"
is "sb_today: today when no override is set" "$( (unset SECOND_BRAIN_TODAY; sb_today) | grep -c '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$')" "1"
mkdir -p "$tmp/vault3/.obsidian" "$tmp/vault4/.obsidian" "$tmp/vault5/.obsidian"
printf '# My index\r\n\r\n## Projects\r\n\r\n- an old nested list\r\n\r\n## Other\r\n' >"$tmp/vault3/CLAUDE.md"
run env SECOND_BRAIN_VAULT="$tmp/vault3" "$SB" scaffold project Legacy --path old/legacy --keys LEG
rc_is "index: a Projects section with no table gets one" 0
run env SECOND_BRAIN_VAULT="$tmp/vault3" "$SB" projects
out_is "index: the new table is readable" "Legacy${TAB}old/legacy${TAB}LEG"
is "index: CRLF kept on every line" "$(grep -c "$CR\$" "$tmp/vault3/CLAUDE.md")" "$(grep -c '' "$tmp/vault3/CLAUDE.md")"
file_has "index: the old content is kept" "$tmp/vault3/CLAUDE.md" "- an old nested list"
is "index: the table sits inside the Projects section" "$(($(lineno "$tmp/vault3/CLAUDE.md" '| Legacy |') < $(lineno "$tmp/vault3/CLAUDE.md" '## Other')))" "1"
printf '# My index\n\nNo project list yet.\n' >"$tmp/vault4/CLAUDE.md"
run env SECOND_BRAIN_VAULT="$tmp/vault4" "$SB" scaffold project Fresh --path fresh
run env SECOND_BRAIN_VAULT="$tmp/vault4" "$SB" projects
out_is "index: a missing Projects section is appended, empty keys print a dash" "Fresh${TAB}fresh${TAB}-"
file_has "index: text before it is kept" "$tmp/vault4/CLAUDE.md" "No project list yet."
run env SECOND_BRAIN_VAULT="$tmp/vault5" "$SB" projects
rc_is "projects: no index gives exit 1" 1
run env SECOND_BRAIN_VAULT="$tmp/vault5" "$SB" scaffold project X --path x
rc_is "scaffold project: no index gives exit 2" 2
absent "scaffold project: nothing created without an index" "$tmp/vault5/x"

# ---------------------------------------------------------------- scaffold project, other roots
R="work/roots"
sb scaffold project Roots --path "$R" --keys RT --tasks-root plan/tasks --topics-root knowledge --sprints-root cadence/sprints
rc_is "scaffold roots: exit 0" 0
out_is "scaffold roots: hubs and board only under the given roots" "$R/README.md
$R/claude/README.md
$R/claude/profile.md
$R/plan/tasks/README.md
$R/plan/tasks/tasks.base
$R/knowledge/README.md
$R/cadence/sprints/README.md"
line_is "scaffold roots: tasks root in the profile" "$vault/$R/claude/profile.md" "tasks_root: plan/tasks"
line_is "scaffold roots: topics root in the profile" "$vault/$R/claude/profile.md" "topics_root: knowledge"
line_is "scaffold roots: sprints root in the profile" "$vault/$R/claude/profile.md" "sprints_root: cadence/sprints"
for d in tasks docs sprints; do absent "scaffold roots: no default $d folder" "$vault/$R/$d"; done
line_is "scaffold roots: board folder is the tasks root" "$vault/$R/plan/tasks/tasks.base" "    - file.inFolder(\"$R/plan/tasks\")"
line_is "scaffold roots: board depth counts the nested tasks root" "$vault/$R/plan/tasks/tasks.base" '    - file.folder.split("/").length == 5'
line_is "scaffold roots: tasks hub embeds its own board" "$vault/$R/plan/tasks/README.md" "![[$R/plan/tasks/tasks.base#Active]]"
line_is "scaffold roots: map links the tasks hub" "$vault/$R/README.md" "- [[$R/plan/tasks/README|Roots Tasks Hub]] - one folder per task, and the task board"
line_is "scaffold roots: map links the topics hub" "$vault/$R/README.md" "- [[$R/knowledge/README|Roots Docs Hub]] - the topics: one folder per subject"
line_is "scaffold roots: map links the sprints hub" "$vault/$R/README.md" "- [[$R/cadence/sprints/README|Roots Sprints Hub]] - one note per sprint"
is "scaffold roots: every map link points at a file" "$(check_links "$vault/$R/README.md")" ""
sb task new RT-1 --project Roots --title First
out_is "other roots: task new writes under the tasks root" "$R/plan/tasks/RT-1/README.md"
line_is "other roots: the task links up to its hub" "$vault/$R/plan/tasks/RT-1/README.md" "> Up: [[$R/plan/tasks/README|Roots Tasks Hub]]"
mkdir -p "$vault/$R/knowledge/api"
sb task tag RT-1 add knowledge/API
out_is "other roots: a tag is the path under the topics root" "api"
is "other roots: an existing topic folder gives no warning" "$ERR" ""
sb board Roots
out_is "other roots: board reads the tasks root" "RT-1 | First | planned | - | api | none yet | Frame the story | -"
sb sprint open Roots --end 2026-10-21
out_is "other roots: sprint open writes under the sprints root" "$R/cadence/sprints/2026-10-21.md"
line_is "other roots: sprint hub line" "$vault/$R/cadence/sprints/README.md" "- [[$R/cadence/sprints/2026-10-21|Roots Sprint 2026-10-21]] - 2026-10-08 to 2026-10-21"
line_is "other roots: board literal rewritten" "$vault/$R/plan/tasks/tasks.base" '        - sprint == "2026-10-21"'
sb sprint current Roots
rc_is "other roots: sprint current finds it" 0
sb project --cwd "$vault/$R/plan/tasks/RT-1"
out_is "other roots: a task folder resolves to its project" "Roots${TAB}$R${TAB}RT"
D="work/dot"
sb scaffold project Dot --path "$D" --topics-root .
out_is "scaffold topics root dot: no topics hub" "$D/README.md
$D/claude/README.md
$D/claude/profile.md
$D/tasks/README.md
$D/tasks/tasks.base
$D/sprints/README.md"
line_is "scaffold topics root dot: quoted in the profile" "$vault/$D/claude/profile.md" 'topics_root: "."'
absent "scaffold topics root dot: no docs folder" "$vault/$D/docs"
file_lacks "scaffold topics root dot: the README has no topics-hub line" "$vault/$D/README.md" "Docs Hub"
is "scaffold topics root dot: three map lines" "$(grep -c '^- \[\[' "$vault/$D/README.md")" "3"
is "scaffold topics root dot: map links point at files" "$(check_links "$vault/$D/README.md")" ""
mkdir -p "$vault/$D/Billing"
sb task new dot-task --project Dot --topics billing
is "scaffold topics root dot: a topic folder at the project root is found" "$ERR" ""
find "$vault/$D" -type f | LC_ALL=C sort >"$tmp/dot.before"
sb scaffold project Dot --path "$D" --topics-root . --tasks-root elsewhere
rc_is "scaffold again: exit 0" 0
out_is "scaffold again: creates nothing new" ""
err_has "scaffold again: reports what is there" "exists: $D/claude/profile.md"
err_has "scaffold again: reports the board too" "exists: $D/tasks/tasks.base"
err_has "scaffold again: root flags ignored once a profile exists" "root flags are ignored"
find "$vault/$D" -type f | LC_ALL=C sort >"$tmp/dot.after"
is "scaffold again: same files as before" "$(cmp -s "$tmp/dot.before" "$tmp/dot.after"; echo $?)" "0"
is "scaffold again: still one index row" "$(grep -c '^| Dot |' "$vault/CLAUDE.md")" "1"
E="work/existing"
mkdir -p "$vault/$E/tasks"
printf -- '---\naliases:\n  - Old Tasks Hub\ntype: moc\n---\n\n# Tasks kept by hand\n' >"$vault/$E/tasks/README.md"
printf 'filters:\n  and:\n    - file.name == "README"\n' >"$vault/$E/tasks/tasks.base"
cp "$vault/$E/tasks/README.md" "$tmp/hub.before"
cp "$vault/$E/tasks/tasks.base" "$tmp/base.before"
sb scaffold project Existing --path "$E"
rc_is "scaffold onto existing files: exit 0" 0
out_lacks "scaffold onto existing files: the hub is not listed as created" "$E/tasks/README.md"
err_has "scaffold onto existing files: hub reported" "exists: $E/tasks/README.md"
err_has "scaffold onto existing files: board reported" "exists: $E/tasks/tasks.base"
is "scaffold onto existing files: hub byte-identical" "$(cmp -s "$tmp/hub.before" "$vault/$E/tasks/README.md"; echo $?)" "0"
is "scaffold onto existing files: board byte-identical" "$(cmp -s "$tmp/base.before" "$vault/$E/tasks/tasks.base"; echo $?)" "0"
line_is "scaffold onto existing files: the map shows the hub by its own alias" "$vault/$E/README.md" "- [[$E/tasks/README|Old Tasks Hub]] - one folder per task, and the task board"
exists "scaffold onto existing files: the missing hubs are created" "$vault/$E/sprints/README.md"
sb scaffold project Bad --path work/bad --tasks-root .
rc_is "scaffold roots: the tasks root cannot be the project folder, exit 5" 5
sb scaffold project Bad --path work/bad --sprints-root ../out
rc_is "scaffold roots: a root leaving the project gives exit 5" 5
sb scaffold project Bad --path work/bad --tasks-root same --sprints-root same
rc_is "scaffold roots: two roots in one folder give exit 5" 5
sb scaffold project Bad --path work/bad --tasks-root plan --sprints-root plan/sprints
rc_is "scaffold roots: a root inside the tasks root gives exit 5" 5
sb scaffold project Bad --path work/bad --topics-root
rc_is "scaffold roots: a flag with no value gives exit 5" 5
absent "scaffold roots: nothing created for a refused call" "$vault/work/bad"
is "scaffold roots: no index row for a refused call" "$(grep -c '^| Bad |' "$vault/CLAUDE.md")" "0"

# ---------------------------------------------------------------- repo
RP="work/repo-one"
RPF="$vault/$RP/claude/profile.md"
sb scaffold project "Repo One" --path "$RP" --keys RA
is "profile: repos_root sits right after repos" "$(($(lineno "$RPF" 'repos_root:') - $(lineno "$RPF" 'repos:')))" "1"
is "profile: repo_paths sits right after repos_root" "$(($(lineno "$RPF" 'repo_paths:') - $(lineno "$RPF" 'repos_root:')))" "1"
line_is "profile: repos_root starts empty" "$RPF" 'repos_root: ""'
line_is "profile: repo_paths starts empty" "$RPF" "repo_paths: []"
sb profile "Repo One" repos
out_has "profile: the repos section explains the two keys" "repo_paths:"
out_has "profile: the repos section names the default repository" "first name is the default repository for branch checks"
sb repo "Repo One"
rc_is "repo: a project with no repos exits 0" 0
out_is "repo: and prints nothing" ""
edit "$RPF" 's/^repos: \[\]$/repos: [alpha-api, alpha-web]/'
sb repo "Repo One"
out_is "repo: no location recorded gives unknown and a dash" "alpha-api${TAB}-${TAB}unknown
alpha-web${TAB}-${TAB}unknown"
sb repo "Repo One" alpha-api
rc_is "repo name: no location recorded gives exit 1" 1
out_is "repo name: nothing on stdout" ""
err_has "repo name: the message says no location is recorded" "no location is recorded for alpha-api"
mkdir -p "$tmp/userdir/code/acme/alpha-api/src"
edit "$RPF" 's|^repos_root: ""$|repos_root: "~/code/acme"|'
sb repo "Repo One"
out_is "repo: rows from repos_root, tilde expanded, in the order of repos" "alpha-api${TAB}$oT/userdir/code/acme/alpha-api${TAB}ok
alpha-web${TAB}$oT/userdir/code/acme/alpha-web${TAB}missing"
run env HOME="$tmp/another" "$SB" repo "Repo One"
out_is "repo: the tilde follows the home directory" "alpha-api${TAB}$oT/another/code/acme/alpha-api${TAB}missing
alpha-web${TAB}$oT/another/code/acme/alpha-web${TAB}missing"
sb repo "Repo One" alpha-api
rc_is "repo name: exit 0 when the folder exists" 0
out_is "repo name: prints the path alone" "$oT/userdir/code/acme/alpha-api"
sb repo "Repo One" alpha-web
rc_is "repo name: a missing folder gives exit 1" 1
out_is "repo name: nothing on stdout for a missing folder" ""
err_has "repo name: the message says the folder is missing" "the folder of alpha-web is missing"
sb repo "Repo One" alpha-nope
rc_is "repo name: a name not in repos gives exit 1" 1
err_has "repo name: the message says it is not in repos" "alpha-nope is not in repos"
mkdir -p "$tmp/else where/alpha-tools" "$tmp/real-elsewhere/alpha-web/lib"
symlink "$tmp/real-elsewhere" "$tmp/userdir/elsewhere"
edit "$RPF" 's/^repos: .*$/repos: [alpha-api, alpha-web, alpha-tools]/'
edit "$RPF" "s|^repo_paths: \\[\\]\$|repo_paths:\\
  - \"alpha-tools=$tmp/else where/alpha-tools\"\\
  - alpha-web=~/elsewhere/alpha-web|"
sb repo "Repo One"
out_is "repo: repo_paths wins over repos_root for the names it lists" "alpha-api${TAB}$oT/userdir/code/acme/alpha-api${TAB}ok
alpha-web${TAB}$oT/userdir/elsewhere/alpha-web${TAB}ok
alpha-tools${TAB}$oT/else where/alpha-tools${TAB}ok"
sb repo "Repo One" alpha-tools
out_is "repo name: a path with spaces" "$oT/else where/alpha-tools"
# Inside the helper a path is in the shell's own form; the repo command prints it as shown.
is "sb_repo_rows: the same rows for other libraries" "$(SB_ROOT=""; sb_repo_rows "Repo One" | while IFS="$TAB" read -r n p s; do
  printf '%s\t%s\t%s\n' "$n" "$oT${p#"$tmp"}" "$s"
done)" "$("$SB" repo "Repo One")"
sb_repo_rows "No Such Project" >/dev/null 2>&1
is "sb_repo_rows: returns 1 for an unknown project" "$?" "1"
SB_ROOT=""
sb repo
rc_is "repo: no project gives exit 5" 5
sb repo "Repo One" alpha-api extra
rc_is "repo: too many arguments give exit 5" 5
sb repo Nope
rc_is "repo: unknown project gives exit 1" 1
sb repo Three
rc_is "repo: no profile gives exit 1" 1
err_has "repo: no profile hints at adopt" "vault-setup adopt"
sb scaffold project "Repo Two" --path work/repo-two --keys RB
mkdir -p "$tmp/other root/alpha-api/pkg" "$tmp/third/alpha-api"
edit "$vault/work/repo-two/claude/profile.md" 's/^repos: \[\]$/repos: [alpha-api]/'
edit "$vault/work/repo-two/claude/profile.md" "s|^repos_root: \"\"\$|repos_root: \"$tmp/other root\"|"
sb repo "Repo Two" alpha-api
out_is "repo: an absolute repos_root with a space" "$oT/other root/alpha-api"
sb project --cwd "$tmp/userdir/code/acme/alpha-api/src"
out_is "project --cwd: inside a recorded repository folder" "Repo One${TAB}$RP${TAB}RA"
sb project --cwd "$tmp/other root/alpha-api/pkg"
out_is "project --cwd: the same folder name under another root is the other project" "Repo Two${TAB}work/repo-two${TAB}RB"
sb project --cwd "$tmp/real-elsewhere/alpha-web/lib"
out_is "project --cwd: a recorded path through a symlink still matches" "Repo One${TAB}$RP${TAB}RA"
symlink "$tmp/other root/alpha-api" "$tmp/link-to-two"
sb project --cwd "$tmp/link-to-two/pkg"
out_is "project --cwd: a working directory reached through a symlink" "Repo Two${TAB}work/repo-two${TAB}RB"
sb project --cwd "$tmp/third/alpha-api"
rc_is "project --cwd: outside every recorded folder the name match is the fallback, exit 4 for two" 4
is "project --cwd: the fallback prints both candidates" "$(lines "$OUT")" "2"
sb project --cwd "$tmp/code/example-api/src/deep"
out_has "project --cwd: a project with no recorded location still matches by folder name" "Example${TAB}$P${TAB}"
sb context --cwd "$tmp/other root/alpha-api"
is "context: still four lines" "$(lines "$OUT")" "4"
out_has "context: project from a recorded repository folder" "project: Repo Two"

# ---------------------------------------------------------------- path forms on Windows
# There an absolute path that is read may be written C:\a, C:/a or /c/a; one that is printed is C:/a.
if sb_is_windows; then
  wV="$(cygpath -w "$vault")"
  run env SECOND_BRAIN_VAULT="$wV" "$SB" root
  rc_is "path forms: a vault written with backslashes, exit 0" 0
  out_is "path forms: the vault is printed in the drive form" "$oV"
  run env SECOND_BRAIN_VAULT="$oV" "$SB" root
  out_is "path forms: a vault in the drive form" "$oV"
  run env SECOND_BRAIN_VAULT="/$(printf '%s' "${vault:1:1}" | tr '[:lower:]' '[:upper:]')${vault:2}" "$SB" root
  out_is "path forms: a vault with an upper-case drive letter" "$oV"
  run env SECOND_BRAIN_VAULT="$wV" "$SB" task head EX-1
  rc_is "path forms: a task is read in a vault written with backslashes" 0
  run env SECOND_BRAIN_VAULT="$wV" "$SB" context --cwd "$(cygpath -w "$tmp/other root/alpha-api")"
  out_has "path forms: context prints the vault in the drive form" "vault: $oV"
  out_has "path forms: context takes --cwd written with backslashes" "project: Repo Two"
  sb project --cwd "$(cygpath -w "$tmp/userdir/code/acme/alpha-api/src")"
  out_is "path forms: project --cwd written with backslashes" "Repo One${TAB}$RP${TAB}RA"
  sb project --cwd "$oT/userdir/code/acme/alpha-api/src"
  out_is "path forms: project --cwd in the drive form" "Repo One${TAB}$RP${TAB}RA"
  sb project --cwd "$(cygpath -w "$vault/$P/tasks")"
  out_has "path forms: project --cwd inside the vault, written with backslashes" "Example${TAB}$P${TAB}"
  W2="$vault/work/repo-two/claude/profile.md"
  cp "$W2" "$tmp/w2.before"
  SB_ROOT="$vault"
  sb_fm_set "$W2" repos_root "$oT/other root"
  sb repo "Repo Two"
  out_is "path forms: repos_root in the drive form" "alpha-api${TAB}$oT/other root/alpha-api${TAB}ok"
  sb_fm_set "$W2" repos_root "$(cygpath -w "$tmp/other root")"
  file_has "path forms: the profile holds repos_root with backslashes" "$W2" "repos_root: $(cygpath -w "$tmp/other root")"
  sb repo "Repo Two"
  out_is "path forms: repos_root written with backslashes" "alpha-api${TAB}$oT/other root/alpha-api${TAB}ok"
  sb project --cwd "$tmp/other root/alpha-api/pkg"
  out_is "path forms: a working directory under that repos_root" "Repo Two${TAB}work/repo-two${TAB}RB"
  sb_fm_set "$W2" repos_root ""
  sb_fm_edit "$W2" listadd repo_paths "alpha-api=$(cygpath -w "$tmp/third/alpha-api")"
  sb repo "Repo Two" alpha-api
  out_is "path forms: a repo_paths entry written with backslashes" "$oT/third/alpha-api"
  cat "$tmp/w2.before" >"$W2"
  SB_ROOT=""
  mkdir -p "$tmp/vault6/.obsidian"
  sb scaffold vault "$(cygpath -w "$tmp/vault6")"
  rc_is "path forms: scaffold vault takes a folder written with backslashes" 0
  exists "path forms: scaffold vault writes the index there" "$tmp/vault6/CLAUDE.md"
  sb scaffold vault "$(cygpath -w "$tmp/userdir")"
  rc_is "path forms: scaffold vault refuses a folder that is no vault, exit 2" 2
  err_has "path forms: the refusal names the folder in the drive form" "$oT/userdir"
  sb search Example "billing" --in 'docs\billing'
  rc_is "path forms: search --in refuses a backslash, exit 5" 5
  sb task head 'EX-1\..\EX-2'
  rc_is "path forms: a task id with a backslash names no task folder, exit 1" 1
fi

# ---------------------------------------------------------------- scaffold project, no sprints
N="work/kanban"
sb scaffold project Kanban --path "$N" --keys KB --no-sprints
rc_is "no sprints: scaffold exit 0" 0
out_is "no sprints: no sprints hub is created" "$N/README.md
$N/claude/README.md
$N/claude/profile.md
$N/tasks/README.md
$N/tasks/tasks.base
$N/docs/README.md"
line_is "no sprints: the profile says so" "$vault/$N/claude/profile.md" "uses_sprints: false"
absent "no sprints: no sprints folder" "$vault/$N/sprints"
file_lacks "no sprints: the map has no sprints line" "$vault/$N/README.md" "Sprints Hub"
is "no sprints: every map link points at a file" "$(check_links "$vault/$N/README.md")" ""
file_lacks "no sprints: the tasks hub names no sprint view" "$vault/$N/tasks/README.md" "Current sprint"
file_lacks "no sprints: the board has no sprint view, filter or column" "$vault/$N/tasks/tasks.base" "sprint"
file_lacks "no sprints: the board has no carried-from column" "$vault/$N/tasks/tasks.base" "carried_from"
for v in Active "By topic" "Needs a status" All; do
  line_is "no sprints: board view $v" "$vault/$N/tasks/tasks.base" "    name: $v"
done
is "no sprints: the board keeps its four views whole" "$(grep -c '^  - type: table$' "$vault/$N/tasks/tasks.base")" "4"
line_is "no sprints: the last view keeps its last column" "$vault/$N/tasks/tasks.base" "      - file.mtime"
sb context --cwd "$vault/$N"
out_has "no sprints: context says off" "sprint: off"
for c in "current Kanban" "next Kanban" "open Kanban --end 2026-02-01" "set Kanban goal=x" "close Kanban"; do
  # shellcheck disable=SC2086
  sb sprint $c
  rc_is "no sprints: sprint ${c%% *} exits 5" 5
  err_has "no sprints: sprint ${c%% *} says why" "Kanban does not use sprints"
done
absent "no sprints: a refused open writes no note" "$vault/$N/sprints"
sb task new KB-1 --project Kanban --title First
rc_is "no sprints: task new works" 0
sb task set KB-1 status=in-progress sprint=2026-02-01
rc_is "no sprints: task set refuses a sprint id" 5
file_lacks "no sprints: a refused task set writes nothing" "$vault/$N/tasks/KB-1/README.md" "in-progress"
edit "$vault/$N/tasks/KB-1/README.md" 's/^status: planned$/status: planned\
sprint: "2026-02-01"/'
line_is "no sprints: a sprint id left over from before" "$vault/$N/tasks/KB-1/README.md" 'sprint: "2026-02-01"'
sb task set KB-1 sprint=
out_is "no sprints: task set may still remove a sprint id" "sprint: (removed)"
file_lacks "no sprints: the leftover id is gone" "$vault/$N/tasks/KB-1/README.md" "sprint:"
sb board Kanban
out_has "no sprints: the board still lists the task" "KB-1 | First | planned | - |"
sb board Kanban "Current sprint"
out_is "no sprints: the sprint view has no rows" ""
sb scaffold project Kanban --path "$N" --keys KB
out_is "no sprints: a second run without the flag creates nothing" ""
absent "no sprints: the profile decides, so still no sprints hub" "$vault/$N/sprints"
sb scaffold project Clash --path work/clash --no-sprints --sprints-root cadence
rc_is "no sprints: the flag and a sprints root together exit 5" 5
absent "no sprints: nothing written on the clash" "$vault/work/clash"
sb scaffold project Roots --path "$R" --keys RT --no-sprints
err_has "no sprints: an existing profile that uses sprints wins over the flag" "--no-sprints is ignored"
line_is "no sprints: that profile is unchanged" "$vault/$R/claude/profile.md" "uses_sprints: true"
edit "$vault/$N/claude/profile.md" 's/^uses_sprints: false$/uses_sprints: False/'
sb sprint current Kanban
rc_is "no sprints: the letter case of false does not matter" 5
edit "$vault/$N/claude/profile.md" 's/^uses_sprints: False$/uses_sprints: true/'
sb scaffold project Kanban --path "$N" --keys KB
out_is "sprints turned on: the next scaffold adds the hub" "$N/sprints/README.md"
err_has "sprints turned on: the map line to add is given" "add the sprints hub to the map in $N/README.md: - [[$N/sprints/README|Kanban Sprints Hub]] - one note per sprint"
err_has "sprints turned on: the board view to add is named" "the board at $N/tasks/tasks.base has no Current sprint view"
sb scaffold project Kanban --path "$N" --keys KB
is "sprints turned on: said once, when the hub is made" "$(printf '%s\n' "$ERR" | grep -c '^note: ' || true)" "0"
sb sprint open Kanban --end 2026-02-01
rc_is "sprints turned on: a sprint opens" 0
err_has "sprints turned on: the missing view is named" "has no Current sprint view to update"
sb context --cwd "$vault/$N"
out_has "sprints turned on: context shows the sprint" "sprint: 2026-02-01"
sb task set KB-1 sprint=2026-02-01
sb board Kanban "Current sprint"
out_has "sprints turned on: the sprint lists its task" "KB-1 | First | planned | 2026-02-01 |"
edit "$vault/$N/claude/profile.md" 's/^uses_sprints: true$/uses_sprints: false/'
sb board Kanban "Current sprint"
out_is "sprints turned off again: a sprint left in progress lists nothing" ""
sb context --cwd "$vault/$N"
out_has "sprints turned off again: context says off" "sprint: off"

# ---------------------------------------------------------------- generated files
is "generated files: no placeholder left" "$(grep -rl '{{' "$vault" "$tmp/vault2" "$tmp/vault3" "$tmp/vault4" | grep -c . || true)" "0"
is "templates: only UPPER_SNAKE placeholders" "$(cat "$here"/templates/*.tmpl | grep -o '{{[^}]*}}' | grep -vc '^{{[A-Z][A-Z0-9_]*}}$' || true)" "0"
bad_links="$(find "$vault" -name '.*' -prune -o -type f -name '*.md' -print | while IFS= read -r f; do check_links "$f"; done)"
is "generated notes: every link carries a path that exists" "$bad_links" ""
sb unresolved
rc_is "generated notes: unresolved exits 0" 0
out_is "generated notes: the helper reads no unresolved link in them" ""

# ---------------------------------------------------------------- a sprint with no tasks
sb sprint close Four
rc_is "sprint close: a sprint with no tasks closes" 0
file_has "sprint close: the board keeps the closed sprint's literal" "$vault/work/four/tasks/tasks.base" 'sprint == date("2026-11-11")'
sb board Four "Current sprint"
out_is "board Current sprint: no rows once the sprint is closed, whatever the board's literal says" ""

# ---------------------------------------------------------------- result
printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
