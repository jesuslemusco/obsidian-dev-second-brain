#!/usr/bin/env bash
# Scratch-vault tests for doctor and session-check: breaks one thing at a time and reads the rows.
# Usage: bash scripts/test-doctor.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
SB="$here/bin/second-brain"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-doctor.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

vault="$tmp/vault"
home="$tmp/claude-home"
mkdir -p "$vault/.obsidian" "$tmp/userdir" "$home"
export HOME="$tmp/userdir"
export SECOND_BRAIN_VAULT="$vault"
export SECOND_BRAIN_CLAUDE_HOME="$home"
export SECOND_BRAIN_TODAY="2026-01-10"
export SECOND_BRAIN_OBSIDIAN="none"
unset CLAUDE_SESSION_ID SECOND_BRAIN_OB_TIMEOUT

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
# edit <file> <sed script>: change a file through a temp file.
edit() {
  sed "$2" "$1" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$1"
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
is "fresh vault: the rows that are not ok, with no Obsidian and no import line" \
  "$(printf '%s\n' "$OUT" | awk -F' [|] ' '$1 != "ok" { printf "%s:%s ", $1, $2 }')" \
  "warn:import warn:obsidian-cli skip:index-fresh skip:unresolved-links "
chk "pointer: ok" pointer vault "ok | 0 | -"
is "rows: six cells each" "$(printf '%s\n' "$OUT" | awk -F' [|] ' 'NF != 6' | grep -c . || true)" "0"

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
printf '# Mine\n\n@%s/CLAUDE.md\n' "$vault" >"$home/CLAUDE.md"
doc
chk "import: an absolute import line is found" import vault "ok | 0 | -"
ln -s "$vault" "$HOME/vault-link"
printf '# Mine\n\n@~/vault-link/CLAUDE.md  \r\n' >"$home/CLAUDE.md"
doc
chk "import: a line starting with ~ and going through a link is found" import vault "ok | 0 | -"
printf '# Mine\n\n@~/elsewhere/CLAUDE.md\nsee @%s/CLAUDE.md\n' "$vault" >"$home/CLAUDE.md"
doc
chk "import: another file does not count" import vault "warn | 1 | CLAUDE.md"
reset

# ---------------------------------------------------------------- links, double-registration, obsidian-cli
doc
chk "obsidian-cli: warns when the CLI is missing" obsidian-cli vault "warn | 1 | missing"
chk "double-registration: ok with no links" double-registration vault "ok | 0 | -"
mkdir -p "$vault/claude/skills/my-skill" "$home/skills" "$home/agents"
printf '%s\n' '---' 'name: my-skill' 'description: A skill of my own.' '---' 'Body.' >"$vault/claude/skills/my-skill/SKILL.md"
doc
if [ -f "$here/scripts/lib/link.sh" ]; then
  rc_is "links: an unlinked skill gives exit 1" 1
  chk "links: an unlinked skill fails" links vault "fail | 1 | my-skill:missing"
  ln -s "$vault/claude/skills/my-skill" "$home/skills/my-skill"
  doc
  chk "links: ok once it is linked" links vault "ok | 0 | -"
else
  chk "links: skip without the link library" links vault "skip | 0 | -"
fi
ln -s "$here/skills/story-tracker" "$home/skills/story-tracker"
ln -s "$here/agents/scrum-master.md" "$home/agents/scrum-master.md"
ln -s "$tmp/userdir" "$home/skills/elsewhere"
doc
chk "double-registration: links into the plugin warn" double-registration vault "warn | 2 | skills/story-tracker, agents/scrum-master.md"
reset

# ---------------------------------------------------------------- sizes
doc
chk "always-loaded-size: ok on a fresh vault" always-loaded-size vault "ok | 0 | -"
chk "descriptions: ok with no skills" descriptions vault "ok | 0 | -"
chk "skill-size: ok with no skills" skill-size vault "ok | 0 | -"
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
chk "board: ok, views left unchecked without Obsidian" board Example "ok | 0 | -"
is "board: says the views were not checked" "$(fix_of board)" "views not checked"
chk "index-fresh: skip without Obsidian" index-fresh Example "skip | 0 | -"
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
mkdir -p "$T/EX-7/notes" "$T/EX-8"
: >"$T/EX-8/README.md"
doc Example
chk "no-readme: a task folder with no README, or an empty one, warns" no-readme Example "warn | 2 | EX-7, EX-8"
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
chk "unresolved-links: skip without Obsidian" unresolved-links Example "skip | 0 | -"
chk "bare-links: ok on new tasks" bare-links Example "ok | 0 | -"
chk "line-endings: ok on new tasks" line-endings Example "ok | 0 | -"
printf '%s\n' '' 'See [[README]] and [[profile|the profile]].' >>"$T/EX-1/README.md"
printf '%s\n' '' "See [[$P/README|Example Hub]] and [[other-note]]." >>"$T/EX-2/README.md"
printf '%s\n' '' 'A bare `[[README]]` does not resolve.' '```' '[[tasks.base]]' '```' >>"$T/EX-3/README.md"
doc Example
rc_is "bare-links: a warning leaves exit 0" 0
chk "bare-links: a bare [[README]] warns, a pathed link and code do not" bare-links Example "warn | 1 | EX-1"
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
is "--fix: the whole table follows" "$(printf '%s\n' "$OUT" | grep -c ' | ')" "26"
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
  got="$(python3 -c '
import json, sys
rows = json.load(sys.stdin)
by = dict((r["check"], r) for r in rows)
print(len(rows), sorted(rows[0].keys()) == ["check", "count", "fix", "offenders", "result", "scope"])
print(by["alias-unique"]["offenders"][0])
print(by["no-readme"]["count"], by["no-readme"]["offenders"], by["pointer"]["offenders"])
names = [r["check"] for r in rows]
print(names.index("sprints") - names.index("repos"), by["repos"]["result"], by["repos"]["offenders"])
print(names.index("repos") - names.index("code-doc-map"), by["code-doc-map"]["result"], by["code-doc-map"]["offenders"])' <"$tmp/doctor.json" 2>&1)"
  is "--json: 26 objects, six keys, strings escaped, offenders as arrays, code-doc-map then repos then sprints" "$got" \
    "26 True${NL}Say \"hi\" \\ there${NL}2 ['EX-7', 'EX-8'] []${NL}1 warn ['gone-repo']${NL}1 warn ['example-api', 'gone-repo']"
  run env SECOND_BRAIN_VAULT="$tmp/userdir" "$SB" doctor --json
  rc_is "--json: exit 2 with no vault" 2
  got="$(printf '%s\n' "$OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d), d[0]["check"], d[0]["result"])' 2>&1)"
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
# scope_rows <scope>: count the rows of one scope in the last run.
scope_rows() { printf '%s\n' "$OUT" | grep -c " | $1 | " || true; }
is "two projects: sixteen rows for each" "$(scope_rows Example)/$(scope_rows Two)" "16/16"
is "two projects: the vault rows come first, in the contract's order" "$(printf '%s\n' "$OUT" | head -10 | awk -F' [|] ' '{ printf "%s ", $2 }')" \
  "pointer index conventions import links double-registration obsidian-cli always-loaded-size descriptions skill-size "
is "two projects: the project rows in the contract's order" "$(printf '%s\n' "$OUT" | grep ' | Two | ' | awk -F' [|] ' '{ printf "%s ", $2 }')" \
  "profile board index-fresh task-frontmatter needs-a-status status-tag yaml-traps alias-unique no-readme topic-tags code-doc-map repos sprints unresolved-links bare-links line-endings "
chk "two projects: each row names its project" yaml-traps Two "fail | 1 | TW-1:epic"
chk "two projects: the other project is clean" yaml-traps Example "ok | 0 | -"
doc example
rc_is "a named project: its name is matched without case, and another project's failure is left out" 0
is "a named project: only its rows, after the vault rows" "$(scope_rows vault)/$(scope_rows Example)/$(scope_rows Two)" "10/16/0"

# ---------------------------------------------------------------- Obsidian answering, a stand-in
stub="$tmp/stub"
mkdir -p "$stub"
cat >"$stub/obsidian" <<'EOF'
#!/usr/bin/env bash
# Stand-in for the Obsidian CLI: answers from files in STUB_DIR.
printf '%s\n' "$*" >>"$STUB_DIR/calls.log"
case "$1" in
  vault) cat "$STUB_DIR/vault.txt" ;;
  unresolved) cat "$STUB_DIR/unresolved.txt" ;;
  base:query)
    view="${3#view=}"
    if [ -f "$STUB_DIR/view-$view.txt" ]; then cat "$STUB_DIR/view-$view.txt"; else printf 'Error: View not found: %s\n' "$view"; fi
    ;;
  *) printf 'Error: Command "%s" not found.\n' "$1" ;;
esac
EOF
chmod +x "$stub/obsidian"
export STUB_DIR="$stub"
export SECOND_BRAIN_OBSIDIAN="$stub/obsidian"
printf '%s\n' "$vault" >"$stub/vault.txt"
for v in "Active" "Current sprint" "By topic" "Needs a status"; do : >"$stub/view-$v.txt"; done
printf '%s\n' "$P/tasks/EX-1/README.md" "$P/tasks/EX-2/README.md" "$P/tasks/EX-3/README.md" >"$stub/view-All.txt"
: >"$stub/unresolved.txt"
doc Example
chk "obsidian-cli: ok when the CLI answers for this vault" obsidian-cli vault "ok | 0 | -"
chk "board: ok when every view answers" board Example "ok | 0 | -"
is "board: nothing left to say once the views are checked" "$(fix_of board)" "-"
chk "index-fresh: ok when view All holds every task README" index-fresh Example "ok | 0 | -"
chk "unresolved-links: ok when Obsidian lists none" unresolved-links Example "ok | 0 | -"
is "board: one query for each of the five views" "$(grep -c '^base:query ' "$stub/calls.log")" "5"
rm "$stub/view-By topic.txt"
printf '%s\n' "$P/tasks/EX-1/README.md" "$P/tasks/EX-2/README.md" >"$stub/view-All.txt"
printf 'gone-note\t1\t%s\nother\t2\tsomewhere/else.md, %s\nthird\t1\tprojects/example-more/x.md\nfourth\t1\tprojects/two/README.md\n' \
  "$P/tasks/EX-1/README.md" "$P/docs/README.md" >"$stub/unresolved.txt"
: >"$stub/calls.log"
doc
rc_is "board: a view that does not answer gives exit 1" 1
chk "board: the view that does not answer is named" board Example "fail | 1 | By topic"
chk "index-fresh: the board holds fewer notes than the disk" index-fresh Example "warn | 1 | disk:3 board:2"
chk "unresolved-links: links from notes under the project" unresolved-links Example "warn | 2 | gone-note, other"
chk "unresolved-links: each project gets its own" unresolved-links Two "warn | 1 | fourth"
is "unresolved-links: one CLI call for the whole run" "$(grep -c '^unresolved ' "$stub/calls.log")" "1"
export SECOND_BRAIN_OBSIDIAN="none"
reset

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

# ---------------------------------------------------------------- result
printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
