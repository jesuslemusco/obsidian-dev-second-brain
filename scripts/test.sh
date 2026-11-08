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

# ---------------------------------------------------------------- syntax
for f in "$here/bin/second-brain" "$here"/scripts/lib/*.sh "$here"/scripts/*.sh; do
  if bash -n "$f" 2>"$tmp/stderr"; then pass "syntax: ${f#"$here"/}"; else fail "syntax: ${f#"$here"/}" "$(cat "$tmp/stderr")"; fi
done
is "awk: every program that loads the shared functions runs in the C locale" \
  "$(grep -n '"$(sb_awk_lib)"' "$here"/scripts/lib/*.sh | grep -v 'LC_ALL=C' || true)" ""

# ---------------------------------------------------------------- undefined commands
# Each suite's head and result block, with a call to a command it never defines in between.
# Bash 3.2, on macOS, never calls command_not_found_handle; the same lines run on Linux.
if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
  for f in "$here"/scripts/test*.sh; do
    probe="$(
      awk '/^# -----/ { exit } { print }' "$f"
      printf '%s\n' 'no_such_check "a check"'
      sed -n '/^# -* result$/,$p' "$f"
    )"
    run env TMPDIR="$tmp" "$BASH" -c "$probe" "$f"
    rc_is "undefined command: ${f#"$here"/} exits 1" 1
    out_has "undefined command: ${f#"$here"/} names it as a failure" "FAIL  undefined command: no_such_check at line "
  done
fi

# ---------------------------------------------------------------- dispatcher
sb version
rc_is "version: exit 0" 0
is "version: matches plugin.json" "$OUT" "$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$here/.claude-plugin/plugin.json" | head -1)"
is "plugin: the namespace is odsb, and the marketplace entry keeps the install name" \
  "$(sed -n 's/^  "name": "\([^"]*\)".*/\1/p' "$here/.claude-plugin/plugin.json")/$(sed -n 's/^      "name": "\([^"]*\)".*/\1/p' "$here/.claude-plugin/marketplace.json")" \
  "odsb/obsidian-dev-second-brain"
sb no-such-command
rc_is "unknown command: exit 5" 5
err_has "unknown command: prints usage" "usage: second-brain"
sb
rc_is "no command: exit 5" 5
sb help
rc_is "help: exit 0" 0
for c in "task tag" "task alias" "task dep <ID> add|remove <ID>" "sprint next" "sprint set" "board <project> [view] [--subproject S] |" "--tasks-root R" "--topics-root R" "--sprints-root R" \
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
out_is "scaffold vault: lists the four files" "CLAUDE.md
obsidian-conventions.md
claude/README.md
claude/pull-request.md"
exists "scaffold vault: index" "$vault/CLAUDE.md"
exists "scaffold vault: conventions" "$vault/obsidian-conventions.md"
exists "scaffold vault: vault Claude hub" "$vault/claude/README.md"
is "pull request format: the goal first, then the four headings, in order and bold" "$(grep '^## \*\*' "$vault/claude/pull-request.md" | tr '\n' '|')" \
  "## **Goal**|## **What was changed?**|## **What was added?**|## **Dependencies:**|## **Risks:**|"
is "pull request format: every bullet of the format starts with a bold label" \
  "$(awk '/^```/ { on = !on; next } on && /^- / { n++; if (/^- \*\*<part>:\*\* </) b++ } END { print b + 0 "/" n + 0 }' "$vault/claude/pull-request.md")" "4/4"
is "pull request format: the goal is one or two lines, not a bullet" \
  "$(awk '/^## \*\*Goal\*\*$/ { on = 1; next } /^## / { on = 0 } on && NF' "$vault/claude/pull-request.md")" \
  "<why this pull request exists, in one or two lines>"
is "pull request format: the rules, word for word" "$(section_of "$vault/claude/pull-request.md" 'The rules')" \
  "- Write the description only from \`git log <target>..<source>\` and
  \`git diff <target>...<source>\`, never from memory of the work.
- \`<source>\` is the branch that holds the work. \`<target>\` is the branch it merges into, as the
  remote has it after a \`git fetch\`: usually \`origin/main\`.
- Name both branches in the commands: the checkout may be on another one.
- Use the five bold headings below, in this order, and no others.
- Under each heading after \`Goal\`, write a few bullets in short plain English, one line each.
- Start each bullet with the part it is about, in bold: \`- **doctor:** warns on an old index\`.
- Name the file, the command or the setting; leave out what the diff shows line by line.
- Under a heading with nothing to say, write \`- **None.**\`"
line_is "pull request format: version property" "$vault/claude/pull-request.md" "pull_request_version: 3"
file_has "pull request format: a project's own note wins" "$vault/claude/pull-request.md" \
  'A project that keeps its own'
line_is "index: the pull request rule points to the note, and a project's own copy wins" "$vault/CLAUDE.md" \
  "  \`<Path>/claude/pull-request.md\` wins."
line_is "index: the pull request rule names the vault note through the pointer" "$vault/CLAUDE.md" \
  "  \`~/.claude/second-brain-vault/claude/pull-request.md\`; a project's own"
line_is "index: the pull request rule opens its bullet" "$vault/CLAUDE.md" \
  "- Write a pull request description in the format of"
file_has "vault Claude hub: names the pull request format note" "$vault/claude/README.md" \
  '`pull-request.md` here is the format of every pull request'
line_is "vault Claude hub: what it holds" "$vault/claude/README.md" \
  'Your own skills and agents that serve every project live here:'
line_is "vault Claude hub: a project's skill or agent goes in its claude folder" "$vault/claude/README.md" \
  '1. Create the file here, or in `<project>/claude/` for one that serves a single project.'
line_is "vault Claude hub: name equals the folder or file name" "$vault/claude/README.md" \
  '2. Give its frontmatter at least `name`, the same as the skill folder or agent file name, and a'
line_is "vault Claude hub: the description is one sentence" "$vault/claude/README.md" \
  '   one-sentence `description`.'
line_is "vault Claude hub: a project-specific name has the project prefix" "$vault/claude/README.md" \
  '3. Names share one namespace. Prefix a project-specific name with the project: `example-deploy`.'
line_is "vault Claude hub: link --apply registers it" "$vault/claude/README.md" \
  '4. Run `second-brain link --apply` to link it into `~/.claude/skills/` or `~/.claude/agents/`.'
line_is "vault Claude hub: the vault file is the only copy" "$vault/claude/README.md" \
  '   The file in the vault stays the only copy.'
line_is "vault Claude hub: each one is listed with its use when line" "$vault/claude/README.md" \
  '5. List it below, or in the project'"'"'s `claude/README.md`, with its "use when" line.'
line_is "vault Claude hub: a rename, move or delete fixes the link" "$vault/claude/README.md" \
  '6. On a rename, move or delete, fix or remove the link in the same change.'
line_is "vault Claude hub: link --check lists dangling links" "$vault/claude/README.md" \
  '   `second-brain link --check` lists dangling links.'
is "index: the pull request rule is in the section for every session" \
  "$(($(lineno "$vault/CLAUDE.md" 'pull-request.md') < $(lineno "$vault/CLAUDE.md" '## Working on a project or on notes')))" "1"
line_is "index: table header as in the contract" "$vault/CLAUDE.md" "| Project | Path | Keys | Use when |"
line_is "index: version property" "$vault/CLAUDE.md" "index_version: 4"
rules="$(section_of "$vault/CLAUDE.md" "Rules for notes that most often go wrong" | tr '\n' ' ' | tr -s ' ')"
is "index: the rules for notes hold the search and read rule" "$(printf '%s\n' "$rules" | grep -c -F 'Find and read notes with the helper, never with grep, cat or sed on vault files: `second-brain find`, `search` (also for related notes before a decision), `task head`, then `outline` and a ranged read, and a whole note last.')" "1"
is "index: what holds in every session comes before what holds for a project" \
  "$(($(lineno "$vault/CLAUDE.md" '## In every session') < $(lineno "$vault/CLAUDE.md" '## Working on a project or on notes')))" "1"
file_has "index: a new skill is not created straight in the link directory" "$vault/CLAUDE.md" '~/.claude/skills'
every="$(awk '/^## / { on = ($0 == "## In every session") } on' "$vault/CLAUDE.md")"
is "index: the every-session section says where the vault is" "$(printf '%s\n' "$every" | tr '\n' ' ' | grep -c -E 'The vault is +`~/\.claude/second-brain-vault/`')" "1"
is "index: it names the command that registers a new skill" "$(printf '%s\n' "$every" | grep -c -F 'second-brain link --apply')" "1"
file_lacks "index: no line says to ignore the file" "$vault/CLAUDE.md" "ignore this file"
file_has "index: story-tracker is named for any question or change on a ticket" "$vault/CLAUDE.md" "\`story-tracker\` for any question or change on a ticket (where it stands, a standup, an"
is "index: the ticket text rule is said once, in the bullet that sends it to story-tracker" "$(grep -ci 'ticket text' "$vault/CLAUDE.md")" "1"
file_has "index: ticket text is never written freehand and goes to story-tracker" "$vault/CLAUDE.md" "- Ticket text is never written freehand. Use \`story-tracker\`"
is "index: the ticket text rule sits under the rules that most often go wrong" \
  "$(($(lineno "$vault/CLAUDE.md" '## Rules for notes that most often go wrong') < $(lineno "$vault/CLAUDE.md" '- Ticket text is never')))" "1"
file_has "index: a rule about one project goes under the project's Rules" "$vault/CLAUDE.md" 'A rule about one project goes under `## Rules` in `<Path>/claude/README.md`'
is "index: the rule placement holds in every session" \
  "$(($(lineno "$vault/CLAUDE.md" 'A rule about one project') < $(lineno "$vault/CLAUDE.md" '## Working on a project or on notes')))" "1"
file_has "index: the subproject note is read with the project's rules" "$vault/CLAUDE.md" 'the `claude/subprojects/<name>.md` that `second-brain context` names'
file_has "index: a new skill is added by the steps of the vault Claude hub" "$vault/CLAUDE.md" \
  '- Add it by the steps under `## Adding a skill or agent` in the vault'"'"'s `claude/README.md`.'
line_is "vault Claude hub: holds the heading the index points to" "$vault/claude/README.md" '## Adding a skill or agent'
line_is "index: Claude Code loads a new skill only after link --apply" "$vault/CLAUDE.md" \
  '  Claude Code loads it only after `second-brain link --apply`.'
file_has "index: only a rule for every project goes in the link directory's CLAUDE.md" "$vault/CLAUDE.md" \
  'Only a rule for every project goes in `~/.claude/CLAUDE.md`. Unsure which: ask.'
line_is "index: a plugin skill or agent is called for its work" "$vault/CLAUDE.md" \
  '- Call a plugin skill or agent for its work, even when the helper alone could answer. Skills:'
file_has "index: a task note is never filed inside its topic" "$vault/CLAUDE.md" '- Never file a task note inside the topic it is about.'
line_is "index: notes move and rename with the helper" "$vault/CLAUDE.md" \
  '- Move and rename notes with `second-brain move` and `second-brain rename`, never `mv`.'
line_is "conventions: version property" "$vault/obsidian-conventions.md" "conventions_version: 7"
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
out_has "conventions: a named section, any case" "Every substantive note carries frontmatter."
out_lacks "conventions: stops at the next section" "In a tag, spaces and underscores"
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
printf -- '- my own pull request rule\n' >>"$vault/claude/pull-request.md"
sb scaffold vault
err_has "scaffold vault again: names the pull request note that exists" "exists: claude/pull-request.md"
file_has "scaffold vault again: does not overwrite the pull request note" "$vault/claude/pull-request.md" "my own pull request rule"
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
$P/claude/validation.md
$P/tasks/README.md
$P/tasks/tasks.base
$P/docs/README.md
$P/sprints/README.md"
line_is "index: one row for the project" "$vault/CLAUDE.md" "| Example | $P | EX, EXOPS | Anything about Example. |"
line_is "profile: ticket keys" "$vault/$P/claude/profile.md" "ticket_keys: [EX, EXOPS]"
line_is "profile: sprints are on by default" "$vault/$P/claude/profile.md" "uses_sprints: true"
line_is "board: folder filter" "$vault/$P/tasks/tasks.base" "    - file.inFolder(\"$P/tasks\")"
line_is "board: folder depth is the path segments plus one" "$vault/$P/tasks/tasks.base" '        - file.folder.split("/").length == 6'
line_is "board: the archive folder is accepted too" "$vault/$P/tasks/tasks.base" "            - file.inFolder(\"$P/tasks/archive\")"
line_is "board: an archived task sits two folders deeper" "$vault/$P/tasks/tasks.base" '            - file.folder.split("/").length == 8'
line_is "board: sprint literal placeholder" "$vault/$P/tasks/tasks.base" '        - sprint == "none"'
line_is "board: a Depends on column" "$vault/$P/tasks/tasks.base" "    displayName: Depends on"
line_is "board: a Subproject column" "$vault/$P/tasks/tasks.base" "    displayName: Subproject"
for v in Active "Current sprint" "By topic" "By subproject" "Needs a status" All; do
  line_is "board: view $v" "$vault/$P/tasks/tasks.base" "    name: $v"
done
file_has "tasks hub: names the By subproject view" "$vault/$P/tasks/README.md" '`By subproject`, `Needs a status` and `All`'
line_is "tasks hub: embedded board" "$vault/$P/tasks/README.md" "![[$P/tasks/tasks.base#Active]]"
line_is "tasks hub: unique alias" "$vault/$P/tasks/README.md" '  - "Example Tasks Hub"'
line_is "tasks hub: up-link in the full-path form" "$vault/$P/tasks/README.md" "> Up: [[$P/README|Example Hub]]"
line_is "tasks hub: names its folder" "$vault/$P/tasks/README.md" 'The hub of `tasks/`.'
line_is "project hub: the Claude hub line" "$vault/$P/README.md" "- [[$P/claude/README|Example Claude Hub]] - rules, profile, skills and agents"
line_is "project hub: the placeholder paragraph" "$vault/$P/README.md" "<One paragraph: what the project is, who it is for, and where its code lives.>"
line_is "Claude hub: what Claude reads first" "$vault/$P/claude/README.md" "What Claude reads before it works on Example: the rules below, then the profile."
line_is "Claude hub: the profile line" "$vault/$P/claude/README.md" "- Profile: [[$P/claude/profile|Example Profile]] - ticket keys, folders, sprint"
line_is "Claude hub: the profile line ends at the doc map" "$vault/$P/claude/README.md" "  cadence, repos and the doc map."
line_is "Claude hub: the rule placeholder" "$vault/$P/claude/README.md" "- <A rule Claude must follow in this project, one per bullet.>"
line_is "Claude hub: the live systems placeholder" "$vault/$P/claude/README.md" "- <Live systems: what is read-only unless you ask for a write. Detail goes in the profile.>"
line_is "Claude hub: where project skills live, and their prefix" "$vault/$P/claude/README.md" 'Project skills live in `claude/skills/<name>/SKILL.md`. Prefix each name with the project.'
line_is "Claude hub: where project agents live" "$vault/$P/claude/README.md" 'Project agents live in `claude/agents/<name>.md`.'
PF="$vault/$P/claude/profile.md"
line_is "profile: facts only, the workflow is in the skills" "$PF" "The one settings note for Example. Keep it to facts: the workflow lives in the skills."
line_is "profile: only archive moves a task" "$PF" '- `task_layout:` above is `flat`, the default, or `archive`. Only `archive` moves a done or'
line_is "profile: the archive command and folder" "$PF" '  abandoned task, once, with `second-brain task archive <ID>`, to `archive/<YYYY>/<ID>/` under'
line_is "profile: with archive only, when a done task is due for the archive" "$PF" '- With `archive`, `archive_after_days:` is how many days a done task waits, counted from its newest'
line_is "profile: the doctor names a due task and doctor --fix archives it" "$PF" '  status note or its sprint'"'"'s end, before the doctor names it and `doctor --fix` archives it.'
file_has "profile: delivery is what a story with none of its own falls back to" "$PF" \
  '- `delivery:` above is `direct | spec`, what a story with no `delivery` of its own falls back'
line_is "profile: delivery points to the contract" "$PF" \
  "  as \`### Profile frontmatter\` in the plugin's \`docs/contract.md\` says."
line_is "profile: where spec_home puts the spec" "$PF" '- `spec_home:` puts the spec in the task'"'"'s folder (`vault`) or in `spec/<ID>/` in the repo (`repo`).'
line_is "profile: where validation_home puts validation.md" "$PF" '- `validation_home:` puts `validation.md` in `claude/` (`vault`) or at each repo'"'"'s root (`repo`).'
line_is "profile: list every repository" "$PF" '- List every repository'"'"'s folder name in `repos:` above.'
line_is "profile: what repos_root holds" "$PF" '- `repos_root:` is where the repositories usually sit on this machine, absolute or starting with `~`.'
line_is "profile: turning sprints off" "$PF" '- Set `uses_sprints: false` above to turn sprints off; the cadence lines then do not apply.'
line_is "profile: docs follow production" "$PF" 'Docs follow production: a doc is updated only after its change is confirmed deployed to production,'
line_is "profile: the branch production runs" "$PF" 'which runs `production_branch` above, or `base_branch` when that is empty. Say here how a'
line_is "profile: every repository has a row in the code to doc map" "$PF" 'Every repository in `repos` has at least one row, added in the same change as the repository.'
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
out_has "profile --keys: the task layout, flat by default" "task_layout: flat"
out_has "profile --keys: the days a done task waits for the archive" "archive_after_days: 14"
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
line_is "task new: the branch line names the canonical branch" "$T1" '**Branch:** `none yet` - <the branch; the canonical one when several carry the ticket id>'
line_is "task new: the description's context line" "$T1" "<Context: what is broken or missing, who asked, where in the system it lives.>"
line_is "task new: findings only from evidence, else the section goes" "$T1" "<Only when evidence exists: conclusion first, then the evidence. Otherwise delete the section.>"
line_is "task new: a criterion someone else can check" "$T1" "- [ ] <a condition someone else can check>"
line_is "task new: the ticket's top 4 criteria only" "$T1" "- [ ] <the top 4 only, as in the ticket>"
line_is "task new: what the code confirmed" "$T1" "<What the code confirmed: files, functions, behaviour, any mismatch with the ticket.>"
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
line_is "task new --envs: a later ticket is added as an alias" "$T7" "- Add a later environment's ticket to \`envs:\` and run \`second-brain task alias EX-7 add <ID>\`."
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

# ---------------------------------------------------------------- task head --json
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
sb task head EX-1
text="$OUT"
sb task head EX-1 --json
rc_is "task head --json: exit 0" 0
json_ok "task head --json: parses as JSON"
json_is "task head --json: the same fields as the text, in its order" "$HEAD_PY" "$text"
out_has "task head --json: one object, a key per line" \
  "{${NL}  \"id\": \"EX-1\",${NL}  \"path\": \"$P/tasks/EX-1/README.md\","
out_has "task head --json: quotes are escaped" '"title": "Fix: totals \"rounded\" twice"'
out_has "task head --json: topics is an array" '"topics": ["billing/invoices"]'
out_has "task head --json: no environment set is an empty array" '"envs": []'
out_has "task head --json: a missing value is a dash" '"epic": "-"'
is "task head --json: the object closes on the last line" "$(printf '%s\n' "$OUT" | tail -1)" "}"
sb task head EX-7 --json
out_has "task head --json: each environment is an item" \
  '"envs": ["dev:EX-7:done", "qa:EX-70:planned"]'
sb task head EX-7
text="$OUT"
sb task head --json EX-7
json_is "task head --json: the flag may come first" "$HEAD_PY" "$text"
sb task head EX-404 --json
rc_is "task head --json: unknown task gives exit 1" 1
out_is "task head --json: and prints nothing" ""
sb task bogus
rc_is "task: unknown subcommand gives exit 5" 5

# ---------------------------------------------------------------- task docs
cp "$T2" "$tmp/t2.saved"
cp "$T3" "$tmp/t3.saved"
edit "$T2" 's/^## Status notes$/## Docs to update\
\
- [ ] docs\/billing.md - say totals round once\
- [x] README.md - already done\
  - [ ] docs\/api.md - the rounding field\
\
```\
- [ ] docs\/example.md - only an example in a fence\
```\
\
## Status notes/'
edit "$T3" 's/^## Status notes$/## Docs to update\
\
- [x] docs\/billing.md - all ticked\
\
## Status notes/'
sb task docs EX-2,EX-3 EX-1
rc_is "task docs: exit 0" 0
out_is "task docs: only the task with unticked lines, its path, then those lines" "EX-2 $P/tasks/EX-2/README.md
- [ ] docs/billing.md - say totals round once
  - [ ] docs/api.md - the rounding field"
out_lacks "task docs: a line inside a fenced code block is skipped" "example.md"
sb task docs "EX-2 EX-3"
rc_is "task docs: an id is never split at a space" 1
sb task docs EX-3 --project Example
rc_is "task docs: every line ticked exits 0" 0
out_is "task docs: every line ticked prints nothing" ""
sb task docs EX-404
rc_is "task docs: unknown task gives exit 1" 1
sb task docs
rc_is "task docs: no id gives exit 5" 5
cp "$tmp/t2.saved" "$T2"
cp "$tmp/t3.saved" "$T3"

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

# ---------------------------------------------------------------- task dep
T5="$vault/$P/tasks/EX-5/README.md"
sb task dep EX-5 add EX-2
rc_is "task dep add: exit 0" 0
out_is "task dep add: prints the resulting links" "[[$P/tasks/EX-2/README|EX-2]]"
line_is "task dep add: the link is a quoted path link" "$T5" "  - \"[[$P/tasks/EX-2/README|EX-2]]\""
is "task dep add: depends_on lands after carried_from" "$(($(lineno "$T5" 'depends_on:') - $(lineno "$T5" 'carried_from:')))" "1"
cp "$T5" "$tmp/t5.before"
sb task dep EX-5 add EX-2
is "task dep add: a task it has is not added twice" "$(cmp -s "$tmp/t5.before" "$T5"; echo $?)" "0"
sb task dep EX-5 add EX-3
out_is "task dep add: appended last" "[[$P/tasks/EX-2/README|EX-2]]
[[$P/tasks/EX-3/README|EX-3]]"
sb task dep EX-5 add EX-70
out_has "task dep add: an alias links the task's folder" "[[$P/tasks/EX-7/README|EX-7]]"
sb task dep EX-5 remove EX-7
out_is "task dep remove: by folder id" "[[$P/tasks/EX-2/README|EX-2]]
[[$P/tasks/EX-3/README|EX-3]]"
cp "$T5" "$tmp/t5.before"
sb task dep EX-5 remove EX-1
rc_is "task dep remove: a task it lacks, exit 0" 0
is "task dep remove: a task it lacks changes nothing" "$(cmp -s "$tmp/t5.before" "$T5"; echo $?)" "0"
sb task dep EX-5 add EX-5
rc_is "task dep: the task itself gives exit 5" 5
sb task dep EX-5 add EX-55
rc_is "task dep: the task itself by an alias gives exit 5" 5
sb task dep EX-5 add EX-404
rc_is "task dep: an unknown task gives exit 1" 1
sb task dep EX-404 add EX-2
rc_is "task dep: an unknown task to edit gives exit 1" 1
is "task dep: nothing written on refusal" "$(cmp -s "$tmp/t5.before" "$T5"; echo $?)" "0"
sb task dep EX-5 block EX-2
rc_is "task dep: unknown action gives exit 5" 5
sb task dep EX-5 add
rc_is "task dep: no task named gives exit 5" 5
sb task set EX-5 depends_on=x
rc_is "task set: depends_on is a list, exit 5" 5
err_has "task set: depends_on points to task dep" "task dep"
sb task dep EX-2 add TWO-1
out_is "task dep add: a task of another project" "[[$P2/tasks/TWO-1/README|TWO-1]]"
sb task dep EX-2 remove TWO-1
out_is "task dep remove: the last one prints a dash" "-"
line_is "task dep remove: an empty list stays" "$T2" "depends_on: []"
edit "$T2" "s#^depends_on: \[\]\$#depends_on: [\"[[$P/tasks/EX-3/README.md|third]]\"]#"
file_has "task dep remove: the hand-written link is there first" "$T2" "README.md|third]]"
sb task dep EX-2 remove EX-3
out_is "task dep remove: matches a hand-written link by its path" "-"
edit "$T2" "s#^depends_on: \[\]\$#depends_on: [\"[[$P/tasks/EX-3/README|EX-3]]\"]#"
sb task dep EX-2 add EX-1
out_is "task dep add: to an inline list" "[[$P/tasks/EX-3/README|EX-3]]
[[$P/tasks/EX-1/README|EX-1]]"
line_is "task dep add: the inline item stays quoted" "$T2" "  - \"[[$P/tasks/EX-3/README|EX-3]]\""
line_is "task dep add: the new item after it" "$T2" "  - \"[[$P/tasks/EX-1/README|EX-1]]\""
file_lacks "task dep add: no inline list left" "$T2" "depends_on: ["
sb task dep EX-2 remove EX-3
sb task dep EX-2 remove EX-1
out_is "task dep remove: both gone" "-"
sb task dep EX-6 add EX-2
is "task dep: CRLF kept" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
line_is "task dep: CRLF line written" "$T6" "  - \"[[$P/tasks/EX-2/README|EX-2]]\"$CR"
sb task dep EX-6 remove EX-2

# ---------------------------------------------------------------- board
edit "$vault/$P/tasks/EX-7/README.md" 's/^status: planned$/status: active/'
sb board Example
rc_is "board: exit 0" 0
out_lacks "board: no source line" "source:"
out_has "board: row format" 'EX-1 | Fix: totals "rounded" twice | in-review | 2026-10-14 | billing/invoices | feature/EX-1-fix | Check: the #1 thing | - | -'
is "board Active: planned, in-progress and in-review only" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "EX-5 EX-1 EX-6 EX-2 "
sb board Example All
is "board All: every task folder" "$(lines "$OUT")" "8"
is "board: every row has nine cells" "$(printf '%s\n' "$OUT" | awk -F' [|] ' 'NF != 9' | grep -c . || true)" "0"
out_has "board: envs column for an environment set" "EX-7 | Per environment | active | - | - | none yet | Promote to qa | dev:EX-7:done,qa:EX-70:planned"
out_has "board: title from the heading when the property is absent" "legacy-task | Legacy task | - | - | - | - | - | -"
is "board: depends_on column, each task with its status" "$(printf '%s\n' "$OUT" | grep '^EX-5 ' | awk -F' [|] ' '{ print $9 }')" "EX-2:planned,EX-3:done"
cp "$T5" "$tmp/t5.before"
edit "$T5" "s#^  - \"\[\[$P/tasks/EX-3/README|EX-3\]\]\"\$#  - \"[[$P/tasks/EX-99/README|EX-99]]\"#"
sb board Example
is "board: a link to no note shows missing" "$(printf '%s\n' "$OUT" | grep '^EX-5 ' | awk -F' [|] ' '{ print $9 }')" "EX-2:planned,EX-99:missing"
cp "$tmp/t5.before" "$T5"
edit "$T5" "s#^  - \"\[\[$P/tasks/EX-2/README|EX-2\]\]\"\$#  - \"[[$P/tasks/ex-2/readme|ex-2]]\"#"
sb board Example
is "board: a link in other letter case shows the task's own id" "$(printf '%s\n' "$OUT" | grep '^EX-5 ' | awk -F' [|] ' '{ print $9 }')" "EX-2:planned,EX-3:done"
cp "$tmp/t5.before" "$T5"
sb board Example All
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
several="$OUT"
sb search Example "qbeta${TAB}QALPHA"
out_is "search: a tab between two words parts them as a space does" "$several"
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
line_is "sprint note: its dates and the board view of its tasks" "$S1" "2026-10-01 to 2026-10-14. Its tasks are the board's \`Current sprint\` view."
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
$R/claude/validation.md
$R/plan/tasks/README.md
$R/plan/tasks/tasks.base
$R/knowledge/README.md
$R/cadence/sprints/README.md"
line_is "scaffold roots: tasks root in the profile" "$vault/$R/claude/profile.md" "tasks_root: plan/tasks"
line_is "scaffold roots: topics root in the profile" "$vault/$R/claude/profile.md" "topics_root: knowledge"
line_is "scaffold roots: sprints root in the profile" "$vault/$R/claude/profile.md" "sprints_root: cadence/sprints"
for d in tasks docs sprints; do absent "scaffold roots: no default $d folder" "$vault/$R/$d"; done
line_is "scaffold roots: board folder is the tasks root" "$vault/$R/plan/tasks/tasks.base" "    - file.inFolder(\"$R/plan/tasks\")"
line_is "scaffold roots: board depth counts the nested tasks root" "$vault/$R/plan/tasks/tasks.base" '        - file.folder.split("/").length == 5'
line_is "scaffold roots: the archive depth counts it too" "$vault/$R/plan/tasks/tasks.base" '            - file.folder.split("/").length == 7'
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
out_is "other roots: board reads the tasks root" "RT-1 | First | planned | - | api | none yet | Frame the story | - | -"
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
$D/claude/validation.md
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
$N/claude/validation.md
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
for v in Active "By topic" "By subproject" "Needs a status" All; do
  line_is "no sprints: board view $v" "$vault/$N/tasks/tasks.base" "    name: $v"
done
is "no sprints: the board keeps its five views whole" "$(grep -c '^  - type: table$' "$vault/$N/tasks/tasks.base")" "5"
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

# ---------------------------------------------------------------- subprojects
M="work/multi"
MF="$vault/$M/claude/profile.md"
mkdir -p "$tmp/mcode/multi-app/src" "$tmp/mcode/multi-infra/mod/deep" "$tmp/far/multi-tools/lib" "$tmp/loose/multi-loose/x"
sb scaffold project Multi --path "$M" --keys MU
edit "$MF" "s|^repos: \\[\\]\$|repos: [multi-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/mcode\"|"
edit "$MF" 's|^base_branch: main$|base_branch: develop|; s|^production_branch: ""$|production_branch: release|; s|^environments: \[\]$|environments: [dev, prod]|'
sb subproject Multi
rc_is "subproject: a project with none exits 0" 0
out_is "subproject: and lists nothing" ""
sb context --cwd "$tmp/mcode/multi-app/src"
is "subproject: with none, context keeps its four lines" "$(lines "$OUT")" "4"
out_lacks "subproject: with none, context has no subproject line" "subproject:"
sb repo Multi
out_is "subproject: with none, repo lists the profile's repos" "multi-app${TAB}$oT/mcode/multi-app${TAB}ok"
sb subproject
rc_is "subproject: no project gives exit 5" 5
sb subproject Multi infra extra
rc_is "subproject: too many arguments give exit 5" 5
sb subproject Nope
rc_is "subproject: an unknown project gives exit 1" 1
sb subproject Multi infra
rc_is "subproject: an unknown subproject gives exit 1" 1
err_has "subproject: the message says how to list them" "second-brain subproject Multi"

sb scaffold subproject Multi infra --repos multi-infra
rc_is "scaffold subproject: exit 0" 0
out_is "scaffold subproject: prints the note and the docs hub" "$M/claude/subprojects/infra.md
$M/docs/infra/README.md"
line_is "scaffold subproject: the note's type" "$vault/$M/claude/subprojects/infra.md" "type: subproject"
line_is "scaffold subproject: the note's repos" "$vault/$M/claude/subprojects/infra.md" "repos: [multi-infra]"
line_is "scaffold subproject: the note has a Rules section" "$vault/$M/claude/subprojects/infra.md" "## Rules"
line_is "scaffold subproject: the note says how to read its settings" "$vault/$M/claude/subprojects/infra.md" 'Read these settings with `second-brain subproject "Multi" "infra"`, which fills in'
line_is "scaffold subproject: the first repo is the default for branch checks" "$vault/$M/claude/subprojects/infra.md" '- `repos`: the subproject'"'"'s repositories, the first the default for branch checks.'
line_is "scaffold subproject: an empty key takes the profile's value" "$vault/$M/claude/subprojects/infra.md" '- `base_branch` to `validation_home` are the profile'"'"'s keys. One left empty takes the value in'
line_is "scaffold subproject: the note links the profile" "$vault/$M/claude/subprojects/infra.md" "  [[$M/claude/profile|Multi Profile]]."
line_is "scaffold subproject: the note links its docs" "$vault/$M/claude/subprojects/infra.md" "- Its docs live in [[$M/docs/infra/README|Multi infra Docs]]."
line_is "scaffold subproject: the Rules placeholder" "$vault/$M/claude/subprojects/infra.md" "- <A rule Claude must follow in this subproject, one per bullet.>"
line_is "scaffold subproject: the docs hub links up to the topics hub" "$vault/$M/docs/infra/README.md" "> Up: [[$M/docs/README|Multi Docs Hub]]"
line_is "scaffold subproject: the docs hub points to the note" "$vault/$M/docs/infra/README.md" "The subproject's repositories, branches and rules are in [[$M/claude/subprojects/infra|Multi infra Subproject]]."
line_is "scaffold subproject: the docs hub says each folder is a topic" "$vault/$M/docs/infra/README.md" "Each folder under this one is a topic, tagged with its path below the topics root."
line_is "scaffold subproject: the topics hub links down to it" "$vault/$M/docs/README.md" "- [[$M/docs/infra/README|Multi infra Docs]] - the docs of the infra subproject"
sb scaffold subproject Multi infra
rc_is "scaffold subproject: again, exit 0" 0
err_has "scaffold subproject: again, it overwrites nothing" "exists: $M/claude/subprojects/infra.md"
is "scaffold subproject: again, the topics hub keeps one line" "$(grep -c "docs/infra/README|" "$vault/$M/docs/README.md")" "1"
sb scaffold subproject Multi INFRA
rc_is "scaffold subproject: the same name in another case gives exit 6" 6
sb scaffold subproject Multi tools --repos MULTI-INFRA
rc_is "scaffold subproject: a repository of another subproject gives exit 6" 6
err_has "scaffold subproject: the message names the owner" "already belongs to the subproject infra"
absent "scaffold subproject: nothing is written on a refusal" "$vault/$M/claude/subprojects/tools.md"
for bad in "a/b" ".hidden" "-x" "a|b" "a#b" "a:b" "a*b" "a?b" "a<b" "a>b"; do
  sb scaffold subproject Multi "$bad"
  rc_is "scaffold subproject: the name $bad gives exit 5" 5
done
sb scaffold subproject Multi tools --repos "multi tools"
rc_is "scaffold subproject: a repository name with a blank gives exit 5" 5
sb scaffold subproject Nope tools
rc_is "scaffold subproject: an unknown project gives exit 1" 1

sb subproject Multi
out_is "subproject: one row per subproject: name, repos, docs folder" "infra${TAB}multi-infra${TAB}$M/docs/infra"
sb subproject Multi Infra
rc_is "subproject name: matched without case" 0
out_is "subproject name: every key falls back to the profile while the note leaves it empty" "subproject: infra
note: $M/claude/subprojects/infra.md
docs: $M/docs/infra
repos: multi-infra
base_branch: develop
production_branch: release
branch_pattern: feature/<ID>-<slug>
environments: dev, prod
delivery: direct
spec_home: vault
validation_home: vault
repo_paths: multi-infra=$oT/mcode/multi-infra"
SF="$vault/$M/claude/subprojects/infra.md"
edit "$SF" 's|^base_branch: ""$|base_branch: main|; s|^branch_pattern: ""$|branch_pattern: "infra/<ID>"|; s|^environments: \[\]$|environments:\
  - staging\
  - live|'
sb subproject Multi infra
out_is "subproject name: its own values win, the rest fall back" "subproject: infra
note: $M/claude/subprojects/infra.md
docs: $M/docs/infra
repos: multi-infra
base_branch: main
production_branch: release
branch_pattern: infra/<ID>
environments: staging, live
delivery: direct
spec_home: vault
validation_home: vault
repo_paths: multi-infra=$oT/mcode/multi-infra"

sb repo Multi
out_is "repo: the subproject's repositories follow the profile's" "multi-app${TAB}$oT/mcode/multi-app${TAB}ok
multi-infra${TAB}$oT/mcode/multi-infra${TAB}ok"
sb project --cwd "$tmp/mcode/multi-infra/mod/deep"
out_is "project --cwd: a subproject's repository resolves to its project" "Multi${TAB}$M${TAB}MU"
sb subproject Multi --cwd "$tmp/mcode/multi-infra/mod/deep"
rc_is "subproject --cwd: exit 0 inside its repository" 0
out_has "subproject --cwd: the settings of the subproject" "subproject: infra"
sb subproject Multi --cwd "$tmp/mcode/multi-app/src"
rc_is "subproject --cwd: a repository of the profile alone is in no subproject, exit 1" 1
sb context --cwd "$tmp/mcode/multi-infra/mod"
is "context: five lines in a subproject's repository" "$(lines "$OUT")" "5"
out_has "context: the subproject line, after project_path" "project_path: $M
subproject: infra
sprint:"
sb context --cwd "$tmp/mcode/multi-app"
out_lacks "context: no subproject line in the profile's own repository" "subproject:"

sb scaffold subproject Multi tools --repos multi-tools
SF2="$vault/$M/claude/subprojects/tools.md"
edit "$SF2" "s|^repo_paths: \\[\\]\$|repo_paths: [\"multi-tools=$tmp/far/multi-tools\"]|"
sb repo Multi multi-tools
out_is "repo: a subproject's repo_paths entry gives the location" "$oT/far/multi-tools"
sb subproject Multi --cwd "$tmp/far/multi-tools/lib"
out_has "subproject --cwd: found through the note's repo_paths" "subproject: tools"
sb subproject Multi tools
out_has "subproject name: its own repo_paths" "repo_paths: multi-tools=$oT/far/multi-tools"
sb scaffold subproject Multi loose --repos multi-loose
edit "$MF" 's|^repos_root: .*$|repos_root: ""|'
sb subproject Multi --cwd "$tmp/loose/multi-loose/x"
rc_is "subproject --cwd: with no location recorded, the folder name decides" 0
out_has "subproject --cwd: the folder name names the subproject" "subproject: loose"
sb subproject Multi loose
out_has "subproject name: no location recorded gives no repo_paths" "repo_paths: -"
mkdir -p "$tmp/loose/multi-loose/vendor/multi-app/y"
sb subproject Multi --cwd "$tmp/loose/multi-loose/vendor/multi-app/y"
rc_is "subproject --cwd: a deeper folder named for a repo of the profile alone gives exit 1" 1
sb context --cwd "$tmp/loose/multi-loose/vendor/multi-app/y"
out_lacks "context: no subproject line under a deeper repo of the profile alone" "subproject:"
sb subproject Multi --cwd "$tmp/far"
rc_is "subproject --cwd: a folder in no repository gives exit 1" 1
edit "$MF" "s|^repos_root: \"\"\$|repos_root: \"$tmp/mcode\"|"
sb scaffold subproject Multi tasks --repos tasks
sb subproject Multi --cwd "$vault/$M/tasks"
rc_is "subproject --cwd: a folder of the vault is in no subproject, whatever its name" 1
sb context --cwd "$vault/$M/tasks"
out_lacks "context: no subproject line in a folder of the vault" "subproject:"
out_has "context: the vault folder still gives the project" "project: Multi"
sb scaffold subproject Multi dup --repos "dup-a, DUP-A ,dup-b"
line_is "scaffold subproject: a repo named twice, in any case, is written once" "$vault/$M/claude/subprojects/dup.md" "repos: [dup-a, dup-b]"
printf '%s\n' '---' 'type: subproject' 'repos: [MULTI-APP]' '---' >"$vault/$M/claude/subprojects/again.md"
sb repo Multi
is "repo: a subproject repo that the profile lists in another case is listed once" "$(printf '%s\n' "$OUT" | grep -ic '^multi-app')" "1"
rm -f "$vault/$M/claude/subprojects/again.md"
cp "$MF" "$tmp/multi-profile"
: >"$MF"
printf '%s\n' '---' 'type: subproject' "repos_root: \"$tmp/mcode\"" 'repos: [rr-x]' '---' >"$vault/$M/claude/subprojects/rr.md"
sb repo Multi
out_has "repo: an empty profile gives no repos_root, not a note's" "rr-x${TAB}-${TAB}unknown"
rm -f "$vault/$M/claude/subprojects/rr.md"
cp "$tmp/multi-profile" "$MF"

sb task new MU-1 --project Multi --title "Infra work" --subproject INFRA --envs
rc_is "task new --subproject: exit 0" 0
TM="$vault/$M/tasks/MU-1/README.md"
line_is "task new --subproject: the key holds the note's own spelling" "$TM" "subproject: infra"
line_is "task new --subproject --envs: the subproject's first environment" "$TM" "  staging: { id: MU-1, status: planned }"
is "task new --subproject: the key sits after epic" "$(($(lineno "$TM" 'subproject:') - $(lineno "$TM" 'epic:')))" "1"
sb task head MU-1
out_has "task head: shows the subproject" "subproject: infra"
text="$OUT"
sb task head MU-1 --json
out_has "task head --json: the subproject key, before topics" \
  ",${NL}  \"subproject\": \"infra\",${NL}  \"topics\": "
json_is "task head --json: with a subproject, the same fields as the text" "$HEAD_PY" "$text"
sb task new MU-2 --project Multi --subproject nope
rc_is "task new --subproject: an unknown subproject gives exit 1" 1
absent "task new --subproject: and writes no README" "$vault/$M/tasks/MU-2/README.md"
sb task new MU-2 --project Multi --title "App work"
sb task head MU-2
out_lacks "task head: no subproject line on a task with none" "subproject:"
sb task head MU-2 --json
out_lacks "task head --json: no subproject key on a task with none" '"subproject"'
sb task set MU-2 subproject=Tools
out_is "task set subproject: written as the note is named" "subproject: tools"
is "task set subproject: the key sits after epic" "$(($(lineno "$vault/$M/tasks/MU-2/README.md" 'subproject:') - $(lineno "$vault/$M/tasks/MU-2/README.md" 'epic:')))" "1"
sb task set MU-2 subproject=nope
rc_is "task set subproject: an unknown subproject gives exit 1" 1
line_is "task set subproject: the old value stays" "$vault/$M/tasks/MU-2/README.md" "subproject: tools"
sb task set MU-2 subproject=
out_is "task set subproject: an empty value removes the key" "subproject: (removed)"
sb task new MU-3 --project Multi --title "Tools work" --subproject tools
sb board Multi "By subproject"
is "board By subproject: active tasks by subproject, none last" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "MU-1 MU-3 MU-2 "
is "board By subproject: a tenth column names each row's subproject, - for none" \
  "$(printf '%s\n' "$OUT" | awk -F' [|] ' '{ printf "%s:%s:%s ", NF, $1, $10 }')" "10:MU-1:infra 10:MU-3:tools 10:MU-2:- "
sb board Multi
is "board: the other views keep nine columns" "$(printf '%s\n' "$OUT" | awk -F' [|] ' '{ printf "%s ", NF }')" "9 9 9 "
sb board Multi subproject
is "board: subproject names the By subproject view" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "MU-1 MU-3 MU-2 "
sb board Multi --subproject INFRA
rc_is "board --subproject: exit 0" 0
is "board --subproject: only that subproject's tasks, the name matched without case" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "MU-1 "
edit "$vault/$M/tasks/MU-3/README.md" 's/^subproject: tools$/subproject: TOOLS/'
sb task set MU-3 status=done
sb board Multi All --subproject tools
is "board --subproject: a value written in another case counts, in any view" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "MU-3 "
sb board Multi --subproject tools
rc_is "board --subproject: the view still applies, exit 0" 0
out_is "board --subproject: a done task is not in the Active view" ""
sb board Multi --subproject nope
rc_is "board --subproject: a name that is no subproject gives exit 1" 1
err_has "board --subproject: the message says how to list them" "second-brain subproject Multi"
sb board Multi --subproject
rc_is "board --subproject: no value gives exit 5" 5
file_has "story-tracker status: inside a subproject's repo, every board call takes its name" "$here/skills/story-tracker/status.md" \
  'add `--subproject <name>` to every `board` call'
file_has "conventions: the board lists the tasks of one subproject" "$vault/obsidian-conventions.md" '`second-brain board <project> --subproject <name>`'

# ---------------------------------------------------------------- task archive
A="work/shelf"
AT="$vault/$A/tasks"
sb scaffold project Shelf --path "$A" --keys SH
line_is "archive: a new profile is flat" "$vault/$A/claude/profile.md" "task_layout: flat"
for t in SH-1 SH-2 SH-3 SH-4; do sb task new "$t" --project Shelf --title "Shelf $t"; done
sb task dep SH-2 add SH-1
sb task alias SH-3 add old-slug
sb task set SH-1 status=done
sb task archive SH-1
rc_is "archive: a flat project gives exit 5" 5
err_has "archive: the message names the layout" "task_layout: flat"
exists "archive: nothing moved in a flat project" "$AT/SH-1/README.md"
edit "$vault/$A/claude/profile.md" '/^task_layout: flat$/d'
sb task archive SH-1
rc_is "archive: no task_layout key means flat" 5
edit "$vault/$A/claude/profile.md" 's/^tasks_root: tasks$/tasks_root: tasks\
task_layout: Archive/'
sb task archive SH-2
rc_is "archive: an open task gives exit 5" 5
err_has "archive: the message names the status" "SH-2 is planned"
exists "archive: the open task stays" "$AT/SH-2/README.md"
sb sprint open Shelf --end 2026-10-14
sb task set SH-1 sprint=2026-10-14
sb task set SH-2 sprint=2026-10-14
printf '{"nodes":[{"type":"file","file":"%s"}]}\n' "$A/tasks/SH-1/README.md" >"$vault/$A/plan.canvas"
cp "$vault/$A/plan.canvas" "$tmp/canvas.before"
sb task archive SH-1
rc_is "archive: a done task, layout in any letter case, exit 0" 0
out_is "archive: prints the new path, then the notes whose links it rewrote" "$A/tasks/archive/2026/SH-1/README.md
links: $A/tasks/SH-2/README.md | 1"
absent "archive: the live folder is gone" "$AT/SH-1"
line_is "archive: the date it was archived" "$AT/archive/2026/SH-1/README.md" 'archived: "2026-10-08"'
line_is "archive: a link to the task follows it" "$AT/SH-2/README.md" "  - \"[[$A/tasks/archive/2026/SH-1/README|SH-1]]\""
err_has "archive: a canvas that names the old path is reported" "note: $A/plan.canvas mentions $A/tasks/SH-1"
is "archive: the canvas is not rewritten" "$(cmp -s "$tmp/canvas.before" "$vault/$A/plan.canvas"; echo $?)" "0"
rm "$vault/$A/plan.canvas"
sb task archive SH-1
rc_is "archive: a task is archived once, exit 6" 6
err_has "archive: the message gives its path" "$A/tasks/archive/2026/SH-1/README.md"
sb find SH-1
out_is "archive: find sees an archived task" "$A/tasks/archive/2026/SH-1/README.md"
sb task head SH-1
out_has "archive: task head reads an archived task" "path: $A/tasks/archive/2026/SH-1/README.md"
sb task set SH-1 next="Nothing left"
out_is "archive: task set edits an archived task" "next: Nothing left"
sb task note SH-1 "Archived"
rc_is "archive: task note writes to an archived task" 0
sb board Shelf All
out_has "archive: the board lists an archived task" "SH-1 | Shelf SH-1 | done | 2026-10-14 |"
out_has "archive: a depends_on link reads its status in the archive" "| SH-1:done"
sb board Shelf "Current sprint"
out_has "archive: the sprint view lists it too" "SH-1 | Shelf SH-1 | done |"
sb task tag SH-1 add shelving
sb topic Shelf shelving
out_is "archive: topic lists an archived task" "$A/tasks/archive/2026/SH-1/README.md"
sb task set SH-3 status=abandoned
sb task archive old-slug
rc_is "archive: an abandoned task, by an alias" 0
sb task head old-slug
out_has "archive: an alias finds an archived task" "path: $A/tasks/archive/2026/SH-3/README.md"
sb task new SH-1 --project Shelf
rc_is "archive: task new refuses an archived id, exit 6" 6
err_has "archive: task new names the archived README" "the task is archived: $A/tasks/archive/2026/SH-1/README.md"
absent "archive: task new writes nothing then" "$AT/SH-1"
sb task new archive --project Shelf
rc_is "archive: the archive folder is no task id, exit 5" 5
for a in Archive ARCHIVE; do
  sb task new "$a" --project Shelf
  rc_is "archive: $a, in another letter case, is no task id either, exit 5" 5
done
is "archive: nothing written for it" "$(ls "$AT" | grep -ci '^archive$')/$(ls "$AT/archive")" "1/2026"
cp "$AT/SH-2/README.md" "$tmp/SH-2.before"
for a in archive Archive; do
  sb task alias SH-2 add "$a"
  rc_is "archive: $a is no task alias, exit 5" 5
done
err_has "archive: the alias message names the folder" "archive is the folder of the archived tasks"
is "archive: the aliases stay as they were" "$(cmp -s "$tmp/SH-2.before" "$AT/SH-2/README.md" && printf same)" "same"
sb task alias SH-2 add SH-1
rc_is "archive: an archived id is no alias for another task, exit 6" 6
mkdir -p "$AT/SH-1"
cp "$AT/archive/2026/SH-1/README.md" "$AT/SH-1/README.md"
sb task head SH-1
rc_is "archive: the same id live and archived is ambiguous, exit 4" 4
rm -r "$AT/SH-1"
sb sprint close Shelf --carry SH-2
rc_is "archive: sprint close sees the archived task" 0
out_has "archive: it counts as done" "done: SH-1"
file_has "archive: the close links the archived README" "$vault/$A/sprints/2026-10-14.md" "- [[$A/tasks/archive/2026/SH-1/README|SH-1]] - Shelf SH-1"
sb task set SH-4 status=done
sb task archive SH-4 --project Shelf
rc_is "archive: --project is taken" 0
sb task new SH-5 --project Shelf --title "Shelf SH-5"
sb task set SH-5 status=done
mkdir -p "$AT/archive/2026/SH-5"
sb task archive SH-5
rc_is "archive: an existing destination folder, even empty, gives exit 6" 6
err_has "archive: the message names the destination" "the destination exists: $A/tasks/archive/2026/SH-5"
exists "archive: the task stays where it was" "$AT/SH-5/README.md"
is "archive: the destination is left as it was" "$(ls -A "$AT/archive/2026/SH-5")" ""
file_lacks "archive: no archived date then" "$AT/SH-5/README.md" "archived:"
rmdir "$AT/archive/2026/SH-5"
printf 'x\n' >"$AT/archive/2026/SH-5"
sb task archive SH-5
rc_is "archive: a file at the destination gives exit 6" 6
exists "archive: the task stays then too" "$AT/SH-5/README.md"
rm "$AT/archive/2026/SH-5"
if ! sb_is_windows; then
  ln -s "$tmp/nowhere" "$AT/archive/2026/SH-5"
  sb task archive SH-5
  rc_is "archive: a link at the destination, even a dead one, gives exit 6" 6
  exists "archive: the task stays then as well" "$AT/SH-5/README.md"
  rm "$AT/archive/2026/SH-5"
fi

# ---------------------------------------------------------------- generated files
is "generated files: no placeholder left" "$(grep -rl '{{' "$vault" "$tmp/vault2" "$tmp/vault3" "$tmp/vault4" | grep -c . || true)" "0"
is "index template: the answer-style rule is pinned" "$(sed -n '/^## In every session/,/^## Working/p' "$here/templates/vault-index.md.tmpl" | tr '\n' ' ' | grep -c 'Answer in short, plain English. Lead with the answer. The user, or their own instructions, may *say otherwise.')" "1"
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

# ---------------------------------------------------------------- ticket text goes to story-tracker
ST="$here/skills/story-tracker/SKILL.md"
st_desc="$(grep -m1 '^description: ' "$ST")"
st_desc="${st_desc#description: }"
for word in "ticket text" summary description "acceptance criteria" draft "where a ticket stands" standup; do
  case "$st_desc" in *"$word"*) pass "story-tracker: the description names $word" ;; *) fail "story-tracker: the description names $word" "in: $st_desc" ;; esac
done
is "story-tracker: the description is under the doctor's 200 characters" "$((${#st_desc} < 200))" "1"
draft_row="$(grep '^| draft |' "$ST")"
case "$draft_row" in
  *"with or without an id"*ticket-description.md.tmpl*"reply with the text"*"Write no file until the id arrives"*) pass "story-tracker: a draft mode row fills the template and writes no file" ;;
  *) fail "story-tracker: a draft mode row fills the template and writes no file" "got: $draft_row" ;;
esac
file_has "sprint: its rules send a request to write a ticket to story-tracker" "$here/skills/sprint/SKILL.md" "goes to the story-tracker skill in \`draft\` mode"
file_lacks "vault-doctor: a request to check the vault may load it" "$here/skills/vault-doctor/SKILL.md" "disable-model-invocation"
line_is "vault-setup: it runs only by name" "$here/skills/vault-setup/SKILL.md" "disable-model-invocation: true"

# ---------------------------------------------------------------- docs-keeper on a ticket marked done
DK="$here/agents/docs-keeper.md"
desc="$(sed -n 's/^description: //p' "$DK")"
is "docs-keeper: the description is under 200 characters" "$((${#desc} < 200))" "1"
case "$desc" in *"a ticket is marked done"*) pass "docs-keeper: the description names a ticket marked done" ;;
  *) fail "docs-keeper: the description names a ticket marked done" "in: $desc" ;; esac
line_is "docs-keeper: Workflow 5 is there" "$DK" "## Workflow 5 - Ticket marked done"
file_has "docs-keeper: Workflow 5 runs step 7 on the docs to update" "$DK" 'run step 7 of Workflow 1 on them'
file_has "docs-keeper: Workflow 5 falls back to the code to doc map" "$DK" 'Then run Workflow 1 steps 3-5, as confirmed.'
file_has "docs-keeper: a gap not fixed goes to the debt file, as Boundaries says" "$DK" "A gap found but not fixed goes to the profile's debt file"
file_has "docs-keeper: Boundaries gives the debt line a shape" "$DK" '`<YYYY-MM-DD> <ID>: <doc path> - <the gap>`'
file_has "docs-keeper: Workflow 5 stops when every line is ticked" "$DK" 'With every line already ticked: go to step 6. Do not check the map again.'
file_has "docs-keeper: Workflow 5 diffs the merge commit" "$DK" 'diff <merge>^1 <merge>'
file_has "docs-keeper: Workflow 5 diffs a branch not merged yet" "$DK" 'diff origin/<production_branch>...<branch>'
file_has "docs-keeper: Workflow 5 stops when the change is not found" "$DK" 'report that the change was not found and stop'
file_has "docs-keeper: Workflow 5 reads the head with the project" "$DK" '`second-brain task head <ID> --project <project>`'
file_has "docs-keeper: Workflow 5 adds a status note" "$DK" 'Add a status note to the ticket naming what was updated'
line_is "docs-keeper: Workflow 6 is there, under the name the doctor's old-namespace fix gives" "$DK" "## Workflow 6 - A renamed command"
ST="$here/skills/story-tracker/SKILL.md"
file_has "story-tracker: a story in production starts docs-keeper" "$ST" 'start the `docs-keeper` agent'
file_has "story-tracker: it hands over the ticket id and the README path" "$ST" 'with the project, the ticket id and the README path'
file_lacks "story-tracker: no longer tells Claude not to start it" "$ST" 'Do not start it yourself.'
file_has "story-tracker: a session that cannot start an agent names docs-keeper" "$ST" 'When the session cannot start an agent, say so and'
file_has "sprint close: reports done tasks with unticked docs through the helper" "$here/skills/sprint/close.md" '`second-brain task docs <done ids> --project <project>`'
file_lacks "sprint close: no Grep" "$here/skills/sprint/close.md" 'Grep'
file_has "scrum-master: carries docs-keeper as an action for the caller" "$here/agents/scrum-master.md" 'start `docs-keeper` Workflow 5 for <ID>, <README path>'
file_has "sprint close: does not start docs-keeper" "$here/skills/sprint/close.md" 'Do not start it here: the close only reports.'
file_has "scrum-master: still does not spawn docs-keeper" "$here/agents/scrum-master.md" 'Do not spawn it.'
file_has "index: names a ticket marked done for docs-keeper" "$vault/CLAUDE.md" '`docs-keeper` for docs that follow the code and for a ticket marked done.'

# ---------------------------------------------------------------- skills follow the subproject and layout standards
ST="$here/skills/story-tracker/SKILL.md"
STC="$here/skills/story-tracker/create.md"
CL="$here/skills/sprint/close.md"
file_has "story-tracker create: task new takes the subproject from context" "$STC" 'Add `--subproject <name>` with the name on the `subproject:` line of `second-brain context`'
file_has "story-tracker create: asks when the repo is in no subproject" "$STC" 'ask which one the story is in, or none'
file_has "story-tracker create: a name that is no subproject is asked about" "$STC" 'Exit 1 with `--subproject`: the name is no'
file_has "story-tracker: a story set done in an archive project gets one question" "$ST" 'the profile says `task_layout: archive`: after'
file_has "story-tracker: the question is asked once" "$ST" 'ask once whether to archive it now'
file_has "story-tracker: it archives through the helper" "$ST" '`second-brain task archive <ID>`'
file_has "story-tracker: never archives without a yes" "$ST" 'Never archive a story without that yes.'
file_has "story-tracker: an archived story is found by id, not by a built path" "$ST" "Take a story's path from \`find\` or \`task head\`; never build it from the id."
file_has "story-tracker status: what waits on docs comes from task docs" "$here/skills/story-tracker/status.md" '`second-brain task docs <their ids> --project <project>`'
file_lacks "story-tracker status: no Grep over the READMEs" "$here/skills/story-tracker/status.md" 'One Grep for'
file_has "sprint close: asks once whether to archive the sprint's done tasks" "$CL" 'once whether to archive those tasks now'
file_has "sprint close: it archives through the helper" "$CL" '`second-brain task archive <ID> --project <project>`'
file_has "sprint close: never archives without a yes" "$CL" 'Never archive a task without that yes.'
is "sprint close: the archive question comes after the achievements and before the report" \
  "$(($(lineno "$CL" '8. Run `second-brain profile') < $(lineno "$CL" '9. `task_layout: archive`') && $(lineno "$CL" '9. `task_layout: archive`') < $(lineno "$CL" '10. Report the summary')))" "1"
file_has "sprint: its rules allow task archive after a yes at close" "$here/skills/sprint/SKILL.md" 'a yes at close, `second-brain task archive`'
file_has "vault-setup: the profile interview asks for task_layout" "$here/skills/vault-setup/SKILL.md" '| `task_layout` |'
file_has "vault-setup: and for archive_after_days" "$here/skills/vault-setup/SKILL.md" '| `archive_after_days` | with `archive` only'
file_has "vault-setup adopt: asks for task_layout through the project interview" "$here/skills/vault-setup/adopt.md" 'Fill the frontmatter keys as steps 3 to 6 of `## project <name>` in `SKILL.md` say.'
file_has "vault-setup adopt: moves nothing under task_layout archive" "$here/skills/vault-setup/adopt.md" 'With `task_layout: archive`, the done tasks already there stay where they are.'
file_has "vault-setup adopt: names the task-layout check" "$here/skills/vault-setup/adopt.md" '`flat` project: `task-layout`.'
line_is "vault-setup subproject: a section on its tasks" "$here/skills/vault-setup/subproject.md" "## 3. Its tasks"
file_has "vault-setup subproject: a task names its subproject" "$here/skills/vault-setup/subproject.md" 'frontmatter, `subproject: <name>`, spelled as the note is named'
file_has "vault-setup subproject: sets it through task set" "$here/skills/vault-setup/subproject.md" '`second-brain task set <ID> subproject=<name>`'
file_has "docs-keeper: the path task head prints wins" "$DK" 'The `path:` line wins over the path'
file_has "docs-keeper: a task is found at both depths" "$DK" '`<tasks_root>/archive/<YYYY>/<ID>/README.md` once'
file_has "docs-keeper: docs to update go into the README find names" "$DK" 'the path `second-brain find <ID> --project <project>` prints'
file_has "scrum-master: a story's path comes from task head" "$here/agents/scrum-master.md" 'path from the `path:` line of `second-brain task head <ID> --project <project>`'
file_has "scrum-master: the close's archive answer is the user's" "$here/agents/scrum-master.md" 'archive the sprint'"'"'s done tasks; that answer is the user'"'"'s too.'
file_has "index: an archived task's path" "$vault/CLAUDE.md" 'under `tasks/archive/<YYYY>/`'
file_has "index: a task names its subproject" "$vault/CLAUDE.md" 'to its subproject with the `subproject` property.'
file_has "conventions: the short version names subproject on a task" "$vault/obsidian-conventions.md" '`branch` and `epic`, and `subproject` when it belongs to one.'
file_has "conventions: subproject is spelled as its note" "$vault/obsidian-conventions.md" '`subproject` is the name of the task'"'"'s subproject, spelled as its note'
VD="$here/skills/vault-doctor/SKILL.md"
file_has "vault-doctor fix: --fix repairs three checks" "$VD" 'repairs three checks only'
file_lacks "vault-doctor fix: no longer says two" "$VD" 'repairs two checks only'
file_has "vault-doctor fix: names the checks --fix repairs" "$VD" '`status-tag`, `pull-request` and'
file_has "vault-doctor checks: names the archive repair" "$here/skills/vault-doctor/checks.md" '`to-archive`: `second-brain doctor --fix` archives each one through `second-brain task archive <ID>`'
file_has "vault-doctor fix: a snapshot comes before an archive" "$VD" 'Then run `second-brain snapshot` before it.'
file_has "vault-doctor fix: compare proves the archive" "$VD" 'After an archive, run `second-brain compare` with that snapshot. It is the proof of the move.'
file_has "vault-doctor fix: an archive by --fix is a bulk change" "$VD" 'offenders makes the `--fix` run a bulk change: it moves'

# ---------------------------------------------------------------- spec-driven delivery
sb help
out_has "help: lists spec" "spec <ID> | spec new <ID> | spec tasks <ID>   (each takes --project P)"
out_has "help: lists spec tick and packet" "spec tick <ID> <task> | spec packet <ID> <task>"
out_has "help: lists validation" "validation <project> [repo] | validation new <project> <repo>"
S="work/specs"
SPF="$vault/$S/claude/profile.md"
mkdir -p "$tmp/scode/spec-app" "$tmp/scode/spec-infra"
sb scaffold project Specs --path "$S" --keys SP
out_has "validation: scaffold project writes claude/validation.md" "$S/claude/validation.md"
line_is "validation: the note is typed" "$vault/$S/claude/validation.md" "type: validation"
line_is "validation: the note links up to the Claude hub" "$vault/$S/claude/validation.md" "> Up: [[$S/claude/README|Specs Claude Hub]]"
file_has "validation: the note holds one section per repo" "$vault/$S/claude/validation.md" 'code, in one `## <repo>` section per repo.'
line_is "validation: the note names the command agents read it with" "$vault/$S/claude/validation.md" 'section with `second-brain validation "Specs" <repo>` before they build or review a change.'
line_is "validation: the note names validation new" "$vault/$S/claude/validation.md" '`second-brain validation new "Specs" <repo>` adds a missing section.'
file_has "validation: the Claude hub links to it" "$vault/$S/claude/README.md" "[[$S/claude/validation|Specs Validation]]"
for k in "delivery: direct" "spec_home: vault" "validation_home: vault"; do
  line_is "profile template: $k" "$SPF" "$k"
done
sb validation Specs
rc_is "validation: a project with no repo exits 0" 0
out_is "validation: and prints no row" ""
edit "$SPF" "s|^repos: \\[\\]\$|repos: [spec-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/scode\"|"
sb task new SP-1 --project Specs --title "First spec"
sb spec SP-1
rc_is "spec: exit 0" 0
out_is "spec: the vault home by default, in the task's folder" "id: SP-1
delivery: direct
spec_home: vault
repo: spec-app
dir: $S/tasks/SP-1/spec
requirements: $S/tasks/SP-1/spec/requirements.md
design: $S/tasks/SP-1/spec/design.md
tasks: $S/tasks/SP-1/spec/tasks.md"
sb spec new SP-1
rc_is "spec new: exit 0" 0
out_is "spec new: names the three files it wrote" "$S/tasks/SP-1/spec/requirements.md
$S/tasks/SP-1/spec/design.md
$S/tasks/SP-1/spec/tasks.md"
SPR="$vault/$S/tasks/SP-1/spec/requirements.md"
line_is "spec new: a vault spec file has its alias" "$SPR" '  - "SP-1 Requirements"'
line_is "spec new: and the spec type" "$SPR" "type: spec"
line_is "spec new: and links up to the task" "$SPR" "> Up: [[$S/tasks/SP-1/README|SP-1]]"
file_has "spec new: the task's title is filled in" "$SPR" "What First spec must do."
line_is "spec new: requirements open at R1" "$SPR" "## R1 - <short name>"
SERVES="- Serves: <AC1, AC3: the story's criteria it meets>"
is "spec new: the Serves line is the first under R1" "$(section_of "$SPR" "R1 - <short name>" | head -1)" "$SERVES"
line_is "spec new: the requirement is in the WHEN form" "$SPR" "<WHEN a trigger, THE part of the system SHALL respond so.>"
line_is "spec new: the tasks file has the task line" "$vault/$S/tasks/SP-1/spec/tasks.md" "- [ ] T1 - <What the task builds.>"
line_is "spec new: and its requirements line" "$vault/$S/tasks/SP-1/spec/tasks.md" "  - Requirements: <R1, R2>"
SPD="$vault/$S/tasks/SP-1/spec/design.md"
line_is "spec new: the design keeps the headings a task names" "$SPD" "How First spec is built. Keep each heading short, and never rename or remove one a task names."
for h in "## Context" "## Approach" "## Components" "## Errors and edge cases" "## Testing"; do
  line_is "spec new: the design has $h" "$SPD" "$h"
done
line_is "spec new: the design asks for each part's job" "$SPD" "<Each part added or changed, and its job.>"
echo "kept" >>"$SPR"
sb spec new SP-1
rc_is "spec new again: exit 0" 0
out_is "spec new again: writes nothing" ""
err_has "spec new again: names what exists" "exists: $S/tasks/SP-1/spec/requirements.md"
line_is "spec new again: never overwrites" "$SPR" "kept"
sb unresolved Specs
out_is "spec: the vault spec files' links resolve" ""
sb find SP-1 --project Specs
out_is "spec: the task is still one task" "$S/tasks/SP-1/README.md"
sb task set SP-1 delivery=maybe
rc_is "delivery: task set refuses another value" 5
sb task set SP-1 delivery=spec
rc_is "delivery: task set writes spec" 0
sb spec SP-1
out_has "delivery: the task's own value wins" "delivery: spec"
edit "$SPF" 's/^delivery: direct$/delivery: SPEC/'
sb task set SP-1 delivery=
sb spec SP-1
out_has "delivery: removed, the profile's holds, in any letter case" "delivery: spec"
edit "$SPF" 's/^delivery: SPEC$/delivery: maybe/'
sb spec SP-1
out_has "delivery: a value that is not allowed means direct" "delivery: direct"
edit "$SPF" 's/^delivery: maybe$/delivery: direct/; s/^spec_home: vault$/spec_home: repo/'
sb spec SP-1
out_has "spec_home repo: the folder is spec/<ID> in the repo" "dir: $oT/scode/spec-app/spec/SP-1"
out_has "spec_home repo: the tasks file is in it" "tasks: $oT/scode/spec-app/spec/SP-1/tasks.md"
sb spec new SP-1
out_has "spec_home repo: spec new writes in the repo" "$oT/scode/spec-app/spec/SP-1/requirements.md"
is "spec_home repo: a repo spec file has no frontmatter" "$(head -1 "$tmp/scode/spec-app/spec/SP-1/requirements.md")" "# SP-1 - Requirements"
is "spec_home repo: the Serves line is the first under R1" "$(section_of "$tmp/scode/spec-app/spec/SP-1/requirements.md" "R1 - <short name>" | head -1)" "$SERVES"
file_lacks "spec_home repo: and no up link" "$tmp/scode/spec-app/spec/SP-1/requirements.md" "> Up:"
edit "$SPF" "s|^repos_root: \"$tmp/scode\"\$|repos_root: \"$tmp/nowhere\"|"
sb spec SP-1
rc_is "spec_home repo: a missing repo folder exits 1" 1
err_has "spec_home repo: and says so" "the folder of spec-app is missing"
edit "$SPF" "s|^repos_root: \"$tmp/nowhere\"\$|repos_root: \"\"|"
sb spec SP-1
rc_is "spec_home repo: no recorded location exits 1" 1
err_has "spec_home repo: and says so" "no location is recorded for spec-app"
edit "$SPF" 's|^repos: \[spec-app\]$|repos: []|'
sb spec SP-1
rc_is "spec_home repo: no repo exits 1" 1
err_has "spec_home repo: and says so" "Specs lists no repo for the spec"
edit "$SPF" "s|^repos: \\[\\]\$|repos: [spec-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/scode\"|"
sb scaffold subproject Specs infra --repos spec-infra
SPS="$vault/$S/claude/subprojects/infra.md"
edit "$SPS" 's/^spec_home: ""$/spec_home: vault/; s/^delivery: ""$/delivery: spec/'
sb task set SP-1 subproject=infra
sb spec SP-1
out_has "subproject: its spec_home wins over the profile's" "spec_home: vault"
out_has "subproject: its delivery wins over the profile's" "delivery: spec"
out_has "subproject: the story's repo is the subproject's first" "repo: spec-infra"
sb subproject Specs infra
out_has "subproject: shows the delivery that holds" "delivery: spec"
out_has "subproject: and the validation home, the profile's" "validation_home: vault"
sb spec
rc_is "spec: no id exits 5" 5
sb spec SP-1 SP-2
rc_is "spec: two ids exit 5" 5
sb spec SP-404 --project Specs
rc_is "spec: an unknown task exits 1" 1

# ---------------------------------------------------------------- validation.md
sb validation Specs
out_is "validation: one row per repo, the vault home, no section yet" "spec-app${TAB}vault${TAB}$S/claude/validation.md${TAB}no-section
spec-infra${TAB}vault${TAB}$S/claude/validation.md${TAB}no-section"
sb validation Specs spec-app
rc_is "validation: a repo with no section exits 1" 1
err_has "validation: and names validation new" "has no ## spec-app section: run second-brain validation new"
sb validation new Specs spec-app
rc_is "validation new: exit 0" 0
out_is "validation new: names the file" "$S/claude/validation.md"
line_is "validation new: adds the repo's section" "$vault/$S/claude/validation.md" "## spec-app"
line_is "validation new: with the check as a user would" "$vault/$S/claude/validation.md" "### Check as a user would"
is "validation new: the section holds the template's four parts, word for word" "$(section_of "$vault/$S/claude/validation.md" spec-app)" \
  "### Set up and start
- <The commands that install, build and start it from a fresh clone, in order.>
### Checks
- <One line per command that must pass, such as the tests, linter and build: the command in backticks, then what it proves.>
- <Each line ends with when it runs: when: each task, when: each build, or when: release for one run only before a release or on the owner's ask.>
### Check as a user would
- <One line per step that uses the change as a user does: its tool, then what to look for, then when it runs.>
- <A tool is a skill by name, such as a browser-testing skill, a command, an API call or a query.>
### A pass
- <What a pass needs: every check above passes, the user steps work, nothing else broke.>"
echo "- npm test" >>"$vault/$S/claude/validation.md"
sb validation new Specs SPEC-APP
rc_is "validation new again: exit 0" 0
out_is "validation new again: writes nothing" ""
err_has "validation new again: names what exists" "exists: $S/claude/validation.md"
sb validation Specs Spec-App
rc_is "validation: the repo is matched without letter case" 0
is "validation: the path comes first" "$(printf '%s\n' "$OUT" | head -1)" "path: $S/claude/validation.md"
out_has "validation: then the repo's steps" "### Set up and start"
out_has "validation: to the end of its section" "- npm test"
sb validation Specs nope
rc_is "validation: a repo that is not the project's exits 1" 1
sb validation Specs spec-app extra
rc_is "validation: too many arguments exit 5" 5
sb validation new Specs
rc_is "validation new: no repo exits 5" 5
edit "$SPS" 's/^validation_home: ""$/validation_home: repo/'
sb validation Specs
out_has "validation: a subproject's home wins for its repos" "spec-infra${TAB}repo${TAB}$oT/scode/spec-infra/validation.md${TAB}missing"
out_has "validation: the profile's holds for the others" "spec-app${TAB}vault${TAB}$S/claude/validation.md${TAB}ok"
sb validation new Specs spec-infra
out_is "validation new: a repo home writes at the repo's root" "$oT/scode/spec-infra/validation.md"
is "validation new: a repo file opens with its title" "$(head -1 "$tmp/scode/spec-infra/validation.md")" "# spec-infra validation"
line_is "validation new: then the repo's section" "$tmp/scode/spec-infra/validation.md" "## spec-infra"
file_lacks "validation new: a repo file has no frontmatter" "$tmp/scode/spec-infra/validation.md" "type: validation"
sb validation Specs
out_has "validation: the repo file is ok" "spec-infra${TAB}repo${TAB}$oT/scode/spec-infra/validation.md${TAB}ok"
rm -rf "$tmp/scode/spec-infra"
sb validation Specs spec-infra
rc_is "validation: a repo home whose folder is missing exits 1" 1
err_has "validation: and says so" "the folder of spec-infra is missing"
sb scaffold project Specs --path "$S" --keys SP
err_has "validation: a second scaffold leaves the note alone" "exists: $S/claude/validation.md"
VS="$here/skills/vault-setup/SKILL.md"
file_has "vault-setup: lists the validation mode" "$VS" '| validation <project> | link]'
file_has "vault-setup: asks for delivery, a fallback" "$VS" \
  '| `delivery` | what a story with no `delivery` of its own falls back to, as `### Profile'
file_has "vault-setup subproject: delivery is a fallback" "$here/skills/vault-setup/subproject.md" \
  '- `delivery` is a fallback, as `### Profile frontmatter` in `docs/contract.md` says.'
file_has "vault-setup: asks for spec_home" "$VS" '| `spec_home` | with `spec`:'
file_has "vault-setup: asks for validation_home" "$VS" '| `validation_home` | whether `validation.md`'
file_has "vault-setup: project mode ends with the validation steps" "$VS" "10. Write each repo's validation steps as"
file_has "vault-setup validation: never invents a step" "$here/skills/vault-setup/validation.md" "Never invent a step."
file_has "vault-setup validation: writes only what the user confirms" "$here/skills/vault-setup/validation.md" "Write only what they confirm"
file_has "vault-setup repo: a new repo gets its validation steps" "$here/skills/vault-setup/repo.md" "Write the repository's validation steps"

# ---------------------------------------------------------------- spec and validation edge cases
sb validation Specs nope
rc_is "validation: an unknown repo exits 1" 1
out_is "validation: and prints nothing" ""
sb validation new Specs nope
rc_is "validation new: an unknown repo exits 1" 1
out_is "validation new: and writes nothing" ""
sb validation Specs --x
rc_is "validation: a flag as the second argument exits 5" 5
sb validation new Specs -h
rc_is "validation new: a flag exits 5" 5
sb task set SP-1 delivery=Spec
rc_is "delivery: task set takes any letter case" 0
line_is "delivery: and writes it in lower case" "$vault/$S/tasks/SP-1/README.md" "delivery: spec"
sb task set SP-1 delivery=
# The vault note in CRLF: a new section keeps the line endings, after one blank line.
VN="$vault/$S/claude/validation.md"
edit "$SPF" 's|^repos: \[spec-app\]$|repos: [spec-app, spec-web]|'
mkdir -p "$tmp/scode/spec-web"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$VN" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$VN"
sb validation new Specs spec-web
rc_is "validation new: a CRLF note takes a new section" 0
is "validation new: every line keeps its CRLF" "$(grep -vc "$CR\$" "$VN" || true)" "0"
is "validation new: one blank line before the new section" \
  "$(awk '{ sub(/\r$/, "") } $0 == "## spec-web" { print prev } { prev = $0 }' "$VN")" ""
is "validation new: and not two" \
  "$(awk '{ sub(/\r$/, "") } $0 == "## spec-web" { print p2 } { p2 = prev; prev = $0 }' "$VN" | grep -c . || true)" "1"
# A section with nothing under its heading is empty, not written.
edit "$SPF" 's|^repos: \[spec-app, spec-web\]$|repos: [spec-app, spec-web, spec-gone]|'
printf '\r\n## spec-gone\r\n' >>"$VN"
sb validation Specs
out_has "validation: a section with nothing under it is empty" "spec-gone${TAB}vault${TAB}$S/claude/validation.md${TAB}empty"
sb validation new Specs spec-gone
err_has "validation new: an empty section is left alone" "exists: $S/claude/validation.md"
edit "$SPF" 's|^repos: \[spec-app, spec-web, spec-gone\]$|repos: [spec-app]|'
# The story's repo: with no repo in the profile, the project's first repo, a subproject's.
P3="work/subonly"
mkdir -p "$tmp/socode/so-api"
sb scaffold project SubOnly --path "$P3" --keys SO
edit "$vault/$P3/claude/profile.md" "s|^repos_root: \"\"\$|repos_root: \"$tmp/socode\"|; s|^spec_home: vault\$|spec_home: repo|"
sb scaffold subproject SubOnly api --repos so-api
sb task new SO-1 --project SubOnly --title "No subproject"
sb spec SO-1
rc_is "spec: a project whose only repo is a subproject's exits 0" 0
out_has "spec: and the story's repo is that repo" "repo: so-api"
# A repo home in the profile: no hub link, and no vault note.
P4="work/repohome"
mkdir -p "$vault/$P4/claude"
printf -- '---\ntype: profile\nvalidation_home: repo\n---\n' >"$vault/$P4/claude/profile.md"
sb scaffold project RepoHome --path "$P4" --keys RH
out_lacks "validation: a repo home writes no vault note" "$P4/claude/validation.md"
file_lacks "validation: and the Claude hub does not link to one" "$vault/$P4/claude/README.md" "claude/validation|"
sb unresolved RepoHome
out_is "validation: so the hub's links resolve" ""

# ---------------------------------------------------------------- spec tasks, tick and packet
SD="$vault/$S/tasks/SP-1/spec"
edit "$SPF" 's/^spec_home: repo$/spec_home: vault/'
sb task set SP-1 subproject= branch=feature/SP-1-first
printf '%s\n' '# SP-1 - Requirements' '' '## R1 - Login form' '' 'WHEN a user opens the page, THE app SHALL show a form.' '' \
  '- [ ] The form has two fields.' '' '## R2 - Bad password' '' 'IF the password is wrong, THEN the app SHALL say so.' '' '## R3 - Unused' '' 'Left out.' >"$SD/requirements.md"
printf '%s\n' '# SP-1 - Design' '' '## Approach' '' 'A new route.' '' '## Components' '' 'The form.' '' '## Testing' '' 'A browser check.' >"$SD/design.md"
printf '%s\n' '# SP-1 - Tasks' '' '- [ ] T1 - The login form' '  - Requirements: R1' '  - Design: Approach, components' '  - Files: src/login.ts' \
  '  - Check: open /login - expected: shows `Sign in: email, password`' '' \
  '- [x] T2 - The error' '  - Requirements: R2, R9' '  - Design: Approach' '- [ ] T3 - Nothing named' '  - Requirements: <R1, R2>' '- [ ] T4 - No design' '  - Requirements: r2' '  - Design: none' >"$SD/tasks.md"
sb spec tasks SP-1
rc_is "spec tasks: exit 0" 0
out_is "spec tasks: one row per item, in order, with no bundle as -" "T1${TAB}todo${TAB}The login form${TAB}-
T2${TAB}done${TAB}The error${TAB}-
T3${TAB}todo${TAB}Nothing named${TAB}-
T4${TAB}todo${TAB}No design${TAB}-"
sb spec packet SP-1 t1
rc_is "spec packet: exit 0, the task matched without letter case" 0
is "spec packet: the header lines first" "$(printf '%s\n' "$OUT" | head -7)" "story: SP-1
task: T1
title: The login form
repo: spec-app
repo_path: $oT/scode/spec-app
branch: feature/SP-1-first
validation: $S/claude/validation.md"
out_has "spec packet: the item as written" "  - Files: src/login.ts"
out_has "spec packet: the check and its expected result, as written" \
  '  - Check: open /login - expected: shows `Sign in: email, password`'
out_has "spec packet: the requirement it names, with its checks" "### R1 - Login form

WHEN a user opens the page, THE app SHALL show a form.

- [ ] The form has two fields."
out_lacks "spec packet: no requirement it does not name" "R2 - Bad password"
out_has "spec packet: each design heading it names, without letter case" "### Approach

A new route.

### Components

The form."
out_lacks "spec packet: no design heading it does not name" "### Testing"
out_has "spec packet: the repo's validation steps" "## Validation

### Set up and start"
out_lacks "spec packet: no other task" "T2 - The error"
out_has "spec packet: names the task's check first, and no each-task line when the section has no command" "## Checks

- task: open /login - expected: shows \`Sign in: email, password\`

## Validation"
sb spec packet SP-1 T2
rc_is "spec packet: a requirement with no section exits 1" 1
err_has "spec packet: and names it" "T2 names R9, which $S/tasks/SP-1/spec/requirements.md has no section for"
sb spec packet SP-1 T3
rc_is "spec packet: a task that names no requirement exits 1" 1
sb spec packet SP-1 T4
rc_is "spec packet: a task with no design exits 0" 0
out_lacks "spec packet: and has no design part" "## Design"
out_has "spec packet: a requirement id is matched without letter case" "### R2 - Bad password"
sb spec packet SP-1 T9
rc_is "spec packet: an unknown task exits 1" 1
sb spec packet SP-1
rc_is "spec packet: no task exits 5" 5
CRT="$SD/tasks.md"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$CRT" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$CRT"
sb spec tick SP-1 T1
rc_is "spec tick: exit 0" 0
out_is "spec tick: names the task" "ticked: T1"
line_is "spec tick: the box is ticked" "$CRT" "- [x] T1 - The login form$CR"
is "spec tick: every line keeps its CRLF" "$(grep -vc "$CR\$" "$CRT" || true)" "0"
sb spec tick SP-1 T1
rc_is "spec tick: a ticked task exits 6" 6
sb spec tick SP-1 T9
rc_is "spec tick: an unknown task exits 1" 1
sb spec tasks SP-1
out_has "spec tasks: the ticked task is done" "T1${TAB}done${TAB}The login form${TAB}-"
mv "$CRT" "$tmp/tasks.md.away"
sb spec tasks SP-1
rc_is "spec tasks: no tasks.md exits 1" 1
err_has "spec tasks: and names spec new" "run second-brain spec new SP-1"
mv "$tmp/tasks.md.away" "$CRT"

# ---------------------------------------------------------------- the spec skill and its agents
SK="$here/skills/spec/SKILL.md"
sk_desc="$(sed -n 's/^description: //p' "$SK")"
is "spec skill: the description is under 200 characters" "$((${#sk_desc} < 200))" "1"
case "$sk_desc" in *"spec-driven"*) pass "spec skill: the description names spec-driven" ;; *) fail "spec skill: the description names spec-driven" "in: $sk_desc" ;; esac
file_has "spec skill: carries the conventions pointer" "$SK" 'Conventions: before writing notes, run `second-brain conventions`'
file_has "spec skill: its first tool call is the context" "$SK" 'Your first tool call is `second-brain context`'
file_has "spec skill: an inherited spec becomes the story's own delivery" "$SK" \
  '5. `delivery: spec`: run `second-brain task set <ID> delivery=spec`. A value that came from the'
file_has "spec skill: so story-tracker never weighs it" "$SK" \
  'subproject or the profile becomes the story'"'"'s own, so story-tracker never weighs it.'
file_lacks "README: no longer says the profile decides a spec" "$here/README.md" \
  'or set `delivery: spec` in'
for ph in requirements design tasks; do
  file_has "spec skill: the $ph approval note" "$SK" "Spec: $ph approved by the owner."
done
file_has "spec skill: asks the owner with AskUserQuestion" "$SK" "Ask with AskUserQuestion whether to approve the phase"
file_has "spec skill: never builds before the tasks are approved" "$SK" "Never start the build before the tasks approval note is written."
for a in implementer reviewer spec-checker; do
  AF="$here/agents/$a.md"
  line_is "$a: named as its file" "$AF" "name: $a"
  ad="$(sed -n 's/^description: //p' "$AF")"
  is "$a: the description is under 200 characters" "$((${#ad} < 200))" "1"
  file_has "$a: carries the conventions pointer" "$AF" 'Conventions: before writing notes, run `second-brain conventions`'
done
for AF in "$here"/agents/*.md; do
  a="$(basename "$AF" .md)"
  if grep -q '^tools:.*Agent' "$AF"; then fail "$a: has no Agent tool"; else pass "$a: has no Agent tool"; fi
done
line_is "reviewer: edits no file, and has the Skill tool" "$here/agents/reviewer.md" "tools: Bash, Read, Glob, Grep, Skill"
SC="$here/agents/spec-checker.md"
line_is "spec-checker: reads, and has no tool that writes" "$SC" "tools: Read, Glob, Grep"
line_is "spec-checker: runs on opus" "$SC" "model: opus"
for g in 'a requirement or design heading a task names that the files lack.' 'a requirement no task meets.' \
  'a task that needs a later one.'; do
  line_is "spec-checker: a tasks.md gap, $g" "$SC" "- In \`tasks.md\`: $g"
done
file_has "spec-checker: its prompt is the spec files' paths alone" "$SC" \
  'Your prompt is the paths of'
file_has "spec-checker: reads nothing but those files" "$SC" \
  '- Read nothing else: not the story, not the code, not another file in the folder.'
file_has "spec-checker: a vague task check is a gap" "$SC" \
  'a task with no `- Check: <command or step> - expected: <what it prints or shows>`'
file_has "spec-checker: reports one line per gap" "$SC" \
  '- One line per gap: `- <file> > <heading> - <what an agent could not build> - <a question>`.'
file_has "spec-checker: says when there is no gap" "$SC" 'No gap: reply `No gaps.` and nothing else.'
file_has "spec-checker: proposes no fix" "$SC" '- Propose no fix: the caller closes each gap with the owner.'
line_is "spec-checker: writes nothing" "$SC" "- Write nothing, anywhere."
PH="$here/skills/spec/phases.md"
file_has "spec phases: one question per AskUserQuestion call" "$PH" \
  '- Ask one question at a time: one question per AskUserQuestion call. Wait for its answer.'
file_has "spec phases: the draft in chunks of 200 to 300 words" "$PH" \
  '- Show the draft in chunks of about 200 to 300 words'
file_has "spec phases: each chunk asks what is wrong or missing, as plain text" "$PH" \
  "- End each chunk with the line \`What's wrong or missing?\` as plain text, not an AskUserQuestion"
line_is "spec phases: then stops for the owner's answer" "$PH" "  call. Then stop for the owner's answer."
line_is "spec phases: the check runs once the last chunk's fixes are written" "$PH" \
  'For design and tasks, once the owner has answered the last chunk and its fixes are written:'
line_is "spec phases: approval only after the last chunk" "$PH" "- Ask for the approval only after the last chunk."
file_has "spec phases: each task check names its expected result" "$PH" \
  '`- Check: <command or step> - expected: <what it prints or shows>`.'
file_has "spec phases: a vague check is rewritten with the owner" "$PH" \
  '- A check with no command or step, or no expected result, is vague: rewrite it with the owner.'
line_is "spec phases: the spec check has a section" "$PH" "## The spec check"
file_has "spec phases: launches spec-checker" "$PH" '1. Launch `odsb:spec-checker` with the Agent tool.'
line_is "spec phases: the design check reads requirements and design" "$PH" \
  '   - Design: `requirements.md` and `design.md`.'
line_is "spec phases: the tasks check reads all three files" "$PH" \
  '   - Tasks: `requirements.md`, `design.md` and `tasks.md`.'
file_has "spec phases: shows the owner the gaps" "$PH" '3. Show the owner the gaps, numbered, as it wrote them.'
file_has "spec phases: closes each gap with the owner" "$PH" \
  '4. Close each gap with the owner, and write the answer in the phase file.'
line_is "spec phases: a gap the owner rejects is left" "$PH" '   - The owner says a gap is not one: leave it.'
line_is "spec phases: a gap in an approved phase reopens it" "$PH" \
  '   - A gap in an approved phase: write `Spec: <phase> reopened.` as a status note, then go back to'
line_is "spec phases: and goes back to that phase" "$PH" '     that phase.'
line_is "spec skill: a change at approval is shown, then asked again" "$SK" \
  '   - A change: make it, show the changed chunk, then ask again.'
file_has "spec skill: asks as the chat rules say" "$SK" 'Ask as `## The chat` in `phases.md` says.'
file_has "spec skill: shows the phase in chunks" "$SK" \
  '4. Show the owner the path, then the phase in chunks, as `## The chat` in `phases.md` says.'
file_has "spec skill: spec-checker reads design and tasks before approval" "$SK" \
  '5. Design and tasks: have `spec-checker` read the spec, and close its gaps with the owner, as'
line_is "spec tasks template: the check names its expected result, and who runs it" "$here/templates/spec-tasks.md.tmpl" \
  '  - Check: <The command or step the implementer and the reviewer run.> - expected: <What it prints or shows.>'
line_is "contract: spec-checker and its tools" "$here/docs/contract.md" \
  '| `spec-checker` | Read, Glob, Grep | reads the spec files it is given and lists what it could not build from them; writes nothing |'
line_is "contract: a task check names its expected result" "$here/docs/contract.md" \
  '  `- Check: <command or step> - expected: <what it prints or shows>`.'
line_is "guide: lists spec-checker" "$here/docs/guide.md" \
  '| `spec-checker` | agent | Reads a spec alone and lists what it could not build from it. Writes no file. |'
file_has "changelog: names spec-checker" "$here/CHANGELOG.md" \
  'the new `spec-checker` agent reads the spec'
file_has "validation template: each user step names its tool" "$here/templates/validation-repo.md.tmpl" \
  "- <One line per step that uses the change as a user does: its tool, then what to look for, then when it runs.>"
file_has "validation template: a tool is a skill, a command, an API call or a query" "$here/templates/validation-repo.md.tmpl" \
  "a skill by name, such as a browser-testing skill, a command, an API call or a query."
file_has "reviewer: runs each user step with the tool its line names" "$here/agents/reviewer.md" "that runs it. Run the step with that tool."
file_has "reviewer: a skill runs through the Skill tool" "$here/agents/reviewer.md" "- A skill: call it with the Skill tool"
file_has "reviewer: a step whose tool it cannot run is BLOCKED and names the tool" "$here/agents/reviewer.md" "found, is BLOCKED. Name the tool."
file_has "reviewer: screenshots go in a temp folder outside the repo" "$here/agents/reviewer.md" "make one temp folder outside the repo with \`mktemp -d\`"
file_has "reviewer: names the screenshots folder" "$here/agents/reviewer.md" 'end the verdict line with ` - screenshots in <folder>`'
file_has "reviewer: keeps step 0's status output" "$here/agents/reviewer.md" "Keep the \`status --porcelain\` output: the user steps are checked against it."
file_has "reviewer: removes only an untracked path step 0 did not list" "$here/agents/reviewer.md" "Remove only an untracked (\`??\`) path that step 0's output did not list, and name it."
file_has "reviewer: a tracked file a step changed is a finding, never deleted" "$here/agents/reviewer.md" "A tracked file a step changed is a finding. Never delete it."
file_has "reviewer: never resets the owner's work" "$here/agents/reviewer.md" "Never run \`git checkout\`, \`restore\`, \`reset\`, \`clean\` or \`stash\`."
file_has "reviewer: a line with no tool runs with Bash only when Bash can do it" "$here/agents/reviewer.md" "run it with Bash when Bash can do what it says."
file_has "reviewer: a browser line with no tool is BLOCKED" "$here/agents/reviewer.md" "A line that needs a browser and names no tool is BLOCKED. Name the step and ask for its tool."
file_has "vault-setup: drafts each user step's tool from the repo" "$here/skills/vault-setup/validation.md" "Draft the tool from the repo"
BM="$here/skills/spec/build.md"
file_has "spec build: the packet is the implementer's whole context" "$BM" "The packet is the implementer's whole context."
file_has "spec build: only a reviewer's pass ticks a task" "$BM" 'Only a reviewer'"'"'s `VERDICT: PASS` ticks a task.'
line_is "spec build: the baseline comes first" "$BM" "## 4. The baseline"
is "spec build: the baseline before the builds" "$(($(lineno "$BM" '## 4. The baseline') < $(lineno "$BM" '## 5. Each task in turn')))" "1"
file_lacks "spec build: no longer two retries" "$BM" "At most two retries"
file_has "reviewer: a step not run is never a pass" "$here/agents/reviewer.md" "A step that could not be run is never a PASS."
file_has "implementer: never the vault or tasks.md" "$here/agents/implementer.md" 'Never the vault, the spec files or `tasks.md`'
file_has "spec phases: every task's packet must build, unprinted" "$here/skills/spec/phases.md" 'Run `second-brain spec packet <ID> T<n> >/dev/null` for every task.'
file_has "spec phases: never prints a packet" "$here/skills/spec/phases.md" '- Never print a packet here: the agents fetch their own.'
file_has "spec phases: a task names what it provides" "$here/skills/spec/phases.md" 'adds `- Provides: <signatures>` lines'
file_has "spec phases: a task names the tasks it uses" "$here/skills/spec/phases.md" 'adds one line, `- Uses: T1, T2`. Its packet then holds those'
file_has "spec skill: writes each phase in this session" "$here/skills/spec/SKILL.md" "write the phase yourself, in this session"
file_has "spec skill: reads only what the session lacks" "$here/skills/spec/SKILL.md" "Read only what this session does not have yet"
file_has "spec skill: asks what the story and the code do not settle" "$here/skills/spec/SKILL.md" "what the story and the code do not settle, before you"
file_has "spec phases: never the whole repo" "$here/skills/spec/phases.md" "and what they call. Not the whole"
if [ -e "$here/agents/spec-writer.md" ]; then fail "spec-writer: the agent is gone"; else pass "spec-writer: the agent is gone"; fi
ST="$here/skills/story-tracker/SKILL.md"
file_has "story-tracker: weighs a story when work starts" "$ST" \
  'Weigh how a story is built when work starts on it: in start mode once the story exists, or on a'
file_has "story-tracker: its own delivery is the key in its frontmatter" "$ST" \
  "A story has its own \`delivery\` when its README's frontmatter sets the key to \`direct\` or"
file_has "story-tracker: the spec command does not tell where delivery comes from" "$ST" \
  '`second-brain spec <ID>` cannot tell: its `delivery` line may come from the subproject or the'
file_lacks "story-tracker: no longer reads the delivery that holds" "$ST" 'Read its `delivery` line'
file_has "story-tracker: a story with its own delivery is never weighed again" "$ST" \
  'A story with its own `delivery` is never weighed again.'
file_has "story-tracker: its own spec offers the spec skill" "$ST" \
  '`spec`: say the story is built from a spec and offer `/odsb:spec <ID>`.'
file_has "story-tracker: a delivery the owner names is written, not weighed" "$ST" \
  'The owner says how to build it, such as "spec-driven": write it with'
file_has "story-tracker: an approved spec note makes a story spec" "$ST" \
  '- A story with a `Spec: <phase> approved by the owner.` status note is `spec`: its spec was'
file_has "story-tracker: that story's spec key is written" "$ST" \
  '  - Write `second-brain task set <ID> delivery=spec`, then go on as for a story with its own'
file_has "story-tracker create: start mode reaches the weighing" "$STC" \
  '6. Weigh how the story is built, as `## Spec-driven stories` in `SKILL.md` says.'
file_has "story-tracker: a spec helps a big, unclear or unattended story" "$ST" \
  'Spec-driven: the story is big, unclear, or meant to run without the owner.'
file_has "story-tracker: gives the signs of a spec" "$ST" \
  'Signs: many files or repos, open questions in the criteria, a long unattended build.'
file_has "story-tracker: a simple story is set direct with no question" "$ST" \
  'Weighed direct: run `second-brain task set <ID> delivery=direct` and ask nothing. Say so in one'
line_is "story-tracker: it says so in one line, with the reason" "$ST" '  line, with the reason.'
file_has "story-tracker: a spec story is described in three lines" "$ST" \
  'describe the story in at most three lines: what it changes, what it'
file_has "story-tracker: the description names what it touches and the criteria" "$ST" \
  'touches and how many criteria it has. Then say why a spec helps.'
file_has "story-tracker: the owner is asked" "$ST" \
  'Ask the owner with AskUserQuestion: `spec` or `direct`.'
file_has "story-tracker: the answer is written" "$ST" \
  'Write the answer with `second-brain task set <ID> delivery=<answer>`.'
line_is "story-tracker: an answered spec offers the spec skill" "$ST" \
  '  - `spec`: offer `/odsb:spec <ID>`.'
line_is "story-tracker: direct goes on" "$ST" '  - `direct`: go on here.'
file_has "conventions: a task's delivery is set when work starts" \
  "$here/templates/obsidian-conventions.md.tmpl" \
  '  - `delivery` - `spec` or `direct`, how the story is built, set when work starts on it.'
file_lacks "guide: the profile's delivery is no default" "$here/docs/guide.md" \
  "A project's default, and where"
file_has "contract: an inherited delivery is what spec falls back to" "$here/docs/contract.md" \
  '- A value a story inherits from its subproject or the profile is what `spec <ID>` and the `spec`'
file_has "contract: story-tracker weighs a story with no delivery of its own" \
  "$here/docs/contract.md" \
  '- When work starts on a story with no `delivery` of its own, `story-tracker` weighs it and'
file_has "contract: points to the weighing in story-tracker" "$here/docs/contract.md" \
  'the story'"'"'s own, as `## Spec-driven stories` in `skills/story-tracker/SKILL.md` says.'
st_desc="$(sed -n 's/^description: //p' "$ST")"
st_check="story-tracker: the description leaves spec requests to the spec skill"
case "$st_desc" in
  *[Ss][Pp][Ee][Cc]*) fail "$st_check" "in: $st_desc" ;;
  *) pass "$st_check" ;;
esac
file_has "guide: the spec request is under What to say" "$here/docs/guide.md" '| Implement EX-2 spec-driven, starting with its requirements. | `spec` |'
file_has "e2e: asks the same spec request" "$here/scripts/e2e-claude.sh" '"Implement EX-2 spec-driven, starting with its requirements."'

# ---------------------------------------------------------------- spec tasks: review edge cases
printf '%s\n' '# SP-1 - Tasks' '' 'An example:' '' '```' '- [ ] T1 - Example' '```' '' '- [ ] T1 - The real one' '  - Requirements: R1' '  - Design: None' \
  '  - Check: run it' '    ```sh' '#!/bin/sh' '    ```' '  - Files: a.sh' '- [ ] T2: Colon form' '  - Requirements: R1,' '- [ ] T5 - Twice' '  - Requirements: R1' '- [ ] T5 - Twice again' '  - Requirements: R1' >"$CRT"
sb spec tasks SP-1
out_is "spec tasks: fenced code is not read, and T2: is a task" "T1${TAB}todo${TAB}The real one${TAB}-
T2${TAB}todo${TAB}Colon form${TAB}-
T5${TAB}todo${TAB}Twice${TAB}-
T5${TAB}todo${TAB}Twice again${TAB}-"
sb spec packet SP-1 T1
rc_is "spec packet: Design: None names no section, in any letter case" 0
out_has "spec packet: a fence inside the item keeps the lines after it" "  - Files: a.sh"
sb spec packet SP-1 T2
rc_is "spec packet: a field that ends in a comma exits 1" 1
err_has "spec packet: and says to write it on one line" "write each field of a task on one line"
sb spec packet SP-1 T5
rc_is "spec packet: two items with one id exit 1" 1
err_has "spec packet: and say so" "have the id T5"
sb spec tick SP-1 T5
rc_is "spec tick: two items with one id exit 1" 1
sb spec tick SP-1 T1
line_is "spec tick: the fenced example is left alone" "$CRT" "- [ ] T1 - Example"
line_is "spec tick: the real item is ticked" "$CRT" "- [x] T1 - The real one"

# ---------------------------------------------------------------- spec tasks: bundles
printf '%s\n' '# SP-1 - Tasks' '' 'Tasks with the same `- Bundle: <n>` line are one bundle.' '' '```' '- [ ] T1 - Example' '  - Bundle: 7' '```' '' \
  '- [ ] T1 - Alone' '  - Requirements: R1' \
  '- [ ] T2 - First of two' '  - Requirements: R1' '  - Bundle: 1' \
  '- [x] T3 - Second of two' '  - Requirements: R1' '  - bundle: 01' '  - Bundle: 9' \
  '- [ ] T4 - None named' '  - Requirements: R1' '  - Bundle: None' \
  '- [ ] T5 - The template' '  - Requirements: R1' '  - Bundle: <n>' \
  '- [ ] T6 - Another bundle' '  - Requirements: R1' '  - Bundle: 2' \
  '- [ ] T7 - Its second' '  - Requirements: R1' '  - Bundle: 2' \
  '- [ ] T8 - Last' '  - Requirements: R1' '' 'Notes:' '  - Bundle: 5' >"$CRT"
sb spec tasks SP-1
rc_is "spec tasks: a bundled list exits 0" 0
out_is "spec tasks: each task's bundle last, from its own first Bundle line, as a number" "T1${TAB}todo${TAB}Alone${TAB}-
T2${TAB}todo${TAB}First of two${TAB}1
T3${TAB}done${TAB}Second of two${TAB}1
T4${TAB}todo${TAB}None named${TAB}-
T5${TAB}todo${TAB}The template${TAB}-
T6${TAB}todo${TAB}Another bundle${TAB}2
T7${TAB}todo${TAB}Its second${TAB}2
T8${TAB}todo${TAB}Last${TAB}-"
text="$OUT"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$CRT" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$CRT"
sb spec tasks SP-1
is "spec tasks: CRLF line endings read the same" "$OUT" "$text"
sb spec tasks SP-1 --json
json_ok "spec tasks --json: a bundled list parses as JSON"
out_has "spec tasks --json: the bundle is a string" '{"id": "T2", "state": "todo", "title": "First of two", "bundle": "1"}'
sb spec packet SP-1 T2
rc_is "spec packet: a bundled task builds its packet" 0
out_has "spec packet: and shows its Bundle line as written" "  - Bundle: 1"
printf '%s\n' '# SP-1 - Tasks' '' '- [ ] T1 - One' '  - Requirements: R1' '  - Bundle: 1' \
  '- [ ] T2 - Two' '  - Requirements: R1' '  - Bundle: two' '- [ ] T3 - Three' '  - Requirements: R1' '  - Bundle: x' >"$CRT"
sb spec tasks SP-1
rc_is "spec tasks: a bundle that is no whole number exits 1" 1
out_is "spec tasks: and prints no row" ""
err_has "spec tasks: and names the first such task" "T2 has the bundle two in $S/tasks/SP-1/spec/tasks.md: a bundle is a whole number"
sb spec tasks SP-1 --json
rc_is "spec tasks --json: a bad bundle exits 1 too" 1
out_is "spec tasks --json: and prints nothing" ""
printf '%s\n' '# SP-1 - Tasks' '' '- [ ] T1 - One' '  - Requirements: R1' '  - Bundle: 1' \
  '- [ ] T2 - Two' '  - Requirements: R1' '- [ ] T3 - Three' '  - Requirements: R1' '  - Bundle: 1' >"$CRT"
sb spec tasks SP-1
rc_is "spec tasks: a bundle split by another task exits 1" 1
out_is "spec tasks: and prints no row either" ""
err_has "spec tasks: and names the task out of place" \
  "T3 is in bundle 1, but the task before it is not: put a bundle's tasks next to each other in $S/tasks/SP-1/spec/tasks.md"
printf '\n## R1 - Again\n' >>"$SD/requirements.md"
printf '%s\n' '# SP-1 - Tasks' '' '- [ ] T1 - One' '  - Requirements: R1' >"$CRT"
sb spec packet SP-1 T1
rc_is "spec packet: a requirement with two sections exits 1" 1
err_has "spec packet: and names it" "has two sections for R1"
edit "$SPF" 's/^spec_home: vault$/spec_home: repo/'
edit "$SPF" "s|^repos_root: \"$tmp/scode\"\$|repos_root: \"\"|"
sb spec SP-1
rc_is "spec: a repo spec with no recorded location still exits 1" 1
out_has "spec: but prints the delivery first" "delivery: direct"
out_has "spec: and the folder as -" "dir: -"
edit "$SPF" "s|^repos_root: \"\"\$|repos_root: \"$tmp/scode\"|; s/^spec_home: repo$/spec_home: vault/"
for a in implementer reviewer spec-checker; do
  line_is "$a: loads no CLAUDE.md" "$here/agents/$a.md" "omitClaudeMd: true"
done
file_has "spec build: read only once all three approvals count" "$BM" 'Read this file only when all three approvals count'
line_is "spec build: a BLOCKED review stops at once" "$BM" '5. BLOCKED: first the stop note,'
file_has "spec build: a BLOCKED build stops at once" "$BM" '3. Its reply starts with `BLOCKED:`, or has no `Commit:` line: first the stop note,'
is "spec build: each block writes the stop note before it sets blocked" \
  "$(awk '/stopped at <task>: <why>\."`, then$/ { n = NR } /^   `second-brain spec status <ID> <task> blocked`, and stop\.$/ && n == NR - 1 { k++ } END { print k + 0 }' "$BM")" "2"
is "spec build: and nothing sets blocked any other way" "$(grep -c 'spec status <ID> <task> blocked`' "$BM")" "2"
file_has "spec build: commits the tick of a repo spec" "$BM" 'commit -m "<ID> <task>: passed review" -- spec/<ID>/tasks.md'
file_has "spec build: a session resumes the build from build.json" "$BM" \
  'It prints a line: the build resumes, from the states `build.json` in the story'"'"'s folder'
file_has "reviewer: a BLOCKED verdict" "$here/agents/reviewer.md" '`VERDICT: BLOCKED`: a step could not be run'
file_has "implementer: reads nothing outside the repo" "$here/agents/implementer.md" 'Read nothing outside `repo_path`'
file_has "spec skill: a reopened phase voids later approvals" "$here/skills/spec/SKILL.md" 'only when it is newer than every `reopened` note'
file_has "spec build: commits a repo spec before the build" "$BM" 'commit -m "<ID>: spec"'

# ---------------------------------------------------------------- spec link
sb help
out_has "help: lists spec link" "spec packet <ID> <task> | spec link <ID>"
for n in 2 3 4 5; do sb task new "SP-$n" --project Specs --title "Linked $n"; done
for n in 2 3 5; do sb task set "SP-$n" delivery=spec; sb spec new "SP-$n"; done
L2="$vault/$S/tasks/SP-2/README.md"
sb spec link SP-2
rc_is "spec link: exit 0" 0
out_is "spec link: names each section it changed" "linked: Approach / Key decisions
linked: Changes
linked: Verification"
is "spec link: the design link opens Approach, the template text gone" \
  "$(awk '/^## Approach/ { on = 1; next } on && /^## / { exit } on' "$L2")" "
See [[$S/tasks/SP-2/spec/design|SP-2 Design]]."
is "spec link: the tasks link replaces None yet. in Changes" \
  "$(awk '/^## Changes/ { on = 1; next } on && /^## / { exit } on' "$L2")" "
See [[$S/tasks/SP-2/spec/tasks|SP-2 Tasks]]."
line_is "spec link: and opens Verification" "$L2" "See [[$S/tasks/SP-2/spec/tasks|SP-2 Tasks]]."
sb unresolved Specs
out_is "spec link: its links resolve" ""
cp "$L2" "$tmp/sp2.before"
sb spec link SP-2
out_is "spec link again: no change" "no change"
if cmp -s "$L2" "$tmp/sp2.before"; then pass "spec link again: the README is byte-identical"; else fail "spec link again: the README is byte-identical"; fi
L3="$vault/$S/tasks/SP-3/README.md"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$L3" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$L3"
sb spec link SP-3
rc_is "spec link: a CRLF README takes the links" 0
is "spec link: every line keeps its CRLF" "$(grep -vc "$CR\$" "$L3" || true)" "0"
L4="$vault/$S/tasks/SP-4/README.md"
cp "$L4" "$tmp/sp4.before"
sb spec link SP-4
out_is "spec link: a direct story is not built from a spec" "no change: SP-4 is not built from a spec (delivery: direct)"
if cmp -s "$L4" "$tmp/sp4.before"; then pass "spec link: a direct story's README is byte-identical"; else fail "spec link: a direct story's README is byte-identical"; fi
L5="$vault/$S/tasks/SP-5/README.md"
awk '{ print } /^## Approach \/ Key decisions$/ { getline; print; getline; print "- Keep this decision."; next }' "$L5" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$L5"
sb spec link SP-5
is "spec link: other text stays under the link" \
  "$(awk '/^## Approach/ { on = 1; next } on && /^## / { exit } on' "$L5" | head -4)" "
See [[$S/tasks/SP-5/spec/design|SP-5 Design]].

- Keep this decision."
rm "$vault/$S/tasks/SP-5/spec/design.md"
sb spec link SP-5
rc_is "spec link: a missing design.md exits 1" 1
edit "$SPF" 's/^spec_home: vault$/spec_home: repo/'
sb task new SP-6 --project Specs --title "Repo link"
sb task set SP-6 delivery=spec
sb spec new SP-6
sb spec link SP-6
line_is "spec link: a repo spec names the file and the repo" "$vault/$S/tasks/SP-6/README.md" 'See `spec/SP-6/design.md` in the `spec-app` repo.'
edit "$SPF" 's/^spec_home: repo$/spec_home: vault/'
file_has "spec skill: runs spec link after the tasks approval" "$here/skills/spec/SKILL.md" 'After the tasks note, run `second-brain spec link <ID>`'
file_has "spec phases: each requirement opens with its Serves line" "$here/skills/spec/phases.md" 'Each section opens with `- Serves: AC1, AC3`'
file_has "spec phases: every criterion is served" "$here/skills/spec/phases.md" 'Every criterion of the story is named on a `- Serves:` line'
file_has "spec phases: the doctor checks the trace" "$here/skills/spec/phases.md" 'its `spec-trace` row must name'

# ---------------------------------------------------------------- spec status and spec issue
sb help
out_has "help: lists spec status and spec issue" 'spec status <ID> [<task> <state> [--commit H]] | spec issue <ID> <task> "<issue>" --fix "<fix>"'
B2="$vault/$S/tasks/SP-2/build.json"
cp "$L2" "$tmp/sp2.readme"
sb spec status SP-2
rc_is "spec status: a story with no build exits 0" 0
out_is "spec status: and prints nothing" ""
absent "spec status: reading writes no build.json" "$B2"
SECOND_BRAIN_NOW="2026-10-08T09:30:00-05:00" sb spec status SP-2 t1 building --session s-1
rc_is "spec status: exit 0" 0
out_is "spec status: names the task and its state" "T1: building"
exists "spec status: build.json is in the task folder" "$B2"
if cmp -s "$L2" "$tmp/sp2.readme"; then pass "spec status: the README is byte-identical, no note and no section"; else fail "spec status: the README is byte-identical, no note and no section"; fi
OUT="$(cat "$B2")"
json_ok "spec status: build.json parses as JSON"
json_is "spec status: build.json names the story and the task" \
  'print(d["story"], d["tasks"][0]["id"], d["tasks"][0]["title"])' "SP-2 T1 <What the task builds.>"
json_is "spec status: the build state is set, the review not yet" \
  't = d["tasks"][0]; print(t["build"], t["review"], t["commits"], t["issues"])' "building - [] []"
json_is "spec status: the history holds the state, its time and session" \
  'print(d["tasks"][0]["history"])' \
  "[{'at': '2026-10-08T09:30:00-05:00', 'session': 's-1', 'field': 'build', 'state': 'building'}]"
sb spec status SP-2 T1 built --commit abc1234
sb spec status SP-2
out_is "spec status: one line per task, its build and review" 'T1 - build: built - review: - - fails 0 - commits abc1234 - <What the task builds.>'
sb spec status SP-2 T1 in-review
sb spec status SP-2 T1 failed --commit def5678
sb spec status SP-2 T1 built --commit abc1234
sb spec status SP-2
out_is "spec status: a review state goes in the review field, a second commit once" \
  'T1 - build: built - review: failed - fails 1 - commits abc1234, def5678 - <What the task builds.>'
sb spec issue SP-2 T1 "The form has one field." --fix "Add the password field." --session s-2
rc_is "spec issue: exit 0" 0
out_is "spec issue: names the task" "T1: issue"
sb spec status SP-2
out_is "spec issue: the issue sits under its task, with its fix" \
  'T1 - build: built - review: failed - fails 1 - commits abc1234, def5678 - <What the task builds.>
  - Issue 2026-10-08: The form has one field. Fix: Add the password field.'
OUT="$(cat "$B2")"
json_is "spec issue: build.json holds the issue, its fix, time and session" 'print(d["tasks"][0]["issues"])' \
  "[{'at': '2026-10-08T00:00:00+00:00', 'session': 's-2', 'issue': 'The form has one field.', 'fix': 'Add the password field.', 'round': 1}]"
json_is "spec status: every state set is in the history, oldest first" \
  'print(" ".join(h["field"] + ":" + h["state"] for h in d["tasks"][0]["history"]))' \
  "build:building build:built review:in-review review:failed build:built"
sb spec status SP-2 T1 in-review
sb spec status SP-2 T1 blocked
sb spec status SP-2
out_has "spec status: blocked during a review is the review's" "T1 - build: built - review: blocked - "
sb spec status SP-2 T1 building
sb spec status SP-2 T1 blocked
sb spec status SP-2
out_has "spec status: blocked otherwise is the build's" "T1 - build: blocked - review: blocked - "
if cmp -s "$L2" "$tmp/sp2.readme"; then pass "spec issue: the README is still byte-identical"; else fail "spec issue: the README is still byte-identical"; fi
printf '%s\n' '' '- [x] T2 - The second task' '  - Requirements: R1' >>"$vault/$S/tasks/SP-2/spec/tasks.md"
sb spec status SP-2
out_has "spec status: a ticked task build.json lacks starts built and passed" \
  'T2 - build: built - review: passed - fails 0 - commits - - The second task'
sb spec status SP-2 T1 done
rc_is "spec status: another state exits 5" 5
err_has "spec status: and names both kinds of state" "a review state is one of: in-review, passed, failed, blocked"
sb spec status SP-2 T1 built --commit xyz
rc_is "spec status: a commit that is not hex exits 5" 5
sb spec status SP-2 T9 built
rc_is "spec status: a task tasks.md lacks exits 1" 1
sb spec status SP-2 T1
rc_is "spec status: a task with no state exits 5" 5
sb spec issue SP-2 T1 "No fix given."
rc_is "spec issue: no --fix exits 5" 5
sb spec tick SP-2 T1 --commit abc
rc_is "spec tick: --commit is not its flag, exit 5" 5
cp "$B2" "$tmp/b2.good"
printf '%s\n' '{"story": "SP-2", "tasks": [' >"$B2"
sb spec status SP-2
rc_is "spec status: a build.json that is not JSON exits 1" 1
err_has "spec status: and names it" "$S/tasks/SP-2/build.json is not a JSON object with a tasks array"
sb spec status SP-2 T1 built
rc_is "spec status: a write on it exits 1 too" 1
is "spec status: and leaves it as it was" "$(cat "$B2")" '{"story": "SP-2", "tasks": ['
for bad in '' '   ' '{}' '[]' '{"tasks": {}}'; do
  printf '%s\n' "$bad" >"$B2"
  sb spec status SP-2
  rc_is "spec status: a build.json that holds '$bad' exits 1, never a fresh build" 1
  sb spec issue SP-2 T1 "Lost?" --fix "No."
  rc_is "spec issue: and a write on '$bad' exits 1" 1
done
: >"$B2"
sb spec status SP-2 --json
rc_is "spec status --json: an empty build.json exits 1" 1
out_is "spec status --json: and prints nothing" ""
cp "$tmp/b2.good" "$B2"
tr -d '\n' <"$tmp/b2.good" >"$B2"
sb spec status SP-2
text="$OUT"
cp "$tmp/b2.good" "$B2"
sb spec status SP-2
is "spec status: a build.json on one line reads the same" "$text" "$OUT"
sb spec status SP-2 T1 built
is "spec status: a write leaves no temp file in the task folder" \
  "$(cd "$vault/$S/tasks/SP-2" && ls -A | grep -v '^README.md$' | grep -v '^spec$' || true)" "build.json"
sb spec issue SP-2 T1 "Line one.${NL}Line two." --fix "Fix it${CR}${NL}now."
sb spec status SP-2
out_has "spec status: a line break in an issue prints as a blank" \
  "  - Issue 2026-10-08: Line one. Line two. Fix: Fix it now."
is "spec status: and every issue stays one line" "$(printf '%s\n' "$OUT" | grep -c '^  - Issue ')" "2"
is "spec status: and no line is left over" "$(printf '%s\n' "$OUT" | grep -vc '^T[0-9]* - build: \|^  - Issue ' || true)" "0"
OUT="$(cat "$B2")"
json_is "spec issue: build.json keeps the line break" 'print(d["tasks"][0]["issues"][-1]["issue"] == "Line one.\nLine two.")' "True"
sb spec status SP-2 --json
json_is "spec status --json: the issue line has no line break" 'print(d[0]["issues"][-1])' \
  "Issue 2026-10-08: Line one. Line two. Fix: Fix it now."
cp "$tmp/b2.good" "$B2"
sb spec status SP-3 T1 todo
rc_is "spec status: a CRLF README takes a write" 0
is "spec status: every line keeps its CRLF" "$(grep -vc "$CR\$" "$L3" || true)" "0"
# A README Build section, as versions before 0.7.0 wrote it: read as it is, moved on the next write.
B5="$vault/$S/tasks/SP-5/build.json"
L5T="$vault/$S/tasks/SP-5/spec/tasks.md"
printf '%s\n' '# SP-5 - Tasks' '' '- [ ] T1 - First' '  - Requirements: R1' '- [x] T2 - Second' '  - Requirements: R1' \
  '- [ ] T3 - Third' '  - Requirements: R1' '- [ ] T4 - Fourth' '  - Requirements: R1' '- [ ] T5 - Fifth' '  - Requirements: R1' >"$L5T"
cp "$L5" "$tmp/sp5.without"
awk '/^## Status notes$/ {
    print "## Build"; print ""
    print "- T1 - failed - commits `abc1234`, `def5678` - First"
    print "  - Issue 2026-10-01: The form has one field. Fix: Add the password field."
    print "- T2 - passed - commits `0a1b2c3` - Second"
    print "- T3 - blocked - commits - - Third"
    print "- T4 - blocked - commits `1111aaa` - Fourth"
    print "- T9 - in-review - commits `2222bbb` - Gone - with a dash"
    print ""
  } { print }' "$tmp/sp5.without" >"$L5"
cp "$L5" "$tmp/sp5.with"
sb spec status SP-5
out_is "spec status: an old Build section is read, each state in its field" \
  'T1 - build: built - review: failed - fails 0 - commits abc1234, def5678 - First
  - Issue 2026-10-01: The form has one field. Fix: Add the password field.
T2 - build: built - review: passed - fails 0 - commits 0a1b2c3 - Second
T3 - build: blocked - review: - - fails 0 - commits - - Third
T4 - build: built - review: blocked - fails 0 - commits 1111aaa - Fourth
T5 - build: todo - review: - - fails 0 - commits - - Fifth
T9 - build: built - review: in-review - fails 0 - commits 2222bbb - Gone - with a dash'
if cmp -s "$L5" "$tmp/sp5.with"; then pass "spec status: reading leaves the old section"; else fail "spec status: reading leaves the old section"; fi
sb spec status SP-5 T5 building
rc_is "spec status: a write on an old section exits 0" 0
err_has "spec status: says it moved the section" "note: moved ## Build of $S/tasks/SP-5/README.md into $S/tasks/SP-5/build.json"
if cmp -s "$L5" "$tmp/sp5.without"; then pass "spec status: the section is gone, the rest byte-identical"; else fail "spec status: the section is gone, the rest byte-identical" "$(diff "$tmp/sp5.without" "$L5")"; fi
sb spec status SP-5
out_has "spec status: the moved rows are in build.json" 'T1 - build: built - review: failed - fails 0 - commits abc1234, def5678 - First
  - Issue 2026-10-01: The form has one field. Fix: Add the password field.'
out_has "spec status: with the write applied" 'T5 - build: building - review: - - fails 0 - commits - - Fifth'
out_has "spec status: a moved row whose task left tasks.md stays at the end" \
  'T9 - build: built - review: in-review - fails 0 - commits 2222bbb - Gone - with a dash'
OUT="$(cat "$B5")"
json_is "spec status: a moved issue keeps its date, its fix split off" 'print(d["tasks"][0]["issues"])' \
  "[{'at': '2026-10-01', 'session': '-', 'issue': 'The form has one field.', 'fix': 'Add the password field.', 'round': 0}]"
json_is "spec status: a moved row has no history" 'print(d["tasks"][0]["history"])' "[]"
printf '%s\n' '' '## Build' '' '- T1 - todo - commits - - First' >>"$L5"
sb spec issue SP-5 T1 "Late." --fix "Fix it."
sb spec status SP-5
is "spec issue: build.json wins over a section written later" "$(printf '%s\n' "$OUT" | head -1)" \
  "T1 - build: built - review: failed - fails 0 - commits abc1234, def5678 - First"
if cmp -s "$L5" "$tmp/sp5.without"; then pass "spec issue: a section at the end goes with the blank lines before it"; else fail "spec issue: a section at the end goes with the blank lines before it" "$(diff "$tmp/sp5.without" "$L5")"; fi
awk '/^## Status notes/ { printf "## Build\r\n\r\n- T1 - built - commits `abc1234` - One\r\n\r\n" } { print }' "$L3" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$L3"
sb spec issue SP-3 T1 "CRLF." --fix "Keep it."
file_lacks "spec issue: the section leaves a CRLF README" "$L3" "## Build"
is "spec issue: and every line keeps its CRLF" "$(grep -vc "$CR\$" "$L3" || true)" "0"
# build.json sits in the vault even for a repo spec, so the repo's tree stays clean.
edit "$SPF" 's/^spec_home: vault$/spec_home: repo/'
printf '%s\n' '# SP-6 - Tasks' '' '- [ ] T1 - Repo task' '  - Requirements: R1' >"$tmp/scode/spec-app/spec/SP-6/tasks.md"
sb spec status SP-6 T1 building
rc_is "spec status: a repo spec takes a write" 0
exists "spec status: its build.json is in the vault's task folder" "$vault/$S/tasks/SP-6/build.json"
absent "spec status: and not in the repo" "$tmp/scode/spec-app/spec/SP-6/build.json"
edit "$SPF" 's/^spec_home: repo$/spec_home: vault/'

# ---------------------------------------------------------------- spec packet: uses, issues and the diff
sb task new SP-10 --project Specs --title "Packet story"
sb task set SP-10 delivery=spec branch=feature/SP-10
sb spec new SP-10
D10="$vault/$S/tasks/SP-10/spec"
printf '%s\n' '# SP-10 - Requirements' '' '## R1 - One' '' 'WHEN a user signs in, THE app SHALL open a session.' >"$D10/requirements.md"
printf '%s\n' '# SP-10 - Tasks' '' '- [ ] T1 - The API' '  - Requirements: R1' \
  '  - Provides: `login(email, password) -> Session`' '  - Provides: `logout(session)`' \
  '- [ ] T2 - The page' '  - Requirements: R1' '  - Uses: T1' \
  '- [ ] T3 - A later one' '  - Requirements: R1' '  - Uses: T4' \
  '- [ ] T4 - Uses one with none' '  - Requirements: R1' '  - Uses: T2' \
  '- [ ] T5 - Unknown' '  - Requirements: R1' '  - Uses: T1, T9' \
  '- [ ] T6 - None named' '  - Requirements: R1' '  - Uses: none' \
  '- [ ] T7 - Comma' '  - Requirements: R1' '  - Uses: T1,' >"$D10/tasks.md"
ODIR="${TMPDIR:-}"
mkdir -p "$tmp/tmpd"
export TMPDIR="$tmp/tmpd"
sb spec packet SP-10 T1
rc_is "spec packet: exit 0 before any build" 0
out_has "spec packet: no commit yet, no diff" "commits: -
fails: 0
diff: none (no commit)"
out_lacks "spec packet: no Uses part when it names none" "## Uses"
out_lacks "spec packet: no Issues part when it has none" "## Issues"
sb spec packet SP-10 T2
rc_is "spec packet: a task that uses an earlier one exits 0" 0
out_has "spec packet: holds the Provides lines of the task it uses" "## Uses

### T1 - The API

- Provides: \`login(email, password) -> Session\`
- Provides: \`logout(session)\`"
sb spec packet SP-10 T3
rc_is "spec packet: a task that uses a later one exits 1" 1
err_has "spec packet: and says so" "T3 uses T4, which is not an earlier task"
sb spec packet SP-10 T4
rc_is "spec packet: a used task with no Provides line exits 1" 1
err_has "spec packet: and names it" "T4 uses T2, which has no - Provides: line"
sb spec packet SP-10 T5
rc_is "spec packet: a used task tasks.md lacks exits 1" 1
err_has "spec packet: and names it" "T5 uses T9, which $S/tasks/SP-10/spec/tasks.md has no item for"
sb spec packet SP-10 T6
rc_is "spec packet: Uses: none exits 0" 0
out_lacks "spec packet: and has no Uses part" "## Uses"
sb spec packet SP-10 T7
rc_is "spec packet: a Uses line that ends in a comma exits 1" 1
err_has "spec packet: and says to write it on one line" "write each field of a task on one line"
APP="$tmp/scode/spec-app"
git -C "$APP" -c init.defaultBranch=main init -q
printf 'one\n' >"$APP/login.txt"
git -C "$APP" add login.txt
git -C "$APP" -c user.name=Test -c user.email=test@example.com commit -qm "SP-10 T1: The API"
h1="$(git -C "$APP" rev-parse --short HEAD)"
sb spec status SP-10 T1 built --commit "$h1"
sb spec issue SP-10 T1 "Logout is missing, at login.txt:1." --fix "Add logout."
sb spec issue SP-10 T1 "Two${NL}lines." --fix "One${NL}line."
sb spec packet SP-10 T1
rc_is "spec packet: exit 0 with a commit" 0
out_has "spec packet: names the task's commits" "commits: $h1"
dline="$(printf '%s\n' "$OUT" | sed -n 's/^diff: //p')"
is "spec packet: the diff is a temp file, outside the repo and the vault" "${dline%/*}" "$(shown "$tmp/tmpd")"
file_has "spec packet: the diff file holds the commit's change" "$dline" "+one"
out_has "spec packet: holds the task's logged issues, each on one line" "## Issues

- Issue 2026-10-08: Logout is missing, at login.txt:1. Fix: Add logout.
- Issue 2026-10-08: Two lines. Fix: One line."
case "$OUT" in
  *"## Issues"*"## Checks"*"## Validation"*) pass "spec packet: the issues, then the checks, then the validation steps" ;;
  *) fail "spec packet: the issues, then the checks, then the validation steps" "in: $OUT" ;;
esac
printf 'two\n' >>"$APP/login.txt"
git -C "$APP" -c user.name=Test -c user.email=test@example.com commit -qam "SP-10 T1: The API"
h2="$(git -C "$APP" rev-parse --short HEAD)"
sb spec status SP-10 T1 built --commit "$h2"
sb spec packet SP-10 T1
dline="$(printf '%s\n' "$OUT" | sed -n 's/^diff: //p')"
out_has "spec packet: a retry's commits, in order" "commits: $h1, $h2"
file_has "spec packet: the diff holds the first commit" "$dline" "+one"
file_has "spec packet: and the second" "$dline" "+two"
is "spec packet: the repo's tree stays clean" "$(git -C "$APP" status --porcelain | grep -v ' spec/' || true)" ""
# A failed review: the next packet is a fix's, with only the findings of that review.
sb spec status SP-10 T1 in-review
sb spec issue SP-10 T1 "Round one: no logout." --fix "Add it."
sb spec status SP-10 T1 failed
sb spec packet SP-10 T1
out_has "spec packet: a fix names the failed reviews" "fails: 1"
out_has "spec packet: no fix commit yet, no diff" "diff: none (no fix commit)"
out_has "spec packet: a fix holds the findings of the failed review" "- Issue 2026-10-08: Round one: no logout. Fix: Add it."
out_lacks "spec packet: and not those logged before it" "Logout is missing"
printf 'three\n' >>"$APP/login.txt"
git -C "$APP" -c user.name=Test -c user.email=test@example.com commit -qam "SP-10 T1: The API"
h3="$(git -C "$APP" rev-parse --short HEAD)"
sb spec status SP-10 T1 building
sb spec status SP-10 T1 built --commit "$h3"
sb spec packet SP-10 T1
out_has "spec packet: a fix still names every commit" "commits: $h1, $h2, $h3"
dline="$(printf '%s\n' "$OUT" | sed -n 's/^diff: //p')"
file_has "spec packet: a fix's diff holds the fix's commit" "$dline" "+three"
file_lacks "spec packet: and not the commits before the failed review" "$dline" "+one"
OUT="$(cat "$vault/$S/tasks/SP-10/build.json")"
json_is "spec status: build.json records the commit of a state set with --commit" \
  'print([h.get("commit", "-") for h in d["tasks"][0]["history"]])' "['$h1', '$h2', '-', '-', '-', '$h3']"
json_is "spec issue: each issue records its review round" 'print([i["round"] for i in d["tasks"][0]["issues"]])' "[0, 0, 1]"
sb spec status SP-10 T1 in-review
sb spec issue SP-10 T1 "Round two: logout leaks." --fix "Close it."
sb spec status SP-10 T1 failed
sb spec status SP-10
out_has "spec status: counts the failed reviews" "T1 - build: built - review: failed - fails 2 - commits $h1, $h2, $h3 - The API"
sb spec packet SP-10 T1
out_has "spec packet: a second fix holds only the second review's findings" "- Issue 2026-10-08: Round two: logout leaks. Fix: Close it."
out_lacks "spec packet: and not the first's" "Round one"
sb spec status SP-10 T1 in-review
sb spec status SP-10 T1 passed
sb spec issue SP-10 T1 "The build-wide run fails." --fix "Fix it."
sb spec status SP-10 T1 failed
sb spec packet SP-10 T1
out_has "spec packet: a passed task failed by the build-wide run counts it" "fails: 3"
out_has "spec packet: and its fix holds that finding" "- Issue 2026-10-08: The build-wide run fails. Fix: Fix it."
out_lacks "spec packet: alone" "Round two"
sb spec status SP-10 --json
json_is "spec status --json: fails is a count" 'print(d[0]["fails"] + 1)' "4"
sb spec status SP-10 T2 built --commit abcdef0
sb spec packet SP-10 T2
rc_is "spec packet: a commit git cannot show still exits 0" 0
out_has "spec packet: and has no diff" "diff: none (git show failed)"
err_has "spec packet: and names the commit" "note: git show abcdef0 failed in spec-app"
if [ -n "$ODIR" ]; then export TMPDIR="$ODIR"; else unset TMPDIR; fi

# ---------------------------------------------------------------- the build runs in the owner's session
lead="spec""-lead"
absent "$lead: the agent is gone" "$here/agents/$lead.md"
named="$(cd "$here" && find . -type f -not -path './.git' -not -path './.git/*' -not -path './.scratch/*' -not -path './tmp/*' \
  -not -path './.omc/*' -not -path './.claude/*' -not -name CHANGELOG.md -exec grep -lF -- "$lead" {} + 2>/dev/null)"
is "$lead: no file but CHANGELOG.md names it" "$named" ""
file_has "changelog: says $lead is gone" "$here/CHANGELOG.md" "The \`$lead\` agent is gone."
is "spec skill: SKILL.md stays a short router" "$(($(lines "$(cat "$SK")") <= 90))" "1"
file_has "spec skill: reads build.md only when a build starts" "$SK" \
  '`${CLAUDE_SKILL_DIR}/build.md` once, when a build starts or resumes, and follow it.'
file_lacks "spec skill: holds no build step" "$SK" 'spec status <ID> <task>'
file_lacks "spec skill: launches no build agent" "$SK" 'odsb:implementer'
exists "spec build: the build has its own file" "$BM"
file_has "spec build: launches one agent at a time with the Agent tool" "$BM" \
  '- Launch one agent at a time with the Agent tool, and wait for its result. Its result is its'
file_has "spec build: takes each report from the result, relays nothing" "$BM" \
  'report: never relay a report by hand, and never read an agent'"'"'s transcript.'
file_has "spec build: names the implementer's model" "$BM" '- `odsb:implementer`: `model: "opus"`.'
line_is "spec build: the stronger model from fix round 4 on" "$BM" \
  '  - `odsb:implementer` from fix round 4 on: `model: "fable"`, the stronger model.'
line_is "spec build: names the reviewer's model" "$BM" '  - `odsb:reviewer` in task, baseline or user mode: `model: "opus"`.'
line_is "spec build: the branch review on the most capable model" "$BM" \
  '  - `odsb:reviewer` in branch mode: `model: "fable"`, the most capable model.'
line_is "spec build: names the implementer for the build" "$BM" \
  '  - The build and fix rounds 1 to 3: `name: "<ID>-<task>-implementer"`.'
line_is "spec build: and from fix round 4 on" "$BM" '  - From fix round 4 on: `name: "<ID>-<task>-implementer-2"`.'
file_has "spec build: never prints a packet" "$BM" 'Never run `spec packet` here, and never put a packet, a diff or'
for l in '  - `Story: <ID>, project <project>.`' '  - `Task: <task>.`' '  - `Session: <session id>.`' \
  '  - Last, the commit line: `Commit it as "<ID> <task>: <title>".`' \
  '  - `Fix: the review of <task> failed. Fetch your packet again: its ## Issues lists the findings.`'; do
  line_is "spec build: the implementer's prompt line ${l#  - }" "$BM" "$l"
done
file_has "spec build: the fix message goes with SendMessage, by name" "$BM" \
  '- The fix message, sent with SendMessage to an `implementer` by its name, one line each:'
file_has "spec build: the branch review starts from the build's start" "$BM" \
  'the hash of the newest `Build: started on <branch> at <short hash>.` note.'
file_lacks "spec build: no pass that builds every task first" "$BM" '## 5. Build every task'
file_lacks "spec build: and no pass that reviews them after" "$BM" '## 6. Review every task'
# The order: each task is built, then reviewed, then fixed, before the next; then the build-wide
# run, the user check and the branch review.
for h in '### Where the task stands' '### Build it' '### Review it' '### The fix loop' '## 6. When every task passed'; do
  line_is "spec build: has $h" "$BM" "$h"
done
# linex <file> <line>: the number of the first line that is exactly that text.
linex() { grep -nxF -- "$2" "$1" | head -1 | cut -d: -f1; }
o1="$(linex "$BM" '### Build it')"
o2="$(lineno "$BM" '2. Launch `implementer` on the task, named for the build.')"
o3="$(linex "$BM" '### Review it')"
o4="$(lineno "$BM" '2. Launch a fresh `reviewer` in task mode on the task.')"
o5="$(linex "$BM" '### The fix loop')"
o6="$(linex "$BM" '## 6. When every task passed')"
o7="$(lineno "$BM" '`second-brain validation run "<project>" <repo> --when each-build`.')"
o8="$(lineno "$BM" '2. Launch `reviewer` in user mode on the finished branch.')"
o9="$(lineno "$BM" '3. Launch `reviewer` in branch mode: one review of the whole branch ends the build.')"
o10="$(lineno "$BM" '7. Read `finish.md`, next to this file, and follow it.')"
is "spec build: build, review, fix, then the build-wide run, the user check and the branch review, in order" \
  "$((${o1:-0} > 0 && o1 < o2 && o2 < o3 && o3 < o4 && o4 < o5 && o5 < o6 && o6 < o7 && o7 < o8 && o8 < o9 && o9 < o10))" "1"
file_has "spec build: each task is reviewed before the next starts" "$BM" \
  'review it right after, before the next task starts. A task that fails holds up the tasks after it'
line_is "spec build: the build-wide run has no agent" "$BM" '1. Run the build-wide checks once, with no agent:'
file_has "spec build: a failing check is logged on its task" "$BM" \
  '"<command> fails in the build-wide run, exit <code>: <its lines>" --fix "<the fix you propose>"`.'
file_has "spec build: and that task takes the fix loop" "$BM" \
  '- Then `second-brain spec status <ID> <task> failed` for each such task, and go back to'
line_is "spec build: building before the implementer" "$BM" '1. `second-brain spec status <ID> <task> building`.'
line_is "spec build: in-review before the reviewer" "$BM" '1. `second-brain spec status <ID> <task> in-review`.'
file_has "spec build: building before each fix round too" "$BM" \
  '2. Otherwise, `second-brain spec status <ID> <task> building`, then the round:'
file_has "spec build: the fix rounds come from build.json, every session's" "$BM" \
  'The task'"'"'s `fails` in `spec status <ID>` is its failed reviews in `build.json`, from every session.'
line_is "spec build: rounds 1 to 3 go to the same implementer" "$BM" \
  '   - `fails` 1 to 3: the same `implementer`. Send the fix message to'
file_has "spec build: a fresh one when it cannot be reached" "$BM" \
  '- SendMessage is not there, or no agent has that name, as in a new session: launch a fresh'
line_is "spec build: round 4 goes to a fresh one on the stronger model" "$BM" \
  '   - `fails` 4: launch a fresh `implementer` on the stronger model, named from round 4 on, with'
line_is "spec build: round 5 goes back to it" "$BM" \
  '   - `fails` 5: send the fix message to `<ID>-<task>-implementer-2`, or launch a fresh one as for'
line_is "spec build: a sixth failed review stops the build" "$BM" \
  '1. `fails` 6 or more, right after a FAIL: the cap is reached. First the stop note,'
is "spec build: the cap is checked before a round sets building" \
  "$(($(lineno "$BM" '1. `fails` 6 or more, right after a FAIL') < $(lineno "$BM" '2. Otherwise, `second-brain spec status <ID> <task> building`')))" "1"
file_has "spec build: every resumed failed task looks for a ruling" "$BM" \
  '4. Review `failed`: look for its ruling as item 3 says, since a stop may have left one.'
file_has "spec build: below the cap it resumes in the fix loop, with the ruling" "$BM" \
  '- `fails` 5 or less: `### The fix loop`, with the ruling as its `Owner:` line when there is one.'
file_has "spec build: a task stopped at the cap waits for a newer ruling on resume" "$BM" \
  '- `fails` 6 or more, the build stopped at the cap: a ruling sends one more round, as for'
file_has "spec build: the cap stops as the stop section says" "$BM" \
  '`second-brain task note <ID> "Build: stopped at <task>: <why>."`, then stop, as'
file_has "spec build: and that section writes no second stop note" "$BM" \
  ', unless a block or the cap'
file_has "spec build: a cut-off fix goes back to the fix loop" "$BM" \
  '- No hash, or one `spec status` lists already: `### The fix loop` when the task'"'"'s `fails` is 1'
file_has "spec build: a blocked task gets the ruling" "$BM" \
  '3. Build or review `blocked`: its `Owner:` line is the owner'"'"'s ruling on it, the status note'
file_has "spec build: a cut-off build takes only a commit build.json lacks" "$BM" \
  '- The full hash starts with no listed hash: that run committed. Run'
file_has "spec build: a ruling counts only when newer than the stop" "$BM" \
  'newest `Build: stopped at <task>: <why>.` note. Status notes are newest first, so it is above.'
file_has "spec build: a cut-off build's commit is found by its full hash" "$BM" \
  'hash: `git -C "<path>" log -1 --format=%H --grep="^<ID> <task>: "`.'
file_has "spec build: and a listed hash matches by prefix" "$BM" \
  '- A hash `spec status` lists under the task is that commit when the full hash starts with it.'
file_has "contract: a blocked task waits for a ruling newer than its stop" "$here/docs/contract.md" \
  '- A `blocked` task is launched again with the owner'"'"'s ruling on it, when that ruling is newer than'
file_has "contract: so does a task stopped at the cap" "$here/docs/contract.md" \
  '- A task stopped past the fix loop'"'"'s cap gets one more round in the same way: only with a ruling'
file_has "spec build: sets the result the implementer reports" "$BM" \
  '4. Otherwise: `second-brain spec status <ID> <task> built --commit <short hash>`, with the hash'
line_is "spec build: sets a failed review" "$BM" '4. FAIL: `second-brain spec status <ID> <task> failed`.'
line_is "spec build: then the fix loop" "$BM" '7. PASS: go on to the next task. FAIL: `### The fix loop`.'
is "spec build: shows the status once per task, after its review" \
  "$(grep -c '^[0-9]\. Show the owner `second-brain spec status <ID>`\.$' "$BM")" "1"
is "spec build: and that is in the review step" \
  "$(awk '/^### Review it/ { on = 1 } /^### The fix loop/ { on = 0 } on && /^6\. Show the owner `second-brain spec status <ID>`\.$/' "$BM")" \
  '6. Show the owner `second-brain spec status <ID>`.'
is "spec build: shown once the verdict's state is set" \
  "$(($(lineno "$BM" '4. FAIL: `second-brain spec status <ID> <task> failed`.') < $(lineno "$BM" '6. Show the owner `second-brain spec status <ID>`.') && \
  $(lineno "$BM" '   - Then `second-brain spec status <ID> <task> passed`.') < $(lineno "$BM" '6. Show the owner `second-brain spec status <ID>`.')))" "1"
file_has "spec build: shows the status when a session starts or resumes" "$BM" \
  '1. Show the owner `second-brain spec status <ID>` as it prints.'
file_has "spec build: shows the status when the build stops" "$BM" \
  '1. Show the owner `second-brain spec status <ID>`, the task that stopped the build, and why'
file_has "spec build: shows the status when it finishes" "$BM" \
  '6. Show the owner `second-brain spec status <ID>` and the final validation result.'
for nt in 'Build: started on <branch> at <short hash>.' 'Build: stopped at <task>: <why>.' \
  'Build: finished; every task passed review, the branch is at <short hash>.' \
  'Build: the owner ruled on <task>: <the ruling, as written>.'; do
  file_has "spec build: the status note $nt" "$BM" "\"$nt\""
done
file_has "spec build: a task's progress is in build.json alone" "$BM" "A task's progress is in \`build.json\` alone."
file_has "spec build: reads finish.md when every task passed" "$BM" 'Read `finish.md`, next to this file, and follow it.'
file_has "spec build: keeps track of the build" "$BM" "You keep track of the build"
file_has "spec build: a release check runs only when the owner asks" "$BM" '- Run a `release` check only when the owner asks:'
file_has "spec build: the build-wide run runs in the background" "$BM" \
  '- Run it with the Bash tool'"'"'s `run_in_background: true`, and wait for its notice. A run can'
file_has "reviewer: runs validation run in the background" "$here/agents/reviewer.md" \
  '- Run it with the Bash tool'"'"'s `run_in_background: true`, and wait for its notice before you go'
file_has "contract: validation run runs in the background, and implementer's tests too" "$here/docs/contract.md" \
  '- The skill, `reviewer` and `implementer` run `validation run`, and `implementer` its tests and'
IM="$here/agents/implementer.md"
file_has "implementer: fetches its own packet" "$IM" '1. Run `second-brain spec packet <ID> <task> --project "<project>"`.'
line_is "implementer: replies with its commit first" "$IM" '1. `Commit: <short hash>`.'
line_is "implementer: then one line on what it built" "$IM" '2. One line on what you built. It also names anything the task asks that you could not do, and'
line_is "implementer: then its test" "$IM" \
  '3. `Test: <the test you wrote> - failed first, then passed`, or `Test: none - <why>` for a task'
line_is "implementer: then each check's result" "$IM" \
  '4. One line per check you ran: `Check: <the command or step> - <pass, fail or skipped>`.'
file_has "implementer: a stop names the checks it ran" "$IM" \
  '- You stop without a commit: the first line is `BLOCKED: <why>`, then the `Check:` lines of the'
file_has "implementer: fixes the packet's issues on a fix" "$IM" "On a fix, the packet's \`fails:\` is above 0 and its \`## Issues\` lists the findings of the last"
file_has "implementer: calls what earlier tasks provide" "$IM" "The packet's \`## Uses\` names what earlier tasks provide."
file_lacks "implementer: no longer runs no check" "$IM" "Run no check"
file_lacks "implementer: and its description no longer says so" "$IM" "runs no check"
file_has "implementer: writes a test that fails for the requirement first" "$IM" \
  '1. Write a test that fails for the task'"'"'s requirement first, where the task'"'"'s `Check` and the'
file_has "implementer: sees it fail before the change" "$IM" '- Run it and see it fail, for the reason the requirement gives.'
line_is "implementer: then makes it pass" "$IM" '2. Then make the change, until the test passes.'
line_is "implementer: runs its own test narrowly, never every suite" "$IM" \
  '   that holds it. Never every suite.'
line_is "implementer: a task with nothing to test says why" "$IM" \
  '4. A task with nothing to test, such as a doc change, gets no test. Your reply says why.'
line_is "implementer: has a check step" "$IM" "## 2. Check"
file_has "implementer: runs every check the packet names" "$IM" \
  "Before you commit, run every check under the packet's \`## Checks\`."
file_has "implementer: the each-task checks through validation run" "$IM" \
  '`second-brain validation run "<project>" <repo> --when each-task`, with the packet'"'"'s `repo`.'
file_has "implementer: runs its tests and checks in the background" "$IM" \
  '- Run each test and check with the Bash tool'"'"'s `run_in_background: true`, and wait for its notice'
line_is "implementer: runs no release check, no user step and no build-wide check" "$IM" \
  '- Run no other check: no `release` check, no user step, and no `each build` check but the one'
line_is "implementer: but the suite that holds its own test" "$IM" \
  '  suite that holds your own test. The `spec` skill runs the build'"'"'s checks once every task has'
line_is "implementer: a step it has no tool for is not its to take" "$IM" \
  '  - A step that needs a tool you do not have, such as a browser or a skill, is not yours to take.'
line_is "implementer: it reports it skipped and leaves it to the review" "$IM" \
  '    Report it as `Check: <the step> - skipped - needs <the tool>`, and leave it to the review.'
line_is "implementer: only a command it cannot pass or run blocks" "$IM" \
  '- A command you cannot make pass, or cannot run, such as one that is not found: commit nothing,'
line_is "implementer: commits only when every check passed or was skipped" "$IM" \
  '- Commit only when every check under `## Checks` passed or was skipped. A row `validation run`'
file_has "implementer: never changes a test so that it passes" "$IM" \
  'Never change a test or a check'
is "implementer: checks before it commits" \
  "$(($(linex "$IM" '## 1. Build test-first') < $(linex "$IM" '## 2. Check') && $(linex "$IM" '## 2. Check') < $(linex "$IM" '## 3. Commit')))" "1"
RV="$here/agents/reviewer.md"
file_has "reviewer: fetches its own packet" "$RV" '1. Run `second-brain spec packet <story> <task> --project "<project>"`.'
file_has "reviewer: reads the diff from the file the helper writes" "$RV" "2. Read the change from the file the packet's \`diff:\` line names, and nothing else of the code."
file_has "reviewer: logs each issue with a proposed fix" "$RV" 'second-brain spec issue <story> <task>'
file_has "reviewer: replies with its verdict and the number of issues" "$RV" '`VERDICT: <PASS, FAIL or BLOCKED> - <n> issues`'
file_lacks "reviewer: no longer says the implementer runs no check" "$RV" "the implementer runs none"
file_has "reviewer: runs the task's checks again" "$RV" "The implementer runs the task's checks before it commits. You run them again, and never take its"
CT="$here/docs/contract.md"
line_is "contract: the skill takes each report from the agent's result" "$CT" \
  '- The skill takes each report from the agent'"'"'s result. Nothing is relayed by hand.'
file_has "contract: the agents run spec packet themselves" "$CT" \
  '`spec packet <ID> <task>` themselves. The skill never prints a packet into the owner'"'"'s session.'
file_has "contract: build progress is build.json in the vault" "$CT" \
  "- A spec story's build progress is \`build.json\` in its task folder in the vault, whatever its"
file_has "guide: the build runs in your session" "$here/docs/guide.md" \
  '- The build runs in your session. The `spec` skill launches `implementer` and `reviewer` one at a'
file_has "guide: progress is in build.json, never in the README" "$here/docs/guide.md" 'issues and times are in `build.json`, never in the'
file_has "changelog: names build.md" "$here/CHANGELOG.md" '`skills/spec/build.md`'
file_has "changelog: names build.json" "$here/CHANGELOG.md" 'build progress is in `build.json`'
file_has "spec tasks template: each task is reviewed right after it is built" "$here/templates/spec-tasks.md.tmpl" "Each task is built, then reviewed right after, before the next one"
file_has "spec phases: written for the build build.md runs" "$here/skills/spec/phases.md" "Write every phase for the build \`build.md\` runs."
file_has "spec phases: a whole-branch check is the final validation's" "$here/skills/spec/phases.md" "belongs to the final validation, not to one task's review."

# ---------------------------------------------------------------- spec and validation --json
sb help
out_has "help: names the commands that take --json" \
  "json:     task head, spec tasks, spec status <ID>, validation <project> [repo] and validation run take --json"
sb task new SP-9 --project Specs --title "Json story"
sb task set SP-9 delivery=spec
sb spec tasks SP-9 --json
rc_is "spec tasks --json: no tasks.md exits 1" 1
out_is "spec tasks --json: and prints nothing" ""
sb spec new SP-9
L9="$vault/$S/tasks/SP-9/README.md"
printf '%s\n' '# SP-9 - Tasks' '' '- [ ] T1 - Say "hi" \ there' '  - Requirements: R1' \
  '- [x] T2 - Two - parts' '  - Requirements: R1' '- [ ] T3' >"$vault/$S/tasks/SP-9/spec/tasks.md"
sb spec tasks SP-9 --json
rc_is "spec tasks --json: exit 0" 0
json_ok "spec tasks --json: parses as JSON"
out_is "spec tasks --json: one object per row, quotes and backslashes escaped" '[
  {"id": "T1", "state": "todo", "title": "Say \"hi\" \\ there", "bundle": "-"},
  {"id": "T2", "state": "done", "title": "Two - parts", "bundle": "-"},
  {"id": "T3", "state": "todo", "title": "-", "bundle": "-"}
]'
sb spec tasks SP-9
text="$OUT"
sb spec tasks SP-9 --json
json_is "spec tasks --json: the same fields as the text" \
  'for r in d: print("\t".join([r["id"], r["state"], r["title"], r["bundle"]]))' "$text"
sb spec status SP-9 --json
rc_is "spec status --json: a story with no build exits 0" 0
out_is "spec status --json: and prints an empty array" "[]"
B9="$vault/$S/tasks/SP-9/build.json"
sb spec status SP-9 T1 built --commit abc1234
sb spec status SP-9 T1 in-review --commit def5678
sb spec status SP-9
out_has "spec status: a task with no commit prints commits -" 'T2 - build: built - review: passed - fails 0 - commits - - Two - parts'
out_has "spec status: and one with no title prints -" 'T3 - build: todo - review: - - fails 0 - commits - - -'
sb spec issue SP-9 T1 'Say "hi" \ there.' --fix "Tab${TAB}here."
sb spec status SP-9 T2 passed --commit 0a1b2c3
sb spec status SP-9 T3 todo --commit 1234abc
sb spec status SP-9 --json
rc_is "spec status --json: exit 0" 0
json_ok "spec status --json: parses as JSON"
row1='{"id": "T1", "build": "built", "review": "in-review", "fails": 0, "commits": ["abc1234", "def5678"], '
row1="$row1"'"title": "Say \"hi\" \\ there", '
row1="$row1"'"issues": ["Issue 2026-10-08: Say \"hi\" \\ there. Fix: Tab\there."]}'
out_is "spec status --json: one object per task, commits and issues as arrays" "[
  $row1,
  "'{"id": "T2", "build": "built", "review": "passed", "fails": 0, "commits": ["0a1b2c3"], "title": "Two - parts", "issues": []},
  {"id": "T3", "build": "todo", "review": "-", "fails": 0, "commits": ["1234abc"], "title": "-", "issues": []}
]'
sb spec status SP-9
text="$OUT"
sb spec status SP-9 --json
json_is "spec status --json: the same fields as the text" 'for r in d:
    c = ", ".join(r["commits"]) or "-"
    print("%s - build: %s - review: %s - fails %d - commits %s - %s" % (r["id"], r["build"], r["review"], r["fails"], c, r["title"]))
    for i in r["issues"]: print("  - " + i)' "$text"
OUT="$(cat "$B9")"
json_ok "spec issue: build.json with quotes, a backslash and a tab parses as JSON"
json_is "spec issue: and reads back as written" 'i = d["tasks"][0]["issues"][0]; print(i["issue"] == "Say \"hi\" \\ there." and i["fix"] == "Tab\there.")' "True"
cp "$B9" "$tmp/b9.before"
sb spec status SP-9 T1 built --json
rc_is "spec status --json: a task and a state exit 5" 5
if cmp -s "$B9" "$tmp/b9.before"; then pass "spec status --json: and nothing is written"; else fail "spec status --json: and nothing is written"; fi
printf '%s\n' '# SP-9 - Tasks' '' '- [ ] T1 - Say "hi" \ there' '  - Requirements: R1' '- [ ] T3' \
  >"$vault/$S/tasks/SP-9/spec/tasks.md"
sb spec status SP-9 T1 built
sb spec status SP-9 T1 built
sb spec status SP-9
is "spec status: a task that left tasks.md keeps its title over two writes, at the end" "$(printf '%s\n' "$OUT" | tail -1)" \
  'T2 - build: built - review: passed - fails 0 - commits 0a1b2c3 - Two - parts'
printf '%s\n' "- [ ] T4 - $(printf 'Caf\303\251 \001') a${CR}b" >>"$vault/$S/tasks/SP-9/spec/tasks.md"
sb spec tasks SP-9 --json
json_ok "spec tasks --json: a title with UTF-8, a control character and a CR parses as JSON"
out_has "spec tasks --json: UTF-8 bytes are kept, \\u0001 and \\r are escaped" \
  "$(printf '{"id": "T4", "state": "todo", "title": "Caf\303\251 \\u0001 a\\rb", "bundle": "-"}')"
json_is "spec tasks --json: and the title reads back as written" \
  'print(d[-1]["title"] == "Caf\u00e9 \x01 a\rb")' "True"
sb spec SP-9 --json
rc_is "spec --json: the spec form takes no --json, exit 5" 5
sb spec tick SP-9 T1 --json
rc_is "spec tick --json: exit 5" 5
sb validation Specs
text="$OUT"
sb validation Specs --json
rc_is "validation --json: exit 0" 0
json_ok "validation --json: parses as JSON"
json_is "validation --json: the same fields as the text" \
  'for r in d: print("\t".join([r["name"], r["home"], r["path"], r["state"]]))' "$text"
vrow="{\"name\": \"spec-app\", \"home\": \"vault\", "
vrow="$vrow\"path\": \"$S/claude/validation.md\", \"state\": \"ok\"}"
out_has "validation --json: one object per repo" "$vrow"
sb validation RepoHome --json
rc_is "validation --json: a project with no repo exits 0" 0
out_is "validation --json: and prints an empty array" "[]"
sb validation Specs spec-app
text="$OUT"
sb validation Specs spec-app --json
rc_is "validation <repo> --json: exit 0" 0
json_ok "validation <repo> --json: parses as JSON"
json_is "validation <repo> --json: the same fields as the text" 'print("path: " + d["path"])
if d["body"]: print(d["body"])' "$text"
out_has "validation <repo> --json: one object, the path first" \
  "{${NL}  \"path\": \"$S/claude/validation.md\",${NL}  \"body\": \""
out_has "validation <repo> --json: the body's lines are escaped" '\n\n### Checks'
sb validation Specs nope --json
rc_is "validation <repo> --json: an unknown repo exits 1" 1
out_is "validation <repo> --json: and prints nothing" ""
sb validation new Specs spec-app --json
rc_is "validation new --json: exit 5" 5

# ---------------------------------------------------------------- README: each rule it points to has a home
RM="$here/README.md"
line_is "README: keeps the Update heading that docs/guide.md links to" "$RM" "## Update"
for ptr in 'docs/contract.md|### Profile frontmatter' 'docs/contract.md|### Validation' \
  'skills/story-tracker/SKILL.md|## Edit an existing story' 'skills/vault-doctor/SKILL.md|## fix' \
  'skills/vault-setup/SKILL.md|## link' 'templates/vault-claude-hub.md.tmpl|## Adding a skill or agent'; do
  pf="${ptr%%|*}" ph="${ptr#*|}"
  file_has "README: points to $ph in $pf" "$RM" "\`$ph\` in \`$pf\`"
  line_is "README: $pf has the heading $ph" "$here/$pf" "$ph"
done
file_has "README: points to the guide's Spec-driven delivery" "$RM" \
  '`## Spec-driven delivery` in `docs/guide.md`'
line_is "README: docs/guide.md has the heading ## Spec-driven delivery" "$here/docs/guide.md" \
  "## Spec-driven delivery"
for pf in skills/spec/build.md skills/vault-doctor/checks.md templates/pull-request.md.tmpl; do
  file_has "README: points to $pf" "$RM" "\`$pf\`"
  exists "README: $pf exists" "$here/$pf"
done
file_has "README: the hand-off to docs-keeper is in story-tracker" "$here/skills/story-tracker/SKILL.md" \
  'The story reaches production: start the `docs-keeper` agent'
file_has "README: vault-setup link leaves a foreign entry alone" "$here/skills/vault-setup/SKILL.md" \
  'It is normal and never touched'
file_has "README: --fix changes three checks without asking" "$here/skills/vault-doctor/SKILL.md" \
  '`second-brain doctor --fix` repairs three checks only'

# ---------------------------------------------------------------- guide: each rule it points to has a home
GD="$here/docs/guide.md"
line_is "guide: keeps the What to say heading that its links name" "$GD" "## What to say"
for ptr in 'docs/contract.md|## 1. Words and paths' 'docs/contract.md|## 2. The index' \
  'docs/contract.md|## 3. The project' 'docs/contract.md|### Profile frontmatter' \
  'docs/contract.md|### Subprojects' 'docs/contract.md|### Validation' 'docs/contract.md|## 4. A task' \
  'docs/contract.md|### Links between notes' 'docs/contract.md|### link, doctor, snapshot' \
  'docs/contract.md|## 9. Skills and agents' 'templates/obsidian-conventions.md.tmpl|## The short version' \
  'skills/vault-setup/adopt.md|## 2. Scaffold only what is missing' 'skills/vault-setup/SKILL.md|## project <name>' \
  'skills/story-tracker/create.md|## 3. Create the story' 'skills/story-tracker/status.md|## Render' \
  'skills/story-tracker/SKILL.md|## Edit an existing story' 'skills/vault-doctor/SKILL.md|## fix' \
  'skills/story-tracker/SKILL.md|## Spec-driven stories' \
  'skills/spec/SKILL.md|## Step 2 - One phase at a time' 'skills/spec/build.md|## 2. Ready to build' \
  'skills/spec/phases.md|## The chat' 'skills/spec/phases.md|## The spec check'; do
  pf="${ptr%%|*}" ph="${ptr#*|}"
  file_has "guide: points to $ph in $pf" "$GD" "\`$ph\` in \`$pf\`"
  line_is "guide: $pf has the heading $ph" "$here/$pf" "$ph"
done
for pf in skills/sprint/close.md skills/spec/SKILL.md skills/spec/build.md .github/workflows/test.yml \
  .github/workflows/e2e.yml scripts/e2e-claude.sh .claude-plugin/plugin.json CHANGELOG.md; do
  file_has "guide: points to $pf" "$GD" "\`$pf\`"
  exists "guide: $pf exists" "$here/$pf"
done
for s in test test-link test-graph test-doctor test-snapshot leak-check; do
  line_is "guide: Development lists scripts/$s.sh" "$GD" "bash scripts/$s.sh"
done
line_is "guide: Development lists the plugin validation" "$GD" "claude plugin validate . --strict"
file_has "guide: version changes only at the end of a release" "$GD" \
  'Neither a feature branch nor the release branch changes `version`.'
file_has "guide: a failing e2e request is fixed in the description" "$GD" \
  "fixed in the skill's \`description\`, in the user's words"
file_has "guide: a task is never filed in its topic" "$here/templates/obsidian-conventions.md.tmpl" \
  'Never file a task inside the topic it is'
file_has "guide: vault-setup runs only by name" "$here/docs/contract.md" \
  '`vault-setup` is the one: it writes the pointer and the links'
file_has "guide: adopt writes the roots into the profile" "$here/skills/vault-setup/adopt.md" \
  'It writes the roots into the new profile'
file_has "guide: vault-setup asks whether the project runs sprints" "$here/skills/vault-setup/SKILL.md" \
  '- No sprints: add `--no-sprints`'
file_has "guide: vault-setup asks for the task layout" "$here/skills/vault-setup/SKILL.md" \
  '| `task_layout` | whether a done or abandoned task moves once'
file_has "guide: the status overview flags a story waiting on a task not done" "$here/skills/story-tracker/status.md" \
  'story waits on each task in its `depends_on` cell that is not `done`'
file_has "guide: no build starts without the repo's steps" "$here/skills/spec/build.md" \
  '`second-brain validation <project> <repo>` must print the repo'"'"'s steps'

# ---------------------------------------------------------------- a new story's branch is cut from the base branch
line_is "guide: a release branch is cut from main" "$GD" \
  '- A release starts with a `release/<version>` branch cut from `main`, such as `release/0.3.0`.'
line_is "guide: a feature branch is cut from main and merges into the release" "$GD" \
  '- A feature branch is cut from `main` and merges into the release branch.'
line_is "guide: a story that needs another story's code is cut from its branch" "$GD" \
  "- A story that needs another story's code not yet in \`main\` is cut from that story's branch. It"
line_is "guide: that story merges after the one it needs" "$GD" '  merges into the release branch after that story.'
line_is "guide: the release goes to main in one pull request" "$GD" \
  '- One pull request takes the release branch into `main`.'
ST="$here/skills/story-tracker/SKILL.md"
line_is "story-tracker: a new story's branch is cut from the base branch" "$ST" \
  "- A new story's branch is cut from the base branch."
line_is "story-tracker: a story that needs another story's code is cut from its branch" "$ST" \
  "  - A story that needs another story's code not yet in the base branch is cut from that story's"
file_has "spec build: cuts a missing branch as the branch check says" "$here/skills/spec/build.md" \
  'No branch yet: ask, then cut it as the branch check says, named by `branch_pattern`.'
line_is "contract: base_branch is where a new story's branch is cut from" "$here/docs/contract.md" \
  "- \`base_branch\` is the branch a new story's branch is cut from, as"

# ---------------------------------------------------------------- a passed spec build is finished
FN="$here/skills/spec/finish.md"
exists "spec finish: the step has its own file" "$FN"
file_has "spec build: reads finish.md only when the build finished" "$here/skills/spec/build.md" \
  'Read `finish.md`, next to this file, and follow it.'
file_has "spec finish: read only when every task passed" "$FN" \
  'Read this file only when the build finished with every task passed, as `build.md` says.'
file_has "spec finish: the story's branch stays its own" "$FN" \
  "- The story's \`branch\` stays \`<branch>\` whatever the owner picks: review fixes go on it."
file_lacks "spec finish: never sets the story's branch" "$FN" 'task set <ID> branch='
file_has "spec finish: asks the owner with AskUserQuestion" "$FN" \
  '- Ask with AskUserQuestion, with three options:'
file_has "spec finish: offers a merge into the target" "$FN" '  - Merge `<branch>` into `<target>`.'
file_has "spec finish: offers a pull request into the target" "$FN" \
  '  - Open a pull request from `<branch>` into `<target>`.'
file_has "spec finish: offers to keep the branch" "$FN" '  - Keep `<branch>` as it is.'
file_has "spec finish: another target is asked again" "$FN" \
  '- The owner names another target in the free-text answer: ask again, with the three options for'
file_has "spec finish: any other answer keeps the branch" "$FN" \
  '- Do only what the owner picks. Any other answer is `## 5. Keep`.'
line_is "spec finish: has the Keep heading it points to" "$FN" '## 5. Keep'
file_has "spec finish: the target is the open release branch" "$FN" \
  '- The target is the open release branch, `release/<version>`.'
line_is "spec finish: lists the release branch names" "$FN" \
  "  git -C \"<path>\" for-each-ref --format='%(refname:lstrip=-2)' \\"
line_is "spec finish: local and remote, highest first, once each" "$FN" \
  "    'refs/heads/release/*' 'refs/remotes/*/release/*' | sort -rVu"
file_lacks "spec finish: no sort by the full ref name" "$FN" 'branch -a --list'
file_has "spec finish: the highest tag is the last release shipped" "$FN" \
  '- The highest `v<version>` tag is the last release that shipped.'
file_has "spec finish: the tags are listed highest first" "$FN" \
  "git -C \"<path>\" tag --list 'v*' --sort=-v:refname"
file_has "spec finish: only a release above that tag is open" "$FN" \
  '- Only a release branch higher than that tag is open.'
file_has "spec finish: with no tag every release is open" "$FN" \
  '- With no `v<version>` tag, every release branch is open.'
file_has "spec finish: the target is the highest open one" "$FN" \
  '- The target is the highest open release branch.'
file_has "spec finish: no open release asks the owner" "$FN" \
  '- No release branch is open: ask the owner to name the target, or a version to cut.'
file_has "spec finish: base_branch only with no release branch" "$FN" \
  '- No release branch at all: the target is `base_branch`.'
file_lacks "spec finish: no repo path the project's repo lacks" "$FN" '`docs/guide.md`'
file_has "spec finish: does only what the owner picks" "$FN" '- Do only what the owner picks.'
file_has "spec finish: finds the worktree that holds the target" "$FN" \
  'git -C "<path>" worktree list --porcelain'
file_has "spec finish: merges in that worktree" "$FN" \
  'git -C "<where>" merge --no-ff <branch> -m "Merge <branch> into <target>"'
file_has "spec finish: a merge pushes nothing" "$FN" 'The merge is local. It pushes nothing.'
file_has "spec finish: a merge sets next" "$FN" \
  'second-brain task set <ID> next="Owner reviews the merge into <target>"'
file_has "spec finish: a merge records a status note" "$FN" \
  '"Finish: merged <branch> into <target> at <short hash>."'
file_has "spec finish: names the push and the pull request before they run" "$FN" \
  '1. Before either runs, name both: the push of `<branch>` to `origin`, and the pull request into'
file_has "spec finish: a pull request sets next" "$FN" \
  'second-brain task set <ID> next="Owner reviews the pull request"'
file_has "spec finish: a pull request records a status note" "$FN" \
  '"Finish: opened a pull request into <target>: <url>."'
file_has "spec finish: the description follows the pull request format" "$FN" \
  '4. Write the description in the pull request format the index points to.'
file_lacks "spec finish: no template path the project's repo lacks" "$FN" 'pull-request.md.tmpl'
file_has "spec finish: a failed pick writes a note" "$FN" \
  '"Finish: <pick> into <target> failed: <reason>; <what ran>."'
line_is "spec finish: has the failure heading it points to" "$FN" '## 7. A pick that fails'
file_has "spec finish: deleting the branch needs discard typed" "$FN" \
  '- Delete the branch only when the owner types `discard`. A pick or a yes is not enough.'
file_has "spec finish: discard detaches before it deletes" "$FN" \
  '- `git -C "<path>" switch --detach`, then `git -C "<path>" branch -D <branch>`.'
file_has "spec finish: discard sets next" "$FN" \
  'second-brain task set <ID> next="<branch> was discarded; the owner decides what follows"'
file_has "spec finish: discard keeps the hash in the note" "$FN" \
  '"Finish: the owner typed discard; <branch> was at <short hash>."'
file_has "spec finish: never forces a push" "$FN" '- Never force a push or rewrite history.'
file_has "guide: points to the finishing step" "$GD" 'as `skills/spec/finish.md` says.'
file_lacks "guide: does not restate the finishing step" "$GD" 'only when you type `discard`'
file_has "changelog: names the finishing step" "$here/CHANGELOG.md" '`skills/spec/finish.md`'
line_is "contract: a merge or a pull request runs only on the pick" "$here/docs/contract.md" \
  "- A merge or a pull request runs only on the owner's pick."
line_is "contract: each push or pull request is named before it runs" "$here/docs/contract.md" \
  '- Each push or pull request is named before it runs.'
file_has "contract: deleting the branch needs discard typed" "$here/docs/contract.md" \
  "- The story's branch is deleted only when the owner types \`discard\`."

# ---------------------------------------------------------------- validation run
sb help
out_has "help: lists validation run" "validation run <project> <repo> [--when each-task|each-build|release] [--timeout S]"
RN="work/runs"
mkdir -p "$tmp/rcode/run-app" "$tmp/tmpr"
: >"$tmp/rcode/run-app/marker.txt"
sb scaffold project Runs --path "$RN" --keys RN
edit "$vault/$RN/claude/profile.md" "s|^repos: \\[\\]\$|repos: [run-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/rcode\"|"
RVF="$vault/$RN/claude/validation.md"
cat >"$RVF" <<'EOF'
# Runs validation

## run-app

### Set up and start

- `echo never` - not a check

### Checks

- `test -f marker.txt` - runs from the repo's root - when: each task
- `test -z "$(cat)"` - reads nothing on stdin - when: Each-Task.
- `echo build-only` - a suite - when: each build
- `printf 'all good\n'` - no when, so each build
- `printf 'line one\nan Error here\nFAILED: x\n'; exit 3` - fails on purpose
  - `echo nested` - a nested item is no check - when: each task
- `echo "when: release"` - a when in the span is not read
- `sleep 30` - hangs - when: release
- `echo e2e` - costs money - when: release
- A note with no command - when: each task
- `echo odd` - when: nightly
- `echo long` - a bullet that wraps
  over two lines - when: each task
- ``echo `tick` `` - a span that holds a backtick - when: each task

### Check as a user would

- `echo user` - a user step is never run - when: each task

### A pass

- Every check passes.
EOF
# The packet names the checks implementer runs before it commits: the task's own, then each command
# validation run --when each-task runs, in order.
sb task new RN-1 --project Runs --title "Checks story"
sb task set RN-1 delivery=spec branch=feature/RN-1
sb spec new RN-1
DR="$vault/$RN/tasks/RN-1/spec"
printf '%s\n' '# RN-1 - Requirements' '' '## R1 - One' '' 'WHEN a user runs it, THE app SHALL pass.' >"$DR/requirements.md"
printf '%s\n' '# RN-1 - Tasks' '' '- [ ] T1 - With a check' '  - Requirements: R1' '  - Files: marker.txt' \
  '  - Check: `test -f marker.txt` - expected: exit 0' \
  '- [ ] T2 - No check' '  - Requirements: R1' \
  '- [ ] T3 - The template' '  - Requirements: R1' \
  '  - Check: <The command or step the implementer and the reviewer run.> - expected: <What it prints or shows.>' \
  '- [ ] T4 - None' '  - Requirements: R1' '  - Check: None' >"$DR/tasks.md"
sb spec packet RN-1 T1
rc_is "spec packet: a task with a check exits 0" 0
out_has "spec packet: names the task's check, then each each-task command, in order" "## Checks

- task: \`test -f marker.txt\` - expected: exit 0
- each task: test -f marker.txt
- each task: test -z \"\$(cat)\"
- each task: echo long
- each task: echo \`tick\` ${NL}${NL}## Validation"
for c in "echo build-only" "all good" "echo odd" "echo e2e" "A note with no command" "echo nested"; do
  is "spec packet: no each-task line for $c" "$(printf '%s\n' "$OUT" | grep -c -- "^- each task: .*$c" || true)" "0"
done
for t in T2 T3 T4; do
  sb spec packet RN-1 "$t"
  out_has "spec packet: $t has no check of its own, and still the each-task ones" "## Checks

- task: none
- each task: test -f marker.txt"
done
mv "$RVF" "$RVF.away"
sb spec packet RN-1 T1
rc_is "spec packet: no validation.md still exits 0" 0
out_has "spec packet: and says so" "validation: none (missing)"
is "spec packet: its Checks part is the task's line alone" "$(printf '%s\n' "$OUT" | sed -n '/^## Checks$/,$p')" "## Checks

- task: \`test -f marker.txt\` - expected: exit 0"
mv "$RVF.away" "$RVF"
ODIR="${TMPDIR:-}"
export TMPDIR="$tmp/tmpr"
# rows <output>: each row's command, result and exit code, and each line under a row.
rows() { printf '%s\n' "$1" | awk -F'\t' '/^  / { print; next } { print $1 "|" $2 "|" $3 }'; }
OUT="$(printf 'some input\n' | "$SB" validation run Runs run-app --when each-task 2>"$tmp/stderr")"
RC=$?
ERR="$(cat "$tmp/stderr")"
rc_is "validation run: each-task, every check passes, exit 0" 0
is "validation run: each-task takes only the each-task bullets, in order, and names the skipped ones" "$(rows "$OUT")" \
  "test -f marker.txt|pass|0
test -z \"\$(cat)\"|pass|0
A note with no command - when: each task|skipped|-
  no command
echo long|pass|0
echo \`tick\` |pass|0"
err_has "validation run: an unknown when is named as a warning, even in a run it is not part of" \
  "note: unknown when: nightly, read as each build: \`echo odd\` - when: nightly"
log1="$(printf '%s\n' "$OUT" | head -1 | cut -f5)"
is "validation run: the log is a temp file, outside the repo and the vault" "${log1%/*/*}" "$(shown "$tmp/tmpr")"
is "validation run: a row's seconds are whole seconds" "$(printf '%s\n' "$OUT" | head -1 | cut -f4 | grep -c '^[0-9][0-9]*$')" "1"
skipped="$(printf '%s\n' "$OUT" | grep "${TAB}skipped${TAB}" | head -1)"
is "validation run: a skipped row's exit code, seconds and log are -" "$(printf '%s\n' "$skipped" | cut -f3-5)" "-${TAB}-${TAB}-"
sb validation run Runs run-app
rc_is "validation run: a failing check exits 1" 1
is "validation run: each-build is the default, and takes the each-task bullets too" "$(rows "$OUT")" \
  "test -f marker.txt|pass|0
test -z \"\$(cat)\"|pass|0
echo build-only|pass|0
printf 'all good\\n'|pass|0
printf 'line one\\nan Error here\\nFAILED: x\\n'; exit 3|fail|3
  an Error here
  FAILED: x
echo \"when: release\"|pass|0
A note with no command - when: each task|skipped|-
  no command
echo odd|pass|0
echo long|pass|0
echo \`tick\` |pass|0"
err_has "validation run: an unknown when runs as each build, with its warning" \
  "note: unknown when: nightly, read as each build: \`echo odd\` - when: nightly"
out_lacks "validation run: a nested item is no check" "nested"
out_lacks "validation run: nor a step of another part" "echo never"
out_lacks "validation run: nor a user step" "echo user"
log4="$(printf '%s\n' "$OUT" | grep "^printf 'all good" | cut -f5)"
file_has "validation run: the log holds the command's output" "$log4" "all good"
text="$OUT"
sb validation run Runs run-app --when each-build --json
rc_is "validation run --json: exits as the text does" 1
json_ok "validation run --json: parses as JSON"
json_is "validation run --json: the same fields as the text" 'for r in d:
    print("|".join([r["command"], r["result"], "-" if r["exit"] is None else str(r["exit"])]))
    for l in r["lines"]: print("  " + l)' "$(rows "$text")"
json_is "validation run --json: each row has its seconds and log" \
  'print(all(set(r) == {"command", "result", "exit", "seconds", "log", "lines"} for r in d))' "True"
json_is "validation run --json: exit and seconds are numbers, null when skipped" \
  'print(sorted(set((type(r["exit"]).__name__, type(r["seconds"]).__name__, r["result"]) for r in d)))' \
  "[('NoneType', 'NoneType', 'skipped'), ('int', 'int', 'fail'), ('int', 'int', 'pass')]"
sb validation run Runs run-app --when release --timeout 1
rc_is "validation run: a timeout fails, exit 1" 1
out_has "validation run: release takes the release bullets too" "echo e2e${TAB}pass${TAB}0"
trow="$(printf '%s\n' "$OUT" | grep '^sleep 30')"
is "validation run: a command stopped at the timeout fails with exit code 124" "$(printf '%s\n' "$trow" | cut -f2,3)" "fail${TAB}124"
is "validation run: and is stopped soon after it" "$(($(printf '%s\n' "$trow" | cut -f4) < 10))" "1"
case "$OUT" in
  *"sleep 30${TAB}fail${TAB}124${TAB}"*"
  stopped after 1 seconds"*) pass "validation run: its first line names the timeout" ;;
  *) fail "validation run: its first line names the timeout" "in: $OUT" ;;
esac
# A timeout stops what the command started too: the child never writes its file.
cat >"$RVF" <<'EOF'
## run-app

### Checks

- `(sleep 3; echo late >late.txt) & sleep 30` - a child that outlives its parent
EOF
sb validation run Runs run-app --timeout 1
rc_is "validation run: a command with a child times out" 1
sleep 4
absent "validation run: and its child is stopped with it" "$tmp/rcode/run-app/late.txt"
# What a command leaves running when it exits is stopped before the next one starts.
cat >"$RVF" <<'EOF'
## run-app

### Checks

- `(sleep 2; echo late >late3.txt) & exit 0` - leaves a child behind
- `sleep 3; test ! -f late3.txt` - the next check runs alone
EOF
sb validation run Runs run-app
rc_is "validation run: a command that leaves a child passes" 0
out_has "validation run: the next check sees nothing of it" "sleep 3; test ! -f late3.txt${TAB}pass${TAB}0"
absent "validation run: and the child is stopped, never past the run" "$tmp/rcode/run-app/late3.txt"
printf '%s\n' '## run-app' '' '### Set up and start' '' '- Nothing.' >"$RVF"
sb validation run Runs run-app
rc_is "validation run: a section with no Checks exits 0" 0
out_is "validation run: and prints no row" ""
err_has "validation run: and says so" "note: no ### Checks in $RN/claude/validation.md"
sb validation run Runs run-app --json
out_is "validation run --json: no row is an empty array" "[]"
for bad in "--when nightly" "--when" "--timeout 0" "--timeout x" "--timeout"; do
  # shellcheck disable=SC2086
  sb validation run Runs run-app $bad
  rc_is "validation run: $bad exits 5" 5
done
sb validation run Runs
rc_is "validation run: no repo exits 5" 5
sb validation run Runs run-app extra
rc_is "validation run: too many arguments exit 5" 5
sb validation Runs run-app --when each-task
rc_is "validation: --when is the run's flag alone, exit 5" 5
sb validation run Runs nope
rc_is "validation run: an unknown repo exits 1" 1
mv "$tmp/rcode/run-app" "$tmp/rcode/run-app.away"
sb validation run Runs run-app
rc_is "validation run: a repo whose folder is missing exits 1" 1
err_has "validation run: and says so" "the folder of run-app is missing"
mv "$tmp/rcode/run-app.away" "$tmp/rcode/run-app"
if [ -n "$ODIR" ]; then export TMPDIR="$ODIR"; else unset TMPDIR; fi
CT="$here/docs/contract.md"
file_has "contract: a check's first code span is its command" "$CT" "- Under \`### Checks\` a bullet's first inline code span is its command:"
file_has "contract: each bullet ends with when it runs" "$CT" '  `when: each task`, `when: each build` or `when: release`.'
line_is "contract: a bullet with no when is each build" "$CT" '- A bullet with no `when:` is `each build`.'
line_is "contract: so is an unknown one, so a typo never drops a check" "$CT" \
  '- Any other value is unknown and counts as `each build`, so a typo never drops a check.'
file_has "contract: documents validation run" "$CT" '| `validation run <project> <repo> [--when each-task\|each-build\|release] [--timeout <seconds>] [--json]` |'
file_has "contract: the fix loop's rounds" "$CT" '- Fix rounds 1 to 3 go back to the same `implementer`, with the findings in its packet. Rounds 4'
file_has "contract: the build-wide run has no agent" "$CT" '- When every task has passed, the skill runs `validation run <project> <repo> --when each-build`'
file_has "contract: a task's fails come from its history" "$CT" '- A task'"'"'s `fails` is the number of `failed` review states in its history, from every session.'
file_has "guide: each task is reviewed right after it is built" "$here/docs/guide.md" '- Each task is reviewed right after it is built, before the next one starts, so no task builds on'
file_has "guide: names validation run" "$here/docs/guide.md" '`second-brain validation run <project> <repo> --when each-task`'
file_has "changelog: names validation run" "$here/CHANGELOG.md" 'The new `second-brain validation run <project> <repo> [--when each-task|each-build|release]'
file_has "changelog: names the fix loop" "$here/CHANGELOG.md" '- The fix loop has five rounds: three on the same `implementer`, then two on a fresh one on the'
VT="$here/templates/validation-repo.md.tmpl"
file_has "validation template: asks for the command in backticks" "$VT" 'the command in backticks, then what it proves.>'
file_has "validation template: asks when each check runs" "$VT" '- <Each line ends with when it runs: when: each task, when: each build, or when: release'
file_has "validation template: and when each user step runs" "$VT" 'then what to look for, then when it runs.>'
file_has "vault-setup validation: drafts when each check runs" "$here/skills/vault-setup/validation.md" \
  '- End each check and each user step with when it runs, as `### Validation` in'
file_has "vault-setup validation: the command is the first code span" "$here/skills/vault-setup/validation.md" \
  "The command is the line's first inline code span: the helper runs it."
RV="$here/agents/reviewer.md"
file_has "reviewer: runs the checks only through validation run" "$RV" \
  '- Run the checks under `### Checks` only through'
file_has "reviewer: never runs a release check" "$RV" '- Never run a `release` check or step: only the owner asks for one.'
file_has "reviewer: a task review runs only its each-task checks" "$RV" \
  '4. Run the task'"'"'s `Check`, the checks with `--when each-task`, and each user step whose `when:` is'
file_has "reviewer: requirements first" "$RV" '3. Requirements first.'
file_has "reviewer: then code quality" "$RV" '6. Then code quality, in the diff alone. Each of these is a finding:'
is "reviewer: requirements before code quality" \
  "$(($(lineno "$RV" '3. Requirements first.') < $(lineno "$RV" '6. Then code quality, in the diff alone.')))" "1"
file_has "reviewer: a requirement not met skips the code quality pass" "$RV" 'is FAIL. Log the findings, and skip step 6.'
file_has "reviewer: a re-review reads only the fix" "$RV" \
  '- `fails` above 0: a re-review. The diff holds only the fix'"'"'s commits, and `## Issues` only the'
line_is "reviewer: has a user mode" "$RV" "## User mode"
line_is "reviewer: has a branch mode" "$RV" "## Branch mode"
file_has "reviewer: the branch review reads the whole change" "$RV" '2. Read the whole change: `git -C "<repo_path>" diff <base>...HEAD`.'
file_has "reviewer: a finished branch's finding goes on its task" "$RV" \
  '- The task is the one whose `- Files:` line in `tasks.md` holds the finding'"'"'s file. Several: the'
IM="$here/agents/implementer.md"
line_is "implementer: takes a fix message" "$IM" "## A fix message"
file_has "implementer: fetches its packet again on a fix" "$IM" \
  '- Run `second-brain spec packet <ID> <task> --project "<project>"` again, and check where you are'
file_has "implementer: a fix runs the checks again before it commits" "$IM" \
  '`## 2. Check` says, commit with the message'"'"'s last line and reply as `## 4. Report` says.'
# Who runs which check: the contract, the guide, the build and the changelog say the same.
CT="$here/docs/contract.md"
file_has "contract: says who runs which check" "$CT" \
  '- **Who runs which check.** `implementer` runs its task'"'"'s checks before it commits. `reviewer`'
file_has "contract: and the skill runs the each-build checks once" "$CT" \
  'runs them again in the task'"'"'s review. The skill runs the `each build` checks once, at the end.'
line_is "contract: implementer writes a failing test first" "$CT" \
  '- `implementer` writes a test that fails for its task'"'"'s requirement first, then makes it pass.'
line_is "contract: a task with nothing to test says why" "$CT" \
  '- A task with nothing to test, such as a doc change, gets no test, and the reply says why.'
line_is "contract: implementer's checks are its packet's" "$CT" \
  '- Its checks are the ones under its packet'"'"'s `## Checks`: the task'"'"'s `Check`, and the repo'"'"'s'
line_is "contract: it commits only when they pass" "$CT" '- It commits only when they all pass, and names each result in its reply.'
line_is "contract: it runs no other build-wide check, no release check and no user step" "$CT" \
  '- It runs no other `each build` check, no `release` check and no user step.'
line_is "contract: the suite that holds its own test is allowed" "$CT" '  even an `each build` one.'
line_is "contract: a step implementer has no tool for is skipped" "$CT" \
  '- A task `Check` that is a step its tools cannot take, such as a browser or a skill step, is'
line_is "contract: it still commits, and the review takes the step" "$CT" \
  '  reported as `Check: <step> - skipped - needs <tool>`. It still commits, and the review takes'
file_lacks "contract: no longer says implementer runs no check" "$CT" '`implementer` runs no check'
file_has "contract: the reviewer runs the task's checks again" "$CT" \
  '- It runs the task'"'"'s `Check` and the `each task` checks again, through'
file_has "contract: implementer's reply names each check's result" "$CT" \
  '`Check:` line with the result of each check it ran.'
file_has "contract: the packet has a Checks part" "$CT" \
  '`## Checks` (the checks `implementer` runs before it commits: `- task: <the item'"'"'s Check, as written>`'
GD="$here/docs/guide.md"
file_has "guide: implementer builds test-first" "$GD" '- `implementer` builds each task test-first. It writes a test that fails for the task'"'"'s'
file_has "guide: says who runs which check" "$GD" \
  '- Who runs which check: `implementer` runs the task'"'"'s `Check` and the repo'"'"'s `each task` checks'
line_is "guide: the reviewer runs them again" "$GD" \
  '- `reviewer` runs those checks again in the task'"'"'s review, with the `each task` user steps.'
file_has "guide: the full validation still runs once at the end" "$GD" \
  '- When every task has passed, the helper runs the repo'"'"'s checks once, with no agent.'
line_is "spec build: never skips the review on its check lines" "$BM" \
  '   - Its `Test:` and `Check:` lines are its own report. The review runs the checks again: never'
line_is "spec phases: implementer runs the task's check before it commits" "$here/skills/spec/phases.md" \
  '- `implementer` builds each task test-first and runs its `- Check:` before it commits. `reviewer`'
file_lacks "spec phases: no longer says reviewer runs every check" "$here/skills/spec/phases.md" '`reviewer` runs every check'
file_has "spec phases: a task's check is its narrowest command" "$here/skills/spec/phases.md" \
  'narrowest command that runs the task'"'"'s test, such as one test file, not every suite.'
file_has "changelog: names the test-first build" "$here/CHANGELOG.md" '- `implementer` builds each task test-first.'
file_has "changelog: names the packet's Checks part" "$here/CHANGELOG.md" '- The packet'"'"'s new `## Checks` part names those checks'

# ---------------------------------------------------------------- the baseline skip and bundles
PH="$here/skills/spec/phases.md"
file_has "spec build: a resumed build skips the baseline, whatever the start" "$BM" '1. Skip it when the build resumes, whatever the start.'
file_has "spec build: the base branch is the subproject's" "$BM" \
  '2. The base branch is the `base_branch` that `second-brain subproject <project> <subproject>`'
file_has "spec build: or the profile's" "$BM" '`second-brain profile <project> --keys` prints.'
file_has "spec build: origin/<base> when the repo has it" "$BM" \
  '`git -C "<path>" rev-parse --verify --quiet "refs/remotes/origin/<base_branch>"` prints a'
file_has "spec build: else the base branch itself" "$BM" 'hash, else `<base_branch>`.'
line_is "spec build: the start is tested with git's own test" "$BM" \
  '3. Run `git -C "<path>" merge-base --is-ancestor <start> <base>`.'
file_has "spec build: a start on the base skips the baseline, with its note" "$BM" \
  '`second-brain task note <ID> "Build: baseline skipped: the branch starts at <start> on <base>."`,'
file_has "spec build: any other start runs it" "$BM" '- Any other exit, such as on a branch cut from `release/<version>` or with commits the base'
is "spec build: the start is tested before the baseline launch" \
  "$(($(lineno "$BM" 'merge-base --is-ancestor <start> <base>') < $(lineno "$BM" '4. Launch `reviewer` in baseline mode on the branch as it is.')))" "1"
line_is "spec build: the start is noted before a spec is committed" "$BM" '   - Then note `<short hash>`: it is `<start>`.'
is "spec build: and that note comes before the spec commit" \
  "$(($(lineno "$BM" 'Then note `<short hash>`: it is `<start>`.') < $(lineno "$BM" 'commit -m "<ID>: spec"')))" "1"
file_has "spec build: the final validation runs either way" "$BM" 'The build-wide checks in `## 6. When every task passed` run either way.'
line_is "spec build: has ### A bundle" "$BM" '### A bundle'
is "spec build: the bundle steps come after the fix loop, before the build-wide run" \
  "$(($(linex "$BM" '### The fix loop') < $(linex "$BM" '### A bundle') && $(linex "$BM" '### A bundle') < $(linex "$BM" '## 6. When every task passed')))" "1"
file_has "spec build: a bundle comes from the last column of spec tasks" "$BM" \
  'A task whose `spec tasks` row names a bundle, in its last column, goes with the other tasks of'
file_has "spec build: one task or bundle at a time, never in parallel" "$BM" 'One task or bundle at a time, never in parallel.'
file_has "spec build: a bundle's tasks go to one fresh implementer run" "$BM" \
  '2. Launch one fresh `implementer` on them, with the bundle'"'"'s prompt and name.'
line_is "spec build: one commit line per task" "$BM" \
  '  - Last, one commit line per task, in order: `Commit <task> as "<ID> <task>: <title>".`'
for l in '  - `Bundle: <n>.`' '  - `Tasks: <task>, <task>.`: the tasks of the bundle it builds, in order.' \
  '  - For each of those tasks with a ruling: `Owner on <task>: <the ruling, as written>.`'; do
  line_is "spec build: the bundle prompt line ${l#  - }" "$BM" "$l"
done
file_has "spec build: names the bundle's implementer" "$BM" '`name: "<ID>-bundle-<n>-implementer"`'
file_has "spec build: each task of a bundle is set building first" "$BM" \
  '1. `second-brain spec status <ID> <task> building` for each of them, in order.'
file_has "spec build: each committed task is set built" "$BM" '`second-brain spec status <ID> <task> built --commit <hash>`, with the hash its `Commit:`'
file_has "spec build: the tasks after a stop go back to todo" "$BM" \
  'first `second-brain spec status <ID> <task> todo` for each task'
file_has "spec build: and the stop is a block, as for a task alone" "$BM" 'Then it stops the build, as item 3 of `### Build it` says.'
file_has "spec build: then one fresh reviewer reads the bundle" "$BM" \
  '2. Launch one fresh `reviewer` in task mode on them, with the bundle'"'"'s prompt.'
file_has "spec build: each task of a bundle is set in-review first" "$BM" \
  '1. `second-brain spec status <ID> <task> in-review` for each of them, in order.'
file_has "spec build: one verdict line per task" "$BM" '`<task>: VERDICT: PASS`, `FAIL` or `BLOCKED`'
file_has "spec build: a failed task of a bundle takes the fix loop alone" "$BM" \
  '4. Fix each task left whose review is not `passed`, one at a time, in order.'
file_has "spec build: a fix is always on one task" "$BM" '- A fix is always on one task, with the prompt and message above, even for a task of a bundle.'
file_has "spec build: fix rounds 1 to 3 reach the bundle's implementer" "$BM" \
  'or to `<ID>-bundle-<n>-implementer` for a task of bundle `<n>`,'
file_has "spec build: a resumed bundle finds each cut-off commit first" "$BM" \
  '1. Where they stand: a build `building` looks for its commit, and sets `built` when it finds one,'
file_has "spec build: the next task or bundle waits for the bundle" "$BM" '5. Every task of the bundle has passed: go on to the next task or bundle.'
file_has "spec build: a split bundle stops the build" "$BM" 'None, or exit 1 as for a split bundle: say so'
file_has "spec phases: names the Bundle line" "$PH" \
  '- Small, alike tasks may form a bundle: each adds one line, `- Bundle: <n>`, the same whole number'
file_has "spec phases: a bundle's tasks stand together and use none of each other" "$PH" \
  "- A bundle's tasks stand next to each other in the list, and none uses another task of its"
file_has "spec phases: each keeps its own check and commit" "$PH" '- Each task of a bundle keeps its own requirements, `- Check:` and commit.'
file_has "spec phases: the owner approves the bundles with the tasks" "$PH" \
  '- Show the bundles with the task list. The owner approves them with the tasks.'
file_has "spec phases: spec tasks must succeed and name each bundle" "$PH" \
  '- Run `second-brain spec tasks <ID>`. It must succeed, and its last column names each task'"'"'s'
file_has "spec tasks template: says how a bundle builds" "$here/templates/spec-tasks.md.tmpl" \
  'Tasks next to each other with the same `- Bundle: <n>` line are one bundle: built in one'
file_has "implementer: builds a bundle one task at a time" "$IM" \
  'per task. Build them one at a time, in that order, each as a task alone:'
file_has "implementer: fetches each packet as it starts the task" "$IM" '1. Fetch its packet only when you start it, and check where you are, as `## 0. Get your packet`'
file_has "implementer: each task test-first, with its checks and its own commit" "$IM" \
  '2. Build it test-first, run its packet'"'"'s `## Checks` and commit it with its own commit line, as'
file_has "implementer: one report per task" "$IM" 'Each opens with a line `Task: <task>`, then the lines'
file_has "implementer: a task it cannot commit stops the bundle" "$IM" '- A task you cannot commit stops the bundle.'
file_has "reviewer: reviews each task of a bundle against its own packet" "$RV" 'one commit per task. Review each task against its own packet:'
file_has "reviewer: runs the each-task checks once for a bundle" "$RV" '   once for the bundle, as step 4 says.'
file_has "reviewer: logs each finding on its own task" "$RV" 'and log each finding on its own task, as'
file_has "reviewer: one verdict line per task of a bundle" "$RV" '`<task>: VERDICT: <PASS, FAIL or BLOCKED> - <n> issues`.'
for a in implementer reviewer; do
  d="$(sed -n 's/^description: //p' "$here/agents/$a.md")"
  is "$a: the description names a bundle, under 200 characters" "$(case "$d" in *bundle*) [ "${#d}" -lt 200 ] && echo ok ;; esac)" "ok"
done
file_has "contract: a task item may name its bundle" "$CT" '- A task item may add `- Bundle: <n>`, a whole number. The tasks with the same number are one'
file_has "contract: spec tasks prints the bundle" "$CT" 'title (`-` when none), bundle (`-` when none).'
file_has "contract: spec tasks --json has the bundle key" "$CT" '`--json` prints the rows with the keys `id`, `state`, `title` and `bundle`'
file_has "contract: the baseline is skipped on a start on the base branch" "$CT" \
  '- The branch starts on the base branch when `git merge-base --is-ancestor HEAD <base>` exits 0.'
file_has "contract: names the skip note" "$CT" '`Build: baseline skipped: the branch starts at <short hash> on <base>.`'
file_has "contract: a resumed build skips it, and the final validation always runs" "$CT" \
  '- A resumed build skips the baseline, whatever the start. The final validation always runs.'
file_has "contract: a bundle goes to one implementer run" "$CT" "- A bundle's tasks go to one fresh \`implementer\` run. It builds them in order, one commit per"
file_has "contract: then one reviewer gives a verdict per task" "$CT" \
  'requirements, logs each finding on its task, and gives one verdict per task.'
file_has "contract: the cap counts per task" "$CT" 'Its own `fails` picks each round, so the cap counts per task.'
file_has "contract: never in parallel" "$CT" '- One task or bundle at a time, never in parallel.'
file_has "guide: says when the baseline is skipped" "$GD" 'It is skipped when the branch starts on the base'
file_has "guide: says how a bundle builds" "$GD" '- Small, alike tasks may form a bundle, which you approve with the task list.'
file_has "guide: spec tasks names each bundle" "$GD" '- `second-brain spec tasks EX-2` prints each task'"'"'s bundle in its last column.'
file_has "changelog: the baseline skip" "$here/CHANGELOG.md" '- A new build skips the baseline when the story'"'"'s branch starts on the base branch'
file_has "changelog: bundles" "$here/CHANGELOG.md" '- A bundle'"'"'s tasks go to one `implementer` run, one commit per'
file_has "changelog: spec tasks names the bundle" "$here/CHANGELOG.md" '- `second-brain spec tasks` prints each task'"'"'s bundle in a fourth column'

# ---------------------------------------------------------------- result
if [ -f "$tmp/undefined" ]; then
  while IFS= read -r cmd; do fail "undefined command: $cmd"; done <"$tmp/undefined"
fi
printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
