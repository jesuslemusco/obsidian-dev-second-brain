#!/usr/bin/env bash
# Shared code of the scratch-vault tests, sourced by scripts/test.sh and by each area file in
# scripts/tests: an empty vault in a temp dir, the assert helpers, the total and the fixtures.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
# On bash 4 and later, an undefined command fails the suite. Bash runs this hook in a subshell,
# so it writes the name to a file, and the result counts each name as a failure.
command_not_found_handle() {
  printf '%s at line %s\n' "$1" "${BASH_LINENO[0]}" >>"$tmp/undefined"
  printf '%s: line %s: %s: command not found\n' "$0" "${BASH_LINENO[0]}" "$1" >&2
  return 127
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
# section_of <file> <heading>: the non-blank lines under one level-2 heading, up to the next.
section_of() { awk -v h="## $2" '/^## / { on = ($0 == h); next } on && NF' "$1"; }
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

# json_ok <desc>: OUT parses as one JSON value. json_is <desc> <python> <wanted>: the python, run
# with the parsed value as d, prints the wanted text. Both skip when python3 is not installed.
HAS_PY=0
command -v python3 >/dev/null 2>&1 && HAS_PY=1
NL=$'\n'
json_ok() {
  if [ "$HAS_PY" -eq 0 ]; then printf 'skip  %s: python3 is not installed\n' "$1"; return 0; fi
  if printf '%s\n' "$OUT" | python3 -I -c 'import json,sys; json.load(sys.stdin.buffer)' \
    2>"$tmp/pyerr"; then
    pass "$1"
  else
    fail "$1" "$(cat "$tmp/pyerr")" "in: $OUT"
  fi
}
json_is() {
  if [ "$HAS_PY" -eq 0 ]; then printf 'skip  %s: python3 is not installed\n' "$1"; return 0; fi
  # A Python built for Windows ends the lines it prints with CRLF; tr takes that away.
  is "$1" "$(printf '%s\n' "$OUT" | python3 -I -c "import json,sys
d = json.load(sys.stdin.buffer)
$2" 2>&1 | tr -d '\r')" "$3"
}
# The task head lines rebuilt from its JSON.
HEAD_PY='for k, v in d.items():
    if isinstance(v, list): v = (", " if k == "topics" else ",").join(v) or "-"
    print(k + ": " + v)'
# linex <file> <line>: the number of the first line that is exactly that text.
linex() { grep -nxF -- "$2" "$1" | head -1 | cut -d: -f1; }
# rows <output>: each row's command, result and exit code, and each line under a row.
rows() { printf '%s\n' "$1" | awk -F'\t' '/^  / { print; next } { print $1 "|" $2 "|" $3 }'; }
# example_of <heading>: the lines under one worked example, up to the next heading.
example_of() { awk -v h="### $1" '/^#+ / { on = ($0 == h); next } on' "$RV"; }
# json_of <heading>: the fenced json block of one worked example.
json_of() { example_of "$1" | awk '/^```json$/ { on = 1; next } /^```$/ { on = 0 } on'; }

# result: count each undefined command as a failure, print the total, and fail on any failure.
result() {
  if [ -f "$tmp/undefined" ]; then
    while IFS= read -r cmd; do fail "undefined command: $cmd"; done <"$tmp/undefined"
  fi
  printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
  [ "$n_fail" -eq 0 ]
}

# The helper's own functions, such as sb_fm_get, for the checks that call them.
SB_PLUGIN_ROOT="$here"
SB_ROOT=""
for lib in "$here"/scripts/lib/*.sh; do . "$lib"; done

# Fixtures. Some areas test what the sections of another area leave in its vault. A fixture builds
# that state in the area's own vault: it runs the commands of those sections that write the vault,
# without their checks. When such a section changes what it writes, change its fixture with it.

# fixture_projects: the vault and the projects Example and Example Two, as scaffold.sh makes them.
fixture_projects() {
  sb scaffold vault
  sb scaffold project Example --path "$P" --keys EX,EXOPS
  sb scaffold project "Example Two" --path "$P2" --keys TWO --use-when "The second | service."
  edit "$vault/CLAUDE.md" 's/^| Example Two | \(.*\) | TWO | /| Example Two | \1 | EX, TWO | /'
}

# fixture_profiles: those two with the repos project.sh gives them, and Three, with no profile.
fixture_profiles() {
  fixture_projects
  edit "$vault/$P/claude/profile.md" 's/^repos: \[\]$/repos: [example-api, shared-lib]/'
  edit "$vault/$P2/claude/profile.md" 's/^repos: \[\]$/repos:\
  - shared-lib/'
  mkdir -p "$vault/misc/three/tasks"
  printf '| Three | misc/three | T | A project with no profile. |\n' >>"$vault/CLAUDE.md"
}

# fixture_tasks: the tasks as tasks.sh leaves them. T1 to T7 are the READMEs of EX-1 to EX-7.
fixture_tasks() {
  fixture_profiles
  T1="$vault/$P/tasks/EX-1/README.md"
  T2="$vault/$P/tasks/EX-2/README.md"
  T3="$vault/$P/tasks/EX-3/README.md"
  T4="$vault/$P/tasks/EX-4/README.md"
  T5="$vault/$P/tasks/EX-5/README.md"
  T6="$vault/$P/tasks/EX-6/README.md"
  T7="$vault/$P/tasks/EX-7/README.md"
  # task new
  mkdir -p "$vault/$P/docs/billing/Invoices" "$vault/$P/docs/api"
  sb task new EX-1 --project Example --title 'Fix: totals "rounded" twice' --topics billing/invoices
  sb task new EX-2 --project Example --title Second --topics "docs/API, billing-old"
  sb task new EX-3 --project Example
  sb task new TWO-1 --title "Other project"
  edit "$vault/$P/claude/profile.md" 's/^environments: \[\]$/environments: [dev, qa]/'
  sb task new EX-7 --project Example --envs --title "Per environment"
  for t in EX-4 EX-5 EX-6; do sb task new "$t" --project Example --title "Task $t"; done
  # task set
  for s in in-progress done in-review abandoned in-review; do sb task set EX-1 status="$s"; done
  sb task set EX-1 "next=Check: the #1 thing"
  sb task set EX-1 sprint=2026-10-14 branch=feature/EX-1-fix epic=-
  sb task set EX-1 epic=
  sb task set EX-2 status=planned next="Draft the API change"
  sb task set EX-3 status=done
  sb task set EX-4 status=abandoned
  sb task set EX-5 status=in-progress
  awk '{ printf "%s\r\n", $0 }' "$T6" >"$tmp/crlf.tmp" && cat "$tmp/crlf.tmp" >"$T6"
  sb task set EX-6 status=in-review "next=a: b" sprint=2026-10-14 epic=
  sb task note EX-6 "Note on a CRLF file" --session s9
  # task note
  sb task note EX-1 "First note" --session abc123
  sb task note EX-1 "Second note" --session abc123
  sb task note EX-2 "No session here"
  mkdir -p "$vault/$P/tasks/legacy-task"
  printf '# Legacy task\n\nNo frontmatter and no sections.\n' >"$vault/$P/tasks/legacy-task/README.md"
  sb task note legacy-task "Picked up again" --project Example
  # task head
  edit "$T1" 's/^\*\*Summary:\*\* .*$/**Summary:** Totals are rounded per line and again per invoice,\
so large invoices drift by a cent./'
  edit "$T7" 's/^  - EX-7$/  - EX-7\
  - EX-70/'
  edit "$T7" 's/^  dev: .*$/  dev:  { id: EX-7, status: done }\
  qa:   { id: EX-70, status: planned }/'
  # an alias as the id
  sb task set EX-70 "next=Promote to qa"
  sb task note EX-70 "qa: promotion started" --session s2
  sb task tag EX-70 add api
  sb task tag EX-70 remove api
  # task tag
  sb task tag EX-4 add billing/invoices
  sb task tag EX-4 add "docs/API"
  sb task tag EX-4 add "Ops Runbooks"
  sb task tag EX-4 remove API
  sb task tag EX-4 remove ops-runbooks
  sb task tag EX-4 remove billing/invoices
  sb task tag EX-6 add api
  sb task tag EX-6 remove api
  # task alias
  sb task alias EX-4 add "Totals: rounding"
  sb task alias EX-4 add Rounding twice
  sb task alias EX-5 add EX-55
  sb task alias EX-6 add "Lambda: node summary"
  mkdir -p "$vault/$P2/tasks/no-alias"
  printf -- '---\nstatus: planned\n---\n\n# no-alias - a note with no aliases\n' >"$vault/$P2/tasks/no-alias/README.md"
  sb task alias no-alias add "Other name" --project "Example Two"
  # task dep
  sb task dep EX-5 add EX-2
  sb task dep EX-5 add EX-3
  sb task dep EX-5 add EX-70
  sb task dep EX-5 remove EX-7
  sb task dep EX-2 add TWO-1
  sb task dep EX-2 remove TWO-1
  edit "$T2" "s#^depends_on: \[\]\$#depends_on: [\"[[$P/tasks/EX-3/README.md|third]]\"]#"
  sb task dep EX-2 remove EX-3
  edit "$T2" "s#^depends_on: \[\]\$#depends_on: [\"[[$P/tasks/EX-3/README|EX-3]]\"]#"
  sb task dep EX-2 add EX-1
  sb task dep EX-2 remove EX-3
  sb task dep EX-2 remove EX-1
  sb task dep EX-6 add EX-2
  sb task dep EX-6 remove EX-2
}

# fixture_board: those tasks with what board.sh leaves: EX-7 with a status off the standard, a
# note with an alias, and the notes the search reads.
fixture_board() {
  fixture_tasks
  edit "$vault/$P/tasks/EX-7/README.md" 's/^status: planned$/status: active/'
  printf -- '---\naliases:\n  - "Billing Notes"\n---\n\n# Notes on billing\n' >"$vault/$P/docs/billing/notes.md"
  i=0
  : >"$vault/$P/docs/billing/Invoices/many.md"
  while [ "$i" -lt 60 ]; do
    printf 'line %s holds needle-x here\n' "$i" >>"$vault/$P/docs/billing/Invoices/many.md"
    i=$((i + 1))
  done
  printf 'needle-x in a text file\n' >"$vault/$P/docs/billing/Invoices/data.txt"
}
