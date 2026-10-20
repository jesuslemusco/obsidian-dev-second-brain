#!/usr/bin/env bash
# Scratch-vault tests for doctor and session-check: breaks one thing at a time and reads the rows.
# Usage: bash scripts/test-doctor.sh
set -u

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

# ---------------------------------------------------------------- syntax
for f in "$here/scripts/lib/doctor.sh" "$here/scripts/test-doctor.sh"; do
  if bash -n "$f" 2>"$tmp/stderr"; then pass "syntax: ${f#"$here"/}"; else fail "syntax: ${f#"$here"/}" "$(cat "$tmp/stderr")"; fi
done

# ---------------------------------------------------------------- setup
sb scaffold vault
sb scaffold project Example --path "$P" --keys EX
sb task new EX-1 --project Example --title "First task"
sb task new EX-2 --project Example --title "Second task"
sb task new EX-3 --project Example --title "Third task"
sb sprint open Example --end 2026-01-14
sb task set EX-1 status=in-progress sprint=2026-01-14
sb task set EX-2 status=done
rc_is "setup: the scratch vault is built" 0
cp -R "$vault" "$tmp/pristine"

# ---------------------------------------------------------------- fresh vault
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
CHECKS="$here/skills/vault-doctor/checks.md"
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
reset

# ---------------------------------------------------------------- index rows and version
# add_row <name> <path> <keys>: add one row to the index table.
add_row() {
  printf '| %s | %s | %s | A row the suite added. |\n' "$1" "$2" "$3" >>"$vault/CLAUDE.md"
}
# index_back: put the index back as it was after the setup.
index_back() {
  cp "$tmp/pristine/CLAUDE.md" "$vault/CLAUDE.md"
}
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
reset

# ---------------------------------------------------------------- global-rules
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
reset

# ---------------------------------------------------------------- links, double-registration
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
reset

# ---------------------------------------------------------------- sizes
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
reset

# ---------------------------------------------------------------- profile, board
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

# ---------------------------------------------------------------- paths that leave the vault
# A project outside the vault, with a mark in every file the doctor could open there.
O="$tmp/outside-proj"
mkdir -p "$O/claude/skills/OUTMARK-3" "$O/tasks/OUTMARK-1" "$O/sprints"
cp "$vault/$P/claude/profile.md" "$O/claude/profile.md"
printf '%s\n' '---' 'name: OUTMARK-3' '---' 'A skill with no description.' >"$O/claude/skills/OUTMARK-3/SKILL.md"
sed 's/sprint == "2026-01-14"/sprint == "OUTMARK-2"/' "$T/tasks.base" >"$O/tasks/tasks.base"
sed 's/^  - status\/active$/  - status\/done/' "$T/EX-1/README.md" >"$O/tasks/OUTMARK-1/README.md"
sed 's/2026-01-14/2031-01-01/g' "$vault/$P/sprints/2026-01-14.md" >"$O/sprints/2031-01-01.md"
cp "$O/tasks/OUTMARK-1/README.md" "$tmp/outside.before"
# marks: count the lines of the last run, stdout and stderr, that hold something read out there.
marks() { printf '%s\n%s\n' "$OUT" "$ERR" | grep -c -e OUTMARK -e 2031-01-01 || true; }
# set_root <key> <raw value>: write one root of the profile as it is given.
set_root() {
  SB_K="$1" SB_V="$2" awk 'index($0, ENVIRON["SB_K"] ":") == 1 { print ENVIRON["SB_K"] ": " ENVIRON["SB_V"]; next } { print }' \
    "$vault/$P/claude/profile.md" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$vault/$P/claude/profile.md"
}
add_row Out ../outside-proj OUT
doc
chk "outside: a row with a .. part fails the index" index vault "fail | 1 | Out:no-folder"
is "outside: it gets no project rows, and nothing under it is read" "$(scope_rows Out)/$(marks)" "0/0"
chk "outside: the skill in its claude folder is not scanned" descriptions vault "ok | 0 | -"
doc Out
rc_is "outside: named, the row still gives exit 1" 1
is "outside: named, it gets the vault rows alone" "$(printf '%s\n' "$OUT" | grep -c ' | ')/$(scope_rows Out)/$(marks)" "11/0/0"
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
reset

# ---------------------------------------------------------------- hubs
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
reset

# ---------------------------------------------------------------- placeholders
HUB="$vault/$P/README.md"
CHUB="$vault/$P/claude/README.md"
PF="$vault/$P/claude/profile.md"
doc Example
rc_is "placeholders: a warning leaves exit 0" 0
chk "placeholders: a fresh scaffold warns, one offender per line, as its path under the project" placeholders Example \
  "warn | 25 | README.md:14, claude/README.md:20, claude/README.md:21, claude/profile.md:39, claude/profile.md:40"
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
chk "placeholders: one leftover line in a filled hub" placeholders Example "warn | 1 | claude/README.md:22"
edit "$PF" 's/^- Tracker: none\.$/- Tracker: Jira. <where tickets live, where epics usually sit, any ticket markup to keep>./'
doc Example
chk "placeholders: a line filled in part still warns" placeholders Example "warn | 2 | claude/README.md:22, claude/profile.md:39"
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
chk "placeholders: a subproject note is read against its own template" placeholders Example "warn | 1 | claude/subprojects/infra.md:31"
reset

# ---------------------------------------------------------------- task frontmatter and status
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
reset

# ---------------------------------------------------------------- yaml traps
# add_alias <ID> <raw item>: add one raw line under aliases, after the first alias.
add_alias() {
  SB_ID="$1" SB_ITEM="$2" awk '{ print } $0 == "  - " ENVIRON["SB_ID"] { print "  - " ENVIRON["SB_ITEM"] }' \
    "$T/$1/README.md" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$T/$1/README.md"
}
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
reset

# ---------------------------------------------------------------- alias-unique, no-readme
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
reset

# ---------------------------------------------------------------- task-location
# stray <vault path> <raw type>: write a note with that type, wherever the path says.
stray() {
  mkdir -p "$vault/${1%/*}"
  printf '%s\n' '---' "type: $2" '---' '' '# A note' >"$vault/$1"
}
doc Example
chk "task-location: ok on new tasks" task-location Example "ok | 0 | -"
stray "$P/docs/billing/EX-2.md" task
doc Example
rc_is "task-location: a warning leaves exit 0" 0
chk "task-location: a task filed under its topic warns, as its path under the project" task-location Example "warn | 1 | docs/billing/EX-2.md"
is "task-location: the fix names the move command and where a task goes" "$(fix_of task-location)" \
  "move it with second-brain move to $P/tasks/<ID>/README.md, and tie it to its topic with a tag"
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
reset

# ---------------------------------------------------------------- roots written another way
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

# ---------------------------------------------------------------- task-layout
# layout <value>: set task_layout in the profile.
layout() { edit "$vault/$P/claude/profile.md" "s/^task_layout: .*/task_layout: $1/"; }
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
chk "task-layout: a done task with no date is old enough to archive" task-layout Example "warn | 1 | EX-2:to-archive"
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
set_root tasks_root ../../../outside-proj/tasks
mkdir -p "$O/tasks/EX-2"
cp "$T/EX-2/README.md" "$O/tasks/EX-2/README.md"
doc Example --fix
is "task-layout --fix: nothing is moved through a tasks root that leaves the project" \
  "$(printf '%s\n' "$OUT" | head -1)/$(ls "$O/tasks" | tr '\n' ' ')" "fixed: nothing/EX-2 OUTMARK-1 tasks.base "
rm -r "$O/tasks/EX-2"
reset

# ---------------------------------------------------------------- topic-tags
# add_topic_line <line>: add one line under ## Topics in the profile.
add_topic_line() {
  SB_LINE="$1" awk '{ print } $0 == "## Topics" { print ""; print ENVIRON["SB_LINE"] }' \
    "$vault/$P/claude/profile.md" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$vault/$P/claude/profile.md"
}
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
reset

# ---------------------------------------------------------------- repos
# set_repos <repos> <repos_root> <repo_paths>: write the three repository keys of the profile.
set_repos() {
  edit "$vault/$P/claude/profile.md" "s|^repos: .*|repos: $1|; s|^repos_root: .*|repos_root: \"$2\"|; s|^repo_paths: .*|repo_paths: $3|"
}
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
reset

# ---------------------------------------------------------------- code-doc-map
PROFILE="$vault/$P/claude/profile.md"
# add_map_row <row>: add one table row to the Code to doc map, after the template's placeholder row.
add_map_row() {
  SB_ROW="$1" awk '{ print } $0 == "| <repo> | <kind of change> | <surfaces> |" { print ENVIRON["SB_ROW"] }' \
    "$PROFILE" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$PROFILE"
}
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
reset

# ---------------------------------------------------------------- subprojects
SUBS="$vault/$P/claude/subprojects"
edit "$T/EX-3/README.md" 's/^epic: "-"$/epic: "-"\
subproject: ghost/'
doc Example
is "subprojects: no row for a project with no subproject" "$(row subprojects)" ""
is "task-subproject: no row for a project with no subproject, whatever its tasks say" "$(row task-subproject)" ""
is "subprojects: a project with no subproject keeps twenty rows" "$(scope_rows Example)" "20"
edit "$T/tasks.base" 's/name: By subproject$/name: By repo/'
doc Example
chk "board: a project with no subproject is not asked for the By subproject view" board Example "ok | 0 | -"
mkdir -p "$tmp/code/example-api" "$tmp/code/example-infra"
set_repos '[example-api]' "$tmp/code" '[]'
add_map_row '| example-api | a new endpoint | the API reference |'
sb scaffold subproject Example infra --repos example-infra
rc_is "subprojects: scaffold subproject exits 0" 0
doc Example
is "subprojects: two more rows once the project has one" "$(scope_rows Example)" "22"
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
reset

# ---------------------------------------------------------------- sprints
S="$vault/$P/sprints"
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
reset

# ---------------------------------------------------------------- sprints, after a close
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
reset

# ---------------------------------------------------------------- links in tasks, line endings
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
# to_crlf <file> [last line]: give the file CRLF endings, down to a line number when one is given.
to_crlf() {
  SB_N="${2:-0}" awk '{ if (ENVIRON["SB_N"] == 0 || NR <= ENVIRON["SB_N"]) printf "%s\r\n", $0; else print }' "$1" >"$tmp/edit.tmp" &&
    cat "$tmp/edit.tmp" >"$1"
}
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
reset

# ---------------------------------------------------------------- depends-on
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
reset

# ---------------------------------------------------------------- --fix
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
is "--fix: the whole table follows" "$(printf '%s\n' "$OUT" | grep -c ' | ')" "31"
chk "--fix: the status tags follow the status" status-tag Example "ok | 0 | -"
chk "--fix: a missing status is still reported" needs-a-status Example "warn | 1 | EX-1"
is "--fix: a missing status is never set" "$(cmp -s "$tmp/EX-1.before" "$T/EX-1/README.md" && printf same)" "same"
is "--fix: one line changed" "$(diff "$tmp/EX-2.before" "$T/EX-2/README.md" | grep '^[<>]' | tr '\n' '/')" \
  "<   - status/active/>   - status/done/"
is "--fix: one line changed in a CRLF file" "$(diff "$tmp/EX-3.before" "$T/EX-3/README.md" | grep -c '^[<>]')" "2"
is "--fix: a CRLF file stays CRLF" "$(awk '!/\r$/ { n++ } END { print n + 0 }' "$T/EX-3/README.md")" "0"
doc Example --fix
is "--fix: nothing left to change" "$(printf '%s\n' "$OUT" | head -1)" "fixed: nothing"
reset

# ---------------------------------------------------------------- --json
add_alias EX-1 "'Say \"hi\" \\ there'"
add_alias EX-2 "'Say \"hi\" \\ there'"
mkdir -p "$T/EX-7" "$T/EX-8"
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
print(names.index("repos") - names.index("code-doc-map"), by["code-doc-map"]["result"], by["code-doc-map"]["offenders"])' <"$tmp/doctor.json" 2>&1 | tr -d '\r')"
  is "--json: 31 objects, six keys, strings escaped, offenders as arrays, code-doc-map then repos then sprints" "$got" \
    "31 True${NL}Say \"hi\" \\ there${NL}2 ['EX-7', 'EX-8'] []${NL}1 warn ['gone-repo']${NL}1 warn ['example-api', 'gone-repo']"
  run env SECOND_BRAIN_VAULT="$tmp/userdir" "$SB" doctor --json
  rc_is "--json: exit 2 with no vault" 2
  got="$(printf '%s\n' "$OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d), d[0]["check"], d[0]["result"])' 2>&1 | tr -d '\r')"
  is "--json: the pointer row alone with no vault" "$got" "1 pointer fail"
else
  printf 'skip  --json: python3 is not installed\n'
fi
reset

# ---------------------------------------------------------------- two projects
sb scaffold project Two --path projects/two --keys TW
sb task new TW-1 --project Two --title "Other task"
edit "$vault/projects/two/tasks/TW-1/README.md" 's/^epic: "-"$/epic: -/'
doc
is "two projects: twenty rows for each" "$(scope_rows Example)/$(scope_rows Two)" "20/20"
is "two projects: the vault rows come first, in the contract's order" "$(printf '%s\n' "$OUT" | head -11 | awk -F' [|] ' '{ printf "%s ", $2 }')" \
  "pointer index conventions pull-request import global-rules links double-registration always-loaded-size descriptions skill-size "
is "two projects: the project rows in the contract's order" "$(printf '%s\n' "$OUT" | grep ' | Two | ' | awk -F' [|] ' '{ printf "%s ", $2 }')" \
  "profile board hubs placeholders task-frontmatter needs-a-status status-tag yaml-traps alias-unique no-readme task-location task-layout topic-tags code-doc-map repos sprints unresolved-links bare-links line-endings depends-on "
chk "two projects: each row names its project" yaml-traps Two "fail | 1 | TW-1:epic"
chk "two projects: the other project is clean" yaml-traps Example "ok | 0 | -"
doc example
rc_is "a named project: its name is matched without case, and another project's failure is left out" 0
is "a named project: only its rows, after the vault rows" "$(scope_rows vault)/$(scope_rows Example)/$(scope_rows Two)" "11/20/0"

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
reset

# ---------------------------------------------------------------- a project without sprints
reset
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

# ---------------------------------------------------------------- arguments and setup
doc Nope
rc_is "a project that is not in the index: exit 1" 1
doc --bogus
rc_is "an unknown flag: exit 5" 5
run env SECOND_BRAIN_VAULT="$tmp/userdir" "$SB" doctor
rc_is "no vault: exit 2" 2
out_is "no vault: the pointer row fails first" "fail | pointer | vault | 1 | SECOND_BRAIN_VAULT | run /obsidian-dev-second-brain:vault-setup init"

# ---------------------------------------------------------------- session-check
sb session-check
rc_is "session-check: exit 0 when set up" 0
out_is "session-check: silent when set up" ""
run env SECOND_BRAIN_VAULT="$tmp/userdir" "$SB" session-check
rc_is "session-check: exit 0 with no vault" 0
out_is "session-check: one line with no vault" "second-brain: no vault is set up - run /obsidian-dev-second-brain:vault-setup init"
mkdir -p "$tmp/bare/.obsidian"
run env SECOND_BRAIN_VAULT="$tmp/bare" "$SB" session-check
rc_is "session-check: exit 0 for a vault with no index" 0
out_has "session-check: one line for a vault with no index" "no vault is set up"
run env -u SECOND_BRAIN_VAULT "$SB" session-check
out_has "session-check: one line when the link directory holds no pointer" "no vault is set up"
sb pointer set "$vault"
run env -u SECOND_BRAIN_VAULT "$SB" session-check
out_is "session-check: silent when the pointer of the link directory leads to the vault" ""

# ---------------------------------------------------------------- session-check, the session block
reset
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
out_is "session-check: only the one line with no vault, in a repo of a project" "second-brain: no vault is set up - run /obsidian-dev-second-brain:vault-setup init"
reset

# ---------------------------------------------------------------- result
printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
