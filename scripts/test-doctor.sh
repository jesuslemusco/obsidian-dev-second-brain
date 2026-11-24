#!/usr/bin/env bash
# Scratch-vault tests for doctor and session-check: breaks one thing at a time and reads the rows.
# Usage: bash scripts/test-doctor.sh [--shard <n>/<total>]
# With --shard it runs share n of total, as the plan above block() says. The shards together run
# each case once.
set -u

# A line that opens a block, as block() says, and is written another way stops the run here.
bad="$(awk '/^[ \t]*if block([^A-Za-z0-9_-]|$)/ && !/^if block (0|[1-9][0-9]*); then$/ { print NR; exit }' "$0")"
if [ -n "$bad" ]; then
  printf 'line %s: open a block with "if block <cost>; then", a cost such as 25 with no leading zero\n' \
    "$bad" >&2
  exit 2
fi

shard_n=0
shard_total=0
if [ "$#" -gt 0 ]; then
  if [ "$1" != --shard ] || [ "$#" -ne 2 ]; then
    printf 'usage: bash scripts/test-doctor.sh [--shard <n>/<total>]\n' >&2
    exit 2
  fi
  case "$2" in [1-9]*/[1-9]*) shard_n="${2%%/*}" shard_total="${2#*/}" ;; esac
  case "$shard_n/$shard_total" in *[!0-9/]* | */*/*) shard_n=0 ;; esac
  # A count too large for the shell to compare is refused too.
  if ! [ "$shard_n" -ge 1 ] 2>/dev/null || ! [ "$shard_n" -le "$shard_total" ] 2>/dev/null; then
    printf -- '--shard takes <n>/<total>, with n from 1 to total, such as 2/4, not %s\n' "$2" >&2
    exit 2
  fi
fi

here="$(cd "$(dirname "$0")/.." && pwd)"
SB="$here/bin/second-brain"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-doctor.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# The suite compares bytes. On Windows, in Git Bash, the platform library gives it the awk, grep
# and sed that keep every CR, as the helper has them.
. "$here/scripts/lib/platform.sh"

vault="$tmp/vault"
home="$tmp/claude-home"
mkdir -p "$vault/.obsidian" "$tmp/userdir" "$home"
export HOME="$tmp/userdir"
export SECOND_BRAIN_VAULT="$vault"
export SECOND_BRAIN_CLAUDE_HOME="$home"
export SECOND_BRAIN_TODAY="2026-01-10"
unset CLAUDE_SESSION_ID

P="projects/example"
T="$vault/$P/tasks"
# The skill's entry for each check.
CHECKS="$here/skills/vault-doctor/checks.md"
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
exists() {
  if [ -e "$2" ]; then pass "$1"; else fail "$1" "missing: $2"; fi
}
out_is() { is "$1" "$OUT" "$2"; }
out_has() {
  case "$OUT" in *"$2"*) pass "$1" ;; *) fail "$1" "missing: $2" "in: $OUT" ;; esac
}
out_lacks() {
  case "$OUT" in *"$2"*) fail "$1" "unwanted: $2" "in: $OUT" ;; *) pass "$1" ;; esac
}
# edit <file> <sed script>: change a file through a temp file.
edit() {
  sed "$2" "$1" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$1"
}
# symlink <target> <link>: a real symlink on every system; on Windows a plain ln -s makes a copy.
symlink() {
  if sb_is_windows; then MSYS=winsymlinks:nativestrict ln -s "$1" "$2"; else ln -s "$1" "$2"; fi
}
# doc [args]: run doctor and keep its rows in OUT.
doc() { run "$SB" doctor "$@"; }
# row <check> [scope]: print "result | count | offenders" of one row of the last run.
row() {
  printf '%s\n' "$OUT" | SB_C="$1" SB_S="${2:-Example}" awk -F' [|] ' \
    '$2 == ENVIRON["SB_C"] && $3 == ENVIRON["SB_S"] { print $1 " | " $4 " | " $5 }'
}
# fix_of <check> [scope]: print the fix cell of one row of the last run.
fix_of() {
  printf '%s\n' "$OUT" | SB_C="$1" SB_S="${2:-Example}" awk -F' [|] ' \
    '$2 == ENVIRON["SB_C"] && $3 == ENVIRON["SB_S"] { print $6 }'
}
# chk <description> <check> <scope> <"result | count | offenders">
chk() { is "$1" "$(row "$2" "$3")" "$4"; }
# scope_rows <scope>: count the rows of one scope in the last run.
scope_rows() { printf '%s\n' "$OUT" | grep -c " | $1 | " || true; }
# reset: put the scratch vault and link directory back as they were after the setup.
reset() {
  rm -rf "$vault" "$home"
  cp -R "$tmp/pristine" "$vault"
  mkdir -p "$home"
}
# The cases after the setup come in blocks. Each opens with "if block <cost>; then" and closes
# with "fi". The cost is about the tenths of a second the block takes on Linux. To measure the
# costs again, time each --shard k/<blocks>, which runs the one block its summary line names, and
# take off the time of --shard <blocks + 1>/<blocks + 1>, which runs the setup alone.
# costs: the cost of each block, in order, as the script writes it.
costs=()
read -r -a costs <<<"$(awk '/^if block (0|[1-9][0-9]*); then$/ { print $3 + 0 }' "$0" | tr '\n' ' ')"
# plan: the shard of each block. The costliest block goes first, each to the shard that holds the
# least cost so far, the first on a tie. With as many shards as blocks, each shard holds one block.
plan=()
if [ "$shard_total" -gt 0 ]; then
  read -r -a plan <<<"$(printf '%s\n' "${costs[@]}" | awk -v total="$shard_total" '
    { cost[NR] = $1 + 0; n = NR }
    END {
      for (k = 1; k <= n; k++) {
        b = 0
        for (i = 1; i <= n; i++) if (!(i in shard) && (b == 0 || cost[i] > cost[b])) b = i
        s = k
        if (k > total) { s = 1; for (j = 2; j <= total; j++) if (load[j] < load[s]) s = j }
        shard[b] = s
        load[s] += cost[b]
      }
      for (i = 1; i <= n; i++) printf "%s ", shard[i]
    }')"
fi
# block <cost>: start the next block and say whether this run holds it, as the plan says. A block
# it holds starts from the scratch vault the setup built, with nothing else in the temp dir and no
# output read, so it runs alone. A helper or name that another block reads is defined outside the
# blocks.
n_block=0
n_held=0
held=""
cost_held=0
block() {
  local f
  n_block=$((n_block + 1))
  if [ "$#" -ne 1 ] || [ -z "${costs[n_block - 1]:-}" ] || [ "${costs[n_block - 1]}" != "$1" ]; then
    printf 'block %s: write it as "if block <cost>; then", alone on its line\n' "$n_block" >&2
    exit 2
  fi
  [ "$shard_total" -eq 0 ] || [ "${plan[n_block - 1]}" -eq "$shard_n" ] || return 1
  n_held=$((n_held + 1))
  held="$held $n_block"
  cost_held=$((cost_held + $1))
  for f in "$tmp"/*; do
    case "${f##*/}" in pristine | undefined) ;; *) rm -rf "$f" ;; esac
  done
  mkdir -p "$tmp/userdir"
  reset
  OUT="" ERR="" RC=0
}

# ---------------------------------------------------------------- setup
# Each shard builds the vault. Only the first counts the check, unless it fails.
sb scaffold vault
sb scaffold project Example --path "$P" --keys EX
sb task new EX-1 --project Example --title "First task"
sb task new EX-2 --project Example --title "Second task"
sb task new EX-3 --project Example --title "Third task"
sb sprint open Example --end 2026-01-14
sb task set EX-1 status=in-progress sprint=2026-01-14
sb task set EX-2 status=done
if [ "$RC" -ne 0 ] || [ "$shard_n" -le 1 ]; then rc_is "setup: the scratch vault is built" 0; fi
cp -R "$vault" "$tmp/pristine"

# ---------------------------------------------------------------- syntax
if block 0; then
for f in "$here/scripts/lib/doctor.sh" "$here/scripts/test-doctor.sh"; do
  if bash -n "$f" 2>"$tmp/stderr"; then pass "syntax: ${f#"$here"/}"; else fail "syntax: ${f#"$here"/}" "$(cat "$tmp/stderr")"; fi
done
fi

# ---------------------------------------------------------------- the script's own flag and blocks
if block 1; then
self="$here/scripts/test-doctor.sh"
for v in 0/4 5/4 abc; do
  run bash "$self" --shard "$v"
  is "shards: --shard $v exits 2 and says what it takes" "$RC/$ERR" \
    "2/--shard takes <n>/<total>, with n from 1 to total, such as 2/4, not $v"
done
# Three copies of the script, each with one block written wrong: the last with no cost, a new one
# with no cost added after it, and the first with a leading zero. Each stops before its setup, and
# the bad --shard stops one that does not.
first="$(grep -n '^if block [0-9]*; then$' "$self" | head -1 | cut -d: -f1)"
last="$(grep -n '^if block [0-9]*; then$' "$self" | tail -1 | cut -d: -f1)"
end="$(grep -n '^# -* result$' "$self" | cut -d: -f1)"
awk -v n="$last" 'NR == n { $0 = "if block; then" } { print }' "$self" >"$tmp/last.sh"
awk -v n="$end" 'NR == n { print "if block; then"; print "fi"; print "" } { print }' "$self" >"$tmp/added.sh"
awk -v n="$first" 'NR == n { $0 = "if block 08; then" } { print }' "$self" >"$tmp/zero.sh"
for c in "last:$last:the last block has no cost" "added:$end:a block added after it has no cost" \
  "zero:$first:a cost has a leading zero"; do
  f="${c%%:*}" c="${c#*:}" ln="${c%%:*}" c="${c#*:}"
  run bash "$tmp/$f.sh" --shard 0/1
  is "blocks: where $c, the run stops before its setup, exit 2, and names the line" "$RC/$ERR" \
    "2/line $ln: open a block with \"if block <cost>; then\", a cost such as 25 with no leading zero"
done
fi

# ---------------------------------------------------------------- fresh vault
if block 102; then
doc
rc_is "fresh vault: exit 0" 0
is "fresh vault: no fail row" "$(printf '%s\n' "$OUT" | grep '^fail ' || true)" ""
is "fresh vault: the rows that are not ok: no import line, and the template text not yet filled" \
  "$(printf '%s\n' "$OUT" | awk -F' [|] ' '$1 != "ok" { printf "%s:%s ", $1, $2 }')" \
  "warn:import warn:placeholders "
is "rows: a result is ok, warn or fail" "$(printf '%s\n' "$OUT" | awk -F' [|] ' '$1 != "ok" && $1 != "warn" && $1 != "fail"' | grep -c . || true)" "0"
chk "pointer: ok" pointer vault "ok | 0 | -"
is "rows: six cells each" "$(printf '%s\n' "$OUT" | awk -F' [|] ' 'NF != 6' | grep -c . || true)" "0"

# ---------------------------------------------------------------- the skill's entries
# The skill reads an entry with one Grep and the four lines after its heading.
# The fresh vault has no subproject, so its rows lack subprojects and task-subproject, which come
# right after repos.
is "checks.md: one entry for each check the doctor prints, in the order of its table" \
  "$(sed -n 's/^### //p' "$CHECKS" | tr '\n' ' ')" \
  "$(printf '%s\n' "$OUT" | awk -F' [|] ' '!seen[$2]++ { printf "%s ", $2 }' | sed 's/ repos / repos subprojects task-subproject /')"
is "checks.md: every entry is its heading, a blank line, then Means, Why and Fix on one line each" "$(awk '
  function entry() {
    while (n > 0 && body[n] == "") n--
    if (name != "" && (n != 4 || body[1] != "" || body[2] !~ /^- Means: [^ ]/ || body[3] !~ /^- Why: [^ ]/ || body[4] !~ /^- Fix: [^ ]/)) print name
  }
  /^### / { entry(); name = substr($0, 5); n = 0; next }
  name != "" { body[++n] = $0 }
  END { entry() }' "$CHECKS")" ""

# ---------------------------------------------------------------- index, conventions, import
chk "index: ok" index vault "ok | 0 | -"
chk "conventions: ok" conventions vault "ok | 0 | -"
chk "import: warns when the link directory has no CLAUDE.md" import vault "warn | 1 | CLAUDE.md"
edit "$vault/CLAUDE.md" 's/^## Projects$/## Other/'
doc
rc_is "index: no Projects table gives exit 1" 1
chk "index: no Projects table fails" index vault "fail | 1 | ## Projects"
rm "$vault/CLAUDE.md" "$vault/obsidian-conventions.md"
doc
chk "index: a missing index fails" index vault "fail | 1 | CLAUDE.md"
chk "conventions: a missing note fails" conventions vault "fail | 1 | obsidian-conventions.md"
reset
tv="$(sed -n 's/^conventions_version: *//p' "$here/templates/obsidian-conventions.md.tmpl" | head -1)"
edit "$vault/obsidian-conventions.md" "s/^conventions_version: .*/conventions_version: $((tv - 1))/"
doc
rc_is "conventions: an older note leaves exit 0" 0
chk "conventions: a note older than the plugin's template warns, with its version" conventions vault "warn | 1 | obsidian-conventions.md:$((tv - 1))"
is "conventions: the fix says to scaffold the note again or to edit it, and gives the template's version" "$(fix_of conventions vault)" \
  "the note is older than the plugin's template, version $tv: delete it and run second-brain scaffold vault, or edit it by hand"
edit "$vault/obsidian-conventions.md" '/^conventions_version:/d'
doc
chk "conventions: a note with no version warns" conventions vault "warn | 1 | obsidian-conventions.md:none"
edit "$vault/obsidian-conventions.md" "s/^type: onboarding\$/type: onboarding\\
conventions_version: $((tv + 1))/"
doc
chk "conventions: a note newer than the template is fine" conventions vault "ok | 0 | -"
reset
doc
chk "pull-request: ok" pull-request vault "ok | 0 | -"
rm "$vault/claude/pull-request.md"
doc
rc_is "pull-request: a missing note leaves exit 0" 0
chk "pull-request: a missing note warns" pull-request vault "warn | 1 | claude/pull-request.md"
is "pull-request: the fix says to scaffold the vault" "$(fix_of pull-request vault)" "run second-brain scaffold vault to create it"
reset
doc
chk "writing-style: ok" writing-style vault "ok | 0 | -"
rm "$vault/claude/writing-style.md"
doc
rc_is "writing-style: a missing note leaves exit 0" 0
chk "writing-style: a missing note warns" writing-style vault "warn | 1 | claude/writing-style.md"
is "writing-style: the fix says to scaffold the vault" "$(fix_of writing-style vault)" "run second-brain scaffold vault to create it"
reset
# The note as 0.2.0 wrote it, with no version.
cat >"$tmp/pr-0.2.0.md" <<'EOF'
---
aliases:
  - Pull Request Format
type: onboarding
tags:
  - type/onboarding
---

> Conventions: [[obsidian-conventions|Obsidian Conventions]]

# Pull request format

Every pull request description Claude writes follows this format. A project that keeps its own
`<project>/claude/pull-request.md` uses that one instead. Edit this note to change the format.

## The rules

- Use the four headings below, in this order, and no others.
- Write short plain English: a few bullets under each heading, one line each.
- Name the file, the command or the setting. Leave out what the diff already shows line by line.
- Under a heading with nothing to say, write `- None.`

## The format

```markdown
## What was changed?

- <behaviour that works differently now, one line each>

## What was added?

- <new files, commands, checks or options, one line each>

## Dependencies:

- <what must be merged, installed or set first, or "None.">

## Risks:

- <what could break and for whom, or "None.">
```
EOF
PRT="$here/templates/pull-request.md.tmpl"
pv="$(sed -n 's/^pull_request_version: *//p' "$PRT" | head -1)"
is "pull-request: the last text the doctor knows is the template's, so a change to it adds a line" \
  "$(. "$here/scripts/lib/doctor.sh" && sb_doc_pr_texts | tail -1)" "$pv $(tr -d '\r' <"$PRT" | cksum)"
UNEDITED="the note is older than the plugin's template, version $pv, and was never edited: run second-brain doctor --fix"
EDITED="the note is older than the plugin's template, version $pv, and was edited: bring it in line with the template by hand, keep your own rules, and set pull_request_version"
cat "$tmp/pr-0.2.0.md" >"$vault/claude/pull-request.md"
doc
rc_is "pull-request: an older note leaves exit 0" 0
chk "pull-request: the note of 0.2.0 warns, with no version" pull-request vault "warn | 1 | claude/pull-request.md:none"
is "pull-request: a note never edited is left to --fix" "$(fix_of pull-request vault)" "$UNEDITED"
edit "$vault/claude/pull-request.md" "s/\$/$CR/"
doc
is "pull-request: CRLF line endings are no edit" "$(fix_of pull-request vault)" "$UNEDITED"
doc --fix
rc_is "pull-request: --fix exits 0" 0
is "pull-request: --fix names the note it replaced, first" "$(printf '%s\n' "$OUT" | head -1)" "fixed: claude/pull-request.md -> version $pv (vault)"
is "pull-request: --fix writes the template" "$(cmp -s "$PRT" "$vault/claude/pull-request.md" && printf same)" "same"
chk "pull-request: the replaced note is ok" pull-request vault "ok | 0 | -"
doc --fix
is "pull-request: --fix again changes nothing" "$(printf '%s\n' "$OUT" | head -1)" "fixed: nothing"
cat "$tmp/pr-0.2.0.md" >"$vault/claude/pull-request.md"
printf -- '- my own pull request rule\n' >>"$vault/claude/pull-request.md"
cp "$vault/claude/pull-request.md" "$tmp/pr.before"
doc --fix
is "pull-request: --fix leaves an edited note alone" "$(printf '%s\n' "$OUT" | head -1)" "fixed: nothing"
is "pull-request: the edited note is unchanged" "$(cmp -s "$tmp/pr.before" "$vault/claude/pull-request.md" && printf same)" "same"
chk "pull-request: an edited note of 0.2.0 warns" pull-request vault "warn | 1 | claude/pull-request.md:none"
is "pull-request: the fix says to bring an edited note in line by hand" "$(fix_of pull-request vault)" "$EDITED"
# The note as version 2 of the template wrote it: a later template still counts it unedited.
cat >"$tmp/pr-2.md" <<'EOF'
---
aliases:
  - Pull Request Format
type: onboarding
pull_request_version: 2
tags:
  - type/onboarding
---

> Conventions: [[obsidian-conventions|Obsidian Conventions]]

# Pull request format

Every pull request description Claude writes follows this format. A project that keeps its own
`<project>/claude/pull-request.md` uses that one instead. Edit this note to change the format.

## The rules

- Write the description from the branch, never from memory of the work. The source branch holds
  the work; the target is the branch it merges into, usually `main`.
- Read `git log <target>..<source>` for the commits and `git diff <target>...<source>` for the
  changes. Name both branches: the checkout may be on another one. Take the target as the remote
  has it, as in `origin/main`, after a `git fetch`. Describe what they show and nothing else.
- Use the five headings below, in this order, and no others. Every heading is bold.
- Under `Goal`, say in one or two lines why the pull request exists.
- Under each other heading, write a few bullets in short plain English, one line each. Every
  bullet starts with a bold label, the part it is about: `- **doctor:** warns on an old index`.
- Name the file, the command or the setting. Leave out what the diff already shows line by line.
- Under a heading with nothing to say, write `- **None.**`

## The format

```markdown
## **Goal**

<why this pull request exists, in one or two lines>

## **What was changed?**

- **<part>:** <behaviour that works differently now>

## **What was added?**

- **<part>:** <a new file, command, check or option>

## **Dependencies:**

- **<part>:** <what must be merged, installed or set first>

## **Risks:**

- **<part>:** <what could break, and for whom>
```
EOF
cat "$tmp/pr-2.md" >"$vault/claude/pull-request.md"
doc
chk "pull-request: the note of version 2 warns, with its version" pull-request vault "warn | 1 | claude/pull-request.md:2"
is "pull-request: the note of version 2, never edited, is left to --fix" "$(fix_of pull-request vault)" "$UNEDITED"
doc --fix
is "pull-request: --fix replaces the note of version 2 with the template" "$(cmp -s "$PRT" "$vault/claude/pull-request.md" && printf same)" "same"
# The note as version 3 of the template wrote it, with its headings as markdown headings.
cat >"$tmp/pr-3.md" <<'EOF'
---
aliases:
  - Pull Request Format
type: onboarding
pull_request_version: 3
tags:
  - type/onboarding
---

> Conventions: [[obsidian-conventions|Obsidian Conventions]]

# Pull request format

Every pull request description Claude writes follows this format. A project that keeps its own
`<project>/claude/pull-request.md` uses that one instead. Edit this note to change the format.

## The rules

- Write the description only from `git log <target>..<source>` and
  `git diff <target>...<source>`, never from memory of the work.
- `<source>` is the branch that holds the work. `<target>` is the branch it merges into, as the
  remote has it after a `git fetch`: usually `origin/main`.
- Name both branches in the commands: the checkout may be on another one.
- Use the five bold headings below, in this order, and no others.
- Under each heading after `Goal`, write a few bullets in short plain English, one line each.
- Start each bullet with the part it is about, in bold: `- **doctor:** warns on an old index`.
- Name the file, the command or the setting; leave out what the diff shows line by line.
- Under a heading with nothing to say, write `- **None.**`

## The format

```markdown
## **Goal**

<why this pull request exists, in one or two lines>

## **What was changed?**

- **<part>:** <behaviour that works differently now>

## **What was added?**

- **<part>:** <a new file, command, check or option>

## **Dependencies:**

- **<part>:** <what must be merged, installed or set first>

## **Risks:**

- **<part>:** <what could break, and for whom>
```
EOF
is "pull-request: the fixture is the text of version 3 that the doctor knows" \
  "$(tr -d '\r' <"$tmp/pr-3.md" | cksum)" "$(. "$here/scripts/lib/doctor.sh" && sb_doc_pr_texts | awk '$1 == 3 { print $2, $3 }')"
cat "$tmp/pr-3.md" >"$vault/claude/pull-request.md"
doc
chk "pull-request: the note of version 3 warns, with its version" pull-request vault "warn | 1 | claude/pull-request.md:3"
is "pull-request: the note of version 3, never edited, is left to --fix" "$(fix_of pull-request vault)" "$UNEDITED"
doc --fix
is "pull-request: --fix names the version 3 note it replaced" "$(printf '%s\n' "$OUT" | head -1)" "fixed: claude/pull-request.md -> version $pv (vault)"
is "pull-request: --fix replaces the note of version 3 with the template" "$(cmp -s "$PRT" "$vault/claude/pull-request.md" && printf same)" "same"
chk "pull-request: the note that replaced version 3 is ok" pull-request vault "ok | 0 | -"
cat "$tmp/pr-3.md" >"$vault/claude/pull-request.md"
printf -- '- my own pull request rule\n' >>"$vault/claude/pull-request.md"
doc
is "pull-request: an edited note of version 3 is left to the hand" "$(fix_of pull-request vault)" "$EDITED"
cat "$PRT" >"$vault/claude/pull-request.md"
edit "$vault/claude/pull-request.md" "s/^pull_request_version: .*/pull_request_version: $((pv - 1))/"
doc
chk "pull-request: a lower version warns, with that version" pull-request vault "warn | 1 | claude/pull-request.md:$((pv - 1))"
is "pull-request: a version changed by hand is an edit" "$(fix_of pull-request vault)" "$EDITED"
edit "$vault/claude/pull-request.md" "s/^pull_request_version: .*/pull_request_version: $((pv + 1))/"
doc
chk "pull-request: a note newer than the template is fine" pull-request vault "ok | 0 | -"
edit "$vault/claude/pull-request.md" "s/^pull_request_version: .*/pull_request_version: 99999999999999999999999/"
doc
chk "pull-request: a version too long to compare counts as newer" pull-request vault "ok | 0 | -"
is "pull-request: such a version gives no shell error" "$ERR" ""
fi

# ---------------------------------------------------------------- index rows and version
# add_row <name> <path> <keys>: add one row to the index table.
add_row() {
  printf '| %s | %s | %s | A row the suite added. |\n' "$1" "$2" "$3" >>"$vault/CLAUDE.md"
}
# index_back: put the index back as it was after the setup.
index_back() {
  cp "$tmp/pristine/CLAUDE.md" "$vault/CLAUDE.md"
}
if block 116; then
mkdir -p "$vault/projects/other" "$tmp/outside"
add_row Ghost projects/ghost GH
doc
rc_is "index: a row to a folder that is gone gives exit 1" 1
chk "index: a row whose path is no folder fails" index vault "fail | 1 | Ghost:no-folder"
is "index: the fix says what a row needs" "$(fix_of index vault)" \
  "give each row its own name, keys and path, and a path that is a folder in the vault"
index_back
add_row Out ../outside OUT
doc
chk "index: a path that leaves the vault is no folder, though one is there on disk" index vault "fail | 1 | Out:no-folder"
index_back
add_row EXAMPLE projects/other OT
doc
chk "index: a name on two rows, whatever the case, in the spelling of its first row" index vault "fail | 1 | Example:twice"
index_back
add_row Other projects/other 'OT, ex'
doc
chk "index: a key on two rows, whatever the case" index vault "fail | 1 | EX:twice"
index_back
add_row Other projects/example/ OT
doc
chk "index: a path on two rows" index vault "fail | 1 | projects/example:twice"
index_back
add_row Other projects/other 'OT, ot'
doc
chk "index: a key written twice on one row is no offender, and a second project is fine" index vault "ok | 0 | -"
index_back
mkdir -p "$vault/projects/third"
add_row Other projects/other '-, OT,,'
add_row Third projects/third '-,, TH'
doc
chk "index: a dash, and an empty item between commas, are no keys" index vault "ok | 0 | -"
index_back
mkdir -p "$vault/Projects/Third"
add_row Two projects//example TW
add_row Other projects/other OT
add_row Other2 projects/./other O2
add_row Third projects/third TH
add_row Third2 Projects/Third T2
doc
chk "index: paths are one when they differ by //, by /./ or by letter case" index vault \
  "fail | 3 | projects/example:twice, projects/other:twice, projects/third:twice"
index_back
: >"$vault/projects/afile"
add_row File projects/afile FI
doc
chk "index: a path that is a file is no folder" index vault "fail | 1 | File:no-folder"
index_back
add_row 'A project with a rather long display name, fifty bytes' projects/ghost GH
doc
chk "index: a long offender is cut in its value and keeps its tag" index vault "fail | 1 | A project with a rather long display n...:no-folder"
index_back
add_row Ghost projects/ghost ex
add_row example projects/example EX
doc
chk "index: the rows with no folder, then the names, the keys and the paths on two rows" index vault \
  "fail | 4 | Ghost:no-folder, Example:twice, EX:twice, projects/example:twice"
index_back
ti="$(sed -n 's/^index_version: *//p' "$here/templates/vault-index.md.tmpl" | head -1)"
edit "$vault/CLAUDE.md" "s/^index_version: .*/index_version: $((ti - 1))/"
doc
rc_is "index: an older index leaves exit 0" 0
chk "index: an index older than the plugin's template warns, with its version" index vault "warn | 1 | CLAUDE.md:$((ti - 1))"
is "index: the fix says what to bring in line, and gives the template's version" "$(fix_of index vault)" \
  "the index is older than the plugin's template, version $ti: bring the text above ## Projects in line with the template, keep the table, and set index_version"
edit "$vault/CLAUDE.md" '1,3d'
doc
chk "index: an index from before the version, with no frontmatter, warns" index vault "warn | 1 | CLAUDE.md:none"
add_row Ghost projects/ghost GH
doc
chk "index: a failure wins over the warning, and the row holds its offenders alone" index vault "fail | 1 | Ghost:no-folder"
index_back
edit "$vault/CLAUDE.md" "s/^index_version: .*/index_version: $((ti + 1))/"
doc
chk "index: an index newer than the template is fine" index vault "ok | 0 | -"
edit "$vault/CLAUDE.md" "s/^index_version: .*/index_version: 99999999999999999999999/"
edit "$vault/obsidian-conventions.md" "s/^conventions_version: .*/conventions_version: 99999999999999999999999/"
doc
chk "index: a version too long to compare counts as newer" index vault "ok | 0 | -"
chk "conventions: a version too long to compare counts as newer" conventions vault "ok | 0 | -"
is "index, conventions: such a version gives no shell error" "$ERR" ""
reset
printf '# Mine\n\n@%s/CLAUDE.md\n' "$vault" >"$home/CLAUDE.md"
doc
chk "import: an absolute import line is found" import vault "ok | 0 | -"
symlink "$vault" "$HOME/vault-link"
printf '# Mine\n\n@~/vault-link/CLAUDE.md  \r\n' >"$home/CLAUDE.md"
doc
chk "import: a line starting with ~ and going through a link is found" import vault "ok | 0 | -"
if sb_is_windows; then
  printf '# Mine\n\n@%s/CLAUDE.md\n' "$(cygpath -m "$vault")" >"$home/CLAUDE.md"
  doc
  chk "import: on Windows a line in the drive form is found" import vault "ok | 0 | -"
  printf '# Mine\r\n\r\n@%s\\CLAUDE.md\r\n' "$(cygpath -w "$vault")" >"$home/CLAUDE.md"
  doc
  chk "import: on Windows a line written with backslashes, in a CRLF file, is found" import vault "ok | 0 | -"
  printf '# Mine\n\n@~\\vault-link\\CLAUDE.md\n' >"$home/CLAUDE.md"
  doc
  chk "import: on Windows a line that starts with ~ and a backslash is found" import vault "ok | 0 | -"
  printf '# Mine\n\n@%s\\CLAUDE.md\n' "$(cygpath -w "$tmp/userdir")" >"$home/CLAUDE.md"
  doc
  chk "import: on Windows another file written with backslashes does not count" import vault "warn | 1 | CLAUDE.md"
fi
printf '# Mine\n\n@~/elsewhere/CLAUDE.md\nsee @%s/CLAUDE.md\n' "$vault" >"$home/CLAUDE.md"
doc
chk "import: another file does not count" import vault "warn | 1 | CLAUDE.md"
fi

# ---------------------------------------------------------------- global-rules
if block 26; then
doc
chk "global-rules: ok with no CLAUDE.md in the link directory" global-rules vault "ok | 0 | -"
printf '# Mine\n\n@%s/CLAUDE.md\n- Answer in short, plain English.\n- For example, say the file.\n' "$vault" >"$home/CLAUDE.md"
doc
chk "global-rules: ok for the import and rules for every project" global-rules vault "ok | 0 | -"
mkdir -p "$HOME/projects"
symlink "$vault" "$HOME/$P"
printf '# Mine\n\n@~/%s/CLAUDE.md\n\n## Projects\n\n| Project | Path | Keys | Use when |\n|---|---|---|---|\n| Example | %s | EX | Anything. |\n' "$P" "$P" >"$home/CLAUDE.md"
doc
chk "global-rules: the import and a Projects table naming the project are not offenders" global-rules vault "ok | 0 | -"
printf '# Mine\n\n- In Example, run the tests first.\r\n- Notes live in %s/notes.\n- Example-api is not the project.\n' "$(printf '%s' "$P" | tr 'a-z' 'A-Z')" >"$home/CLAUDE.md"
doc
chk "global-rules: a line naming the project by name or path warns" global-rules vault "warn | 2 | Example:3, Example:4"
is "global-rules: the fix moves the line to the project's rules" "$(fix_of global-rules vault)" \
  "move the line to the project's claude/README.md under ## Rules, or to its subproject's note"
rc_is "global-rules: a warn alone keeps exit 0" 0
printf 'Example runs the tests first.\n%s keeps its notes.\n' "$P" >"$home/CLAUDE.md"
doc
chk "global-rules: a line that starts with the name or the path warns" global-rules vault "warn | 2 | Example:1, Example:2"
printf '# Mine\n\n@~/%s/claude/README.md\n' "$P" >"$home/CLAUDE.md"
doc
chk "global-rules: an import of a project's file warns, marked with @" global-rules vault "warn | 1 | Example:@3"
case "$(fix_of global-rules vault)" in
  *"remove an @ import of a project's file"*) pass "global-rules: an import gets its own fix" ;;
  *) fail "global-rules: an import gets its own fix" "fix: $(fix_of global-rules vault)" ;;
esac
fi

# ---------------------------------------------------------------- links, double-registration
if block 39; then
doc
chk "double-registration: ok with no links" double-registration vault "ok | 0 | -"
mkdir -p "$vault/claude/skills/my-skill" "$home/skills" "$home/agents"
printf '%s\n' '---' 'name: my-skill' 'description: A skill of my own.' '---' 'Body.' >"$vault/claude/skills/my-skill/SKILL.md"
doc
rc_is "links: an unlinked skill gives exit 1" 1
chk "links: an unlinked skill fails" links vault "fail | 1 | my-skill:missing"
symlink "$vault/claude/skills/my-skill" "$home/skills/my-skill"
doc
chk "links: ok once it is linked" links vault "ok | 0 | -"
symlink "$here/skills/story-tracker" "$home/skills/story-tracker"
symlink "$here/agents/scrum-master.md" "$home/agents/scrum-master.md"
symlink "$tmp/userdir" "$home/skills/elsewhere"
doc
chk "double-registration: links into the plugin warn" double-registration vault "warn | 2 | skills/story-tracker, agents/scrum-master.md"

# ---------------------------------------------------------------- foreign
chk "foreign: a vault link, links into the plugin and a link to a folder with no SKILL.md do not warn" foreign vault "ok | 0 | -"
mkdir -p "$home/skills/kept" "$home/skills/synced/notes" "$tmp/out/outer"
printf '%s\n' '---' 'name: kept' 'description: A real folder.' '---' >"$home/skills/kept/SKILL.md"
printf '%s\n' '---' 'name: outer' '---' >"$tmp/out/outer/SKILL.md"
printf '%s\n' '---' 'name: solo' '---' >"$home/agents/solo.md"
printf 'x\n' >"$home/agents/notes.txt"
printf 'x\n' >"$home/skills/stray.txt"
symlink "$tmp/out/outer" "$home/skills/outer"
oOuter="$(sb_path_out "$tmp/out/outer")"
doc
rc_is "foreign: a warning leaves exit 0" 0
chk "foreign: a real folder, a link and where it leads, and a real file warn; a folder with no SKILL.md and other files do not" foreign vault \
  "warn | 3 | skills/kept:folder, skills/outer:link to $oOuter, agents/solo.md:file"
is "foreign: the fix names link move" "$(fix_of foreign vault)" \
  "ask where each one belongs, then run second-brain link move <skill or agent> <name> [--project P]"
chk "foreign: links stays ok" links vault "ok | 0 | -"
sb link move skill kept
rc_is "foreign: link move takes the real folder into the vault" 0
doc
chk "foreign: the next doctor run no longer names it" foreign vault "warn | 2 | skills/outer:link to $oOuter, agents/solo.md:file"
chk "foreign: the next doctor run has it linked" links vault "ok | 0 | -"
sb link --check
out_has "foreign: link --check shows it linked" "kept | skill | linked | $(sb_path_out "$vault")/claude/skills/kept"
mkdir -p "$vault/claude/skills/odd" "$vault/claude/skills/twin" "$vault/$P/claude/skills/twin"
printf '%s\n' '---' 'name: other' '---' >"$vault/claude/skills/odd/SKILL.md"
printf '%s\n' '---' 'name: twin' '---' >"$vault/claude/skills/twin/SKILL.md"
printf '%s\n' '---' 'name: twin' '---' >"$vault/$P/claude/skills/twin/SKILL.md"
symlink "$vault/claude/skills/odd" "$home/skills/odd"
symlink "$vault/claude/skills/twin" "$home/skills/twin"
doc
chk "foreign: a link to a vault item that is name-mismatch or duplicate is left to links" foreign vault \
  "warn | 2 | skills/outer:link to $oOuter, agents/solo.md:file"
chk "foreign: links names the name-mismatch and the duplicates" links vault "fail | 3 | odd:name-mismatch, twin:duplicate, twin:duplicate"
fi

# ---------------------------------------------------------------- sizes
if block 14; then
doc
chk "always-loaded-size: ok on a fresh vault" always-loaded-size vault "ok | 0 | -"
chk "descriptions: ok with no skills" descriptions vault "ok | 0 | -"
chk "skill-size: ok with no skills" skill-size vault "ok | 0 | -"
mkdir -p "$vault/claude/skills/no-desc" "$vault/claude/agents"
printf '%s\n' '---' 'name: no-desc' '---' 'Body.' >"$vault/claude/skills/no-desc/SKILL.md"
printf '%s\n' '---' 'name: blank' 'description: ""' '---' 'Body.' >"$vault/claude/agents/blank.md"
printf '%s\n' '---' 'name: fine' 'description: Short enough.' '---' 'Body.' >"$vault/claude/agents/fine.md"
doc
chk "descriptions: a skill with no description and an agent with an empty one warn, a short one does not" descriptions vault \
  "warn | 2 | no-desc:none, blank:none"
is "descriptions: the fix covers a missing and a long description" "$(fix_of descriptions vault)" \
  "give each one a description of one sentence under 200 characters"
reset
awk 'BEGIN { for (i = 1; i <= 30; i++) print "- filler line " i }' >>"$vault/CLAUDE.md"
awk 'BEGIN { for (i = 1; i <= 41; i++) print "- my line " i }' >"$home/CLAUDE.md"
long="$(awk 'BEGIN { for (i = 1; i <= 250; i++) printf "x"; print "" }')"
mkdir -p "$vault/claude/skills/long-desc" "$vault/claude/agents" "$vault/$P/claude/skills/long-skill" "$vault/$P/claude/agents"
printf '%s\n' '---' 'name: long-desc' "description: \"$long\"" '---' 'Body.' >"$vault/claude/skills/long-desc/SKILL.md"
{
  printf '%s\n' '---' 'name: long-skill' 'description: Short.' '---'
  awk 'BEGIN { for (i = 1; i <= 196; i++) print "line " i }'
} >"$vault/$P/claude/skills/long-skill/SKILL.md"
printf '%s\n' '---' 'name: folded' 'description: >-' "  $long" '  and a second line' '---' 'Body.' >"$vault/$P/claude/agents/folded.md"
printf '%s\n' '---' 'name: fine' 'description: Short enough.' '---' 'Body.' >"$vault/claude/agents/fine.md"
printf '%s\n' '---' 'type: moc' '---' "$long" >"$vault/claude/agents/README.md"
doc
n_index="$(awk 'END { print NR }' "$vault/CLAUDE.md")"
chk "always-loaded-size: both files over their limit" always-loaded-size vault "warn | 2 | index:$n_index, CLAUDE.md:41"
chk "descriptions: a 250-character and a folded description warn" descriptions vault "warn | 2 | long-desc:250, folded:268"
chk "skill-size: a 200-line SKILL.md warns" skill-size vault "warn | 1 | long-skill:200"
fi

# ---------------------------------------------------------------- old-namespace
OLD='obsidian-dev-second-brain:'
N="$vault/$P/docs/rename.md"
if block 40; then
doc
chk "old-namespace: ok on a fresh vault" old-namespace vault "ok | 0 | -"
printf '%s\n' '---' "next: \"Run /${OLD}sprint open\"" '---' '# Rename' '' \
  "Run \`/${OLD}spec EX-1\` to build it." "A cut name ${OLD}s... and ${OLD}specs name no skill." '' \
  '```' '## Status notes' "${OLD}vault-doctor in fenced code" '```' '' \
  '## Status notes' '' "- Ran /${OLD}spec." '### Older' "- ${OLD}sprint" '' \
  '## Discovery log' "- ${OLD}spec" '## build' "- T1 - passed - commits - - ${OLD}reviewer" \
  '# Changelog' '## 0.1.0' "- ${OLD}spec" '# After' "Ask ${OLD}reviewer." >"$N"
printf '%s\n' '# Changes' '' "- ${OLD}spec stopped working." >"$vault/$P/docs/CHANGELOG.md"
mkdir -p "$vault/.trash"
printf '%s\n' "${OLD}spec" >"$vault/.trash/old.md"
doc
rc_is "old-namespace: a warn alone keeps exit 0" 0
chk "old-namespace: live lines warn, frontmatter, fenced code and a Build outside a task too; history, a CHANGELOG.md, a dot folder and a cut name do not" \
  old-namespace vault "warn | 5 | $P/docs/rename.md:2, $P/docs/rename.md:6, $P/docs/rename.md:11, $P/docs/rename.md:23, $P/docs/rename.md:28"
is "old-namespace: the fix hands the vault lines to docs-keeper" "$(fix_of old-namespace vault)" \
  "hand the vault lines to docs-keeper, Workflow 6 - A renamed command, from ${OLD} to odsb:"
edit "$N" "2s/$OLD/odsb:/;6s/$OLD/odsb:/;11s/$OLD/odsb:/;23s/$OLD/odsb:/;28s/$OLD/odsb:/"
n_ex3="$(awk 'END { print NR }' "$T/EX-3/README.md")"
printf '%s\n' '## Build' '' "- T1 - passed - commits - - ${OLD}reviewer" '## Next' "- Run ${OLD}spec." >>"$T/EX-3/README.md"
doc
chk "old-namespace: a task README's Build is history, the section after it is not" old-namespace vault \
  "warn | 1 | $P/tasks/EX-3/README.md:$((n_ex3 + 5))"
edit "$T/EX-3/README.md" "$((n_ex3 + 5))s/$OLD/odsb:/"
doc
chk "old-namespace: ok once the live lines are rewritten, with the history left as written" old-namespace vault "ok | 0 | -"
reset
mkdir -p "$vault/claude/skills/mine" "$home/skills"
printf '%s\n' '---' 'name: mine' 'description: A skill of my own.' '---' "Call ${OLD}story-tracker first." >"$vault/claude/skills/mine/SKILL.md"
symlink "$vault/claude/skills/mine" "$home/skills/mine"
printf '## Status notes\r\n- %sspec\r\n## Next\r\n- Run %sspec.\r\n' "$OLD" "$OLD" >"$vault/$P/docs/crlf.md"
printf '%s\n' '# Mine' "- Run ${OLD}vault-doctor after an update." '- Then odsb:vault-doctor fix.' >"$home/CLAUDE.md"
doc
chk "old-namespace: a vault skill, a CRLF note, then the link directory's CLAUDE.md" old-namespace vault \
  "warn | 3 | claude/skills/mine/SKILL.md:5, $P/docs/crlf.md:4, ~/.claude/CLAUDE.md:2"
is "old-namespace: the fix adds the CLAUDE.md lines" "$(fix_of old-namespace vault)" \
  "hand the vault lines to docs-keeper, Workflow 6 - A renamed command, from ${OLD} to odsb:; write odsb: in the ~/.claude/CLAUDE.md lines"
reset
printf '%s\n' '{' '  "permissions": {' "    \"allow\": [\"Skill(${OLD}spec)\", \"Bash(ls)\"]," "    \"deny\": [\"Skill(${OLD}*)\"]" '  },' \
  '  "enabledPlugins": { "obsidian-dev-second-brain@second-brain": true }' '}' >"$home/settings.json"
printf '%s\n' "{ \"permissions\": { \"ask\": [\"Bash(echo \\\"${OLD}spec\\\")\"] } }" >"$home/settings.local.json"
cp "$home/settings.json" "$tmp/settings.before"
cp "$home/settings.local.json" "$tmp/settings.local.before"
doc
chk "old-namespace: each settings string with the old name, a wildcard and an escape included; the install id is none" old-namespace vault \
  "warn | 3 | ~/.claude/settings.json:Skill(${OLD}spec), ~/.claude/settings.json:Skill(${OLD}*), ~/.claude/settings.local.json:Bash(echo \"${OLD}spec\")"
is "old-namespace: the fix leaves the settings rules to the owner" "$(fix_of old-namespace vault)" \
  "change the settings rules to odsb: yourself, as nothing edits a settings file"
doc --json
out_has "old-namespace: --json holds the same row" \
  "\"check\": \"old-namespace\", \"scope\": \"vault\", \"count\": 3, \"offenders\": [\"~/.claude/settings.json:Skill(${OLD}spec)\", \"~/.claude/settings.json:Skill(${OLD}*)\", \"~/.claude/settings.local.json:Bash(echo \\\"${OLD}spec\\\")\"]"
doc --fix
is "old-namespace: --fix writes no settings file" \
  "$(cmp -s "$tmp/settings.before" "$home/settings.json" && cmp -s "$tmp/settings.local.before" "$home/settings.local.json" && printf same)" "same"
reset
printf '%s\n' "- Run ${OLD}spec." >>"$vault/CLAUDE.md"
n_index="$(awk 'END { print NR }' "$vault/CLAUDE.md")"
symlink "$vault/CLAUDE.md" "$home/CLAUDE.md"
doc
chk "old-namespace: a link directory CLAUDE.md that is the index is read once, as the vault's note" old-namespace vault \
  "warn | 1 | CLAUDE.md:$n_index"
fi

# ---------------------------------------------------------------- profile, board
# no_sprint_branch: the board's filters as 0.10.0 wrote them, with the archive and status branches
# and no branch for a task in a group folder, the third and: of the filters.
no_sprint_branch() {
  awk '/^        - and:$/ { n++ } /^formulas:/ { n = 0 } n < 3 { print }' "$T/tasks.base" >"$tmp/edit.tmp" &&
    cat "$tmp/edit.tmp" >"$T/tasks.base"
}
if block 135; then
doc Example
rc_is "a named project: exit 0" 0
chk "profile: ok on a scaffolded project" profile Example "ok | 0 | -"
chk "board: ok when the board file is there" board Example "ok | 0 | -"
is "board: nothing to fix" "$(fix_of board)" "-"
edit "$vault/$P/claude/profile.md" '/^persona:/d; /^## Live systems$/d'
rm "$T/tasks.base"
doc Example
rc_is "profile and board: exit 1" 1
chk "profile: a missing key and a missing section fail" profile Example "fail | 2 | persona, ## Live systems"
chk "board: a missing board file fails" board Example "fail | 1 | tasks.base"
rm "$vault/$P/claude/profile.md"
doc Example
chk "profile: a missing profile fails" profile Example "fail | 1 | profile.md"
reset
is "board: the Current sprint view filters on the sprint in progress" "$(grep -c 'sprint == "2026-01-14"' "$T/tasks.base")" "1"
edit "$T/tasks.base" 's/sprint == "2026-01-14"/sprint == "2025-12-31"/'
doc Example
rc_is "board: a warning leaves exit 0" 0
chk "board: a view that filters on another sprint than the one in progress warns, with its id" board Example "warn | 1 | tasks.base:2025-12-31"
is "board: the fix names the sprint in progress" "$(fix_of board)" \
  "set the filter of the board's Current sprint view to the sprint in progress, 2026-01-14"
reset
edit "$T/tasks.base" "s/sprint == \"2026-01-14\"/sprint == '2026-01-14'/"
doc Example
chk "board: a filter in single quotes is not a missing view" board Example "warn | 1 | tasks.base:filter"
is "board: the fix gives the form sprint open rewrites" "$(fix_of board)" \
  "write the filter of the board's Current sprint view as sprint == \"2026-01-14\", the form sprint open rewrites"
reset
edit "$T/tasks.base" 's/sprint == "2026-01-14"/"2026-01-14" == sprint/'
doc Example
chk "board: a filter with its sides swapped is not a missing view either" board Example "warn | 1 | tasks.base:filter"
reset
edit "$T/tasks.base" 's/name: Current sprint/name: Last Current sprint/'
doc Example
chk "board: a view whose name only holds the words Current sprint is not that view" board Example "warn | 1 | tasks.base:no-view"
reset
# The board's filters as 0.2.0 wrote them, with no archive branch and no status branch.
edit "$T/tasks.base" '/^    - or:$/d; /^        - and:$/d; /^            - /d; /^                - /d; s/^        - file\.folder/    - file.folder/'
is "board: the old filters keep one depth line" "$(grep -c '^    - file.folder.split("/").length == 4$' "$T/tasks.base")/$(grep -c 'archive' "$T/tasks.base")" "1/0"
is "board: the old filters keep one folder filter" "$(grep -c 'file\.inFolder' "$T/tasks.base")" "1"
doc Example
chk "board: a flat project is not asked for the archive filter" board Example "ok | 0 | -"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: status/'
doc Example
chk "board: a status project whose board takes no status folder warns, and is not asked for the archive filter" board Example \
  "warn | 1 | tasks.base:no-status-filter"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: Archive/'
doc Example
rc_is "board: a missing archive filter leaves exit 0" 0
chk "board: an archive project whose board takes no archived task warns" board Example "warn | 1 | tasks.base:no-archive-filter"
is "board: the fix names the filters block" "$(fix_of board)" "copy the filters block from templates/tasks.base.tmpl"
edit "$T/tasks.base" 's/sprint == "2026-01-14"/sprint == "2025-12-31"/'
doc Example
chk "board: the sprint finding and the archive filter share one row" board Example \
  "warn | 2 | tasks.base:2025-12-31, tasks.base:no-archive-filter"
is "board: the fix holds both" "$(fix_of board)" \
  "set the filter of the board's Current sprint view to the sprint in progress, 2026-01-14; copy the filters block from templates/tasks.base.tmpl"
reset
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: archive/'
doc Example
chk "board: an archive project with the template's filters is ok" board Example "ok | 0 | -"
reset
# no_status_branch: the board's filters as 0.8.0 wrote them, with the archive branch and no status
# branch, the second and: of the filters.
no_status_branch() {
  awk '/^        - and:$/ { n++ } /^formulas:/ { n = 0 } n < 2 { print }' "$T/tasks.base" >"$tmp/edit.tmp" &&
    cat "$tmp/edit.tmp" >"$T/tasks.base"
}
no_status_branch
is "board: the 0.8.0 filters take the archive and no status folder" \
  "$(grep -c 'file\.inFolder' "$T/tasks.base")/$(grep -c 'file\.inFolder(".*/archive")' "$T/tasks.base")" "2/1"
doc Example
chk "board: a flat project is not asked for the status filter" board Example "ok | 0 | -"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: archive/'
doc Example
chk "board: an archive project is not asked for the status filter" board Example "ok | 0 | -"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: Status/'
doc Example
rc_is "board: a missing status filter leaves exit 0" 0
chk "board: a status project whose board takes no status folder warns, in any letter case" board Example \
  "warn | 1 | tasks.base:no-status-filter"
is "board: the status fix names the filters block" "$(fix_of board)" "copy the filters block from templates/tasks.base.tmpl"
reset
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: status/'
doc Example
chk "board: a status project with the template's filters is ok" board Example "ok | 0 | -"
edit "$T/tasks.base" 's#^\(                - file\.inFolder("\)[^"]*/\([a-z-]*"\))$#\1old/tasks/\2)#'
is "board: the status folders under another path" "$(grep -c 'inFolder("old/tasks/' "$T/tasks.base")" "5"
doc Example
chk "board: a status folder under any path counts" board Example "ok | 0 | -"
edit "$T/tasks.base" '/\/abandoned")$/d'
doc Example
chk "board: a board that misses one status folder warns" board Example "warn | 1 | tasks.base:no-status-filter"
reset
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: status/'
no_status_branch
# The last view, All, takes the five folders as a filter of its own.
printf '%s\n' "    filters:" "      or:" >>"$T/tasks.base"
for s in planned in-progress in-review done abandoned; do
  printf '%s\n' "        - file.inFolder(\"$P/tasks/$s\")" >>"$T/tasks.base"
done
doc Example
chk "board: the status folders in a view's filters are not the board's own" board Example "warn | 1 | tasks.base:no-status-filter"
reset
# A task in a group folder, $P/tasks/<group>/<ID>, has five folder parts, and its ID is part 4,
# counted from 0.
is "board: a new board holds the branch that takes a task in a group folder whose name is its first alias" \
  "$(awk '/^formulas:/ { exit } /^        - and:$/ { n++ } n == 3' "$T/tasks.base")" \
  "$(printf '%s\n' "        - and:" '            - file.folder.split("/").length == 5' \
    '            - file.folder.split("/")[4] == aliases[0]')"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: sprint/'
doc Example
chk "board: a sprint project with the template's filters is ok" board Example "ok | 0 | -"
edit "$T/tasks.base" 's/split("\/")\[4\] == aliases\[0\]/split("\/")[12] == aliases[0]/'
is "board: the branch under another index" "$(grep -c 'split("/")\[12\] == aliases\[0\]' "$T/tasks.base")" "1"
doc Example
chk "board: the branch at any index counts" board Example "ok | 0 | -"
reset
no_sprint_branch
is "board: the 0.10.0 filters take the archive and the five status folders, and no task by its alias" \
  "$(grep -c 'file\.inFolder' "$T/tasks.base")/$(grep -c '== aliases\[0\]' "$T/tasks.base")" "7/0"
doc Example
chk "board: a flat project is not asked for the sprint filter" board Example "ok | 0 | -"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: archive/'
doc Example
chk "board: an archive project is not asked for the sprint filter" board Example "ok | 0 | -"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: status/'
doc Example
chk "board: a status project is not asked for the sprint filter" board Example "ok | 0 | -"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: Sprint/'
doc Example
rc_is "board: a missing sprint filter leaves exit 0" 0
chk "board: a sprint project whose board has the 0.10.0 filters warns, in any letter case" board Example \
  "warn | 1 | tasks.base:no-sprint-filter"
is "board: the sprint fix names the filters block" "$(fix_of board)" "copy the filters block from templates/tasks.base.tmpl"
edit "$T/tasks.base" 's/sprint == "2026-01-14"/sprint == "2025-12-31"/'
doc Example
chk "board: the sprint finding and the sprint filter share one row" board Example \
  "warn | 2 | tasks.base:2025-12-31, tasks.base:no-sprint-filter"
edit "$vault/$P/claude/profile.md" 's/^uses_sprints: .*/uses_sprints: false/'
doc Example
chk "board: task_layout: sprint with sprints off is not asked for the sprint filter" board Example "ok | 0 | -"
reset
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: sprint/'
no_status_branch
doc Example
chk "board: a sprint project's 0.8.0 board warns the sprint filter alone, not the status filter" board Example \
  "warn | 1 | tasks.base:no-sprint-filter"
reset
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: sprint/'
no_sprint_branch
# The last view, All, takes a task by its alias as a filter of its own.
printf '%s\n' "    filters:" "      and:" '        - file.folder.split("/")[4] == aliases[0]' >>"$T/tasks.base"
doc Example
chk "board: the branch in a view's filters is not the board's own" board Example "warn | 1 | tasks.base:no-sprint-filter"
fi

# ---------------------------------------------------------------- paths that leave the vault
O="$tmp/outside-proj"
# outside_proj: build a project outside the vault, with a mark in every file the doctor could open
# there, and keep a copy of its task in outside.before.
outside_proj() {
  mkdir -p "$O/claude/skills/OUTMARK-3" "$O/tasks/OUTMARK-1" "$O/sprints"
  cp "$vault/$P/claude/profile.md" "$O/claude/profile.md"
  printf '%s\n' '---' 'name: OUTMARK-3' '---' 'A skill with no description.' >"$O/claude/skills/OUTMARK-3/SKILL.md"
  sed 's/sprint == "2026-01-14"/sprint == "OUTMARK-2"/' "$T/tasks.base" >"$O/tasks/tasks.base"
  sed 's/^  - status\/active$/  - status\/done/' "$T/EX-1/README.md" >"$O/tasks/OUTMARK-1/README.md"
  sed 's/2026-01-14/2031-01-01/g' "$vault/$P/sprints/2026-01-14.md" >"$O/sprints/2031-01-01.md"
  cp "$O/tasks/OUTMARK-1/README.md" "$tmp/outside.before"
}
# marks: count the lines of the last run, stdout and stderr, that hold something read out there.
marks() { printf '%s\n%s\n' "$OUT" "$ERR" | grep -c -e OUTMARK -e 2031-01-01 || true; }
# set_root <key> <raw value>: write one root of the profile as it is given.
set_root() {
  SB_K="$1" SB_V="$2" awk 'index($0, ENVIRON["SB_K"] ":") == 1 { print ENVIRON["SB_K"] ": " ENVIRON["SB_V"]; next } { print }' \
    "$vault/$P/claude/profile.md" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$vault/$P/claude/profile.md"
}
if block 43; then
outside_proj
add_row Out ../outside-proj OUT
doc
chk "outside: a row with a .. part fails the index" index vault "fail | 1 | Out:no-folder"
is "outside: it gets no project rows, and nothing under it is read" "$(scope_rows Out)/$(marks)" "0/0"
chk "outside: the skill in its claude folder is not scanned" descriptions vault "ok | 0 | -"
doc Out
rc_is "outside: named, the row still gives exit 1" 1
is "outside: named, it gets the vault rows alone" "$(printf '%s\n' "$OUT" | grep -c ' | ')/$(scope_rows Out)/$(marks)" "14/0/0"
doc --fix
is "outside: --fix writes nothing there" "$(cmp -s "$tmp/outside.before" "$O/tasks/OUTMARK-1/README.md" && printf same)" "same"
index_back
mkdir -p "$vault/"'projects\example'
add_row Back 'projects\example' BK
add_row Whole . WH
doc
chk "outside: a path with a backslash, though a folder is there on disk, and the vault itself are no project folders" index vault \
  "fail | 2 | Back:no-folder, Whole:no-folder"
is "outside: neither gets project rows" "$(scope_rows Back)/$(scope_rows Whole)" "0/0"
reset
set_root tasks_root ../../../outside-proj/tasks
doc Example
rc_is "outside: a root that leaves the project gives exit 1" 1
chk "outside: a tasks root with a .. part fails the profile" profile Example "fail | 1 | tasks_root:leaves-project"
is "outside: the fix says what a root is" "$(fix_of profile)" \
  "write each root as a folder inside the project, with no .. part and no backslash; add a missing key or section as in the profile template"
is "outside: nothing is read through it, and the project is checked under the default root" \
  "$(marks)/$(row board)/$(row task-location)" "0/ok | 0 | -/ok | 0 | -"
doc Example --fix
is "outside: --fix writes nothing through it" "$(cmp -s "$tmp/outside.before" "$O/tasks/OUTMARK-1/README.md" && printf same)" "same"
set_root tasks_root "'..\\..\\..\\outside-proj\\tasks'"
set_root sprints_root ../../../outside-proj/sprints
doc Example
chk "outside: a backslash and a .. part, one root each" profile Example \
  "fail | 2 | tasks_root:leaves-project, sprints_root:leaves-project"
is "outside: nothing is read through either of them" "$(marks)" "0"
reset
set_root tasks_root /tasks/
set_root topics_root //docs
doc Example
rc_is "roots: a slash in front of a root is no failure" 0
is "roots: such a root is the folder every command reads, and it is checked" \
  "$(row profile)/$(row board)/$(row hubs)/$(row task-location)" "ok | 0 | -/ok | 0 | -/ok | 0 | -/ok | 0 | -"
reset
edit "$vault/$P/claude/profile.md" '/^tasks_root:/d'
doc Example
chk "roots: a root key that is absent is a missing key of the profile" profile Example "fail | 1 | tasks_root"
is "roots: the folder checked is then its default, not the project folder" "$(row board)/$(row task-location)" "ok | 0 | -/ok | 0 | -"
reset
edit "$vault/CLAUDE.md" "s#| $P |#| projects//example |#"
printf '%s\n' '[[gone-for-good]]' >"$vault/$P/docs/broken.md"
doc
chk "a row written with a doubled slash: the project is checked under the folded path" unresolved-links Example "warn | 1 | docs/broken.md:1"
fi

# ---------------------------------------------------------------- hubs
if block 38; then
doc Example
chk "hubs: ok on a scaffolded project" hubs Example "ok | 0 | -"
rm "$vault/$P/README.md"
doc Example
rc_is "hubs: a warning leaves exit 0" 0
chk "hubs: a missing project hub warns, as its path under the project" hubs Example "warn | 1 | README.md"
is "hubs: the fix names the scaffold command, and says what it does with an empty hub" "$(fix_of hubs)" \
  "run second-brain scaffold project again with the same name and path: it writes what is missing and overwrites nothing, so delete an empty hub first"
reset
rm "$vault/$P/claude/README.md" "$vault/$P/docs/README.md"
: >"$T/README.md"
: >"$vault/$P/sprints/README.md"
doc Example
chk "hubs: the Claude hub and the hubs of the three roots, missing or empty" hubs Example \
  "warn | 4 | claude/README.md, tasks/README.md, docs/README.md, sprints/README.md"
sb scaffold project Example --path "$P"
doc Example
chk "hubs: the scaffold writes the missing hubs again and keeps the empty ones" hubs Example "warn | 2 | tasks/README.md, sprints/README.md"
reset
sb scaffold project Flat --path projects/flat --keys FL --topics-root .
doc Flat
chk "hubs: ok with the topics at the project root, where there is no topics hub" hubs Flat "ok | 0 | -"
rm "$vault/projects/flat/README.md"
doc Flat
chk "hubs: there the project hub is one offender, not two" hubs Flat "warn | 1 | README.md"
reset
sb scaffold project Long --path projects/long --keys LG --topics-root a-rather-long-folder-for-the-docs/of-the-long-project
rm "$vault/projects/long/a-rather-long-folder-for-the-docs/of-the-long-project/README.md"
doc Long
chk "hubs: a long path is printed whole" hubs Long "warn | 1 | a-rather-long-folder-for-the-docs/of-the-long-project/README.md"
fi

# ---------------------------------------------------------------- placeholders
HUB="$vault/$P/README.md"
CHUB="$vault/$P/claude/README.md"
PF="$vault/$P/claude/profile.md"
if block 30; then
doc Example
rc_is "placeholders: a warning leaves exit 0" 0
chk "placeholders: a fresh scaffold warns, one offender per line, as its path under the project" placeholders Example \
  "warn | 25 | README.md:14, claude/README.md:22, claude/README.md:23, claude/profile.md:41, claude/profile.md:42"
is "placeholders: the fix says to fill the line or delete it" "$(fix_of placeholders)" \
  "write what the <...> text asks for, such as the project's rules, in its place, or delete the line"
# Filled as an owner would, with angle brackets of their own; the task READMEs keep the template's text.
edit "$HUB" 's#^<One paragraph.*>$#Example is the scratch project. Its code is in `<repo>/src`, see <https://example.com>.#'
edit "$CHUB" 's#^- <A rule .*>$#- Name a branch feature/<ID>-<slug>.#'
edit "$CHUB" 's#^- <Live systems: .*>$#- Live systems: none.#'
edit "$PF" '/^## Stories$/,$s/<[^ >][^>]*>/none/g'
doc Example
chk "placeholders: ok once filled; the owner's own angle brackets, inline code and task READMEs are not read" placeholders Example "ok | 0 | -"
edit "$CHUB" 's/^- Live systems: none\.$/&\
- <A rule Claude must follow in this project, one per bullet.>/'
doc Example
chk "placeholders: one leftover line in a filled hub" placeholders Example "warn | 1 | claude/README.md:24"
edit "$PF" 's/^- Tracker: none\.$/- Tracker: Jira. <where tickets live, where epics usually sit, any ticket markup to keep>./'
doc Example
chk "placeholders: a line filled in part still warns" placeholders Example "warn | 2 | claude/README.md:24, claude/profile.md:41"
edit "$CHUB" '/^- <A rule /d'
edit "$PF" 's/^- Tracker: Jira\. .*$/- Tracker: Jira./'
printf '%s\n' '```' '- <A rule Claude must follow in this project, one per bullet.>' '```' >>"$CHUB"
edit "$HUB" 's/^type: moc$/&\
note: "<One paragraph: what the project is, who it is for, and where its code lives.>"/'
printf '%s\n' '<A rule Claude must follow in this subproject, one per bullet.>' >>"$HUB"
doc Example
chk "placeholders: frontmatter, fenced code and another template's placeholder are not read" placeholders Example "ok | 0 | -"
sb scaffold subproject Example infra --repos example-infra
doc Example
chk "placeholders: a subproject note is read against its own template" placeholders Example "warn | 1 | claude/subprojects/infra.md:33"
fi

# ---------------------------------------------------------------- task-template
TT="$vault/$P/claude/templates/task-readme.md.tmpl"
if block 41; then
doc Example
chk "task-template: ok for a project with no template of its own" task-template Example "ok | 0 | -"
mkdir -p "$vault/$P/claude/templates"
printf '%s\n' 'No frontmatter and no section.' >"$vault/$P/claude/templates/ticket-description.md.tmpl"
doc Example
chk "task-template: the ticket text template is not read" task-template Example "ok | 0 | -"
cp "$here/templates/task-readme.md.tmpl" "$TT"
doc Example
chk "task-template: ok for a copy of the plugin's" task-template Example "ok | 0 | -"
edit "$TT" '/^next: /d; /^epic: /d; /^## Status notes$/d'
doc Example
rc_is "task-template: a warning leaves exit 0" 0
chk "task-template: each key, then each section, it lacks" task-template Example "warn | 3 | next, epic, ## Status notes"
is "task-template: the fix names the file and the plugin's template" "$(fix_of task-template)" \
  "add them to claude/templates/task-readme.md.tmpl, as the plugin's templates/task-readme.md.tmpl has them"
printf '%s\n' '```' '## Status notes' '```' 'next: "Frame the story"' 'epic: "-"' >>"$TT"
doc Example
chk "task-template: a heading in fenced code and a key in the body do not count" task-template Example "warn | 3 | next, epic, ## Status notes"
printf '%s\n' '## status NOTES  ' >>"$TT"
doc Example
chk "task-template: a heading matches without letter case and trailing blanks, as task note finds it" task-template Example "warn | 2 | next, epic"
grep -v '^---$' "$here/templates/task-readme.md.tmpl" >"$TT"
doc Example
chk "task-template: with no frontmatter every key is missing" task-template Example "warn | 7 | aliases, title, status, next, branch"
grep -v -x -F -e 'aliases:' -e '  - {{ID}}' "$here/templates/task-readme.md.tmpl" >"$TT"
doc Example
chk "task-template: a template with no aliases warns, as each story made from it fails task-frontmatter" task-template Example \
  "warn | 1 | aliases"
{ printf '\357\273\277'; awk '{ printf "%s\r\n", $0 }' "$here/templates/task-readme.md.tmpl"; } >"$TT"
doc Example
chk "task-template: a BOM and CRLF line endings are read" task-template Example "ok | 0 | -"
fi

# ---------------------------------------------------------------- task frontmatter and status
if block 23; then
doc Example
chk "task-frontmatter: ok on new tasks" task-frontmatter Example "ok | 0 | -"
chk "needs-a-status: ok on new tasks" needs-a-status Example "ok | 0 | -"
chk "status-tag: ok on new tasks" status-tag Example "ok | 0 | -"
edit "$T/EX-1/README.md" 's/^  - EX-1$/  - Other name/'
edit "$T/EX-2/README.md" '/^type: task$/d'
edit "$T/EX-3/README.md" '/^  - type\/task$/d'
doc Example
rc_is "task-frontmatter: exit 1" 1
chk "task-frontmatter: first alias, type and type tag" task-frontmatter Example "fail | 3 | EX-1:alias, EX-2:type, EX-3:type-tag"
reset
edit "$T/EX-3/README.md" '/^status: /d'
doc Example
rc_is "needs-a-status: a warning leaves exit 0" 0
chk "needs-a-status: a missing status warns" needs-a-status Example "warn | 1 | EX-3"
chk "status-tag: a missing status is not its business" status-tag Example "ok | 0 | -"
edit "$T/EX-1/README.md" 's/^status: .*/status: active/'
doc Example
chk "needs-a-status: a status outside the five warns" needs-a-status Example "warn | 2 | EX-1:active, EX-3"
reset
edit "$T/EX-2/README.md" 's/^  - status\/done$/  - status\/active/'
edit "$T/EX-3/README.md" '/^  - status\/active$/d'
doc Example
chk "status-tag: a tag that disagrees and a tag that is missing warn" status-tag Example "warn | 2 | EX-2, EX-3"
fi

# ---------------------------------------------------------------- yaml traps
# add_alias <ID> <raw item>: add one raw line under aliases, after the first alias.
add_alias() {
  SB_ID="$1" SB_ITEM="$2" awk '{ print } $0 == "  - " ENVIRON["SB_ID"] { print "  - " ENVIRON["SB_ITEM"] }' \
    "$T/$1/README.md" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$T/$1/README.md"
}
if block 23; then
doc Example
chk "yaml-traps: ok on new tasks" yaml-traps Example "ok | 0 | -"
add_alias EX-1 '"Fix: quoted is fine"'
doc Example
chk "yaml-traps: a quoted alias with a colon is fine" yaml-traps Example "ok | 0 | -"
add_alias EX-1 'Fix: the thing'
doc Example
rc_is "yaml-traps: exit 1" 1
chk "yaml-traps: an unquoted alias with a colon and a space" yaml-traps Example "fail | 1 | EX-1:aliases"
reset
edit "$T/EX-2/README.md" 's/^epic: "-"$/epic: -/'
doc Example
chk "yaml-traps: an unquoted lone dash" yaml-traps Example "fail | 1 | EX-2:epic"
reset
edit "$T/EX-1/README.md" 's/^sprint: "2026-01-14"$/sprint: 2026-01-14/'
doc Example
chk "yaml-traps: an unquoted sprint id" yaml-traps Example "fail | 1 | EX-1:sprint"
fi

# ---------------------------------------------------------------- alias-unique, no-readme
if block 23; then
doc Example
chk "alias-unique: ok on new tasks" alias-unique Example "ok | 0 | -"
chk "no-readme: ok on new tasks" no-readme Example "ok | 0 | -"
add_alias EX-2 'ex-1'
doc Example
rc_is "alias-unique: exit 1" 1
chk "alias-unique: one alias on two tasks, whatever the case" alias-unique Example "fail | 1 | ex-1"
reset
add_alias EX-3 '"Example Tasks Hub"'
add_alias EX-3 'EX-3'
doc Example
chk "alias-unique: a task alias that a hub carries" alias-unique Example "fail | 1 | Example Tasks Hub"
reset
v40="$(awk 'BEGIN { for (i = 1; i <= 40; i++) printf "v"; print "" }')"
t20="$(awk 'BEGIN { for (i = 1; i <= 20; i++) printf "t"; print "" }')"
for id in EX-1 EX-2; do
  add_alias "$id" "\"$v40:tttt tttt\""
  add_alias "$id" "\"$v40:${t20}t\""
  add_alias "$id" "\"$v40:$t20\""
done
doc Example
chk "rows: what follows the last colon is a tag at 20 bytes, and no tag at 21 or with a blank" alias-unique Example \
  "fail | 3 | $(printf '%s\n' "$v40" | cut -c1-27)...:$t20, $v40:ttttttt..., $v40:tttt tt..."
reset
mkdir -p "$T/EX-7/notes" "$T/EX-8"
: >"$T/EX-8/README.md"
doc Example
chk "no-readme: a task folder with no README, or an empty one, warns" no-readme Example "warn | 2 | EX-7, EX-8"
fi

# ---------------------------------------------------------------- task-location
# stray <vault path> <raw type>: write a note with that type, wherever the path says.
stray() {
  mkdir -p "$vault/${1%/*}"
  printf '%s\n' '---' "type: $2" '---' '' '# A note' >"$vault/$1"
}
if block 54; then
doc Example
chk "task-location: ok on new tasks" task-location Example "ok | 0 | -"
stray "$P/docs/billing/EX-2.md" task
doc Example
rc_is "task-location: a warning leaves exit 0" 0
chk "task-location: a task filed under its topic warns, as its path under the project" task-location Example "warn | 1 | docs/billing/EX-2.md"
is "task-location: the fix names the move command and where a task goes" "$(fix_of task-location)" \
  "move it with second-brain move to $P/tasks/<ID>/README.md, and tie it to its topic with a tag"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: status/'
doc Example
is "task-location: in a status project the fix names the folder of the task's status" "$(fix_of task-location)" \
  "move it with second-brain move to $P/tasks/<status>/<ID>/README.md, with the task's status, and tie it to its topic with a tag"
edit "$vault/$P/claude/profile.md" 's/^task_layout: .*/task_layout: sprint/'
doc Example
is "task-location: in a sprint project the fix names backlog/, from where doctor --fix moves a task with a sprint" "$(fix_of task-location)" \
  "move it with second-brain move to $P/tasks/backlog/<ID>/README.md, from where second-brain doctor --fix moves a task with a sprint to its sprint's folder, and tie it to its topic with a tag"
reset
stray "$P/tasks/EX-3.md" '"task"'
doc Example
chk "task-location: a loose note in the tasks root, its type in quotes" task-location Example "warn | 1 | tasks/EX-3.md"
reset
stray "$P/tasks/EX-1/sub/README.md" "'task' # misfiled"
doc Example
chk "task-location: a README deeper in a task folder" task-location Example "warn | 1 | tasks/EX-1/sub/README.md"
reset
stray "$P/docs/a-rather-long-topic-folder/with-a-long-sub-folder/EX-21-first.md" task
stray "$P/docs/a-rather-long-topic-folder/with-a-long-sub-folder/EX-22-second.md" task
doc Example
chk "task-location: two long paths are printed whole, so they are told apart" task-location Example \
  "warn | 2 | docs/a-rather-long-topic-folder/with-a-long-sub-folder/EX-21-first.md, docs/a-rather-long-topic-folder/with-a-long-sub-folder/EX-22-second.md"
reset
mkdir -p "$vault/$P/zz"
printf '%s\n' '---' 'type: note' 'type: task' '---' '# Two type lines' >"$vault/$P/zz/last.md"
printf '%s\r\n' '---' 'type: task' '---' '# CRLF' >"$vault/$P/docs/crlf.md"
stray "$P/a-first.md" task
printf '\357\273\277---\ntype: task\n---\n# BOM\n' >"$vault/$P/docs/bom.md"
stray "$P/tasks/EX-9.md" task
doc Example
chk "task-location: the offenders come sorted by path" task-location Example \
  "warn | 5 | a-first.md, docs/bom.md, docs/crlf.md, tasks/EX-9.md, zz/last.md"
out_has "task-location: a note with CRLF line endings is read" "docs/crlf.md"
out_has "task-location: a note that opens with a BOM is read" "docs/bom.md"
out_has "task-location: of two type lines the last one counts" "zz/last.md"
reset
stray "$P/docs/billing/notes.md" note
stray "$P/.trash/EX-8.md" task
stray "$P/docs/.drafts/EX-9.md" task
printf '%s\n' '# No frontmatter' '' 'type: task' >"$vault/$P/docs/plain.md"
printf '%s\n' '---' 'title: "A note"' '---' '' 'type: task' >"$vault/$P/docs/body.md"
printf '%s\n' '---' 'type:task' '---' '# No blank after the colon' >"$vault/$P/docs/nospace.md"
printf '%s\n' '---' 'type: task' '' '# The frontmatter never closes' >"$vault/$P/docs/open.md"
printf '%s\n' '---' 'type: task' 'type: note' '---' '# Two type lines' >"$vault/$P/docs/first.md"
sb scaffold project Child --path "$P/child" --keys CH
sb task new CH-1 --project Child --title "A task of the project inside"
stray "$P/child/docs/CH-2.md" task
doc
chk "task-location: another type, dot folders, body text and the tasks of a project inside are left alone" task-location Example "ok | 0 | -"
is "task-location: reading stops at the line that closes the frontmatter" "$(printf '%s\n' "$OUT" | grep -c 'docs/body.md' || true)" "0"
is "task-location: type:task with no blank is no property" "$(printf '%s\n' "$OUT" | grep -c 'docs/nospace.md' || true)" "0"
is "task-location: frontmatter that never closes holds no type" "$(printf '%s\n' "$OUT" | grep -c 'docs/open.md' || true)" "0"
is "task-location: a first type line gives way to a later one" "$(printf '%s\n' "$OUT" | grep -c 'docs/first.md' || true)" "0"
chk "task-location: the project inside gets its own misfiled task" task-location Child "warn | 1 | docs/CH-2.md"
chk "index: a project inside another is a row like any other" index vault "ok | 0 | -"
doc Example
chk "task-location: the project inside is left alone when the doctor is run for one project" task-location Example "ok | 0 | -"
fi

# ---------------------------------------------------------------- roots written another way
if block 9; then
set_root tasks_root '"."'
cp -R "$T/EX-1" "$vault/$P/EX-1"
rm "$vault/$P/README.md"
doc Example
chk "hubs: with the tasks at the project root, the project hub is one offender" hubs Example "warn | 1 | README.md"
chk "task-location: with that root a task folder at the project root is in its place, and the old ones are not" task-location Example \
  "warn | 3 | tasks/EX-1/README.md, tasks/EX-2/README.md, tasks/EX-3/README.md"
is "task-location: the fix names the project folder, with no dot part" "$(fix_of task-location)" \
  "move it with second-brain move to $P/<ID>/README.md, and tie it to its topic with a tag"
reset
set_root tasks_root ./tasks//
set_root topics_root tasks/
rm "$T/README.md"
stray "$P/docs/EX-9.md" task
doc Example
chk "hubs: two roots on one folder name its hub once" hubs Example "warn | 1 | tasks/README.md"
chk "task-location: a tasks root written with ./ and // is the same folder" task-location Example "warn | 1 | docs/EX-9.md"
is "task-location: the fix names that folder folded" "$(fix_of task-location)" \
  "move it with second-brain move to $P/tasks/<ID>/README.md, and tie it to its topic with a tag"
chk "board: the board is found under a root written that way" board Example "ok | 0 | -"
reset
if [ -d "$vault/PROJECTS" ]; then
  set_root tasks_root TASKS
  doc Example
  chk "task-location: where the file system ignores letter case, a tasks root in another case is the same folder" task-location Example "ok | 0 | -"
  reset
else
  printf 'skip  task-location: this file system tells TASKS from tasks\n'
fi
fi

# ---------------------------------------------------------------- task-layout
# layout <value>: set task_layout in the profile.
layout() { edit "$vault/$P/claude/profile.md" "s/^task_layout: .*/task_layout: $1/"; }
if block 105; then
doc Example
chk "task-layout: ok in a flat project" task-layout Example "ok | 0 | -"
mkdir -p "$T/archive/2025/EX-0"
sed 's/^  - EX-2$/  - EX-0/' "$T/EX-2/README.md" >"$T/archive/2025/EX-0/README.md"
doc Example
rc_is "task-layout: a warning leaves exit 0" 0
chk "task-layout: an archive folder in a flat project warns" task-layout Example "warn | 1 | archive:flat"
is "task-layout: the flat fix names both ways out" "$(fix_of task-layout)" \
  "set task_layout: archive in the profile, or move each task in $P/tasks/archive back to $P/tasks/<ID> with second-brain move"
chk "no-readme: the archive folder is no task folder, in a flat project too" no-readme Example "ok | 0 | -"
chk "task-location: an archived task is in its place, in a flat project too" task-location Example "ok | 0 | -"
cp "$T/EX-2/README.md" "$tmp/EX-2.before"
doc Example --fix
is "task-layout: --fix moves nothing in a flat project" "$(printf '%s\n' "$OUT" | head -1)/$(cmp -s "$tmp/EX-2.before" "$T/EX-2/README.md" && printf same)" \
  "fixed: nothing/same"
reset
layout archive
doc Example
chk "task-layout: a done task with no status note and no sprint is not due, as nothing dates it" task-layout Example "ok | 0 | -"
cp "$T/EX-2/README.md" "$tmp/EX-2.before"
doc Example --fix
is "task-layout --fix: a task it cannot date is not moved" "$(printf '%s\n' "$OUT" | head -1)/$(cmp -s "$tmp/EX-2.before" "$T/EX-2/README.md" && printf same)" \
  "fixed: nothing/same"
edit "$T/EX-2/README.md" 's/^## Status notes$/## Status notes\
\
**2025-12-01 - Closed/'
doc Example
chk "task-layout: a done task with an old status note is due" task-layout Example "warn | 1 | EX-2:to-archive"
edit "$T/EX-2/README.md" '/^\*\*2025-12-01 - Closed$/d'
is "task-layout: the archive fix names --fix and the way back" "$(fix_of task-layout)" \
  "run second-brain doctor --fix to archive each done task; an open task in the archive goes back to $P/tasks/<ID> with second-brain move, or is set done; archive_after_days is a whole number"
sb task note EX-2 "Done"
doc Example
chk "task-layout: a done task with a status note of today stays, 14 days by default" task-layout Example "ok | 0 | -"
edit "$T/EX-2/README.md" 's/^\*\*2026-01-10 /**2025-12-27 /'
doc Example
chk "task-layout: 14 days after its newest status note it is old enough" task-layout Example "warn | 1 | EX-2:to-archive"
edit "$T/EX-2/README.md" 's/^## Status notes$/## Status notes\
\
**2025-12-01 - An older note on top**/'
edit "$T/EX-2/README.md" 's/^\*\*2025-12-27 /**2025-12-28 /'
doc Example
chk "task-layout: the newest status note counts, wherever it is" task-layout Example "ok | 0 | -"
edit "$T/EX-2/README.md" 's/^\*\*2025-12-28 /**2025-12-02 /'
sb task set EX-2 sprint=2026-01-14
doc Example
chk "task-layout: a sprint id newer than every note counts" task-layout Example "ok | 0 | -"
edit "$vault/$P/claude/profile.md" 's/^archive_after_days: .*/archive_after_days: 0/'
doc Example
chk "task-layout: archive_after_days 0 still waits for the sprint's end" task-layout Example "ok | 0 | -"
sb task set EX-2 sprint=
sb task note EX-2 "Closed"
doc Example
chk "task-layout: archive_after_days 0 takes a task done today" task-layout Example "warn | 1 | EX-2:to-archive"
edit "$vault/$P/claude/profile.md" 's/^archive_after_days: .*/archive_after_days: two weeks/'
doc Example
chk "task-layout: a value that is no whole number warns, and 14 days count" task-layout Example "warn | 1 | archive_after_days:not-a-number"
edit "$vault/$P/claude/profile.md" '/^archive_after_days: /d'
sb task set EX-3 status=abandoned
sb task note EX-3 "Dropped"
edit "$T/EX-3/README.md" 's/^\*\*2026-01-10 /**2025-12-27 /'
doc Example
chk "task-layout: no key is 14 days, and an abandoned task is archived too" task-layout Example "warn | 1 | EX-3:to-archive"
reset
layout Archive
mkdir -p "$T/archive/2025"
sb task set EX-1 status=planned
sb task note EX-2 "Done"
mv "$T/EX-1" "$T/archive/2025/EX-1"
mkdir -p "$T/archive/2025/EX-9" "$T/archive/EX-8"
printf '%s\n' '---' 'type: task' '---' '' '# A task with no year' >"$T/archive/EX-8/README.md"
doc Example
chk "task-layout: an open task in the archive warns, the layout in any letter case" task-layout Example "warn | 1 | EX-1:open"
chk "no-readme: a folder in a year of the archive with no README warns" no-readme Example "warn | 1 | EX-9"
chk "task-location: a task in the archive with no year folder warns" task-location Example "warn | 1 | tasks/archive/EX-8/README.md"
rm -r "$T/archive/2025/EX-9" "$T/archive/EX-8"
edit "$T/EX-2/README.md" 's/^\*\*2026-01-10 /**2025-06-30 /'
cp "$T/EX-3/README.md" "$tmp/EX-3.before"
doc Example --fix
rc_is "task-layout --fix: exit 0" 0
is "task-layout --fix: one fixed line per archived task" "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-2 -> $P/tasks/archive/2026/EX-2/README.md (Example)"
exists "task-layout --fix: the task is in the archive, under the year of today" "$T/archive/2026/EX-2/README.md"
is "task-layout --fix: it went through task archive" "$(grep -c '^archived: "2026-01-10"$' "$T/archive/2026/EX-2/README.md")" "1"
exists "task-layout --fix: an open task in the archive is never moved" "$T/archive/2025/EX-1/README.md"
is "task-layout --fix: an open task outside it is never moved" "$(cmp -s "$tmp/EX-3.before" "$T/EX-3/README.md" && printf same)" "same"
chk "task-layout --fix: the open task is left to the user" task-layout Example "warn | 1 | EX-1:open"
doc Example --fix
is "task-layout --fix: nothing left to move" "$(printf '%s\n' "$OUT" | head -1)" "fixed: nothing"
reset
layout archive
sb task note EX-2 "Done"
edit "$T/EX-2/README.md" 's/^\*\*2026-01-10 /**2025-06-30 /'
mkdir -p "$T/archive/2026/EX-2"
doc Example --fix
is "task-layout --fix: a task whose destination folder exists is not moved" "$(printf '%s\n' "$OUT" | head -1)" "fixed: nothing"
case "$ERR" in *"the destination exists: $P/tasks/archive/2026/EX-2"*) pass "task-layout --fix: stderr says why" ;; *) fail "task-layout --fix: stderr says why" "in stderr: $ERR" ;; esac
is "task-layout --fix: the task stays in place, and the destination stays empty" \
  "$(ls "$T/EX-2")/$(ls -A "$T/archive/2026/EX-2")" "README.md/"
chk "task-layout --fix: the task is still named" task-layout Example "warn | 1 | EX-2:to-archive"
reset
outside_proj
layout archive
set_root tasks_root ../../../outside-proj/tasks
mkdir -p "$O/tasks/EX-2"
cp "$T/EX-2/README.md" "$O/tasks/EX-2/README.md"
doc Example --fix
is "task-layout --fix: nothing is moved through a tasks root that leaves the project" \
  "$(printf '%s\n' "$OUT" | head -1)/$(ls "$O/tasks" | tr '\n' ' ')" "fixed: nothing/EX-2 OUTMARK-1 tasks.base "
rm -r "$O/tasks/EX-2"
fi

# ---------------------------------------------------------------- task-layout, the status folders
# drift: print the rows of sb_doc_layout_drift for Example, as id, file under the tasks root and
# status, one blank apart.
drift() {
  (
    for f in "$here"/scripts/lib/*.sh; do . "$f"; done
    SB_ROOT="$vault"
    sb_doc_project Example "$P" EX
    sb_doc_layout_drift | while IFS=$'\t' read -r id file status; do
      printf '%s %s %s\n' "$id" "${file#"$T/"}" "$status"
    done
  )
}
if block 49; then
layout status
mkdir -p "$T/planned" "$T/in-progress"
mv "$T/EX-1" "$T/in-progress/EX-1"
mv "$T/EX-2" "$T/planned/EX-2"
mv "$T/EX-3" "$T/planned/EX-3"
doc Example
rc_is "task-layout: a warning in a status project leaves exit 0" 0
chk "task-layout: a done task in planned warns, as its id and status" task-layout Example "warn | 1 | EX-2:done"
is "task-layout: the status fix names --fix" "$(fix_of task-layout)" \
  "run second-brain doctor --fix to move each task to the folder of its status"
chk "no-readme: a status folder needs no README" no-readme Example "ok | 0 | -"
chk "task-location: a task in a status folder is in its place" task-location Example "ok | 0 | -"
is "task-layout: the drift is the id, the file and the status" "$(drift)" "EX-2 planned/EX-2/README.md done"
mv "$T/planned/EX-2" "$T/EX-2"
doc Example
chk "task-layout: a done task directly under the tasks root warns too" task-layout Example "warn | 1 | EX-2:done"
mkdir -p "$T/done/EX-9"
mv "$T/EX-2" "$T/done/EX-2"
doc Example
chk "task-layout: a task in the folder of its status is in its place" task-layout Example "ok | 0 | -"
chk "no-readme: a folder in a status folder with no README warns" no-readme Example "warn | 1 | EX-9"
rmdir "$T/done/EX-9"
edit "$T/planned/EX-3/README.md" '/^status: /d'
edit "$T/in-progress/EX-1/README.md" 's/^status: .*/status: blocked/'
mv "$T/in-progress/EX-1" "$T/done/EX-1"
doc Example
chk "task-layout: no row for a task with no status, or one outside the five" task-layout Example "ok | 0 | -"
chk "task-layout: needs-a-status names them" needs-a-status Example "warn | 2 | EX-3, EX-1:blocked"
is "task-layout: the drift names a task with no status of the five no-status" "$(drift)" \
  "EX-3 planned/EX-3/README.md no-status${NL}EX-1 done/EX-1/README.md no-status"
mkdir -p "$T/archive/2025"
doc Example
chk "task-layout: an archive that holds no task is not named" task-layout Example "ok | 0 | -"
mv "$T/done/EX-2" "$T/archive/2025/EX-2"
doc Example
chk "task-layout: a task in the archive warns, and so does the archive" task-layout Example "warn | 2 | EX-2:done, archive:status"
mv "$T/archive/2025/EX-2" "$T/done/EX-2"
mv "$T/planned/EX-3" "$T/archive/2025/EX-3"
doc Example
chk "task-layout: an archive that holds a task with no status warns alone" task-layout Example "warn | 1 | archive:status"
reset
mkdir -p "$T/planned" "$T/done"
mv "$T/EX-2" "$T/done/EX-2"
doc Example
chk "task-layout: a status folder that holds a task warns in a flat project, and an empty one does not" task-layout Example \
  "warn | 1 | done:flat"
is "task-layout: the fix names the status layout and the way back" "$(fix_of task-layout)" \
  "set task_layout: status in the profile, or move each task in <folder> back to $P/tasks/<ID> with second-brain move"
chk "no-readme: a status folder needs no README, in a flat project too" no-readme Example "ok | 0 | -"
chk "task-location: a task in a status folder is in its place, in a flat project too" task-location Example "ok | 0 | -"
is "task-layout: no drift in a flat project" "$(drift)" ""
mkdir -p "$T/archive/2025/EX-0"
sed 's/^  - EX-2$/  - EX-0/' "$T/done/EX-2/README.md" >"$T/archive/2025/EX-0/README.md"
doc Example
chk "task-layout: the archive and a status folder share one row" task-layout Example "warn | 2 | archive:flat, done:flat"
is "task-layout: the fix holds both" "$(fix_of task-layout)" \
  "set task_layout: archive in the profile, or move each task in $P/tasks/archive back to $P/tasks/<ID> with second-brain move; set task_layout: status in the profile, or move each task in <folder> back to $P/tasks/<ID> with second-brain move"
rm -r "$T/archive"
layout archive
mkdir -p "$T/in-progress"
mv "$T/EX-1" "$T/in-progress/EX-1"
doc Example
chk "task-layout: each status folder that holds a task warns in an archive project" task-layout Example \
  "warn | 2 | in-progress:archive, done:archive"
is "task-layout: the fix names the status layout and the way back, in an archive project" "$(fix_of task-layout)" \
  "set task_layout: status in the profile, or move each task in <folder> back to $P/tasks/<ID> with second-brain move"
fi

# ---------------------------------------------------------------- task-layout --fix, the status folders
# A flat project with an archive, left from the time it archived tasks, turned status. The links
# between the tasks lead into the archive and out of it.
if block 65; then
layout archive
sb task new EX-4 --project Example --title "Fourth task"
sb task set EX-4 status=abandoned
sb task dep EX-3 add EX-2
sb task dep EX-1 add EX-4
SECOND_BRAIN_TODAY=2025-12-20 sb task archive EX-4
sb task archive EX-2
layout flat
doc Example
chk "task-layout --fix: the setup is a flat project with an archive" task-layout Example "warn | 1 | archive:flat"
layout status
doc Example --fix
rc_is "task-layout --fix: exit 0 in a project turned status" 0
is "task-layout --fix: one fixed line per task moved, archived ones included, then one per archive folder removed" \
  "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-1 -> $P/tasks/in-progress/EX-1/README.md (Example)
fixed: EX-3 -> $P/tasks/planned/EX-3/README.md (Example)
fixed: EX-4 -> $P/tasks/abandoned/EX-4/README.md (Example)
fixed: EX-2 -> $P/tasks/done/EX-2/README.md (Example)
fixed: $P/tasks/archive/2025 -> removed (Example)
fixed: $P/tasks/archive/2026 -> removed (Example)
fixed: $P/tasks/archive -> removed (Example)"
is "task-layout --fix: every task is in the folder of its status, and the archive is gone" \
  "$(LC_ALL=C ls "$T" | tr '\n' ' ')/$(cd "$T" && LC_ALL=C ls -d -- */*/README.md | tr '\n' ' ')" \
  "README.md abandoned done in-progress planned tasks.base /abandoned/EX-4/README.md done/EX-2/README.md in-progress/EX-1/README.md planned/EX-3/README.md "
is "task-layout --fix: a task out of the archive loses its archived key" \
  "$(cat "$T/done/EX-2/README.md" "$T/abandoned/EX-4/README.md" | grep -c '^archived:' || true)" "0"
is "task-layout --fix: the links follow the moves" \
  "$(grep -h -e 'done/EX-2/README|EX-2' -e 'abandoned/EX-4/README|EX-4' "$T/planned/EX-3/README.md" "$T/in-progress/EX-1/README.md" | wc -l | tr -d ' ')" "2"
doc Example
chk "task-layout --fix: the next doctor shows task-layout ok" task-layout Example "ok | 0 | -"
sb unresolved Example
is "task-layout --fix: unresolved lists nothing" "$RC/$OUT" "0/"
doc Example --fix
is "task-layout --fix: nothing left to move or remove" "$(printf '%s\n' "$OUT" | grep '^fixed: ')" "fixed: nothing"
reset
# A task with no status, and one whose destination is taken, stay where they are. A year folder
# that holds a task, and an archive that holds a README, stay; an empty year folder goes.
layout status
edit "$T/EX-3/README.md" '/^status: /d'
mkdir -p "$T/archive/2025" "$T/archive/2026" "$T/done/EX-2"
mv "$T/EX-2" "$T/archive/2025/EX-2"
printf '%s\n' '# The archive' >"$T/archive/README.md"
doc Example --fix
rc_is "task-layout --fix: a task it cannot move leaves exit 0" 0
is "task-layout --fix: the task it can move, and the emptied year folder, are fixed" \
  "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-1 -> $P/tasks/in-progress/EX-1/README.md (Example)
fixed: $P/tasks/archive/2026 -> removed (Example)"
case "$ERR" in *"EX-3 has no status of the five: left where it is"*) pass "task-layout --fix: stderr names the task with no status" ;;
  *) fail "task-layout --fix: stderr names the task with no status" "in stderr: $ERR" ;; esac
case "$ERR" in *"the destination exists: $P/tasks/done/EX-2"*) pass "task-layout --fix: stderr names the taken destination" ;;
  *) fail "task-layout --fix: stderr names the taken destination" "in stderr: $ERR" ;; esac
exists "task-layout --fix: the task with no status stays where it is" "$T/EX-3/README.md"
is "task-layout --fix: the task whose destination is taken stays, and the destination stays empty" \
  "$(ls "$T/archive/2025/EX-2")/$(ls -A "$T/done/EX-2")" "README.md/"
is "task-layout --fix: the year folder that holds a task and the archive that holds a README stay" \
  "$(ls "$T/archive" | tr '\n' ' ')" "2025 README.md "
chk "task-layout --fix: the task it could not move is still named" task-layout Example "warn | 2 | EX-2:done, archive:status"
reset
# The same id in the folder of its status and in the archive: the lookup refuses it, and nothing is
# said to be fixed for it.
layout status
mkdir -p "$T/done" "$T/archive/2025"
mv "$T/EX-2" "$T/done/EX-2"
cp -R "$T/done/EX-2" "$T/archive/2025/EX-2"
cp "$T/done/EX-2/README.md" "$tmp/EX-2.before"
doc Example --fix
rc_is "task-layout --fix: an id held by two folders leaves exit 0" 0
is "task-layout --fix: no fixed line for an id held by two folders" "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-1 -> $P/tasks/in-progress/EX-1/README.md (Example)
fixed: EX-3 -> $P/tasks/planned/EX-3/README.md (Example)"
case "$ERR" in *"several tasks match EX-2"*) pass "task-layout --fix: stderr says the id is held by two folders" ;;
  *) fail "task-layout --fix: stderr says the id is held by two folders" "in stderr: $ERR" ;; esac
is "task-layout --fix: the copy stays in the archive, and the task in its folder is unchanged" \
  "$(ls "$T/archive/2025/EX-2")/$(cmp -s "$tmp/EX-2.before" "$T/done/EX-2/README.md" && printf same)" "README.md/same"
chk "task-layout --fix: the copy in the archive is still named" task-layout Example "warn | 2 | EX-2:done, archive:status"
reset
# A fix from a sprint folder and backlog/ in a status project: each task goes to the folder of its
# status, then each empty group folder other than the five status folders goes, so no-readme names
# none. An empty status folder is the layout's own, and stays.
layout status
mkdir -p "$T/planned" "$T/in-review" "$T/backlog" "$T/2026-01-14"
mv "$T/EX-1" "$T/2026-01-14/EX-1"
mv "$T/EX-2" "$T/backlog/EX-2"
mv "$T/EX-3" "$T/planned/EX-3"
doc Example
chk "task-layout --fix: the setup is a status project with tasks in backlog/ and a sprint folder" task-layout Example \
  "warn | 4 | EX-2:done, EX-1:in-progress, backlog:status, 2026-01-14:status"
doc Example --fix
rc_is "task-layout --fix: exit 0 with tasks in backlog/ and a sprint folder of a status project" 0
is "task-layout --fix: in a status project the folders the moves leave empty, backlog/ and a sprint folder, are removed" \
  "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-2 -> $P/tasks/done/EX-2/README.md (Example)
fixed: EX-1 -> $P/tasks/in-progress/EX-1/README.md (Example)
fixed: $P/tasks/backlog -> removed (Example)
fixed: $P/tasks/2026-01-14 -> removed (Example)"
is "task-layout --fix: in a status project an empty status folder stays" "$(LC_ALL=C ls "$T" | tr '\n' ' ')" \
  "README.md done in-progress in-review planned tasks.base "
chk "task-layout --fix: a fix from a sprint folder in a status project leaves no no-readme row" no-readme Example "ok | 0 | -"
chk "task-layout --fix: and task-layout ok" task-layout Example "ok | 0 | -"
fi

# ---------------------------------------------------------------- task-layout, the sprint folders
# set_pattern <raw value>: write the profile's sprint_folder key, under task_layout, as it is given.
set_pattern() {
  SB_V="$1" awk '!/^sprint_folder:/ { print } /^task_layout:/ { print "sprint_folder: " ENVIRON["SB_V"] }' \
    "$vault/$P/claude/profile.md" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$vault/$P/claude/profile.md"
}
# EX-1 is in sprint 2026-01-14; EX-2 and EX-3 are in none.
if block 111; then
layout sprint
mkdir -p "$T/backlog" "$T/2026-01-14"
mv "$T/EX-1" "$T/2026-01-14/EX-1"
mv "$T/EX-2" "$T/backlog/EX-2"
mv "$T/EX-3" "$T/backlog/EX-3"
doc Example
chk "task-layout: in a sprint project a task in its sprint's folder, or in backlog/ with none, is in its place" task-layout Example \
  "ok | 0 | -"
is "task-layout: no sprint drift when every task is in its place" "$(drift)" ""
mkdir -p "$T/2026-11-20"
doc Example
chk "no-readme: in a sprint project backlog/, a sprint folder that holds a task and an empty one need no README" \
  no-readme Example "ok | 0 | -"
mkdir -p "$T/backlog/EX-8" "$T/2026-01-14/EX-9"
doc Example
chk "no-readme: in a sprint project a folder in backlog/ or in a sprint folder with no README warns" no-readme Example \
  "warn | 2 | EX-8, EX-9"
rmdir "$T/backlog/EX-8" "$T/2026-01-14/EX-9" "$T/2026-11-20"
edit "$T/2026-01-14/EX-1/README.md" 's/^sprint: .*/sprint: "2026-12-04"/'
mv "$T/2026-01-14/EX-1" "$T/backlog/EX-1"
doc Example
chk "task-layout: <ID>:<folder>, a task with sprint 2026-12-04 left in backlog/ warns as its id and that sprint's folder" \
  task-layout Example "warn | 1 | EX-1:2026-12-04"
is "task-layout: the sprint fix names --fix" "$(fix_of task-layout)" \
  "run second-brain doctor --fix to move each task to the folder of its sprint, or to backlog/ with no sprint"
is "task-layout: the sprint drift is the id, the file and the folder it belongs in" "$(drift)" \
  "EX-1 backlog/EX-1/README.md 2026-12-04"
mkdir -p "$T/2026-12-04"
mv "$T/backlog/EX-1" "$T/2026-12-04/EX-1"
mv "$T/backlog/EX-2" "$T/2026-12-04/EX-2"
doc Example
chk "task-layout: <ID>:backlog, a task with no sprint in a sprint folder warns as its id and backlog" task-layout Example \
  "warn | 1 | EX-2:backlog"
mkdir -p "$T/planned" "$T/archive/2025"
mv "$T/2026-12-04/EX-1" "$T/EX-1"
mv "$T/backlog/EX-3" "$T/planned/EX-3"
mv "$T/2026-12-04/EX-2" "$T/archive/2025/EX-2"
doc Example
chk "task-layout: a task at the tasks root, in a status folder or in the archive warns, and no folder does" task-layout Example \
  "warn | 3 | EX-1:2026-12-04, EX-3:backlog, EX-2:backlog"
is "task-layout: the drift names each, with the folder it belongs in" "$(drift)" \
  "EX-1 EX-1/README.md 2026-12-04${NL}EX-3 planned/EX-3/README.md backlog${NL}EX-2 archive/2025/EX-2/README.md backlog"
reset
# A renamed pattern: <n> of sprint 2026-01-14 is 1, as no note is earlier.
layout sprint
set_pattern '"sprint-<n>"'
mkdir -p "$T/backlog" "$T/2026-01-14"
mv "$T/EX-1" "$T/2026-01-14/EX-1"
mv "$T/EX-2" "$T/backlog/EX-2"
mv "$T/EX-3" "$T/backlog/EX-3"
doc Example
rc_is "task-layout: a warning in a sprint project leaves exit 0" 0
chk "task-layout: with a renamed pattern a task in its sprint's old folder warns as the folder the pattern gives" task-layout Example \
  "warn | 1 | EX-1:sprint-1"
mkdir -p "$T/sprint-1"
mv "$T/2026-01-14/EX-1" "$T/sprint-1/EX-1"
doc Example
chk "task-layout: in the folder the renamed pattern gives it is in its place" task-layout Example "ok | 0 | -"
set_pattern '"Sprint <n>"'
doc Example
chk "task-layout: sprint_folder:invalid, a pattern that gives no folder name warns, and no task of that sprint is named" \
  task-layout Example "warn | 1 | sprint_folder:invalid"
is "task-layout: the pattern fix names the key" "$(fix_of task-layout)" \
  "set sprint_folder in the profile to a pattern with <end>, <start> or <n> that gives a folder name"
is "task-layout: no drift row for a task whose sprint gives no folder" "$(drift)" ""
mv "$T/backlog/EX-2" "$T/sprint-1/EX-2"
doc Example
chk "task-layout: sprint_folder:invalid comes first, and the other tasks are still named" task-layout Example \
  "warn | 2 | sprint_folder:invalid, EX-2:backlog"
is "task-layout: the fix holds both" "$(fix_of task-layout)" \
  "set sprint_folder in the profile to a pattern with <end>, <start> or <n> that gives a folder name; run second-brain doctor --fix to move each task to the folder of its sprint, or to backlog/ with no sprint"
mv "$T/sprint-1/EX-2" "$T/backlog/EX-2"
edit "$T/sprint-1/EX-1/README.md" 's/^sprint: .*/sprint: ""/'
mv "$T/sprint-1/EX-1" "$T/backlog/EX-1"
set_pattern '"sprint"'
doc Example
chk "task-layout: sprint_folder:invalid, a pattern with no placeholder warns with no task in a sprint" task-layout Example \
  "warn | 1 | sprint_folder:invalid"
set_pattern '"sprint-<n>"'
doc Example
chk "task-layout: a valid pattern with no task in a sprint is ok" task-layout Example "ok | 0 | -"
reset
# task_layout: sprint with sprints off is the flat layout.
layout sprint
edit "$vault/$P/claude/profile.md" 's/^uses_sprints: .*/uses_sprints: false/'
doc Example
rc_is "task-layout: task_layout:no-sprints leaves exit 0" 0
chk "task-layout: task_layout:no-sprints, task_layout: sprint with uses_sprints: false warns" task-layout Example \
  "warn | 1 | task_layout:no-sprints"
is "task-layout: the no-sprints fix names both keys" "$(fix_of task-layout)" \
  "set uses_sprints: true in the profile, or another task_layout"
is "task-layout: no sprint drift with sprints off" "$(drift)" ""
mkdir -p "$T/backlog"
mv "$T/EX-2" "$T/backlog/EX-2"
doc Example
chk "task-layout: with sprints off a task in backlog/ warns as backlog:flat, after task_layout:no-sprints" task-layout Example \
  "warn | 2 | task_layout:no-sprints, backlog:flat"
is "task-layout: the fix with sprints off names the sprint keys alone" "$(fix_of task-layout)" \
  "set uses_sprints: true in the profile, or another task_layout"
reset
# The group folders of the other layouts.
mkdir -p "$T/backlog"
doc Example
chk "task-layout: an empty backlog/ in a flat project is not named" task-layout Example "ok | 0 | -"
chk "no-readme: backlog/ needs no README, empty, in a flat project too" no-readme Example "ok | 0 | -"
mv "$T/EX-2" "$T/backlog/EX-2"
doc Example
chk "task-layout: backlog:flat, a task moved by hand into backlog/ in a flat project warns" task-layout Example \
  "warn | 1 | backlog:flat"
is "task-layout: the backlog fix names the sprint layout and the way back" "$(fix_of task-layout)" \
  "set task_layout: sprint in the profile, or move each task in <folder> back to $P/tasks/<ID> with second-brain move"
is "task-layout: no drift for backlog/ in a flat project" "$(drift)" ""
chk "no-readme: backlog/ holding a task in a flat project is task-layout's alone" no-readme Example "ok | 0 | -"
edit "$vault/$P/claude/profile.md" 's/^uses_sprints: .*/uses_sprints: false/'
doc Example
chk "task-layout: with sprints off a task in backlog/ of a flat project still warns backlog:flat" task-layout Example \
  "warn | 1 | backlog:flat"
is "task-layout: with sprints off the way to the sprint layout turns sprints on too" "$(fix_of task-layout)" \
  "set uses_sprints: true and task_layout: sprint in the profile, or move each task in <folder> back to $P/tasks/<ID> with second-brain move"
layout archive
doc Example
chk "task-layout: with sprints off a task in backlog/ of an archive project warns backlog:archive" task-layout Example \
  "warn | 1 | backlog:archive"
is "task-layout: and its way to the sprint layout turns sprints on too" "$(fix_of task-layout)" \
  "set uses_sprints: true and task_layout: sprint in the profile, or move each task in <folder> back to $P/tasks/<ID> with second-brain move"
layout flat
edit "$vault/$P/claude/profile.md" 's/^uses_sprints: .*/uses_sprints: true/'
mv "$T/backlog/EX-2" "$T/EX-2"
mkdir -p "$T/planned"
mv "$T/EX-3" "$T/planned/EX-3"
doc Example
chk "task-layout: planned:flat, a task in planned/ in a flat project warns" task-layout Example "warn | 1 | planned:flat"
mkdir -p "$T/sprint-12" "$T/2026-01-14"
mv "$T/EX-1" "$T/sprint-12/EX-1"
mv "$T/EX-2" "$T/backlog/EX-2"
doc Example
chk "task-layout: a status folder, backlog/ and a sprint folder each warn in a flat project, in that order, and an empty one does not" \
  task-layout Example "warn | 3 | planned:flat, backlog:flat, sprint-12:flat"
is "task-layout: the fix names the status layout and the sprint layout" "$(fix_of task-layout)" \
  "set task_layout: status in the profile, or move each task in <folder> back to $P/tasks/<ID> with second-brain move; set task_layout: sprint in the profile, or move each task in <folder> back to $P/tasks/<ID> with second-brain move"
chk "no-readme: in a flat project a group folder that holds a task needs no README, and an empty one is still named" \
  no-readme Example "warn | 1 | 2026-01-14"
layout archive
doc Example
chk "task-layout: in an archive project backlog/ and a sprint folder warn as <folder>:archive" task-layout Example \
  "warn | 3 | planned:archive, backlog:archive, sprint-12:archive"
reset
layout status
mkdir -p "$T/in-progress" "$T/planned" "$T/backlog"
mv "$T/EX-1" "$T/in-progress/EX-1"
mv "$T/EX-2" "$T/backlog/EX-2"
mv "$T/EX-3" "$T/planned/EX-3"
doc Example
chk "task-layout: in a status project backlog/ holding a task warns as backlog:status, after the task" task-layout Example \
  "warn | 2 | EX-2:done, backlog:status"
is "task-layout: the status fix is unchanged" "$(fix_of task-layout)" \
  "run second-brain doctor --fix to move each task to the folder of its status"
fi

# ---------------------------------------------------------------- task-layout --fix, the sprint folders
# A fix from a flat project: one with sprints and an archive, left from the time it archived tasks,
# switched to task_layout: sprint. EX-1 is in sprint 2026-01-14; EX-2, archived, and EX-3 are in
# none. The links between the tasks lead into the archive and out of it.
if block 122; then
layout archive
sb task dep EX-3 add EX-1
sb task dep EX-1 add EX-2
sb task archive EX-2
layout flat
doc Example
chk "task-layout --fix: the sprint setup is a flat project with an archive" task-layout Example "warn | 1 | archive:flat"
layout sprint
doc Example
chk "task-layout --fix: switched to the sprint layout, each task warns with the folder it belongs in" task-layout Example \
  "warn | 3 | EX-1:2026-01-14, EX-3:backlog, EX-2:backlog"
doc Example --fix
rc_is "task-layout --fix: exit 0 in a flat project switched to the sprint layout" 0
is "task-layout --fix: a fix from a flat project prints one fixed line per task moved, then one per folder removed" \
  "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-1 -> $P/tasks/2026-01-14/EX-1/README.md (Example)
fixed: EX-3 -> $P/tasks/backlog/EX-3/README.md (Example)
fixed: EX-2 -> $P/tasks/backlog/EX-2/README.md (Example)
fixed: $P/tasks/archive/2026 -> removed (Example)
fixed: $P/tasks/archive -> removed (Example)"
is "task-layout --fix: a task with a sprint is in its sprint's folder, every other in backlog/, and the archive is gone" \
  "$(LC_ALL=C ls "$T" | tr '\n' ' ')/$(cd "$T" && LC_ALL=C ls -d -- */*/README.md | tr '\n' ' ')" \
  "2026-01-14 README.md backlog tasks.base /2026-01-14/EX-1/README.md backlog/EX-2/README.md backlog/EX-3/README.md "
is "task-layout --fix: a task out of the archive loses its archived key, in the sprint layout too" \
  "$(grep -c '^archived:' "$T/backlog/EX-2/README.md" || true)" "0"
is "task-layout --fix: the links follow the moves to the sprint folders" \
  "$(grep -h -e '2026-01-14/EX-1/README|EX-1' -e 'backlog/EX-2/README|EX-2' "$T/backlog/EX-3/README.md" "$T/2026-01-14/EX-1/README.md" | wc -l | tr -d ' ')" "2"
doc Example
chk "task-layout --fix: after a fix from a flat project the next doctor shows task-layout ok" task-layout Example "ok | 0 | -"
sb unresolved Example
is "task-layout --fix: after the sprint moves unresolved lists nothing" "$RC/$OUT" "0/"
doc Example --fix
is "task-layout --fix: in the sprint layout nothing is left to move or remove" "$(printf '%s\n' "$OUT" | grep '^fixed: ')" "fixed: nothing"
reset
# A fix from a status project switched to task_layout: sprint: every status folder goes, in-review/
# too, left empty by an earlier status move, and compare lists the moved paths alone.
layout status
doc Example --fix
sb task set EX-3 status=in-review
sb task set EX-3 status=planned
doc Example
chk "task-layout --fix: the status setup is in its place, with in-review/ left empty" task-layout Example "ok | 0 | -"
is "task-layout --fix: the status setup has its folders" "$(LC_ALL=C ls "$T" | tr '\n' ' ')" \
  "README.md done in-progress in-review planned tasks.base "
sb snapshot before-sprint
rc_is "task-layout --fix: a snapshot is taken before the fix" 0
layout sprint
doc Example --fix
rc_is "task-layout --fix: exit 0 in a status project switched to the sprint layout" 0
is "task-layout --fix: a fix from a status project moves each task, then removes each status folder" \
  "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-3 -> $P/tasks/backlog/EX-3/README.md (Example)
fixed: EX-1 -> $P/tasks/2026-01-14/EX-1/README.md (Example)
fixed: EX-2 -> $P/tasks/backlog/EX-2/README.md (Example)
fixed: $P/tasks/planned -> removed (Example)
fixed: $P/tasks/in-progress -> removed (Example)
fixed: $P/tasks/in-review -> removed (Example)
fixed: $P/tasks/done -> removed (Example)"
is "task-layout --fix: no status folder is left" "$(LC_ALL=C ls "$T" | tr '\n' ' ')" "2026-01-14 README.md backlog tasks.base "
sb compare before-sprint
rc_is "task-layout --fix: compare exits 1, as the moves differ" 1
is "task-layout --fix: compare with a snapshot taken before lists only the moves, each alias removed at its old path and added at its new" \
  "$OUT" "snapshot: .second-brain/snapshots/before-sprint
aliases added:
  EX-1	$P/tasks/2026-01-14/EX-1/README.md
  EX-2	$P/tasks/backlog/EX-2/README.md
  EX-3	$P/tasks/backlog/EX-3/README.md
aliases removed:
  EX-1	$P/tasks/in-progress/EX-1/README.md
  EX-2	$P/tasks/done/EX-2/README.md
  EX-3	$P/tasks/planned/EX-3/README.md"
doc Example
chk "task-layout --fix: after a fix from a status project the next doctor shows task-layout ok" task-layout Example "ok | 0 | -"
reset
# A renamed pattern: each task moves to the folder its sprint's new name gives, and the folder of
# the old name, emptied, goes. backlog/, which still holds tasks, stays.
layout sprint
mkdir -p "$T/backlog" "$T/2026-01-14"
mv "$T/EX-1" "$T/2026-01-14/EX-1"
mv "$T/EX-2" "$T/backlog/EX-2"
mv "$T/EX-3" "$T/backlog/EX-3"
set_pattern '"sprint-<n>"'
doc Example
chk "task-layout --fix: the renamed pattern names the task of the old folder" task-layout Example "warn | 1 | EX-1:sprint-1"
doc Example --fix
rc_is "task-layout --fix: exit 0 with a renamed pattern" 0
is "task-layout --fix: a renamed pattern moves the task to the folder of the new name, and removes the old one" \
  "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-1 -> $P/tasks/sprint-1/EX-1/README.md (Example)
fixed: $P/tasks/2026-01-14 -> removed (Example)"
is "task-layout --fix: with a renamed pattern the old folder is gone and backlog/ stays" \
  "$(LC_ALL=C ls "$T" | tr '\n' ' ')/$(ls "$T/backlog" | tr '\n' ' ')" "README.md backlog sprint-1 tasks.base /EX-2 EX-3 "
doc Example
chk "task-layout --fix: after a renamed pattern's fix the next doctor shows task-layout ok" task-layout Example "ok | 0 | -"
reset
# A taken destination: that task stays where it is, with the reason on stderr; the others still
# move, and the folder they empty goes. The folder that holds the destination is not empty, and stays.
layout sprint
mkdir -p "$T/planned" "$T/2026-01-14/EX-1"
mv "$T/EX-3" "$T/planned/EX-3"
cp "$T/EX-1/README.md" "$tmp/EX-1.before"
doc Example --fix
rc_is "task-layout --fix: a task whose sprint folder destination is taken leaves exit 0" 0
is "task-layout --fix: the tasks it can move, and the folder they empty, are fixed" \
  "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-2 -> $P/tasks/backlog/EX-2/README.md (Example)
fixed: EX-3 -> $P/tasks/backlog/EX-3/README.md (Example)
fixed: $P/tasks/planned -> removed (Example)"
case "$ERR" in *"the destination exists: $P/tasks/2026-01-14/EX-1"*) pass "task-layout --fix: stderr names the taken sprint folder destination" ;;
  *) fail "task-layout --fix: stderr names the taken sprint folder destination" "in stderr: $ERR" ;; esac
is "task-layout --fix: the task whose destination is taken stays unchanged, and the destination stays empty" \
  "$(cmp -s "$tmp/EX-1.before" "$T/EX-1/README.md" && printf same)/$(ls -A "$T/2026-01-14/EX-1")" "same/"
chk "task-layout --fix: the task it could not move is still named" task-layout Example "warn | 1 | EX-1:2026-01-14"
# A sprint folder that is a task, one with a README of its own, is taken too.
rmdir "$T/2026-01-14/EX-1" "$T/2026-01-14"
mkdir -p "$T/sprint-1"
sed 's/^  - EX-2$/  - sprint-1/' "$T/backlog/EX-2/README.md" >"$T/sprint-1/README.md"
set_pattern '"sprint-<n>"'
doc Example
chk "task-layout --fix: the setup has a task whose folder is the sprint folder" task-layout Example \
  "warn | 2 | EX-1:sprint-1, sprint-1:backlog"
cp "$T/sprint-1/README.md" "$tmp/sprint-1.before"
doc Example --fix
case "$ERR" in *"the sprint folder is a task: $P/tasks/sprint-1"*) pass "task-layout --fix: stderr says the sprint folder is a task" ;;
  *) fail "task-layout --fix: stderr says the sprint folder is a task" "in stderr: $ERR" ;; esac
is "task-layout --fix: the task in the way still moves to backlog/, and nothing is moved inside it" \
  "$(printf '%s\n' "$OUT" | grep '^fixed: ')/$(cmp -s "$tmp/sprint-1.before" "$T/backlog/sprint-1/README.md" && printf same)/$(cmp -s "$tmp/EX-1.before" "$T/EX-1/README.md" && printf same)" \
  "fixed: sprint-1 -> $P/tasks/backlog/sprint-1/README.md (Example)/same/same"
doc Example --fix
is "task-layout --fix: once the folder is free, the next fix moves the task into it" "$(printf '%s\n' "$OUT" | grep '^fixed: ')" \
  "fixed: EX-1 -> $P/tasks/sprint-1/EX-1/README.md (Example)"
fi

# ---------------------------------------------------------------- task-layout, the child folders
# A child task, one whose epic names another task, belongs inside a folder named for its parent, in
# the folder of its own status or sprint. EX-2 and EX-3 are made children of EX-1 while the project
# is flat, where the epic moves nothing.
# fixed_moves: the fixed: lines of the last run that move a task or remove a folder.
fixed_moves() { printf '%s\n' "$OUT" | grep '^fixed: ' | grep -v ' -> status/' || true; }
# set_key <file> <key> <value>: write one frontmatter key by hand, as an edit in Obsidian does.
set_key() { edit "$1" "s/^$2: .*/$2: $3/"; }
if block 163; then
sb task alias EX-1 add "First of all"
sb task set EX-2 epic=EX-1
sb task set EX-3 epic="first OF all"
rc_is "children: an epic that names the parent by an alias is written in a flat project" 0
exists "children: in a flat project the child stays at the tasks root" "$T/EX-3/README.md"
doc Example
chk "children: a flat project does not ask for the child folders" task-layout Example "ok | 0 | -"
layout status
doc Example
chk "children: in a status project a child warns with its parent's folder in the folder of its status" task-layout Example \
  "warn | 3 | EX-1:in-progress, EX-2:done/EX-1, EX-3:planned/EX-1"
is "children: the status fix says --fix puts a child inside its parent's folder" "$(fix_of task-layout)" \
  "run second-brain doctor --fix to move each task to the folder of its status, each child inside its epic's folder there"
is "children: the drift names the folder named for the parent" "$(drift)" \
  "EX-1 EX-1/README.md in-progress${NL}EX-2 EX-2/README.md done/EX-1${NL}EX-3 EX-3/README.md planned/EX-1"
doc Example --fix
rc_is "children --fix: exit 0 in a status project" 0
is "children --fix: the parent, then each child into a folder named for it" "$(fixed_moves)" \
  "fixed: EX-1 -> $P/tasks/in-progress/EX-1/README.md (Example)
fixed: EX-2 -> $P/tasks/done/EX-1/EX-2/README.md (Example)
fixed: EX-3 -> $P/tasks/planned/EX-1/EX-3/README.md (Example)"
doc Example
chk "children --fix: then task-layout is ok" task-layout Example "ok | 0 | -"
chk "children --fix: no-readme takes the folders named for the parent, which hold tasks" no-readme Example "ok | 0 | -"
chk "children --fix: task-location takes a child one level deeper" task-location Example "ok | 0 | -"
chk "children --fix: the template's board takes a child" board Example "ok | 0 | -"
sb find EX-3
is "children --fix: find sees the child" "$OUT" "$P/tasks/planned/EX-1/EX-3/README.md"
sb board Example All
is "children --fix: the board lists each task" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | sort | tr '\n' ' ')" "EX-1 EX-2 EX-3 "
sb unresolved Example
is "children --fix: unresolved lists nothing" "$RC/$OUT" "0/"
# A child in each status folder: a status edited by hand names the child, and --fix moves it into a
# folder named for its parent there, removing the one it leaves when that holds nothing more.
prev=planned
for s in in-progress in-review done abandoned planned; do
  f="$(ls "$T"/*/EX-1/EX-3/README.md)"
  set_key "$f" status "$s"
  doc Example
  chk "children: a child set $s by hand warns as $s/EX-1" task-layout Example "warn | 1 | EX-3:$s/EX-1"
  doc Example --fix
  want="fixed: EX-3 -> $P/tasks/$s/EX-1/EX-3/README.md (Example)"
  # planned/EX-1, in-review/EX-1 and abandoned/EX-1 held the child alone; in-progress/EX-1 is the
  # parent's own folder, and done/EX-1 still holds EX-2.
  case "$prev" in planned | in-review | abandoned) want="$want${NL}fixed: $P/tasks/$prev/EX-1 -> removed (Example)" ;; esac
  is "children --fix: the child in $prev/ goes into $s/EX-1/" "$(fixed_moves)" "$want"
  doc Example
  chk "children --fix: then the child in $s/EX-1/ is in its place" task-layout Example "ok | 0 | -"
  chk "children --fix: and no-readme names nothing in $s/" no-readme Example "ok | 0 | -"
  prev="$s"
done
# A parent whose status changes by hand moves its own files alone, and leaves its children where
# they are: done/EX-1 holds its done child already, and takes the parent's README beside it.
set_key "$T/in-progress/EX-1/README.md" status done
doc Example
chk "children: a parent set done by hand warns as its id and status" task-layout Example "warn | 1 | EX-1:done"
doc Example --fix
is "children --fix: the parent moves into the folder that holds its done child" "$(fixed_moves)" \
  "fixed: EX-1 -> $P/tasks/done/EX-1/README.md (Example)"
is "children --fix: done/EX-1 holds the parent's README and its done child" "$(ls "$T/done/EX-1" | tr '\n' ' ')" "EX-2 README.md "
is "children --fix: the folder the parent left is gone" "$([ -e "$T/in-progress/EX-1" ] && printf there || printf gone)" "gone"
exists "children --fix: its planned child stays where it was" "$T/planned/EX-1/EX-3/README.md"
doc Example
chk "children --fix: then task-layout is ok with the parent done" task-layout Example "ok | 0 | -"
# A parent abandoned with an open child: its own files move, and its children stay.
set_key "$T/done/EX-1/README.md" status abandoned
doc Example --fix
is "children --fix: the abandoned parent moves its own files alone" "$(fixed_moves)" \
  "fixed: EX-1 -> $P/tasks/abandoned/EX-1/README.md (Example)"
is "children --fix: done/EX-1 keeps the done child, and no README" "$(ls "$T/done/EX-1" | tr '\n' ' ')" "EX-2 "
doc Example
chk "children --fix: the abandoned parent's open child is still in its place" task-layout Example "ok | 0 | -"
chk "children --fix: and needs no README for the folder it is in" no-readme Example "ok | 0 | -"
sb task head EX-3
is "children --fix: task head still reads the open child" "$(printf '%s\n' "$OUT" | grep '^path: ')" "path: $P/tasks/planned/EX-1/EX-3/README.md"
sb unresolved Example
is "children --fix: unresolved lists nothing after the parent's moves" "$RC/$OUT" "0/"
# A task that is no child, in a folder named for another task, belongs directly in its folder.
set_key "$T/done/EX-1/EX-2/README.md" epic '"-"'
doc Example
chk "children: a task that is no child, one level deeper, warns as its status" task-layout Example "warn | 1 | EX-2:done"
doc Example --fix
is "children --fix: it moves out, and the folder it leaves empty goes" "$(fixed_moves)" \
  "fixed: EX-2 -> $P/tasks/done/EX-2/README.md (Example)
fixed: $P/tasks/done/EX-1 -> removed (Example)"
# no-readme reads a folder that holds tasks one level deeper; an empty one stays its finding.
mkdir -p "$T/planned/EX-1/EX-9" "$T/in-review/EX-8"
doc Example
chk "no-readme: a folder with no README in a folder that holds tasks warns, and so does an empty one" no-readme Example \
  "warn | 2 | EX-8, EX-9"
rmdir "$T/planned/EX-1/EX-9" "$T/in-review/EX-8"
# task-location: a task note inside a task whose epic does not name it is out of its place.
mkdir -p "$T/abandoned/EX-1/notes"
printf '%s\n' '---' 'aliases:' '  - notes' 'type: task' 'epic: EX-2' '---' '' '# notes' >"$T/abandoned/EX-1/notes/README.md"
doc Example
chk "task-location: a task note inside a task whose epic names another task warns" task-location Example \
  "warn | 1 | tasks/abandoned/EX-1/notes/README.md"
rm -r "$T/abandoned/EX-1/notes"
fi

# A child whose epic names no single task stays where it is, and the doctor names it in the
# profile's word.
if block 34; then
sb task set EX-3 epic=EX-900
layout status
doc Example
chk "children: an epic that names no single task warns as unknown-epic" task-layout Example \
  "warn | 3 | EX-1:in-progress, EX-2:done, EX-3:unknown-epic"
is "children: the fix says how to mend it" "$(fix_of task-layout)" \
  "run second-brain doctor --fix to move each task to the folder of its status; set epic on each <ID>:unknown-epic to a task of the project, or clear it with second-brain task set <ID> epic="
doc Example --fix
is "children --fix: a task whose epic names no single task is left where it is" "$(fixed_moves)/$(ls "$T/EX-3")" \
  "fixed: EX-1 -> $P/tasks/in-progress/EX-1/README.md (Example)
fixed: EX-2 -> $P/tasks/done/EX-2/README.md (Example)/README.md"
case "$ERR" in *"EX-3: its epic EX-900 names no single task of Example: left where it is"*) pass "children --fix: stderr names it, with its epic" ;;
  *) fail "children --fix: stderr names it, with its epic" "in stderr: $ERR" ;; esac
edit "$vault/$P/claude/profile.md" 's/^persona: \(.*\)$/persona: \1\
parent_label: Feature/'
doc Example
chk "children: with parent_label: Feature the offender takes that word" task-layout Example "warn | 1 | EX-3:unknown-feature"
is "children: and so does the fix" "$(fix_of task-layout)" \
  "set epic on each <ID>:unknown-feature to a task of the project, or clear it with second-brain task set <ID> epic="
doc Example --fix
case "$ERR" in *"EX-3: its feature EX-900 names no single task of Example: left where it is"*) pass "children --fix: stderr takes the word too" ;;
  *) fail "children --fix: stderr takes the word too" "in stderr: $ERR" ;; esac
edit "$vault/$P/claude/profile.md" 's/^parent_label: .*/parent_label: story/'
doc Example
rc_is "children: an unknown parent_label leaves exit 0" 0
chk "children: parent_label:invalid comes first, and the unknown epic is named as epic" task-layout Example \
  "warn | 2 | parent_label:invalid, EX-3:unknown-epic"
is "children: the label fix comes first" "$(fix_of task-layout)" \
  "set parent_label in the profile to feature or epic, or remove it for epic; set epic on each <ID>:unknown-epic to a task of the project, or clear it with second-brain task set <ID> epic="
layout flat
doc Example
chk "children: parent_label:invalid is named in a flat project too" task-layout Example \
  "warn | 3 | parent_label:invalid, in-progress:flat, done:flat"
fi

# The sprint layout: a child in no sprint goes into its parent's folder in backlog/, and a child in
# a sprint into a folder named for its parent in that sprint's folder.
if block 56; then
sb task set EX-2 epic=EX-1
sb task set EX-3 epic=EX-1
layout sprint
doc Example
chk "children: in a sprint project a child warns with its parent's folder in backlog/" task-layout Example \
  "warn | 3 | EX-1:2026-01-14, EX-2:backlog/EX-1, EX-3:backlog/EX-1"
is "children: the sprint fix says --fix puts a child inside its parent's folder" "$(fix_of task-layout)" \
  "run second-brain doctor --fix to move each task to the folder of its sprint, or to backlog/ with no sprint, each child inside its epic's folder there"
doc Example --fix
rc_is "children --fix: exit 0 in a sprint project" 0
is "children --fix: in a sprint project each child goes into a folder named for its parent in backlog/" "$(fixed_moves)" \
  "fixed: EX-1 -> $P/tasks/2026-01-14/EX-1/README.md (Example)
fixed: EX-2 -> $P/tasks/backlog/EX-1/EX-2/README.md (Example)
fixed: EX-3 -> $P/tasks/backlog/EX-1/EX-3/README.md (Example)"
doc Example
chk "children --fix: then a sprint project's task-layout is ok" task-layout Example "ok | 0 | -"
chk "children --fix: and no-readme takes backlog/EX-1" no-readme Example "ok | 0 | -"
sb task set EX-3 sprint=2026-01-14
is "children: a child that joins its parent's sprint goes inside the parent's folder" \
  "$(printf '%s\n' "$OUT" | grep '/README.md$')" "$P/tasks/2026-01-14/EX-1/EX-3/README.md"
edit "$T/backlog/EX-1/EX-2/README.md" 's/^epic: \(.*\)$/epic: \1\
sprint: "2026-01-14"/'
doc Example
chk "children: a child whose sprint is set by hand warns as its sprint's folder and its parent" task-layout Example \
  "warn | 1 | EX-2:2026-01-14/EX-1"
doc Example --fix
is "children --fix: it moves in, then backlog/EX-1 and backlog/, both left empty, go" "$(fixed_moves)" \
  "fixed: EX-2 -> $P/tasks/2026-01-14/EX-1/EX-2/README.md (Example)
fixed: $P/tasks/backlog/EX-1 -> removed (Example)
fixed: $P/tasks/backlog -> removed (Example)"
is "children --fix: the parent's folder holds its two children" "$(ls "$T/2026-01-14/EX-1" | tr '\n' ' ')" "EX-2 EX-3 README.md "
# The parent leaves the sprint by hand: its own files move to backlog/, and its children stay.
edit "$T/2026-01-14/EX-1/README.md" '/^sprint: /d'
doc Example
chk "children: a parent with no sprint left in a sprint's folder warns as backlog" task-layout Example "warn | 1 | EX-1:backlog"
doc Example --fix
is "children --fix: the parent's own files move to backlog/" "$(fixed_moves)" \
  "fixed: EX-1 -> $P/tasks/backlog/EX-1/README.md (Example)"
is "children --fix: its children stay in the sprint's folder, under its name" "$(ls "$T/2026-01-14/EX-1" | tr '\n' ' ')" "EX-2 EX-3 "
doc Example
chk "children --fix: then every task is in its place" task-layout Example "ok | 0 | -"
sb unresolved Example
is "children --fix: unresolved lists nothing after the sprint moves" "$RC/$OUT" "0/"
fi

# A task folder that lost its README is named for no task: a README in it is no task, so no-readme
# still names the folder, and --fix moves nothing out of it, in a sprint project too.
if block 22; then
layout sprint
doc Example --fix
mkdir -p "$T/planned/ST-9/notes"
printf '%s\n' '---' 'type: note' '---' '' '# Notes' >"$T/planned/ST-9/notes/README.md"
sb find notes --project Example
rc_is "lost README: find sees no task in a folder named for no task, exit 1" 1
doc Example
chk "lost README: no-readme still names the folder" no-readme Example "warn | 1 | ST-9"
chk "lost README: task-layout names nothing in it" task-layout Example "ok | 0 | -"
doc Example --fix
is "lost README: --fix moves nothing out of it" "$(fixed_moves)/$(ls "$T/planned/ST-9/notes")" "fixed: nothing/README.md"
fi

# ---------------------------------------------------------------- board, the child folders
# no_child_branch: the board's filters as 0.11.0 wrote them before the child folders, with no
# branch for a task one level deeper, the fourth and: of the filters.
no_child_branch() {
  awk '/^        - and:$/ { n++ } /^formulas:/ { n = 0 } n < 4 { print }' "$T/tasks.base" >"$tmp/edit.tmp" &&
    cat "$tmp/edit.tmp" >"$T/tasks.base"
}
if block 26; then
no_child_branch
is "board: the filters before the child folders take one task by its alias" "$(grep -c '== aliases\[0\]' "$T/tasks.base")" "1"
layout status
doc Example
chk "board: a status project with no child is not asked for the child branch" board Example "ok | 0 | -"
sb task set EX-3 epic=EX-1
doc Example
rc_is "board: a missing child branch leaves exit 0" 0
chk "board: a status project with a child and no child branch warns" board Example "warn | 1 | tasks.base:no-child-filter"
is "board: the child fix names the filters block" "$(fix_of board)" "copy the filters block from templates/tasks.base.tmpl"
layout sprint
doc Example
chk "board: a sprint project with a child and no child branch warns" board Example "warn | 1 | tasks.base:no-child-filter"
no_sprint_branch
doc Example
chk "board: a sprint project's 0.10.0 board warns the sprint filter alone" board Example "warn | 1 | tasks.base:no-sprint-filter"
layout flat
doc Example
chk "board: a flat project with a child is not asked for the child branch" board Example "ok | 0 | -"
fi

# ---------------------------------------------------------------- topic-tags
# add_topic_line <line>: add one line under ## Topics in the profile.
add_topic_line() {
  SB_LINE="$1" awk '{ print } $0 == "## Topics" { print ""; print ENVIRON["SB_LINE"] }' \
    "$vault/$P/claude/profile.md" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$vault/$P/claude/profile.md"
}
if block 32; then
doc Example
chk "topic-tags: ok with no topic tags" topic-tags Example "ok | 0 | -"
sb task tag EX-1 add billing/invoices
sb task tag EX-2 add billing_stuff
doc Example
rc_is "topic-tags: a warning leaves exit 0" 0
chk "topic-tags: tags with no folder warn" topic-tags Example "warn | 2 | billing/invoices, billing-stuff"
mkdir -p "$vault/$P/docs/Billing/Invoices" "$vault/$P/docs/Billing Stuff"
doc Example
chk "topic-tags: folders match without case, spaces as hyphens" topic-tags Example "ok | 0 | -"
rm -rf "$vault/$P/docs/Billing" "$vault/$P/docs/Billing Stuff"
mkdir -p "$vault/$P/docs/Money/Paid invoices" "$vault/$P/notes/Stuff"
add_topic_line '- `billing/invoices` -> `docs/Money/Paid invoices`'
add_topic_line '- billing-stuff -> notes/Missing'
doc Example
chk "topic-tags: an exception line is accepted, one to a missing folder is not" topic-tags Example "warn | 1 | billing-stuff"
reset
sb task tag EX-1 add billing/invoices
mkdir -p "$vault/$P/docs/Money/Invoices"
add_topic_line '- billing -> docs/Money'
doc Example
chk "topic-tags: an exception covers the sub-tags under its folder" topic-tags Example "ok | 0 | -"
reset
sb task tag EX-1 add billing
mkdir -p "$vault/$P/"'docs\money'
add_topic_line '- billing -> docs\money'
doc Example
chk "topic-tags: an exception whose folder holds a backslash is not taken, though the folder is there" topic-tags Example "warn | 1 | billing"
fi

# ---------------------------------------------------------------- repos
# set_repos <repos> <repos_root> <repo_paths>: write the three repository keys of the profile.
set_repos() {
  edit "$vault/$P/claude/profile.md" "s|^repos: .*|repos: $1|; s|^repos_root: .*|repos_root: \"$2\"|; s|^repo_paths: .*|repo_paths: $3|"
}
if block 32; then
doc Example
chk "repos: ok on a fresh scaffold, with nothing recorded" repos Example "ok | 0 | -"
mkdir -p "$tmp/code/example-api" "$tmp/code/example-web" "$HOME/code/example-api" "$HOME/code/example-web"
set_repos '[example-api, example-web]' "$tmp/code" '[]'
doc Example
chk "repos: ok when every folder under repos_root exists" repos Example "ok | 0 | -"
set_repos '[example-api, example-web]' '~/code' '[]'
doc Example
chk "repos: ok with a repos_root that starts with ~" repos Example "ok | 0 | -"
set_repos '[example-api, example-web]' "$tmp/code" '[]'
rmdir "$tmp/code/example-web"
doc Example
rc_is "repos: a warning leaves exit 0" 0
chk "repos: a folder that is gone warns, naming the repository" repos Example "warn | 1 | example-web"
is "repos: the fix names the two keys and the repo command" "$(fix_of repos)" \
  "correct repos_root or the repo_paths entry in the profile, then run second-brain repo <project>"
mkdir -p "$tmp/code/example-web" "$tmp/elsewhere"
set_repos '[example-api, example-web]' "$tmp/code" "[\"example-api=$tmp/elsewhere/api\"]"
doc Example
chk "repos: an exception in repo_paths that leads to no folder warns" repos Example "warn | 1 | example-api"
mkdir -p "$tmp/elsewhere/api"
doc Example
chk "repos: ok once the exception's folder exists" repos Example "ok | 0 | -"
set_repos '[example-api, example-web]' '' '[]'
doc Example
chk "repos: ok when repositories are listed with no location" repos Example "ok | 0 | -"
fi

# ---------------------------------------------------------------- old-namespace, the settings of the vault root and the repos
R="$tmp/nscode"
if block 9; then
mkdir -p "$R/example-api/.claude" "$R/example-web/.claude" "$vault/.claude"
set_repos '[example-api, example-web, gone-repo]' "$R" '[]'
printf '%s\n' "{ \"permissions\": { \"allow\": [\"Skill(${OLD}story-tracker)\"] } }" >"$R/example-api/.claude/settings.local.json"
printf '%s\n' "{ \"permissions\": { \"deny\": [\"Skill(${OLD}vault-setup)\"] } }" >"$R/example-web/.claude/settings.json"
printf '%s\n' "{ \"permissions\": { \"allow\": [\"Skill(${OLD}spec)\"] } }" >"$vault/.claude/settings.local.json"
doc
chk "old-namespace: the settings of the vault root, then of each repo the profile lists with a folder" old-namespace vault \
  "warn | 3 | .claude/settings.local.json:Skill(${OLD}spec), example-api/.claude/settings.local.json:Skill(${OLD}story-tracker), example-web/.claude/settings.json:Skill(${OLD}vault-setup)"
is "old-namespace: the fix leaves a repo's settings rules to the owner" "$(fix_of old-namespace vault)" \
  "change the settings rules to odsb: yourself, as nothing edits a settings file"
set_repos '[example-api, example-web]' "$R" "[\"example-web=$vault\"]"
doc
chk "old-namespace: a repo whose folder is the vault root has its settings read once" old-namespace vault \
  "warn | 2 | .claude/settings.local.json:Skill(${OLD}spec), example-api/.claude/settings.local.json:Skill(${OLD}story-tracker)"
fi

# ---------------------------------------------------------------- code-doc-map
PROFILE="$vault/$P/claude/profile.md"
# add_map_row <row>: add one table row to the Code to doc map, after the template's placeholder row.
add_map_row() {
  SB_ROW="$1" awk '{ print } $0 == "| <repo> | <kind of change> | <surfaces> |" { print ENVIRON["SB_ROW"] }' \
    "$PROFILE" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$PROFILE"
}
if block 33; then
doc Example
chk "code-doc-map: ok on a fresh scaffold, with no repositories" code-doc-map Example "ok | 0 | -"
set_repos '["<repo>", example-api, Example-Web]' '' '[]'
doc Example
rc_is "code-doc-map: a warning leaves exit 0" 0
chk "code-doc-map: the placeholder row does not count" code-doc-map Example "warn | 3 | <repo>, example-api, Example-Web"
is "code-doc-map: the fix says where the row goes" "$(fix_of code-doc-map)" \
  "add a row for the repository under \"Code to doc map\" in the profile's Docs section"
set_repos '[example-api, Example-Web, example-jobs]' '' '[]'
add_map_row '| EXAMPLE-WEB | a new page | the web guide |'
add_map_row '| `example-api` | a new endpoint | the API reference |'
doc Example
chk "code-doc-map: a repository with no row is the offender" code-doc-map Example "warn | 1 | example-jobs"
add_map_row '| `example-jobs` | a new job | the runbook |'
doc Example
chk "code-doc-map: ok with a row for each, with or without backticks, whatever the case" code-doc-map Example "ok | 0 | -"
cp "$PROFILE" "$tmp/profile.mapped"
edit "$PROFILE" 's/^| Repo | Change in the code | Docs to update |$/| Change in the code | Docs to update |/'
doc Example
chk "code-doc-map: a table with no Repo column covers no repository" code-doc-map Example "warn | 3 | example-api, Example-Web, example-jobs"
cp "$tmp/profile.mapped" "$PROFILE"
edit "$PROFILE" '/^### Code to doc map$/d'
doc Example
chk "code-doc-map: a missing heading leaves every repository without a row" code-doc-map Example "warn | 3 | example-api, Example-Web, example-jobs"
cp "$tmp/profile.mapped" "$PROFILE"
edit "$PROFILE" 's/^## Docs$/## Notes/'
doc Example
chk "code-doc-map: the map counts only inside the Docs section" code-doc-map Example "warn | 3 | example-api, Example-Web, example-jobs"
fi

# ---------------------------------------------------------------- subprojects
SUBS="$vault/$P/claude/subprojects"
if block 63; then
edit "$T/EX-3/README.md" 's/^epic: "-"$/epic: "-"\
subproject: ghost/'
doc Example
is "subprojects: no row for a project with no subproject" "$(row subprojects)" ""
is "task-subproject: no row for a project with no subproject, whatever its tasks say" "$(row task-subproject)" ""
is "subprojects: a project with no subproject keeps twenty-four rows" "$(scope_rows Example)" "24"
edit "$T/tasks.base" 's/name: By subproject$/name: By repo/'
doc Example
chk "board: a project with no subproject is not asked for the By subproject view" board Example "ok | 0 | -"
mkdir -p "$tmp/code/example-api" "$tmp/code/example-infra"
set_repos '[example-api]' "$tmp/code" '[]'
add_map_row '| example-api | a new endpoint | the API reference |'
sb scaffold subproject Example infra --repos example-infra
rc_is "subprojects: scaffold subproject exits 0" 0
doc Example
is "subprojects: two more rows once the project has one" "$(scope_rows Example)" "26"
is "subprojects: its rows sit between repos and sprints" \
  "$(printf '%s\n' "$OUT" | grep ' | Example | ' | awk -F' [|] ' '$2 == "repos" || $2 == "subprojects" || $2 == "task-subproject" || $2 == "sprints" { printf "%s ", $2 }')" \
  "repos subprojects task-subproject sprints "
chk "task-subproject: a value that names no note warns as <ID>:<value>" task-subproject Example "warn | 1 | EX-3:ghost"
is "task-subproject: the fix names task set" "$(fix_of task-subproject)" \
  "run second-brain task set <ID> subproject=<name> with a subproject of the project, or subproject= for a task in none"
chk "subprojects: a repository with no map row" subprojects Example "warn | 1 | infra/example-infra:no-map-row"
chk "subprojects: the profile's own map check is left as it was" code-doc-map Example "ok | 0 | -"
chk "board: a project with a subproject and a board with no By subproject view warns" board Example "warn | 1 | tasks.base:no-subproject-view"
is "board: the fix names what to add" "$(fix_of board)" "add the By subproject view and the subproject column from templates/tasks.base.tmpl"
edit "$T/tasks.base" 's/sprint == "2026-01-14"/sprint == "2025-12-31"/'
doc Example
chk "board: the sprint finding and the missing view share one row" board Example \
  "warn | 2 | tasks.base:2025-12-31, tasks.base:no-subproject-view"
is "board: the fix holds both" "$(fix_of board)" \
  "set the filter of the board's Current sprint view to the sprint in progress, 2026-01-14; add the By subproject view and the subproject column from templates/tasks.base.tmpl"
edit "$T/tasks.base" 's/sprint == "2025-12-31"/sprint == "2026-01-14"/; s/name: By repo$/name: By subproject/'
doc Example
chk "board: ok once the view is back" board Example "ok | 0 | -"
sb task set EX-3 subproject=infra
edit "$T/EX-1/README.md" 's/^epic: "-"$/epic: "-"\
subproject: INFRA/'
doc Example
chk "task-subproject: ok when each value names a note, in any letter case" task-subproject Example "ok | 0 | -"
add_map_row '| example-infra | a new module | docs/infra |'
doc Example
rc_is "subprojects: exit 0" 0
chk "subprojects: ok with its type, repos found, a docs folder and a map row" subprojects Example "ok | 0 | -"
rm -rf "$vault/$P/docs/infra"
edit "$SUBS/infra.md" 's/^type: subproject$/type: note/'
edit "$SUBS/infra.md" 's/^repos: .*$/repos: [example-infra, gone-infra]/'
doc Example
chk "subprojects: a wrong type, no docs folder, a missing repo with no map row" subprojects Example \
  "warn | 4 | infra:type, infra:no-docs, infra/gone-infra:no-map-row, infra/gone-infra:missing"
is "subprojects: the fix names each part" "$(fix_of subprojects)" \
  "set type: subproject and the repos in the note, record where each repo is, create the docs folder <topics root>/<name>/, add a Code to doc map row per repo, and keep each repo in one subproject"
chk "subprojects: the repos check sees the subproject's repositories too" repos Example "warn | 1 | gone-infra"
printf '%s\n' '---' 'type: subproject' 'repos: [EXAMPLE-INFRA]' '---' >"$SUBS/ops.md"
printf '%s\n' '---' 'type: subproject' 'repos: []' '---' >"$SUBS/web.md"
mkdir -p "$vault/$P/docs/ops" "$vault/$P/docs/web"
edit "$PROFILE" 's/^repos_root: .*$/repos_root: ""/'
doc Example
chk "subprojects: with no location recorded, every note is read, five offenders shown" subprojects Example \
  "warn | 8 | infra:type, infra:no-docs, infra/example-infra:no-location, infra/gone-infra:no-map-row, infra/gone-infra:no-location"
rm -f "$SUBS/infra.md"
printf '%s\n' '---' 'type: subproject' 'repos: [example-infra]' '---' >"$SUBS/more.md"
mkdir -p "$vault/$P/docs/more"
doc Example
chk "task-subproject: a removed note leaves its tasks with a stale value" task-subproject Example "warn | 2 | EX-1:INFRA, EX-3:infra"
chk "subprojects: a repo in two subprojects, whatever the case, and a subproject with no repos" subprojects Example \
  "warn | 4 | more/example-infra:no-location, EXAMPLE-INFRA:twice, ops/EXAMPLE-INFRA:no-location, web:no-repos"
rm -f "$SUBS/more.md" "$SUBS/ops.md" "$SUBS/web.md"
: >"$SUBS/blank.md"
doc Example
chk "subprojects: an empty note lends the profile's repos to nobody" subprojects Example \
  "warn | 3 | blank:type, blank:no-repos, blank:no-docs"
fi

# ---------------------------------------------------------------- sprints
S="$vault/$P/sprints"
if block 29; then
doc Example
chk "sprints: ok with one sprint in progress" sprints Example "ok | 0 | -"
sed 's/2026-01-14/2026-01-28/g' "$S/2026-01-14.md" >"$S/2026-01-28.md"
doc Example
rc_is "sprints: exit 1" 1
chk "sprints: two in progress" sprints Example "fail | 2 | 2026-01-14:in-progress, 2026-01-28:in-progress"
reset
run env SECOND_BRAIN_TODAY=2026-01-14 "$SB" doctor Example
chk "sprints: ok on the end date itself" sprints Example "ok | 0 | -"
run env SECOND_BRAIN_TODAY=2026-01-15 "$SB" doctor Example
chk "sprints: one in progress past its end" sprints Example "fail | 1 | 2026-01-14:past-end"
is "sprints: an ended sprint is closed with sprint close" "$(fix_of sprints)" \
  "close the extra or ended sprint with second-brain sprint close; point each task at a sprint that has a note"
sb task set EX-3 sprint=2026-03-01
doc Example
chk "sprints: a task pointing at a sprint with no note" sprints Example "fail | 1 | EX-3:2026-03-01"
reset
sb task set EX-3 sprint=2026-01-28
doc Example
chk "sprints: the next id is no excuse while a sprint is in progress" sprints Example "fail | 1 | EX-3:2026-01-28"
fi

# ---------------------------------------------------------------- sprints, after a close
if block 20; then
sb sprint close Example --carry EX-1
out_has "close: the carried task now points at the next sprint, which has no note yet" "next: 2026-01-28"
doc Example
rc_is "sprints: exit 0 after a close with a carry" 0
chk "sprints: ok after a close with a carry" sprints Example "ok | 0 | -"
chk "board: with no sprint in progress the view's old sprint id is not reported" board Example "ok | 0 | -"
sb task set EX-3 sprint=2026-03-01
sb task set EX-2 sprint=2026-01-28
doc Example
rc_is "sprints: exit 1 for a sprint id with no note" 1
chk "sprints: a made-up id, and a done task on the next id, are still reported" sprints Example "fail | 2 | EX-2:2026-01-28, EX-3:2026-03-01"
is "sprints: tasks alone are left to the sprint skill" "$(fix_of sprints)" \
  "open the next sprint through the sprint skill; do not re-point carried tasks by hand"
sb task set EX-3 sprint=
sb task set EX-2 sprint=
edit "$vault/$P/claude/profile.md" 's/^sprint_anchor_end: .*/sprint_anchor_end: ""/'
doc Example
chk "sprints: with no anchor there is no next id, so nothing is exempt" sprints Example "fail | 1 | EX-1:2026-01-28"
fi

# ---------------------------------------------------------------- links in tasks, line endings
# to_crlf <file> [last line]: give the file CRLF endings, down to a line number when one is given.
to_crlf() {
  SB_N="${2:-0}" awk '{ if (ENVIRON["SB_N"] == 0 || NR <= ENVIRON["SB_N"]) printf "%s\r\n", $0; else print }' "$1" >"$tmp/edit.tmp" &&
    cat "$tmp/edit.tmp" >"$1"
}
if block 23; then
doc Example
chk "unresolved-links: ok on a scaffolded project" unresolved-links Example "ok | 0 | -"
chk "bare-links: ok on new tasks" bare-links Example "ok | 0 | -"
chk "line-endings: ok on new tasks" line-endings Example "ok | 0 | -"
printf '%s\n' '' 'See [[README]] and [[profile|the profile]].' >>"$T/EX-1/README.md"
printf '%s\n' '' "See [[$P/README|Example Hub]] and [[other-note]]." >>"$T/EX-2/README.md"
printf '%s\n' '' 'A bare `[[README]]` and a `[[gone-in-code]]` do not count.' '```' '[[tasks.base]]' '[[gone-in-a-fence]]' '```' >>"$T/EX-3/README.md"
printf '%s\n' '' 'See [the plan](missing/plan.md) and [the site](https://example.com).' >>"$vault/$P/docs/README.md"
printf '%s\n' '[[nowhere-at-all]]' >"$vault/outside.md"
doc Example
rc_is "bare-links: a warning leaves exit 0" 0
chk "bare-links: a bare [[README]] warns, a pathed link and code do not" bare-links Example "warn | 1 | EX-1"
n1="$(grep -n 'missing/plan' "$vault/$P/docs/README.md" | cut -d: -f1)"
n2="$(grep -n 'other-note' "$T/EX-2/README.md" | cut -d: -f1)"
chk "unresolved-links: each link to no file, as the note under the project and its line" unresolved-links Example \
  "warn | 2 | docs/README.md:$n1, tasks/EX-2/README.md:$n2"
is "unresolved-links: the fix names the command that lists them" "$(fix_of unresolved-links)" \
  "give each link a path that exists; second-brain unresolved <project> lists them"
reset
to_crlf "$T/EX-2/README.md" 5
to_crlf "$T/EX-3/README.md"
doc Example
chk "line-endings: a mixed README warns, a CRLF one does not" line-endings Example "warn | 1 | EX-2"
chk "line-endings: the other checks read a CRLF README" task-frontmatter Example "ok | 0 | -"
printf 'last line with no newline' >>"$T/EX-3/README.md"
doc Example
chk "line-endings: a CRLF file with no final newline is not mixed" line-endings Example "warn | 1 | EX-2"
printf '\n' >>"$T/EX-3/README.md"
doc Example
chk "line-endings: one bare LF at the end is mixed" line-endings Example "warn | 2 | EX-2, EX-3"
fi

# ---------------------------------------------------------------- depends-on
if block 78; then
doc Example
chk "depends-on: ok on new tasks" depends-on Example "ok | 0 | -"
sb task dep EX-2 add EX-1
sb task dep EX-3 add EX-2
doc Example
chk "depends-on: a chain is no cycle" depends-on Example "ok | 0 | -"
sb task dep EX-1 add EX-3
doc Example
rc_is "depends-on: a warning leaves exit 0" 0
chk "depends-on: every task of a ring is named" depends-on Example "warn | 3 | EX-1:cycle, EX-2:cycle, EX-3:cycle"
is "depends-on: the fix names the command" "$(fix_of depends-on)" \
  "link each depends_on item to a task README that exists; break a cycle with second-brain task dep <ID> remove <ID>"
sb task dep EX-1 remove EX-3
printf '%s\n' "$(sed "s#^depends_on:\$#depends_on:\\$NL  - \"[[$P/tasks/EX-9/README|EX-9]]\"#" "$T/EX-3/README.md")" >"$T/EX-3/README.md"
printf '%s\n' "$(sed 's#^carried_from: \[\]$#depends_on: ["[[../outside/README|out]]"]#' "$T/EX-1/README.md")" >"$T/EX-1/README.md"
doc Example
chk "depends-on: a link to no note, or out of the vault, is missing" depends-on Example "warn | 2 | EX-1:missing, EX-3:missing"
reset
# A chord: EX-3 joins the ring of EX-1 and EX-2 through an edge the first walk reaches last.
sb task dep EX-1 add EX-2
sb task dep EX-2 add EX-1
sb task dep EX-1 add EX-3
sb task dep EX-3 add EX-2
doc Example
chk "depends-on: every task of a ring is named, a chord's too" depends-on Example "warn | 3 | EX-1:cycle, EX-2:cycle, EX-3:cycle"
reset
printf '%s\n' "$(sed "s#^carried_from: \[\]\$#depends_on: [\"[[$P/tasks/EX-1/README|EX-1]]\"]#" "$T/EX-1/README.md")" >"$T/EX-1/README.md"
sb task dep EX-2 add EX-1
doc Example
chk "depends-on: a task that waits on itself is a ring alone" depends-on Example "warn | 1 | EX-1:cycle"
reset
printf '%s\n' "$(sed "s#^carried_from: \[\]\$#depends_on: [\"[[projects/example/tasks/ex-1/readme|ex-1]]\"]#" "$T/EX-2/README.md")" >"$T/EX-2/README.md"
doc Example
chk "depends-on: a link in other letter case finds the task" depends-on Example "ok | 0 | -"
reset
# 500 tasks in one ring, then in one chain: deeper than an awk recursion goes.
i=1
while [ "$i" -le 500 ]; do
  mkdir -p "$T/LG-$i"
  printf -- '---\naliases:\n  - LG-%s\nstatus: planned\ndepends_on:\n  - "[[%s/tasks/LG-%s/README|LG-%s]]"\ntype: task\ntags:\n  - type/task\n  - status/active\n---\n\n# LG-%s\n' \
    "$i" "$P" "$((i % 500 + 1))" "$((i % 500 + 1))" "$i" >"$T/LG-$i/README.md"
  i=$((i + 1))
done
doc Example
is "depends-on: a ring of 500 tasks names each" "$(row depends-on | cut -d'|' -f1-2)" "warn | 500 "
printf -- '---\naliases:\n  - LG-500\nstatus: planned\ntype: task\ntags:\n  - type/task\n  - status/active\n---\n' >"$T/LG-500/README.md"
doc Example
chk "depends-on: a chain of 500 tasks is no ring" depends-on Example "ok | 0 | -"
fi

# ---------------------------------------------------------------- --fix
if block 16; then
edit "$T/EX-1/README.md" '/^status: /d'
edit "$T/EX-2/README.md" 's/^  - status\/done$/  - status\/active/'
to_crlf "$T/EX-3/README.md"
edit "$T/EX-3/README.md" "s/^  - status\/active$CR\$/  - status\/done$CR/"
for id in EX-1 EX-2 EX-3; do cp "$T/$id/README.md" "$tmp/$id.before"; done
doc Example
chk "--fix: three tasks to look at first" status-tag Example "warn | 2 | EX-2, EX-3"
is "no --fix: nothing is written" "$(cmp -s "$tmp/EX-2.before" "$T/EX-2/README.md" && printf same)" "same"
doc Example --fix
rc_is "--fix: exit 0" 0
is "--fix: prints what it changed, then the table" "$(printf '%s\n' "$OUT" | head -3 | cut -d' ' -f1-4 | tr '\n' '/')" \
  "fixed: EX-2 -> status/done/fixed: EX-3 -> status/active/ok | pointer |/"
is "--fix: the whole table follows" "$(printf '%s\n' "$OUT" | grep -c ' | ')" "38"
chk "--fix: the status tags follow the status" status-tag Example "ok | 0 | -"
chk "--fix: a missing status is still reported" needs-a-status Example "warn | 1 | EX-1"
is "--fix: a missing status is never set" "$(cmp -s "$tmp/EX-1.before" "$T/EX-1/README.md" && printf same)" "same"
is "--fix: one line changed" "$(diff "$tmp/EX-2.before" "$T/EX-2/README.md" | grep '^[<>]' | tr '\n' '/')" \
  "<   - status/active/>   - status/done/"
is "--fix: one line changed in a CRLF file" "$(diff "$tmp/EX-3.before" "$T/EX-3/README.md" | grep -c '^[<>]')" "2"
is "--fix: a CRLF file stays CRLF" "$(awk '!/\r$/ { n++ } END { print n + 0 }' "$T/EX-3/README.md")" "0"
doc Example --fix
is "--fix: nothing left to change" "$(printf '%s\n' "$OUT" | head -1)" "fixed: nothing"
fi

# ---------------------------------------------------------------- --json
if block 9; then
add_alias EX-1 "'Say \"hi\" \\ there'"
add_alias EX-2 "'Say \"hi\" \\ there'"
mkdir -p "$T/EX-7" "$T/EX-8" "$tmp/code/example-api"
set_repos '[example-api, gone-repo]' "$tmp/code" '[]'
doc --json
rc_is "--json: exit 1 when a row fails" 1
if command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "$OUT" >"$tmp/doctor.json"
  if python3 -c 'import json,sys; json.load(sys.stdin)' <"$tmp/doctor.json" 2>"$tmp/stderr"; then
    pass "--json: parses as JSON"
  else
    fail "--json: parses as JSON" "$(cat "$tmp/stderr")"
  fi
  # A Python built for Windows ends the lines it prints with CRLF; tr takes that away.
  got="$(python3 -c '
import json, sys
rows = json.load(sys.stdin)
by = dict((r["check"], r) for r in rows)
print(len(rows), sorted(rows[0].keys()) == ["check", "count", "fix", "offenders", "result", "scope"])
print(by["alias-unique"]["offenders"][0])
print(by["no-readme"]["count"], by["no-readme"]["offenders"], by["pointer"]["offenders"])
names = [r["check"] for r in rows]
print(names.index("sprints") - names.index("repos"), by["repos"]["result"], by["repos"]["offenders"])
print(names.index("spec-trace") - names.index("validation"), by["spec-trace"]["result"], by["spec-trace"]["offenders"])
print(names.index("repos") - names.index("code-doc-map"), by["code-doc-map"]["result"], by["code-doc-map"]["offenders"])' <"$tmp/doctor.json" 2>&1 | tr -d '\r')"
  is "--json: 38 objects, six keys, strings escaped, offenders as arrays, code-doc-map then repos, then delivery, validation and spec-trace, then sprints" "$got" \
    "38 True${NL}Say \"hi\" \\ there${NL}2 ['EX-7', 'EX-8'] []${NL}4 warn ['gone-repo']${NL}1 ok []${NL}1 warn ['example-api', 'gone-repo']"
  run env SECOND_BRAIN_VAULT="$tmp/userdir" "$SB" doctor --json
  rc_is "--json: exit 2 with no vault" 2
  got="$(printf '%s\n' "$OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d), d[0]["check"], d[0]["result"])' 2>&1 | tr -d '\r')"
  is "--json: the pointer row alone with no vault" "$got" "1 pointer fail"
else
  printf 'skip  --json: python3 is not installed\n'
fi
fi

# ---------------------------------------------------------------- two projects
if block 29; then
sb scaffold project Two --path projects/two --keys TW
sb task new TW-1 --project Two --title "Other task"
edit "$vault/projects/two/tasks/TW-1/README.md" 's/^epic: "-"$/epic: -/'
doc
is "two projects: twenty-four rows for each" "$(scope_rows Example)/$(scope_rows Two)" "24/24"
is "two projects: the vault rows come first, in the contract's order" "$(printf '%s\n' "$OUT" | head -14 | awk -F' [|] ' '{ printf "%s ", $2 }')" \
  "pointer index conventions pull-request writing-style import global-rules links foreign double-registration always-loaded-size descriptions skill-size old-namespace "
is "two projects: the project rows in the contract's order" "$(printf '%s\n' "$OUT" | grep ' | Two | ' | awk -F' [|] ' '{ printf "%s ", $2 }')" \
  "profile board hubs placeholders task-template task-frontmatter needs-a-status status-tag yaml-traps alias-unique no-readme task-location task-layout topic-tags code-doc-map repos delivery validation spec-trace sprints unresolved-links bare-links line-endings depends-on "
chk "two projects: each row names its project" yaml-traps Two "fail | 1 | TW-1:epic"
chk "two projects: the other project is clean" yaml-traps Example "ok | 0 | -"
doc example
rc_is "a named project: its name is matched without case, and another project's failure is left out" 0
is "a named project: only its rows, after the vault rows" "$(scope_rows vault)/$(scope_rows Example)/$(scope_rows Two)" "14/24/0"

# ---------------------------------------------------------------- unresolved links, two projects
mkdir -p "$vault/projects/example-more"
printf '%s\n' '[[gone-note]] and [[gone-note#part]]' '[[also-gone|text]]' >"$vault/$P/docs/first.md"
printf '%s\n' '' '[[fourth]]' >>"$vault/projects/two/README.md"
printf '%s\n' '[[third]]' >"$vault/projects/example-more/x.md"
n="$(grep -c '' "$vault/projects/two/README.md")"
doc
chk "unresolved-links: one offender for each line of a note under the project, not of a look-alike folder" unresolved-links Example \
  "warn | 2 | docs/first.md:1, docs/first.md:2"
chk "unresolved-links: each project gets its own" unresolved-links Two "warn | 1 | README.md:$n"
printf '%s\n' '# Gone note' >"$vault/gone-note.md"
printf '%s\n' '# Also gone' >"$vault/$P/docs/also-gone.md"
doc Example
chk "unresolved-links: ok once the files exist, wherever they are in the vault" unresolved-links Example "ok | 0 | -"
fi

# ---------------------------------------------------------------- a project without sprints
if block 30; then
K="$vault/projects/kanban"
sb scaffold project Kanban --path projects/kanban --keys KB --no-sprints
sb task new KB-1 --project Kanban --title "First task"
doc Kanban
rc_is "no sprints: exit 0" 0
is "no sprints: no fail row" "$(printf '%s\n' "$OUT" | grep '^fail ' || true)" ""
chk "no sprints: the profile passes without a sprints hub" profile Kanban "ok | 0 | -"
chk "no sprints: the sprints check passes" sprints Kanban "ok | 0 | -"
is "no sprints: the sprints row says why" "$(fix_of sprints Kanban)" "sprints are off"
chk "no sprints: the board passes with no Current sprint view" board Kanban "ok | 0 | -"
chk "no sprints: the hubs pass with no sprints hub" hubs Kanban "ok | 0 | -"
edit "$K/tasks/KB-1/README.md" 's/^status: planned$/status: planned\
sprint: "2026-03-01"/'
is "no sprints: a sprint id left on a task" "$(grep -c '^sprint: "2026-03-01"$' "$K/tasks/KB-1/README.md")" "1"
doc Kanban
chk "no sprints: a leftover sprint id is not reported" sprints Kanban "ok | 0 | -"
edit "$K/claude/profile.md" 's/^uses_sprints: false$/uses_sprints: true/'
doc Kanban
chk "no sprints: turned on again, the leftover id is reported" sprints Kanban "fail | 1 | KB-1:2026-03-01"
sb scaffold project Kanban --path projects/kanban --keys KB
sb sprint open Kanban --end 2026-01-14
doc Kanban
chk "board: sprints turned on and a sprint opened, the board with no Current sprint view warns" board Kanban "warn | 1 | tasks.base:no-view"
is "board: the fix says what to add, and names the sprint in progress" "$(fix_of board Kanban)" \
  "add the Current sprint view and the sprint columns from templates/tasks.base.tmpl, with the filter on the sprint in progress, 2026-01-14"
edit "$K/claude/profile.md" 's/^uses_sprints: true$/uses_sprints: false/'
doc Kanban
rc_is "no sprints: a sprint left in progress is no failure" 0
chk "no sprints: a sprint left in progress is a warning" sprints Kanban "warn | 1 | 2026-01-14:in-progress"
chk "no sprints: the board is not asked for a Current sprint view" board Kanban "ok | 0 | -"
is "no sprints: the way to close it is given" "$(fix_of sprints Kanban)" \
  "set uses_sprints to true, close the sprint through the sprint skill, then set it to false again"
fi

# ---------------------------------------------------------------- arguments and setup
if block 1; then
doc Nope
rc_is "a project that is not in the index: exit 1" 1
doc --bogus
rc_is "an unknown flag: exit 5" 5
run env SECOND_BRAIN_VAULT="$tmp/userdir" "$SB" doctor
rc_is "no vault: exit 2" 2
out_is "no vault: the pointer row fails first" "fail | pointer | vault | 1 | SECOND_BRAIN_VAULT | run /odsb:vault-setup init"
fi

# ---------------------------------------------------------------- session-check
if block 3; then
sb session-check
rc_is "session-check: exit 0 when set up" 0
out_is "session-check: silent when set up" ""
run env SECOND_BRAIN_VAULT="$tmp/userdir" "$SB" session-check
rc_is "session-check: exit 0 with no vault" 0
out_is "session-check: one line with no vault" "second-brain: no vault is set up - run /odsb:vault-setup init"
mkdir -p "$tmp/bare/.obsidian"
run env SECOND_BRAIN_VAULT="$tmp/bare" "$SB" session-check
rc_is "session-check: exit 0 for a vault with no index" 0
out_has "session-check: one line for a vault with no index" "no vault is set up"
run env -u SECOND_BRAIN_VAULT "$SB" session-check
out_has "session-check: one line when the link directory holds no pointer" "no vault is set up"
sb pointer set "$vault"
run env -u SECOND_BRAIN_VAULT "$SB" session-check
out_is "session-check: silent when the pointer of the link directory leads to the vault" ""
fi

# ---------------------------------------------------------------- session-check, the session block
if block 15; then
R="$tmp/code/example-api"
RULE='rule: find and read notes with `second-brain find`, `search`, `task head` and `outline`, then a ranged read; never grep, cat or sed on vault files.'
mkdir -p "$R/.git" "$R/src/deep" "$tmp/code/outside/.git"
set_repos '[example-api]' "$tmp/code" '[]'
# on_branch <repo folder> <HEAD line>: the repository's HEAD file, written as git writes it.
on_branch() { printf '%s\n' "$2" >"$1/.git/HEAD"; }
on_branch "$R" 'ref: refs/heads/feature/EX-1-first-task'
sb task set EX-1 "next=Write the first test"
start=$SECONDS
sb session-check --cwd "$R/src/deep"
rc_is "session-check: exit 0 in a repo of a project" 0
is "session-check: the block for a ticket branch with a story" "$OUT" "second-brain context for this session:
project: Example
sprint: 2026-01-14
branch: feature/EX-1-first-task
ticket: EX-1
story: projects/example/tasks/EX-1/README.md - in-progress, next: Write the first test
$RULE"
is "session-check: well under the hook's 5 second timeout" "$(((SECONDS - start) < 5))" "1"
run bash -c 'cd "$1" && "$2" session-check' _ "$R" "$SB"
out_has "session-check: the working directory is the default" "ticket: EX-1"
on_branch "$R" 'ref: refs/heads/fix/ex-9-later'
sb session-check --cwd "$R"
out_has "session-check: a key in another letter case names the ticket as the index spells it" "ticket: EX-9"
out_has "session-check: a ticket branch with no story says how to start one" "story: none - run story-tracker start"
is "session-check: the block ends with the search and read rule" "$(printf '%s\n' "$OUT" | tail -1)" "$RULE"
on_branch "$R" 'ref: refs/heads/feature/hex-12-and-EX-3'
sb session-check --cwd "$R"
out_has "session-check: a key inside a word is no ticket, the next one is" "ticket: EX-3"
on_branch "$R" 'ref: refs/heads/main'
sb session-check --cwd "$R"
out_has "session-check: a branch that names no ticket" "branch: main
ticket: none
$RULE"
out_lacks "session-check: no story line with no ticket" "story:"
on_branch "$R" '0123456789abcdef0123456789abcdef01234567'
sb session-check --cwd "$R"
out_has "session-check: a detached head" "branch: detached
ticket: none"
mv "$R/.git" "$tmp/code/main-git"
mkdir -p "$tmp/code/main-git/worktrees/w1"
printf 'gitdir: %s\n' "$tmp/code/main-git/worktrees/w1" >"$R/.git"
printf '%s\n' 'ref: refs/heads/main' >"$tmp/code/main-git/HEAD"
printf '%s\n' 'ref: refs/heads/feature/EX-2-second' >"$tmp/code/main-git/worktrees/w1/HEAD"
sb session-check --cwd "$R/src"
out_has "session-check: a linked worktree reads the HEAD of its own git folder" "ticket: EX-2
story: projects/example/tasks/EX-2/README.md - done, next: Frame the story"
printf 'gitdir: %s\n' "../main-git/worktrees/w1" >"$R/.git"
sb session-check --cwd "$R"
out_has "session-check: a git folder named from the repo's own folder" "ticket: EX-2"
if sb_is_windows; then
  printf 'gitdir: %s\n' "$(cygpath -m "$tmp/code/main-git/worktrees/w1")" >"$R/.git"
  sb session-check --cwd "$R"
  out_has "session-check: on Windows a git folder in the drive form" "ticket: EX-2"
fi
rm -f "$R/.git"
sb session-check --cwd "$R"
out_has "session-check: a project folder that is no git repository" "branch: none
ticket: none"
mkdir -p "$R/.git"
on_branch "$R" 'ref: refs/heads/feature/EX-1-first-task'
edit "$vault/$P/sprints/2026-01-14.md" 's/^status: in-progress$/status: done/'
sb session-check --cwd "$R"
out_has "session-check: no sprint in progress" "sprint: none"
edit "$vault/$P/claude/profile.md" 's/^uses_sprints: .*$/uses_sprints: false/'
sb session-check --cwd "$R"
out_lacks "session-check: no sprint line for a project without sprints" "sprint:"
sb scaffold subproject Example infra --repos example-infra
mkdir -p "$tmp/code/example-infra/.git"
on_branch "$tmp/code/example-infra" 'ref: refs/heads/feature/EX-3-infra'
sb session-check --cwd "$tmp/code/example-infra"
out_has "session-check: the subproject of the repo" "project: Example
subproject: infra"
out_has "session-check: the subproject's repo names its ticket too" "ticket: EX-3"
sb session-check --cwd "$tmp/code/outside"
rc_is "session-check: exit 0 in a repo outside every project" 0
out_is "session-check: silent in a repo outside every project" ""
sb session-check --cwd "$tmp/nowhere"
out_is "session-check: silent for a folder that is not there" ""
printf '%s\n' '# Index' '' 'No table.' >"$vault/CLAUDE.md"
sb session-check --cwd "$R"
rc_is "session-check: exit 0 with an index that has no table" 0
out_is "session-check: silent with an index that has no table" ""
run env SECOND_BRAIN_VAULT="$tmp/userdir" "$SB" session-check --cwd "$R"
out_is "session-check: only the one line with no vault, in a repo of a project" "second-brain: no vault is set up - run /odsb:vault-setup init"
fi

# ---------------------------------------------------------------- delivery and validation
PROFILE="$vault/$P/claude/profile.md"
if block 145; then
doc Example
chk "delivery: ok with the template's values" delivery Example "ok | 0 | -"
chk "validation: ok for a project with no repo that has its note" validation Example "ok | 0 | -"
rm "$vault/$P/claude/validation.md"
doc Example
chk "validation: a project with no repo names a missing note" validation Example "warn | 1 | claude/validation.md:missing"
reset
edit "$PROFILE" 's/^delivery: direct$/delivery: always/; s/^spec_home: vault$/spec_home: Repo/'
sb task set EX-3 delivery=spec
awk '{ print } /^status: / { print "delivery: someday" }' "$T/EX-1/README.md" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$T/EX-1/README.md"
doc Example
chk "delivery: a profile value and a task value that are not allowed, never another letter case" delivery Example "warn | 2 | profile:delivery, EX-1:delivery"
is "delivery: the fix names the values" "$(fix_of delivery)" \
  "write delivery as direct or spec, spec_home and validation_home as vault or repo, and lead_check_minutes as 10, 12, 15, 20, 30 or 60, or remove the key"
reset
# lcm <value>: add lead_check_minutes to the profile, under validation_home.
lcm() {
  awk -v v="$1" '{ print } /^validation_home: / { print "lead_check_minutes: " v }' "$PROFILE" >"$tmp/edit.tmp" &&
    cat "$tmp/edit.tmp" >"$PROFILE"
}
for v in 10 12 15 20 30 60 '""'; do
  lcm "$v"
  doc Example
  chk "delivery: lead_check_minutes $v is taken" delivery Example "ok | 0 | -"
  reset
done
for v in 25 abc '"45"'; do
  lcm "$v"
  doc Example
  chk "delivery: lead_check_minutes $v warns" delivery Example "warn | 1 | lead_check_minutes:invalid"
  reset
done
lcm 45
edit "$PROFILE" 's/^delivery: direct$/delivery: always/'
doc Example
chk "delivery: lead_check_minutes is named after the profile's own keys" delivery Example \
  "warn | 2 | profile:delivery, lead_check_minutes:invalid"
reset
mkdir -p "$tmp/code/example-api" "$tmp/code/example-infra"
edit "$PROFILE" "s|^repos: .*|repos: [example-api]|; s|^repos_root: .*|repos_root: \"$tmp/code\"|"
doc Example
chk "validation: a repo with no section in the vault note" validation Example "warn | 1 | example-api:no-section"
is "validation: the fix names validation new" "$(fix_of validation)" \
  "run second-brain validation new <project> <repo> for a missing file or section, then write the repo's steps in place of each <...> line"
sb validation new Example example-api
doc Example
chk "validation: a section that still holds the template's text" validation Example "warn | 1 | example-api:placeholders"
edit "$vault/$P/claude/validation.md" '/^- <What a pass needs: every check above passes, the user steps work, nothing else broke\.>$/!s/^- <.*>$/- make test/'
doc Example
chk "validation: a section with only the A pass line left unfilled" validation Example "warn | 1 | example-api:placeholders"
edit "$vault/$P/claude/validation.md" 's/^- <.*>$/- make test/'
doc Example
chk "validation: ok once the section is written" validation Example "ok | 0 | -"
grep -F -- '- <A tool is a skill by name, ' "$here/templates/validation-repo.md.tmpl" >>"$vault/$P/claude/validation.md"
doc Example
chk "validation: a section that still holds the user steps' tool line" validation Example "warn | 1 | example-api:placeholders"
edit "$vault/$P/claude/validation.md" '/^- <A tool is a skill by name, /d'
printf '%s\n' '- <The steps that use the change as a user does, and what to look for.>' >>"$vault/$P/claude/validation.md"
doc Example
chk "validation: a section that still holds a retired placeholder of an earlier template" validation Example "warn | 1 | example-api:placeholders"
edit "$vault/$P/claude/validation.md" '/^- <The steps that use the change as a user does, /d'
doc Example
chk "validation: ok again once the retired line is gone" validation Example "ok | 0 | -"
# The lines the template held before each check said when it runs are still flagged.
for old in '- <Each command that must pass, such as the tests, linter and build, and what it proves.>' \
  '- <One line per step that uses the change as a user does: its tool, then what to look for.>'; do
  if grep -qF -- "$old" "$here/templates/validation-repo.md.tmpl"; then
    fail "validation: the template no longer holds the retired line: $old"
  else
    pass "validation: the template no longer holds the retired line: ${old:0:40}"
  fi
  printf '%s\n' "$old" >>"$vault/$P/claude/validation.md"
  doc Example
  chk "validation: a section that still holds the retired line ${old:0:40}" validation Example "warn | 1 | example-api:placeholders"
  edit "$vault/$P/claude/validation.md" '$d'
  doc Example
  chk "validation: ok again without ${old:0:40}" validation Example "ok | 0 | -"
done
sb scaffold subproject Example infra --repos example-infra
edit "$vault/$P/claude/subprojects/infra.md" 's/^validation_home: ""$/validation_home: repo/; s/^delivery: ""$/delivery: later/'
doc Example
chk "validation: a subproject's repo home with no file" validation Example "warn | 1 | example-infra:missing"
chk "delivery: a subproject note's value is named by the subproject" delivery Example "warn | 1 | infra:delivery"
sb validation new Example example-infra
doc Example
chk "validation: a repo file that still holds the template's text" validation Example "warn | 1 | example-infra:placeholders"
rm -rf "$tmp/code/example-infra"
doc Example
chk "validation: a repo home whose folder is missing is left to the repos check" validation Example "ok | 0 | -"
fi
# ---------------------------------------------------------------- validation edge cases
if block 10; then
mkdir -p "$tmp/code/example-api"
edit "$PROFILE" "s|^repos: .*|repos: [example-api, example-ghost]|; s|^repos_root: .*|repos_root: \"\"|; s|^repo_paths: .*|repo_paths: [\"example-api=$tmp/code/example-api\"]|; s|^validation_home: vault\$|validation_home: repo|"
doc Example
chk "validation: a repo home with no recorded location is named, as repos says nothing" validation Example "warn | 2 | example-api:missing, example-ghost:no-location"
chk "validation: while repos leaves it" repos Example "ok | 0 | -"
printf '# example-api validation\n\n## example-api\n' >"$tmp/code/example-api/validation.md"
doc Example
chk "validation: a section with nothing under its heading" validation Example "warn | 2 | example-api:empty, example-ghost:no-location"
fi

# ---------------------------------------------------------------- spec-trace
TRACE_FIX="add the criterion's AC<n> to the - Serves: line of the requirement that meets it, or write a requirement for it, and give every requirement a - Serves: line that names only criteria the story has"
# criteria <ID> <line>...: put the lines under the task's ## Acceptance criteria, in place of its own.
criteria() {
  printf '%s\n' "${@:2}" >"$tmp/lines"
  SB_L="$tmp/lines" awk '
    /^## / { on = 0 }
    $0 == "## Acceptance criteria" { print; print ""; while ((getline l < ENVIRON["SB_L"]) > 0) print l; print ""; on = 1; next }
    !on' "$T/$1/README.md" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$T/$1/README.md"
}
# reqs <file> <line>...: write a requirements.md that holds the lines under its title.
reqs() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' '# Requirements' '' "${@:2}" >"$1"
}
# trace_files <dir>: list the task READMEs and spec files under a folder, for a cmp after --fix.
trace_files() { find "$1" -type f \( -name README.md -o -name requirements.md -o -name design.md -o -name tasks.md \) | LC_ALL=C sort; }
SPR="$T/EX-3/spec/requirements.md"
if block 107; then
doc Example
chk "spec-trace: a project with no spec story is ok" spec-trace Example "ok | 0 | -"
sb task set EX-3 delivery=spec
sb spec new EX-3
rc_is "spec-trace: spec new writes the spec of a story" 0
doc Example
chk "spec-trace: the template's Serves line names R1, and leaves every criterion unserved" spec-trace Example \
  "warn | 3 | EX-3:AC1, EX-3:AC2, EX-3:R1"
is "spec-trace: the fix says how to add the criterion or a requirement" "$(fix_of spec-trace)" "$TRACE_FIX"
is "spec-trace: the Fix of checks.md says the same, code marks aside" \
  "$(awk '/^### / { on = ($0 == "### spec-trace") } on && /^- Fix: / { print }' "$CHECKS" | tr -d '`' | grep -c -F "$TRACE_FIX")" "1"
rc_is "spec-trace: a warning leaves exit 0" 0

# R3: a criterion no requirement serves.
criteria EX-3 '- [ ] one' '- [x] two' '- [X] three'
reqs "$SPR" '## R1 - one' '' '- Serves: AC1' '' 'The first.' '' '## R2 - three' '' '- Serves: AC3'
doc Example
chk "spec-trace: three criteria with AC1 and AC3 served name <ID>:AC2 alone" spec-trace Example "warn | 1 | EX-3:AC2"
doc Example --json
out_has "spec-trace: --json holds the same row" \
  "{\"result\": \"warn\", \"check\": \"spec-trace\", \"scope\": \"Example\", \"count\": 1, \"offenders\": [\"EX-3:AC2\"], \"fix\": \"$TRACE_FIX\"}"
criteria EX-3 '- [ ] one' '- [ ] two' '- [ ] three'
doc Example
chk "spec-trace: a ticked criterion, - [x] or - [X], is counted like an unticked one" spec-trace Example "warn | 1 | EX-3:AC2"
reqs "$SPR" '## R1 - one' '' '- Serves: AC1' '' '## R2 - three' '' '- Serves: ac2,AC3'
doc Example
chk "spec-trace: ok once a Serves line names it, in any letter case and with no blank after a comma" spec-trace Example "ok | 0 | -"
reqs "$SPR" '## R1 - one' '' '- Serves: AC1' '' '## Notes' '' '- Serves: AC2' '' '# Part two' '' '- Serves: AC2' '' '## R2 - three' '' '- Serves: AC3'
doc Example
chk "spec-trace: a Serves line under a heading that is no requirement is not read" spec-trace Example "warn | 1 | EX-3:AC2"
reqs "$SPR" '## R1 - one' '' '- Serves: AC1' '' '## R2 - three' '' '- SERVES: AC3' '- serves: AC2'
doc Example
chk "spec-trace: every Serves line of a requirement counts, the word in any letter case" spec-trace Example "ok | 0 | -"
criteria EX-3 '- [ ] one' '' '### More' '' '- [ ] two' '' '```' '- [ ] not a criterion' '```' '- [ ]three is not one either'
reqs "$SPR" '## R1 - one' '' '- Serves: AC1, AC2'
doc Example
chk "spec-trace: a ### subsection keeps the criteria; fenced code and a marker with no blank after it do not count" \
  spec-trace Example "ok | 0 | -"
reqs "$SPR" '## R1 - one' '' '- Serves: AC1, AC3'
doc Example
chk "spec-trace: so AC3 is a criterion the story does not have" spec-trace Example "warn | 2 | EX-3:AC2, EX-3:R1"

# R4: a requirement with no criterion.
criteria EX-3 '- [ ] one' '- [ ] two' '- [ ] three' '- [ ] four'
reqs "$SPR" '## R1 - all' '' '- Serves: AC1, AC2, AC3, AC4' '' '## R2 - none' '' 'No Serves line.'
doc Example
chk "spec-trace: a requirement with no Serves line is <ID>:R<n>" spec-trace Example "warn | 1 | EX-3:R2"
reqs "$SPR" '## R1 - all' '' '- Serves: AC1, AC2, AC3, AC4' '' '## R2 - five' '' '- Serves: AC5'
doc Example
chk "spec-trace: AC5 on a story with four criteria is <ID>:R<n>" spec-trace Example "warn | 1 | EX-3:R2"
reqs "$SPR" '## R1 - all' '' '- Serves: AC1, AC2, AC3, AC4' '' '## R2 - empty' '' '- Serves:'
doc Example
chk "spec-trace: an empty Serves line is <ID>:R<n>" spec-trace Example "warn | 1 | EX-3:R2"
reqs "$SPR" '## R1 - three' '' '- Serves: AC1, AC2, AC3' '' '## R2 - fenced' '' '```' '- Serves: AC4' '```' '' '  ~~~' '- Serves: AC4' '  ~~~'
doc Example
chk "spec-trace: a Serves line inside fenced code is not read" spec-trace Example "warn | 2 | EX-3:AC4, EX-3:R2"
is "spec-trace: <ID>:AC<n> and <ID>:R<n> share the one row" "$(printf '%s\n' "$OUT" | grep -c ' | spec-trace | Example | ')" "1"
reqs "$SPR" '## R1 - three' '' '- Serves: AC1, AC2, AC3, AC0' '' '## R2 - four' '' '- Serves: AC4, , ' '' '## r3 - five' '' '- Serves: AC1, AC5'
doc Example
chk "spec-trace: a bad item makes its requirement an offender, as written, and its good items still serve" spec-trace Example "warn | 2 | EX-3:R1, EX-3:r3"
reqs "$SPR" '## R1 - all' '' '- Serves: AC1, AC2, AC3, AC4' '' '## R2 - one' '' '## R2 - two' '' '## Rx - not one' ''
doc Example
chk "spec-trace: two sections with one id are each read, the id named once" spec-trace Example "warn | 1 | EX-3:R2"
# The BOM sits on the first requirement's heading, so a BOM left in place would hide R1.
printf '\357\273\277## R1 - one\r\n\r\n- Serves: AC1, AC3\r\n\r\n## R2 - none\r\n' >"$SPR"
to_crlf "$T/EX-3/README.md"
doc Example
chk "spec-trace: CRLF files and a BOM read as the same lines" spec-trace Example "warn | 3 | EX-3:AC2, EX-3:AC4, EX-3:R2"
edit "$T/EX-3/README.md" '/^## Acceptance criteria/d'
reqs "$SPR" '## R1 - one' '' '- Serves: AC1'
doc Example
chk "spec-trace: a story with no criteria section has no criterion" spec-trace Example "warn | 1 | EX-3:R1"
reqs "$SPR" 'No requirement yet.'
doc Example
chk "spec-trace: and with no requirement either, no offender" spec-trace Example "ok | 0 | -"
fi

# R5: the stories the check reads. Each requirements.md here serves nothing.
if block 84; then
reqs "$T/EX-1/spec/requirements.md" '## R1 - one'
reqs "$SPR" '## R1 - one'
doc Example
chk "spec-trace: a direct story is not read, its spec files aside" spec-trace Example "ok | 0 | -"
sb task set EX-3 delivery=spec
doc Example
chk "spec-trace: a spec story whose requirements serve nothing" spec-trace Example "warn | 3 | EX-3:AC1, EX-3:AC2, EX-3:R1"
sb task set EX-3 status=done
doc Example
chk "spec-trace: a done story is not read" spec-trace Example "ok | 0 | -"
sb task set EX-3 status=abandoned
doc Example
chk "spec-trace: an abandoned story is not read" spec-trace Example "ok | 0 | -"
sb task set EX-3 status=in-progress
doc Example
chk "spec-trace: set back to in-progress, its offenders come back" spec-trace Example "warn | 3 | EX-3:AC1, EX-3:AC2, EX-3:R1"
edit "$T/EX-3/README.md" '/^status: /d'
doc Example
chk "spec-trace: a story with no status is read" spec-trace Example "warn | 3 | EX-3:AC1, EX-3:AC2, EX-3:R1"
edit "$T/EX-3/README.md" 's/^title: /status: someday\
title: /'
doc Example
chk "spec-trace: a story whose status is not one of the five is read" spec-trace Example "warn | 3 | EX-3:AC1, EX-3:AC2, EX-3:R1"
edit "$PROFILE" 's/^task_layout: flat$/task_layout: archive/'
sb task set EX-3 status=done
sb task archive EX-3
rc_is "spec-trace: the story is archived" 0
doc Example
chk "spec-trace: an archived story is not read" spec-trace Example "ok | 0 | -"
sb task set EX-3 status=in-progress
doc Example
chk "spec-trace: one set back to open in the archive is read, from the spec folder that moved with it" spec-trace Example \
  "warn | 3 | EX-3:AC1, EX-3:AC2, EX-3:R1"
chk "spec-trace: and task-layout names it too" task-layout Example "warn | 1 | EX-3:open"
reset
reqs "$T/EX-1/spec/requirements.md" '## R1 - one'
reqs "$SPR" '## R1 - one'
edit "$PROFILE" 's/^delivery: direct$/delivery: spec/'
sb task set EX-3 delivery=direct
doc Example
chk "spec-trace: with delivery: spec in the profile, a story with no key is read and a task's own direct is not" spec-trace Example \
  "warn | 3 | EX-1:AC1, EX-1:AC2, EX-1:R1"
sb task set EX-3 delivery=
doc Example
chk "spec-trace: the offenders of two stories share the one row, the first five shown" spec-trace Example \
  "warn | 6 | EX-1:AC1, EX-1:AC2, EX-1:R1, EX-3:AC1, EX-3:AC2"
rm -rf "$T/EX-1/spec" "$T/EX-3/spec"
doc Example
chk "spec-trace: a spec story with no spec folder is not read" spec-trace Example "ok | 0 | -"
mkdir -p "$T/EX-3/spec"
doc Example
chk "spec-trace: nor one with a spec folder and no requirements.md" spec-trace Example "ok | 0 | -"
fi

# R5: a spec in the repo.
if block 44; then
mkdir -p "$tmp/spec-code/example-api"
edit "$PROFILE" "s|^repos: .*|repos: [example-api]|; s|^repos_root: .*|repos_root: \"$tmp/spec-code\"|; s/^spec_home: vault\$/spec_home: repo/; s/^validation_home: vault\$/validation_home: repo/"
sb task set EX-3 delivery=spec
sb spec new EX-3
rc_is "spec-trace: spec new writes the spec in the repo" 0
reqs "$SPR" '## R1 - all' '' '- Serves: AC1, AC2'
doc Example
chk "spec-trace: with spec_home: repo, the spec in the repo is read, not one in the task folder" spec-trace Example \
  "warn | 3 | EX-3:AC1, EX-3:AC2, EX-3:R1"
{ trace_files "$vault/$P/tasks"; trace_files "$tmp/spec-code"; } >"$tmp/trace.files"
while IFS= read -r f; do
  mkdir -p "$tmp/before$(dirname "$f")"
  cp "$f" "$tmp/before$f"
done <"$tmp/trace.files"
doc Example --fix
is "spec-trace: --fix fixes nothing for it" "$(printf '%s\n' "$OUT" | head -1)" "fixed: nothing"
chk "spec-trace: and the row is the same after --fix" spec-trace Example "warn | 3 | EX-3:AC1, EX-3:AC2, EX-3:R1"
changed=""
while IFS= read -r f; do
  cmp -s "$tmp/before$f" "$f" || changed="$changed $f"
done <"$tmp/trace.files"
is "spec-trace: --fix leaves every spec file and task README byte-identical" \
  "$(trace_files "$vault/$P/tasks" | grep -c .)/$(trace_files "$tmp/spec-code" | grep -c .)/$changed" "5/3/"
edit "$PROFILE" 's|^repos_root: .*|repos_root: ""|'
doc Example
chk "spec-trace: a repo with no recorded location gives no offender" spec-trace Example "ok | 0 | -"
chk "spec-trace: the validation check names the location" validation Example "warn | 1 | example-api:no-location"
edit "$PROFILE" "s|^repos_root: .*|repos_root: \"$tmp/spec-code\"|"
mv "$tmp/spec-code/example-api" "$tmp/spec-code/example-api.away"
doc Example
chk "spec-trace: a repo whose folder is missing gives no offender" spec-trace Example "ok | 0 | -"
chk "spec-trace: the repos check names the folder" repos Example "warn | 1 | example-api"
mv "$tmp/spec-code/example-api.away" "$tmp/spec-code/example-api"
# A repo story that cannot be reached comes first; a vault story after it is still read.
sb scaffold subproject Example infra --repos example-infra
edit "$vault/$P/claude/subprojects/infra.md" 's/^spec_home: ""$/spec_home: vault/'
edit "$PROFILE" 's|^repos_root: .*|repos_root: ""|; s/^delivery: direct$/delivery: spec/'
sb task set EX-3 subproject=infra
reqs "$T/EX-3/spec/requirements.md" '## R1 - one' '' '- Serves: AC1'
doc Example
chk "spec-trace: a story whose repo cannot be reached hides no later story" spec-trace Example "warn | 1 | EX-3:AC2"
edit "$vault/$P/claude/subprojects/infra.md" 's/^delivery: ""$/delivery: direct/'
sb task set EX-3 delivery=
doc Example
chk "spec-trace: a subproject's delivery holds for its story with no key of its own" spec-trace Example "ok | 0 | -"
fi

# ---------------------------------------------------------------- result
if [ -f "$tmp/undefined" ]; then
  while IFS= read -r cmd; do fail "undefined command: $cmd"; done <"$tmp/undefined"
fi
[ "$n_block" -eq "${#costs[@]}" ] || fail "blocks: $n_block ran, and the script writes ${#costs[@]}"
if [ "$shard_total" -gt 0 ]; then
  cost_all=0
  for f in "${costs[@]}"; do cost_all=$((cost_all + f)); done
  [ -n "$held" ] || held=" none"
  printf '\nshard %s/%s: %s of the %s blocks (%s), cost %s of %s\n' \
    "$shard_n" "$shard_total" "$n_held" "$n_block" "${held# }" "$cost_held" "$cost_all"
fi
printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
