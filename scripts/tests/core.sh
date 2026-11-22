#!/usr/bin/env bash
# Area core: syntax, the undefined-command guard, the dispatcher, the frontmatter functions, root
# and context on an empty vault.
# Usage: bash scripts/test.sh core, or bash scripts/tests/core.sh
. "$(dirname "$0")/lib.sh"

# ---------------------------------------------------------------- syntax
for f in "$here/bin/second-brain" "$here"/scripts/lib/*.sh "$here"/scripts/*.sh "$here"/scripts/tests/*.sh; do
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
  "repo <project> [name]" "conventions [section]" "task new <ID> [--project P]" "link [--check | --apply | --foreign]" "link move <skill|agent> <name> [--project P]" "link drop-original <skill|agent> <name> <path>" "doctor [project] [--json] [--fix]" "snapshot [name]" "compare [name]" "session-check" \
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
# A vault inside the plugin's folder: the template named in a refusal is the one filled.
mkdir -p "$tmp/plug/templates" "$tmp/plug/vault/proj/claude/templates"
printf '%s\n' '{{TEAM}}' >"$tmp/plug/templates/task-readme.md.tmpl"
cp "$tmp/plug/templates/task-readme.md.tmpl" "$tmp/plug/vault/proj/claude/templates/"
(SB_PLUGIN_ROOT="$tmp/plug" SB_ROOT="$tmp/plug/vault" SB_P_DIR="$tmp/plug/vault/proj" &&
  sb_fill task-readme.md.tmpl "$tmp/plug/one.md") 2>"$tmp/stderr"
ERR="$(cat "$tmp/stderr")"
err_has "sb_fill: a project's own template is named by its vault path, wherever the vault is" \
  "unfilled in proj/claude/templates/task-readme.md.tmpl"
rm "$tmp/plug/vault/proj/claude/templates/task-readme.md.tmpl"
(SB_PLUGIN_ROOT="$tmp/plug" SB_ROOT="$tmp/plug/vault" SB_P_DIR="$tmp/plug/vault/proj" &&
  sb_fill task-readme.md.tmpl "$tmp/plug/two.md") 2>"$tmp/stderr"
ERR="$(cat "$tmp/stderr")"
err_has "sb_fill: the plugin's template is named by its name" "unfilled in task-readme.md.tmpl,"
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

# ---------------------------------------------------------------- result
result
