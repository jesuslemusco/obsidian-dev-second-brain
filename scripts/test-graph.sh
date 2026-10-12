#!/usr/bin/env bash
# Scratch-vault tests for the links between notes: outline, backlinks, unresolved, move and rename.
# Usage: bash scripts/test-graph.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
SB="$here/bin/second-brain"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-graph-test.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# The suite compares bytes. On Windows, in Git Bash, the platform library gives it the awk, grep
# and sed that keep every CR, as the helper has them.
. "$here/scripts/lib/platform.sh"

vault="$tmp/vault"
mkdir -p "$vault/.obsidian" "$tmp/userdir"
export HOME="$tmp/userdir"
export SECOND_BRAIN_VAULT="$vault"
export SECOND_BRAIN_TODAY="2026-01-10"
unset CLAUDE_SESSION_ID SECOND_BRAIN_CLAUDE_HOME

P="projects/example"
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
err_is() { is "$1" "$ERR" "$2"; }
err_has() {
  case "$ERR" in *"$2"*) pass "$1" ;; *) fail "$1" "missing: $2" "in stderr: $ERR" ;; esac
}
exists() {
  if [ -e "$2" ]; then pass "$1"; else fail "$1" "missing: $2"; fi
}
absent() {
  if [ -e "$2" ]; then fail "$1" "should not exist: $2"; else pass "$1"; fi
}
same() { # same <desc> <file> <file>
  if cmp -s "$2" "$3"; then pass "$1"; else fail "$1" "$2 and $3 differ"; fi
}
# note <vault path> <line...>: write a file of the vault, one argument per line.
note() {
  local f="$vault/$1"
  shift
  mkdir -p "${f%/*}"
  printf '%s\n' "$@" >"$f"
}
# line <vault path> <number>: print one line of a file.
line() { sed -n "${2}p" "$vault/$1"; }
# tree: print every folder of the vault, and every file with its checksum.
tree() {
  (cd "$vault" && find . -type d | LC_ALL=C sort && find . -type f -exec cksum {} + | LC_ALL=C sort -k3)
}
# unresolved_links: print the links of the last unresolved run without their place, sorted.
unresolved_links() {
  printf '%s\n' "$OUT" | sed 's/^[^:]*:[0-9]*: //' | LC_ALL=C sort
}

# ---------------------------------------------------------------- syntax
for f in "$here/scripts/lib/graph.sh" "$here/scripts/test-graph.sh"; do
  if bash -n "$f" 2>"$tmp/stderr"; then pass "syntax: ${f#"$here"/}"; else fail "syntax: ${f#"$here"/}" "$(cat "$tmp/stderr")"; fi
done
is "awk: every program that loads the link functions runs in the C locale" \
  "$(grep -n '"$(sb_graph_awk)"' "$here"/scripts/lib/*.sh | grep -v 'LC_ALL=C' || true)" ""

# ---------------------------------------------------------------- a scratch vault
sb scaffold vault
sb scaffold project Example --path "$P" --keys EX
sb scaffold project Two --path projects/two --keys TW
sb task new EX-1 --project Example --title "First task"
rc_is "setup: the scratch vault is built" 0
sb unresolved
rc_is "unresolved: exit 0 with nothing to list" 0
out_is "unresolved: no rows on a scaffolded vault" ""

# ---------------------------------------------------------------- outline
note "$P/docs/guide.md" '---' 'title: "# not a heading"' '# also not' '---' '# Guide' '' 'text' '## Part one' '```' '# in a fence' '```' \
  '### Deep  ' '#tag is no heading' '####### seven' '###### six' '~~~~' '## in tildes' '~~~' '## still in tildes' '~~~~' '## After' '##' 'not # one'
sb outline "$P/docs/guide.md"
rc_is "outline: exit 0" 0
out_is "outline: line, hashes and heading; frontmatter, fences and seven hashes left out" "5: # Guide
8: ## Part one
12: ### Deep
15: ###### six
21: ## After"
printf '# Title\r\n\r\n```\r\n# code\r\n```\r\n## Two\r\n' >"$vault/$P/docs/crlf.md"
sb outline "$P/docs/crlf.md"
out_is "outline: a CRLF note, with no carriage return in the rows" "1: # Title${NL}6: ## Two"
note "$P/docs/plain.md" 'no heading here'
sb outline "$P/docs/plain.md"
rc_is "outline: a note with no heading gives exit 0" 0
out_is "outline: and no rows" ""
sb outline "./$P/docs//guide.md"
out_has "outline: a path with a dot and a doubled slash is the same note" "5: # Guide"
sb outline "$P/docs/nope.md"
rc_is "outline: a missing note gives exit 1" 1
sb outline "$P/docs"
rc_is "outline: a folder gives exit 1" 1
sb outline
rc_is "outline: no path gives exit 5" 5
sb outline a b
rc_is "outline: two paths give exit 5" 5
sb outline "../outside.md"
rc_is "outline: a path that leaves the vault gives exit 5" 5
sb outline "$P/../../../outside.md"
rc_is "outline: a path that climbs out further down gives exit 5" 5
sb outline ".obsidian/app.json"
rc_is "outline: a path into a dot folder gives exit 5" 5
sb outline "$vault/$P/docs/guide.md"
rc_is "outline: a path from the system root gives exit 5" 5

# ---------------------------------------------------------------- reading the links of a note
note "lab/hub.md" '# Hub' '' '## Section'
note "lab/with space.md" '# With a space'
note "lab/twin.md" '# The note'
printf 'the file with no extension\n' >"$vault/lab/twin"
printf 'png' >"$vault/lab/pic.png"
printf '[[gone-in-a-text-file]]\n' >"$vault/lab/data.txt"
mkdir -p "$vault/.trash"
printf '[[gone-in-the-trash]]\n' >"$vault/.trash/old.md"
note "lab/reader.md" '---' 'up: "[[lab/hub|Hub]]"' 'related:' '  - "[[missing-in-frontmatter]]"' '---' '# Reader' '' \
  '[[lab/hub]] and [[LAB/Hub#Section|shown]] and ![[lab/pic.png]] and [[lab/hub#^block-1]]' \
  '[[#Only a heading]] and [[  ]] stay in the note' \
  '`[[in-code-span]]` and ``[[in a ` double]]`` hold none' \
  '[[gone]], [[gone#part|text]] and ![[gone.png]]' \
  '```' '[[in-a-fence]]' '```' '~~~~' '[[in-tildes]]' '```' '[[still-in-tildes]]' '~~~~' \
  '[md](lab/hub.md), [bare](lab/hub), [web](https://example.com/x.md), [mail](mailto:a@example.com), [anchor](#part)' \
  '[gone md](lab/nope.md), [gone angle](<lab/no pe.md>), [gone enc](lab/no%20pe.md#part)' \
  '[angle](<lab/with space.md>), [enc](lab/with%20space.md), [titled](lab/hub.md "A title"), ![img](lab/pic.png)' \
  '| cell | [[lab/hub\|Hub]] | [[gone-in-a-table\|x]] |' \
  '[not a link] (lab/nope.md) and [ ] a checkbox and [[unclosed' \
  '[[old]] and [[.trash/old]] are in a dot folder' \
  '[[gone-with-text|a [bracket] in the text]] and [[[[gone-in-brackets]]]]'
sb unresolved
rc_is "unresolved: exit 0 with rows" 0
out_is "unresolved: path, line and the link as written; code, fences, schemes and own-note links left out" "lab/reader.md:4: [[missing-in-frontmatter]]
lab/reader.md:11: [[gone]]
lab/reader.md:11: [[gone#part|text]]
lab/reader.md:11: ![[gone.png]]
lab/reader.md:21: [gone md](lab/nope.md)
lab/reader.md:21: [gone angle](<lab/no pe.md>)
lab/reader.md:21: [gone enc](lab/no%20pe.md#part)
lab/reader.md:23: [[gone-in-a-table\\|x]]
lab/reader.md:25: [[old]]
lab/reader.md:25: [[.trash/old]]
lab/reader.md:26: [[gone-with-text|a [bracket] in the text]]
lab/reader.md:26: [[gone-in-brackets]]"
sb backlinks lab/hub.md
rc_is "backlinks: exit 0" 0
out_is "backlinks: frontmatter, heading, block, text, markdown and table links, in reading order" "lab/reader.md:2: [[lab/hub|Hub]]
lab/reader.md:8: [[lab/hub]]
lab/reader.md:8: [[LAB/Hub#Section|shown]]
lab/reader.md:8: [[lab/hub#^block-1]]
lab/reader.md:20: [md](lab/hub.md)
lab/reader.md:20: [bare](lab/hub)
lab/reader.md:22: [titled](lab/hub.md \"A title\")
lab/reader.md:23: [[lab/hub\\|Hub]]"
sb backlinks lab/pic.png
out_is "backlinks: a file that is not a note, with its embeds" "lab/reader.md:8: ![[lab/pic.png]]${NL}lab/reader.md:22: ![img](lab/pic.png)"
sb backlinks "lab/with space.md"
out_is "backlinks: a markdown target in <> and a percent-encoded one" \
  "lab/reader.md:22: [angle](<lab/with space.md>)${NL}lab/reader.md:22: [enc](lab/with%20space.md)"
note "lab/twins.md" '[[lab/twin]] as written' '[[lab/twin.md]] with its extension' '[[lab/data.txt]] a text file'
sb backlinks lab/twin
out_is "resolve: a target is tried as written first" "lab/twins.md:1: [[lab/twin]]"
sb backlinks lab/twin.md
out_is "resolve: the note is reached with its extension" "lab/twins.md:2: [[lab/twin.md]]"
rm "$vault/lab/twin"
sb backlinks lab/twin.md
out_is "resolve: then with .md added" "lab/twins.md:1: [[lab/twin]]${NL}lab/twins.md:2: [[lab/twin.md]]"
sb backlinks lab/data.txt
out_is "backlinks: only notes are read for links, any file can be linked" "lab/twins.md:3: [[lab/data.txt]]"
sb backlinks lab/reader.md
rc_is "backlinks: a note nothing links to gives exit 0" 0
out_is "backlinks: and no rows" ""
sb backlinks lab/nope.md
rc_is "backlinks: a missing note gives exit 1" 1
sb backlinks lab
rc_is "backlinks: a folder gives exit 1" 1
sb backlinks
rc_is "backlinks: no path gives exit 5" 5
sb backlinks "../lab/hub.md"
rc_is "backlinks: a path that leaves the vault gives exit 5" 5
sb backlinks ".trash/old.md"
rc_is "backlinks: a path into a dot folder gives exit 5" 5

# ---------------------------------------------------------------- how a target resolves
note "target.md" '# At the vault root'
note "res/a/target.md" '# Beside the linking note'
note "res/a/near.md" '# Beside the linking note'
note "res/near.md" '# One folder up'
note "res/x/y/far.md" '# Three folders'
note "res/zz/far.md" '# Two folders'
note "res/Q/tie.md" '# Capital first in byte order'
note "res/m/tie.md" '# Same depth'
note "res/k/same.md" '# Fewer folders'
note "res/t/k/same.md" '# In the folder of the linking note'
note "res/t/k/note.md" '[[k/same]] the folder of the linking note wins'
note "res/a/note.md" '[[target]] the vault path first' '[[near]] then the folder of the note' '[up](../near.md) and [down](./near.md) from that folder' \
  '[[far]] the fewest folders' '[[tie]] the first in byte order' '[[ar]] and [[y/fa]] end at no folder boundary' \
  '[[RES/ZZ/FAR]] and [[Far.MD]] in any letter case' '[[y/far]] a longer end of the path' '[[/res/near]] from the vault root only'
sb backlinks target.md
out_is "resolve: the file at the vault path comes first" "res/a/note.md:1: [[target]]"
sb backlinks res/a/target.md
out_is "resolve: so the file beside the note is not reached by that name" ""
sb backlinks res/a/near.md
out_is "resolve: then the path taken from the note's folder" "res/a/note.md:2: [[near]]${NL}res/a/note.md:3: [down](./near.md)"
sb backlinks res/near.md
out_is "resolve: a path with dots is taken from the note's folder; a leading slash from the vault root" \
  "res/a/note.md:3: [up](../near.md)${NL}res/a/note.md:9: [[/res/near]]"
sb backlinks res/zz/far.md
out_is "resolve: then the end of a path, the fewest folders first; letter case is ignored" \
  "res/a/note.md:4: [[far]]${NL}res/a/note.md:7: [[RES/ZZ/FAR]]${NL}res/a/note.md:7: [[Far.MD]]"
sb backlinks res/x/y/far.md
out_is "resolve: a longer end of the path picks the deeper file" "res/a/note.md:8: [[y/far]]"
sb backlinks res/Q/tie.md
out_is "resolve: with the same number of folders, the first in byte order" "res/a/note.md:5: [[tie]]"
sb backlinks res/m/tie.md
out_is "resolve: and the other one is not reached" ""
sb backlinks res/t/k/same.md
out_is "resolve: among several ends of a path, the file in the linking note's folder wins" "res/t/k/note.md:1: [[k/same]]"
sb backlinks res/k/same.md
out_is "resolve: over the one with fewer folders" ""
sb unresolved
out_has "resolve: the end of a path counts at a folder boundary only" "res/a/note.md:6: [[ar]]${NL}res/a/note.md:6: [[y/fa]]"
is "unresolved: the whole vault" "$(printf '%s\n' "$OUT" | cut -d/ -f1 | LC_ALL=C sort -u | tr '\n' ' ')" "lab res "

# ---------------------------------------------------------------- unresolved, one project
note "$P/docs/broken.md" '[[no-such-note]] and [the plan](plan.md)'
note "projects/two/docs/broken.md" '[[other-missing]]'
sb unresolved Example
rc_is "unresolved <project>: exit 0" 0
out_is "unresolved <project>: the notes under the project only" \
  "$P/docs/broken.md:1: [[no-such-note]]${NL}$P/docs/broken.md:1: [the plan](plan.md)"
sb unresolved two
out_is "unresolved <project>: the project is named as everywhere else" "projects/two/docs/broken.md:1: [[other-missing]]"
note "$P/docs/plan.md" '# The plan'
note "no-such-note.md" '# Now it exists, outside the project'
sb unresolved Example
rc_is "unresolved <project>: exit 0 once every link resolves" 0
out_is "unresolved <project>: no rows; the files of the whole vault count" ""
sb unresolved Nope
rc_is "unresolved: an unknown project gives exit 1" 1
sb unresolved Example Two
rc_is "unresolved: two projects give exit 5" 5
rm "$vault/projects/two/docs/broken.md"

# ---------------------------------------------------------------- move, a note
note "mv/src/alpha.md" '# Alpha' '[[beta]] the sibling, by name' '[rel](beta.md), [dots](./beta.md) and [up](../other/gamma.md)' \
  '[[mv/other/gamma|Gamma]] by vault path' '[[alpha]] itself' '[[nowhere]] goes nowhere'
note "mv/src/beta.md" '# Beta'
note "mv/other/beta.md" '# Another beta'
note "mv/other/gamma.md" '# Gamma' '[sibling](beta.md) and [[mv/src/alpha#Top|Alpha]]'
printf 'a,b\n[[alpha]],[[mv/src/alpha]]\n' >"$vault/mv/other/data.csv"
printf '{"nodes":[{"type":"file","file":"mv/other/gamma.md"}]}\n' >"$vault/mv/other/map.canvas"
note "mv/linkers.md" '---' 'up: "[[mv/src/alpha|Alpha]]"' '---' \
  '[[alpha]] bare, [[alpha#Part|shown]], ![[alpha]], [[alpha.md]], [[mv/src/alpha]], [[mv/src/alpha.md#^b1|x]]' \
  '[vp](mv/src/alpha.md), [rel](src/alpha.md), [dots](./src/alpha.md#part), [ang](<mv/src/alpha.md>), [noext](mv/src/alpha)' \
  '`[[mv/src/alpha]]` in code and [[mv/other/gamma]] untouched' '```' '[[mv/src/alpha]]' '```'
printf '# CRLF\r\n\r\n[[mv/src/alpha|Alpha]] and [[alpha]]\r\nlast line, [here](src/alpha.md)' >"$vault/mv/crlf.md"
printf '{"nodes":[{"type":"file","file":"mv/src/alpha.md"}]}\n' >"$vault/mv/board.canvas"
printf '{"nodes":[{"type":"file","file":"mv/src/beta.md"}]}\n' >"$vault/mv/quiet.canvas"
printf 'filters:\n  and:\n    - file.inFolder("mv/other")\n' >"$vault/mv/list.base"
sb unresolved
unresolved_links >"$tmp/unresolved.before"
sb backlinks mv/src/alpha.md
is "move: seventeen links lead to the note before it moves" "$(printf '%s\n' "$OUT" | grep -c '')" "17"
tree >"$tmp/tree.before"
sb move mv/src/alpha.md mv/dst/alpha.md --dry-run
rc_is "move --dry-run: exit 0" 0
out_is "move --dry-run: a first line, then what a move would print" "dry run
moved: mv/src/alpha.md -> mv/dst/alpha.md
links: mv/crlf.md | 2
links: mv/linkers.md | 8
links: mv/other/gamma.md | 1
links: mv/dst/alpha.md | 3"
err_is "move --dry-run: names the canvas that mentions the old path" "note: mv/board.canvas mentions mv/src/alpha.md"
tree >"$tmp/tree.after"
same "move --dry-run: every file and folder of the vault is byte-identical" "$tmp/tree.before" "$tmp/tree.after"
cp "$vault/mv/crlf.md" "$tmp/crlf.before"
cp "$vault/mv/board.canvas" "$tmp/board.before"
sb move mv/src/alpha.md mv/dst/alpha.md
rc_is "move: exit 0" 0
out_is "move: the move, then one line per note it rewrote, with the path after the move" "moved: mv/src/alpha.md -> mv/dst/alpha.md
links: mv/crlf.md | 2
links: mv/linkers.md | 8
links: mv/other/gamma.md | 1
links: mv/dst/alpha.md | 3"
err_is "move: names the canvas that mentions the old path, and no other" "note: mv/board.canvas mentions mv/src/alpha.md"
same "move: the canvas is not edited" "$tmp/board.before" "$vault/mv/board.canvas"
absent "move: the note left its old place" "$vault/mv/src/alpha.md"
exists "move: a missing folder is created" "$vault/mv/dst/alpha.md"
is "move: a link in frontmatter gets the new vault path" "$(line mv/linkers.md 2)" 'up: "[[mv/dst/alpha|Alpha]]"'
is "move: a name that still resolves is left as written; a vault path is rewritten, .md only where it was" "$(line mv/linkers.md 4)" \
  '[[alpha]] bare, [[alpha#Part|shown]], ![[alpha]], [[alpha.md]], [[mv/dst/alpha]], [[mv/dst/alpha.md#^b1|x]]'
is "move: a markdown link keeps its form: vault path, path from the note, ./, <> and no extension" "$(line mv/linkers.md 5)" \
  '[vp](mv/dst/alpha.md), [rel](dst/alpha.md), [dots](./dst/alpha.md#part), [ang](<mv/dst/alpha.md>), [noext](mv/dst/alpha)'
is "move: a code span is not rewritten, nor a link to another note" "$(line mv/linkers.md 6)" '`[[mv/src/alpha]]` in code and [[mv/other/gamma]] untouched'
is "move: a fenced block is not rewritten" "$(line mv/linkers.md 8)" '[[mv/src/alpha]]'
is "move: #heading and |text are kept" "$(line mv/other/gamma.md 2)" '[sibling](beta.md) and [[mv/dst/alpha#Top|Alpha]]'
is "move, inside the note: a name that would now reach another file gets the vault path" "$(line mv/dst/alpha.md 2)" '[[mv/src/beta]] the sibling, by name'
is "move, inside the note: a path from the note's folder stays one; one that still resolves is left" "$(line mv/dst/alpha.md 3)" \
  '[rel](../src/beta.md), [dots](../src/beta.md) and [up](../other/gamma.md)'
is "move, inside the note: a vault path is left as written" "$(line mv/dst/alpha.md 4)" '[[mv/other/gamma|Gamma]] by vault path'
is "move, inside the note: a link to itself still resolves and is left" "$(line mv/dst/alpha.md 5)" '[[alpha]] itself'
is "move, inside the note: a link that went nowhere is left" "$(line mv/dst/alpha.md 6)" '[[nowhere]] goes nowhere'
is "move, CRLF: three carriage returns and three line feeds as before, and the last line still ends with neither" \
  "$(tr -cd '\r' <"$vault/mv/crlf.md" | wc -c | tr -d ' ')/$(tr -cd '\n' <"$vault/mv/crlf.md" | wc -c | tr -d ' ')/$(tail -c 1 "$vault/mv/crlf.md")" "3/3/)"
is "move, CRLF: the links are rewritten" "$(tr -d '\r' <"$vault/mv/crlf.md" | sed -n '3,4p')" \
  "[[mv/dst/alpha|Alpha]] and [[alpha]]${NL}last line, [here](dst/alpha.md)"
tr -d '\r' <"$tmp/crlf.before" >"$tmp/crlf.before.lf"
tr -d '\r' <"$vault/mv/crlf.md" >"$tmp/crlf.after.lf"
is "move, CRLF: only the two lines with a rewritten link change" "$(diff "$tmp/crlf.before.lf" "$tmp/crlf.after.lf" | grep -c '^[<>]')" "4"
sb backlinks mv/dst/alpha.md
is "move: every link that led to the note still does" "$(printf '%s\n' "$OUT" | grep -c '')" "17"
sb unresolved
is "move: no link was broken" "$(unresolved_links)" "$(cat "$tmp/unresolved.before")"
sb move mv/dst/alpha.md mv/dst/alpha.md
rc_is "move: onto itself gives exit 6" 6

# ---------------------------------------------------------------- rename, and the name alone
sb rename mv/dst/alpha.md omega --dry-run
out_has "rename --dry-run: a first line" "dry run${NL}moved: mv/dst/alpha.md -> mv/dst/omega.md"
exists "rename --dry-run: nothing is renamed" "$vault/mv/dst/alpha.md"
sb rename mv/dst/alpha.md omega
rc_is "rename: exit 0" 0
out_is "rename: the same lines as move; the extension is kept when the name has none" "moved: mv/dst/alpha.md -> mv/dst/omega.md
links: mv/crlf.md | 3
links: mv/dst/omega.md | 1
links: mv/linkers.md | 12
links: mv/other/gamma.md | 1"
is "rename: a file name alone stays a file name alone when the new name is unique; ! # and | are kept" "$(line mv/linkers.md 4)" \
  '[[omega]] bare, [[omega#Part|shown]], ![[omega]], [[omega.md]], [[mv/dst/omega]], [[mv/dst/omega.md#^b1|x]]'
is "rename: the markdown links follow" "$(line mv/linkers.md 5)" \
  '[vp](mv/dst/omega.md), [rel](dst/omega.md), [dots](./dst/omega.md#part), [ang](<mv/dst/omega.md>), [noext](mv/dst/omega)'
is "rename: the note's link to itself follows" "$(line mv/dst/omega.md 5)" '[[omega]] itself'
sb rename mv/dst/omega.md beta
out_has "rename: a name that other notes carry" "moved: mv/dst/omega.md -> mv/dst/beta.md"
is "rename: a file name alone becomes the vault path when the new name is not unique" "$(line mv/linkers.md 4)" \
  '[[mv/dst/beta]] bare, [[mv/dst/beta#Part|shown]], ![[mv/dst/beta]], [[mv/dst/beta.md]], [[mv/dst/beta]], [[mv/dst/beta.md#^b1|x]]'
is "rename: and so does the note's link to itself" "$(line mv/dst/beta.md 5)" '[[mv/dst/beta]] itself'
sb rename mv/dst/beta.md "final v1.2 draft"
out_has "rename: a dot inside the name is part of the name, and .md is kept" "moved: mv/dst/beta.md -> mv/dst/final v1.2 draft.md"
sb rename "mv/dst/final v1.2 draft.md" alpha
out_has "rename: back to the first name" "moved: mv/dst/final v1.2 draft.md -> mv/dst/alpha.md"
is "rename: .md stays where a link had it, through every rename" "$(line mv/linkers.md 4)" \
  '[[mv/dst/alpha]] bare, [[mv/dst/alpha#Part|shown]], ![[mv/dst/alpha]], [[mv/dst/alpha.md]], [[mv/dst/alpha]], [[mv/dst/alpha.md#^b1|x]]'
note "mv/ext.md" '# A note that becomes a text file'
note "mv/ext-reader.md" '[[mv/ext|Ext]] and [[ext]]'
sb rename mv/ext.md ext.txt
out_is "rename: an ending that is not the file's own extension is part of the name" "moved: mv/ext.md -> mv/ext.txt.md${NL}links: mv/ext-reader.md | 2"
sb rename mv/ext.txt.md api.v2
out_has "rename: and so is an ending that looks like an extension" "moved: mv/ext.txt.md -> mv/api.v2.md"
sb rename mv/api.v2.md ext.md
out_has "rename: the name may repeat the file's extension" "moved: mv/api.v2.md -> mv/ext.md"
sb rename mv/ext.md Other.MD
out_has "rename: in any letter case, and the file keeps its own spelling of it" "moved: mv/ext.md -> mv/Other.md"
sb rename mv/Other.md ext
is "rename: the links followed through every name" "$(line mv/ext-reader.md 1)" '[[mv/ext|Ext]] and [[ext]]'
printf 'all:\n' >"$vault/mv/Makefile"
sb rename mv/Makefile Buildfile.txt
out_is "rename: a file with no extension takes the name as it is typed" "moved: mv/Makefile -> mv/Buildfile.txt"
rm "$vault/mv/Buildfile.txt"
sb move mv/ext.md mv/ext.txt
out_is "move: changes an extension, which rename never does" "moved: mv/ext.md -> mv/ext.txt${NL}links: mv/ext-reader.md | 2"
is "move: links to a file that is no longer a note carry its extension" "$(line mv/ext-reader.md 1)" '[[mv/ext.txt|Ext]] and [[ext.txt]]'
sb rename mv/dst/alpha.md "sub/alpha"
rc_is "rename: a name with a slash gives exit 5" 5
sb rename mv/dst/alpha.md ..
rc_is "rename: a name that leaves the folder gives exit 5" 5
sb rename mv/dst/alpha.md .hidden
rc_is "rename: a dot name gives exit 5" 5
sb rename mv/dst/nope.md other
rc_is "rename: a missing note gives exit 1" 1
sb rename mv/src/beta.md linkers
rc_is "rename: a free name in the folder is taken" 0
sb rename mv/src/linkers.md beta
sb rename mv/linkers.md crlf
rc_is "rename: a name that exists in the folder gives exit 6" 6
sb rename mv/dst/alpha.md
rc_is "rename: no name gives exit 5" 5
sb rename mv/dst/alpha.md one two
rc_is "rename: two names give exit 5" 5
sb rename mv/dst renamed
out_has "rename: a folder" "moved: mv/dst -> mv/renamed"
exists "rename: the folder's notes go with it" "$vault/mv/renamed/alpha.md"
is "rename: links to a note of the folder follow" "$(line mv/linkers.md 2)" 'up: "[[mv/renamed/alpha|Alpha]]"'
sb rename mv/renamed dst

# ---------------------------------------------------------------- move, names with spaces and markdown forms
note "mv/my notes/first note.md" '# First' '[[plain]] and [same folder](<second note.md>)'
note "mv/my notes/second note.md" '# Second'
note "mv/src/plain.md" '# Plain' '[[first note]]'
note "mv/spaces.md" '[enc](mv/my%20notes/first%20note.md), [ang](<mv/my notes/first note.md>), [[first note]], [[mv/my notes/first note|x]]' \
  '[rel enc](my%20notes/first%20note.md#top), [titled](<my notes/first note.md> "The first"), ![[mv/my notes/first note#Part]]' \
  '[plain](mv/src/plain.md), [rel plain](src/plain.md), [high](mv/my%20notes/f%C3%A9e.md)'
# Two names with a letter outside ASCII, written as bytes so that this file stays ASCII.
fee="$(printf 'f\303\251e')"
fete="$(printf 'f\303\252te')"
note "mv/my notes/$fee.md" '# A name outside ASCII'
sb unresolved
is "markdown: percent-encoded bytes above ASCII are decoded" "$(unresolved_links)" "$(cat "$tmp/unresolved.before")"
sb rename "mv/my notes/first note.md" "third note"
out_is "rename, spaces: the lines" "moved: mv/my notes/first note.md -> mv/my notes/third note.md
links: mv/spaces.md | 7
links: mv/src/plain.md | 1"
is "rename, spaces: percent-encoding and <> are kept, in a vault path" "$(line mv/spaces.md 1)" \
  '[enc](mv/my%20notes/third%20note.md), [ang](<mv/my notes/third note.md>), [[third note]], [[mv/my notes/third note|x]]'
is "rename, spaces: and in a path from the note, with #heading, a title and an embed" "$(line mv/spaces.md 2)" \
  '[rel enc](my%20notes/third%20note.md#top), [titled](<my notes/third note.md> "The first"), ![[mv/my notes/third note#Part]]'
sb move mv/src/plain.md "mv/my notes/"
out_is "move, trailing slash: the note goes into the folder under its own name" "moved: mv/src/plain.md -> mv/my notes/plain.md
links: mv/spaces.md | 2"
is "move, spaces: a plain target is percent-encoded when its new path needs it" "$(line mv/spaces.md 3)" \
  '[plain](mv/my%20notes/plain.md), [rel plain](my%20notes/plain.md), [high](mv/my%20notes/f%C3%A9e.md)'
is "move, spaces: a name that still resolves from the note is left" "$(line "mv/my notes/third note.md" 2)" '[[plain]] and [same folder](<second note.md>)'
sb rename "mv/my notes/$fee.md" "$fete"
is "rename: percent-encoded bytes above ASCII are kept that way" "$(line mv/spaces.md 3)" \
  '[plain](mv/my%20notes/plain.md), [rel plain](my%20notes/plain.md), [high](mv/my%20notes/f%C3%AAte.md)'
sb unresolved
is "move, spaces: no link was broken" "$(unresolved_links)" "$(cat "$tmp/unresolved.before")"

# ---------------------------------------------------------------- move, a folder and files that are not notes
printf 'png' >"$vault/mv/other/chart.png"
note "mv/embeds.md" '![[mv/other/chart.png]] and ![shot](other/chart.png) and [[chart.png]]' '[data](mv/other/data.csv)'
cp "$vault/mv/other/data.csv" "$tmp/data.before"
cp "$vault/mv/list.base" "$tmp/base.before"
tree >"$tmp/tree.before"
sb move mv/other mv/archive/ --dry-run
out_has "move a folder --dry-run: a first line" "dry run${NL}moved: mv/other -> mv/archive/other"
tree >"$tmp/tree.after"
same "move a folder --dry-run: the vault is byte-identical" "$tmp/tree.before" "$tmp/tree.after"
sb move mv/other mv/archive/
rc_is "move a folder: exit 0" 0
out_is "move a folder, trailing slash: it goes inside under its own name, the folder being created" "moved: mv/other -> mv/archive/other
links: mv/dst/alpha.md | 2
links: mv/embeds.md | 2
links: mv/linkers.md | 1"
err_is "move a folder: names the base and the canvas that mention the old path, the canvas at its new place" \
  "note: mv/list.base mentions mv/other${NL}note: mv/archive/other/map.canvas mentions mv/other"
same "move a folder: the base is not edited" "$tmp/base.before" "$vault/mv/list.base"
same "move a folder: a file that is not a note is moved untouched" "$tmp/data.before" "$vault/mv/archive/other/data.csv"
absent "move a folder: the folder left its old place" "$vault/mv/other"
is "move a folder: a vault path to one of its files follows; a name or a path that still ends the same way is left" "$(line mv/embeds.md 1)" \
  '![[mv/archive/other/chart.png]] and ![shot](other/chart.png) and [[chart.png]]'
is "move a folder: a link to a file that is not a note follows" "$(line mv/embeds.md 2)" '[data](mv/archive/other/data.csv)'
is "move a folder: a link between its notes, and a vault path out of it, still resolve and are left" "$(line mv/archive/other/gamma.md 2)" \
  '[sibling](beta.md) and [[mv/dst/alpha#Top|Alpha]]'
is "move a folder: links into it from outside" "$(line mv/dst/alpha.md 3)$(line mv/dst/alpha.md 4)" \
  '[rel](../src/beta.md), [dots](../src/beta.md) and [up](../archive/other/gamma.md)[[mv/archive/other/gamma|Gamma]] by vault path'
note "mv/one.md" '# One'
note "mv/pointer.md" '[[mv/one]]'
sb move mv/one.md mv/archive
out_is "move into an existing folder: the note goes inside under its own name" "moved: mv/one.md -> mv/archive/one.md${NL}links: mv/pointer.md | 1"
is "move into an existing folder: the link follows" "$(line mv/pointer.md 1)" '[[mv/archive/one]]'
sb move mv/archive/other/chart.png mv/img/shot.png
out_is "move a file that is not a note: its links follow" "moved: mv/archive/other/chart.png -> mv/img/shot.png${NL}links: mv/embeds.md | 3"
is "move a file that is not a note: a name gets the new name, which is unique; a markdown path that was the end of a path gets the vault path" \
  "$(line mv/embeds.md 1)" '![[mv/img/shot.png]] and ![shot](mv/img/shot.png) and [[shot.png]]'
sb move mv/archive/one.md .
out_is "move to the vault root" "moved: mv/archive/one.md -> one.md${NL}links: mv/pointer.md | 1"
is "move to the vault root: the vault path is the file name" "$(line mv/pointer.md 1)" '[[one]]'
sb move "$P/docs" "$P/topics"
rc_is "move: a folder inside a project moves" 0
is "move: the project hub's link to the folder's hub follows" "$(grep -c "\[\[$P/topics/README|" "$vault/$P/README.md")" "1"
sb move "$P/topics" "$P/docs"
is "move: and back" "$(grep -c "\[\[$P/docs/README|" "$vault/$P/README.md")" "1"
sb unresolved
is "move a folder: no link was broken" "$(unresolved_links)" "$(cat "$tmp/unresolved.before")"

# ---------------------------------------------------------------- move, a link a moved file would capture
note "shadow/x/notes.md" '# The notes'
note "shadow/draft.md" '# A draft'
note "shadow/reader.md" '[[notes]] by the end of its path' '[md](x/notes.md) from the folder'
sb move shadow/draft.md notes.md
out_is "move: a link that the moved file would capture is rewritten to keep its file" "moved: shadow/draft.md -> notes.md${NL}links: shadow/reader.md | 1"
is "move: it gets the vault path, the name being shared now" "$(line shadow/reader.md 1)" '[[shadow/x/notes]] by the end of its path'
sb backlinks shadow/x/notes.md
is "move: both links still lead to the same note" "$(printf '%s\n' "$OUT" | grep -c '')" "2"

# ---------------------------------------------------------------- move, refusals
note "mv/solo.md" '# Solo'
note "mv/archive/solo.md" '# Another solo'
tree >"$tmp/tree.before"
sb move mv/nope.md mv/there.md
rc_is "move: a missing source gives exit 1" 1
sb move mv/solo.md mv/crlf.md
rc_is "move: a destination that exists gives exit 6" 6
sb move mv/solo.md mv/archive
rc_is "move: a folder that already holds the name gives exit 6" 6
err_has "move: names the destination that exists" "the destination exists: mv/archive/solo.md"
sb move mv/solo.md mv/archive/
rc_is "move: and so does the same folder with a trailing slash" 6
sb move mv/archive mv/src
rc_is "move: a folder goes inside an existing folder, where its name is free" 0
sb move mv/src/archive mv
sb move "$P" projects/renamed
rc_is "move: an index project's folder gives exit 5" 5
err_has "move: says why" "it holds the profile of the project Example"
sb move "$P" projects/renamed --dry-run
rc_is "move --dry-run: the same refusal" 5
sb move projects archive
rc_is "move: a folder that holds a project gives exit 5" 5
sb move . elsewhere
rc_is "move: the vault root gives exit 5" 5
sb rename "$P" renamed
rc_is "rename: an index project's folder gives exit 5" 5
sb move "$P/claude" "$P/config"
rc_is "move: the folder that holds a project's profile gives exit 5" 5
sb move "$P/claude/profile.md" "$P/claude/settings.md"
rc_is "move: a project's profile gives exit 5" 5
err_has "move: names the profile" "it is the profile of the project Example"
sb move CLAUDE.md index.md
rc_is "move: the index gives exit 5" 5
err_has "move: names the index" "it is the index of the vault"
sb rename obsidian-conventions.md rules
rc_is "rename: the conventions note gives exit 5" 5
err_has "rename: names the conventions note" "it is the conventions note"
mv "$vault/projects/two/claude/profile.md" "$tmp/profile.aside"
sb move projects/two projects/second
rc_is "move: a project whose profile is not written yet stays too, exit 5" 5
mv "$tmp/profile.aside" "$vault/projects/two/claude/profile.md"
sb move "$P/claude/README.md" "$P/claude/hub.md" --dry-run
rc_is "move: another note of a project's claude folder may move" 0
sb move mv mv/inside
rc_is "move: a folder into itself gives exit 5" 5
sb move ../outside.md mv/in.md
rc_is "move: a source that leaves the vault gives exit 5" 5
sb move mv/linkers.md ../outside.md
rc_is "move: a destination that leaves the vault gives exit 5" 5
sb move mv/linkers.md .trash/linkers.md
rc_is "move: a destination in a dot folder gives exit 5" 5
sb move .trash/old.md mv/old.md
rc_is "move: a source in a dot folder gives exit 5" 5
sb move mv/linkers.md
rc_is "move: no destination gives exit 5" 5
sb move mv/linkers.md a b
rc_is "move: three paths give exit 5" 5
sb move mv/linkers.md mv/x.md --force
rc_is "move: an unknown flag gives exit 5" 5
exists "move: the project is where it was" "$vault/$P/claude/profile.md"
sb outline 'mv\crlf.md'
rc_is "outline: a path written with a backslash gives exit 5 on every system" 5
err_has "outline: the message asks for forward slashes" "with forward slashes"
sb backlinks 'mv\crlf.md'
rc_is "backlinks: a path written with a backslash gives exit 5" 5
sb unresolved 'projects\example'
rc_is "unresolved: a project path written with a backslash gives exit 5" 5
sb move 'mv\solo.md' mv/there.md
rc_is "move: a source written with a backslash gives exit 5" 5
sb move mv/solo.md 'mv\there.md'
rc_is "move: a destination written with a backslash gives exit 5" 5
sb rename mv/solo.md 'a\b'
rc_is "rename: a name that holds a backslash gives exit 5" 5
tree >"$tmp/tree.after"
same "move: the refusals, and the folder moved there and back, leave the vault byte-identical" "$tmp/tree.before" "$tmp/tree.after"

# ---------------------------------------------------------------- a name that a move may not create
# Obsidian allows none of # ^ [ ] | \ : * ? " < > in a name. A link reader ends a target at some
# of them, a colon makes a markdown target a URL, and a backtick can open a code span.
note "sp/spnote.md" '# A note'
note "sp/reader.md" '[[spnote]] and [[sp/spnote|shown]]'
note "sp/C# course/inner.md" '[[sibling]] next to it'
note "sp/C# course/sibling.md" '# A sibling'
note "sp/sibling.md" '# Another sibling'
note "sp/meeting.md" '# The meeting'
note "sp/sib.md" '[m](meeting.md) [d](./meeting.md) [a](<meeting.md>) [[meeting]]'
mkdir -p "$vault/sp/[archive]" "$vault/sp/ti\`ck"
note "sp/minutes.md" '# Minutes'
note "sp/min-reader.md" '[[sp/minutes|the minutes]]'
note "sp/mover.md" '# A note to move'
note "sp/tick-wiki.md" '[[sp/mover]] and a lone ` here'
tree >"$tmp/tree.before"
# unspelled <what the name holds> <name>: neither rename nor move may give a note that name.
unspelled() {
  sb rename sp/spnote.md "$2"
  rc_is "rename: a name with $1 gives exit 5" 5
  sb move sp/spnote.md "sp/$2.md"
  rc_is "move: a destination with $1 gives exit 5" 5
}
unspelled "a hash" 'C# notes'
unspelled "a caret" 'a^b'
unspelled "a bar" 'a|b'
unspelled "an opening bracket" 'a[b'
unspelled "a closing bracket" 'a]b'
unspelled "a colon" 'a:b'
unspelled "a star" 'a*b'
unspelled "a question mark" 'a?b'
unspelled "a double quote" 'a"b'
unspelled "a less-than sign" 'a<b'
unspelled "a greater-than sign" 'a>b'
unspelled "a backtick" 'a`b'
unspelled "a blank at its start" ' lead'
unspelled "a blank at its end" 'trail '
unspelled "a tab" "$(printf 'x\ty')"
unspelled "a line break" "$(printf 'x\ny')"
unspelled "a control byte" "$(printf 'x\001y')"
sb rename sp/spnote.md 'C# notes' --dry-run
rc_is "rename --dry-run: the same refusal" 5
err_has "rename: says what a name cannot hold" "a name cannot hold any of"
sb backlinks sp/meeting.md
is "rename: four links lead to a note" "$(printf '%s\n' "$OUT" | grep -c '')" "4"
sb rename sp/meeting.md 'RFC: design'
rc_is "rename: a name that would turn its markdown links into a URL gives exit 5" 5
sb backlinks sp/meeting.md
is "rename: the four links still lead to it" "$(printf '%s\n' "$OUT" | grep -c '')" "4"
sb move sp/spnote.md 'sp/bad#folder/note.md'
rc_is "move: a folder that the move would make, with such a name, gives exit 5" 5
sb move sp/spnote.md 'sp/trail .png'
rc_is "move: a blank before an extension that links always carry is fine" 0
sb move 'sp/trail .png' sp/spnote.md
# A folder that is there already may have such a name. A link that cannot be written for it stops the move.
sb move sp/spnote.md 'sp/C# course/'
rc_is "move: into a folder whose path a wikilink cannot spell, a link that needs the path stops the move, exit 1" 1
err_has "move: names the note and the line" "note: sp/reader.md:1 cannot be rewritten"
sb move 'sp/C# course/inner.md' sp/inner.md
rc_is "move: out of such a folder, a link that would need its path stops the move, exit 1" 1
err_has "move: names that note and line too" "note: sp/C# course/inner.md:1 cannot be rewritten"
sb move sp/minutes.md 'sp/[archive]/'
rc_is "move: into a folder with brackets in its name, the same, exit 1" 1
sb move sp/mover.md 'sp/ti`ck/'
rc_is "move: a path with a backtick that would close a code span over the link stops the move, exit 1" 1
err_has "move: names the note whose link would be hidden" "note: sp/tick-wiki.md:1 cannot be rewritten"
tree >"$tmp/tree.after"
same "a name a move may not create: every refusal leaves the vault byte-identical" "$tmp/tree.before" "$tmp/tree.after"
if ! sb_is_windows; then
  # Another tool can leave a colon in a name; Windows cannot store one.
  note "sp/RFC: design.md" '# A name another tool gave'
  note "sp/deep/colon.md" '[a](<../RFC: design.md>)'
  tree >"$tmp/tree.before"
  sb backlinks 'sp/RFC: design.md'
  out_is "markdown: a target that starts with dots is not a URL" "sp/deep/colon.md:1: [a](<../RFC: design.md>)"
  sb move sp/deep/colon.md sp/colon.md
  rc_is "move: a markdown link that would read as a URL once rewritten stops the move, exit 1" 1
  err_has "move: names the note and the line of that link" "note: sp/deep/colon.md:1 cannot be rewritten"
  tree >"$tmp/tree.after"
  same "move: and nothing is moved or written" "$tmp/tree.before" "$tmp/tree.after"
fi
rm "$vault/sp/tick-wiki.md"
note "sp/free.md" '# Free'
note "sp/free-reader.md" '[[free]] and [md](./free.md)'
sb move sp/free.md 'sp/C# course/'
out_is "move: a note whose links can still be written goes into a folder with such a name" \
  "moved: sp/free.md -> sp/C# course/free.md${NL}links: sp/free-reader.md | 1"
is "move: the name alone is left, and the markdown path is percent-encoded" "$(line sp/free-reader.md 1)" '[[free]] and [md](./C%23%20course/free.md)'
sb rename 'sp/C# course/free.md' freed
out_is "rename: a note inside such a folder gets a new name" "moved: sp/C# course/free.md -> sp/C# course/freed.md${NL}links: sp/free-reader.md | 2"
is "rename: both links follow" "$(line sp/free-reader.md 1)" '[[freed]] and [md](./C%23%20course/freed.md)'
sb backlinks 'sp/C# course/freed.md'
is "rename: and both still lead to the note" "$(printf '%s\n' "$OUT" | grep -c '')" "2"
note "sp/overview.md" '# Overview'
note "sp/ov-reader.md" '[[overview]] and [m](./overview.md)'
sb move sp/overview.md 'sp/[archive]/'
out_is "move: into a folder with brackets in its name" "moved: sp/overview.md -> sp/[archive]/overview.md${NL}links: sp/ov-reader.md | 1"
is "move: the markdown path keeps the brackets and reads back" "$(line sp/ov-reader.md 1)" '[[overview]] and [m](./[archive]/overview.md)'
note "sp/tick-md.md" '[m](./mover.md) and a lone ` here'
sb move sp/mover.md 'sp/ti`ck/'
out_is "move: into a folder with a backtick in its name" "moved: sp/mover.md -> sp/ti\`ck/mover.md${NL}links: sp/tick-md.md | 1"
is "move: the backtick is percent-encoded in a markdown path, so no code span opens" "$(line sp/tick-md.md 1)" '[m](./ti%60ck/mover.md) and a lone ` here'
sb backlinks 'sp/ti`ck/mover.md'
out_is "move: and the link reads back" 'sp/tick-md.md:1: [m](./ti%60ck/mover.md)'
sb rename 'sp/C# course' 'C sharp course'
out_is "rename: a folder that has such a name gets one that links can spell" \
  "moved: sp/C# course -> sp/C sharp course${NL}links: sp/free-reader.md | 1"

# ---------------------------------------------------------------- a link in a single-quoted frontmatter value
# YAML writes an apostrophe twice inside single quotes. A new name with one must not end the value.
note "ya/yanote.md" '# A note'
note "ya/ref.md" '---' "up: '[[yanote]]'" 'rel: "[[yanote]]"' 'related:' "  - '[[yanote|N]]'" "  - '[[ya/yanote]]'" \
  "flow: ['[[yanote]]', \"[[yanote]]\"]" "plain: John's [[yanote]]" "said: 'it''s [[yanote]]'" '---' 'body [[yanote]]'
note "ya/it's here.md" '# A name with an apostrophe'
note "ya/hand.md" '---' "up: '[[ya/it''s here]]'" "gone: '[[ya/it''s gone]]'" '---'
cp "$vault/ya/ref.md" "$tmp/ya.before"
sb backlinks "ya/it's here.md"
out_is "frontmatter: a doubled apostrophe in a single-quoted value is read as one" "ya/hand.md:2: [[ya/it''s here]]"
sb unresolved
out_has "frontmatter: an unresolved link there is printed as it is written" "ya/hand.md:3: [[ya/it''s gone]]"
sb rename ya/yanote.md "John's note"
rc_is "rename: to a name with an apostrophe, exit 0" 0
out_is "rename: every link of the note is rewritten" "moved: ya/yanote.md -> ya/John's note.md${NL}links: ya/ref.md | 9"
is "rename: in a single-quoted value the apostrophe is written twice" "$(line ya/ref.md 2)" "up: '[[John''s note]]'"
is "rename: in a double-quoted value it is written once" "$(line ya/ref.md 3)" 'rel: "[[John'"'"'s note]]"'
is "rename: single-quoted list items" "$(line ya/ref.md 5)$(line ya/ref.md 6)" "  - '[[John''s note|N]]'  - '[[ya/John''s note]]'"
is "rename: a flow list with both kinds of quotes" "$(line ya/ref.md 7)" "flow: ['[[John''s note]]', \"[[John's note]]\"]"
is "rename: an apostrophe in a plain value opens no quote" "$(line ya/ref.md 8)" "plain: John's [[John's note]]"
is "rename: a single-quoted value that held an apostrophe already" "$(line ya/ref.md 9)" "said: 'it''s [[John''s note]]'"
is "rename: the body is not YAML" "$(line ya/ref.md 11)" "body [[John's note]]"
sb backlinks "ya/John's note.md"
is "rename: the nine links read back and lead to the note" "$(printf '%s\n' "$OUT" | grep -c '')" "9"
out_has "backlinks: prints the link as it is written" "ya/ref.md:2: [[John''s note]]"
sb unresolved
is "rename: none of them is unresolved" "$(printf '%s\n' "$OUT" | grep -c '^ya/ref' || true)" "0"
sb rename "ya/John's note.md" "Mary's own"
out_is "rename: a second rename, from the name with an apostrophe" "moved: ya/John's note.md -> ya/Mary's own.md${NL}links: ya/ref.md | 9"
is "rename: the single-quoted value follows" "$(line ya/ref.md 2)$(line ya/ref.md 9)" "up: '[[Mary''s own]]'said: 'it''s [[Mary''s own]]'"
sb rename "ya/Mary's own.md" yanote
same "rename: there and back leaves the note byte-identical" "$tmp/ya.before" "$vault/ya/ref.md"

# ---------------------------------------------------------------- the end of options, and the temp folder
note "dash/x.md" '# X'
note "dash/reader.md" '[[dash/x]]'
sb rename dash/x.md -draft
rc_is "rename: a name that starts with a dash reads as an option, exit 5" 5
sb rename dash/x.md -- -draft
out_is "rename: after --, a name may start with a dash" "moved: dash/x.md -> dash/-draft.md${NL}links: dash/reader.md | 1"
sb rename --dry-run -- dash/-draft.md --dry-run
out_is "rename: after --, --dry-run is a name; before it, the option" \
  "dry run${NL}moved: dash/-draft.md -> dash/--dry-run.md${NL}links: dash/reader.md | 1"
sb move -- dash/-draft.md dash/x.md
out_is "move: takes -- too" "moved: dash/-draft.md -> dash/x.md${NL}links: dash/reader.md | 1"
mkdir -p "$tmp/work"
run env TMPDIR="$tmp/work" "$SB" move dash/x.md dash/y.md --dry-run
run env TMPDIR="$tmp/work" "$SB" move dash/x.md dash/y.md
rc_is "move: with its temp files in another folder, exit 0" 0
run env TMPDIR="$tmp/work" "$SB" move sp/minutes.md 'sp/[archive]/'
rc_is "move: a move refused after the vault was read, exit 1" 1
is "move: no temp file is left after a dry run, a move or a refusal" "$(ls -A "$tmp/work" | grep -c '' || true)" "0"

# ---------------------------------------------------------------- stand-ins that make a move go wrong
# The helper finds awk and mv on the PATH. These two do what a test asks for, then run the real one.
shim="$tmp/shim"
mkdir -p "$shim"
REAL_AWK="$(type -P awk)"
REAL_MV="$(type -P mv)"
export REAL_AWK REAL_MV
cat >"$shim/awk" <<'EOF'
#!/bin/sh
# Stand-in for awk. While the vault is read for a move it lets a file appear; while the links
# are put in place it takes the write permission of a note away.
if [ "${SB_MODE:-}" = "move" ] && [ -n "${SHIM_APPEAR:-}" ]; then printf 'written by someone else\n' >"$SHIM_APPEAR"; fi
if [ -n "${SB_SKIP:-}" ] && [ -n "${SHIM_LOCK:-}" ]; then chmod 444 "$SHIM_LOCK"; fi
exec "$REAL_AWK" "$@"
EOF
cat >"$shim/mv" <<'EOF'
#!/bin/sh
# Stand-in for mv: fails without moving when a test asks for it, or moves and then runs what
# the test gives it, as someone who edits a note while the command runs.
[ -z "${SHIM_MV_FAILS:-}" ] || exit 1
"$REAL_MV" "$@"
rc=$?
[ -z "${SHIM_AFTER_MV:-}" ] || eval "$SHIM_AFTER_MV"
exit "$rc"
EOF
chmod +x "$shim/awk" "$shim/mv"
# Whoever runs the suite as root reads and writes a file whatever its mode says.
printf 'probe\n' >"$tmp/probe"
chmod 000 "$tmp/probe"
modes=1
[ ! -r "$tmp/probe" ] || modes=0

# ---------------------------------------------------------------- move, a destination that turns up
note "race/a.md" '# A'
note "race/reader.md" '[[race/a]]'
run env PATH="$shim:$PATH" SHIM_APPEAR="$vault/race/d.md" "$SB" move race/a.md race/d.md
rc_is "move: a destination that appears while the vault is read gives exit 6" 6
is "move: the file that appeared is not overwritten" "$(cat "$vault/race/d.md")" "written by someone else"
exists "move: the note stays where it was" "$vault/race/a.md"
is "move: no link is rewritten" "$(line race/reader.md 1)" '[[race/a]]'
rm "$vault/race/d.md"
ln -s nowhere "$vault/race/dangling.md" 2>/dev/null
if [ -L "$vault/race/dangling.md" ] && [ ! -e "$vault/race/dangling.md" ]; then
  sb move race/a.md race/dangling.md
  rc_is "move: a dangling symlink at the destination counts as existing, exit 6" 6
  if [ -L "$vault/race/dangling.md" ]; then pass "move: the symlink is left alone"; else fail "move: the symlink is left alone" "it was replaced"; fi
  exists "move: the note stays where it was, again" "$vault/race/a.md"
else
  printf 'note: this system makes no dangling symlink, so that destination is not tried\n'
fi
rm -f "$vault/race/dangling.md"
run env PATH="$shim:$PATH" SHIM_MV_FAILS=1 "$SB" move race/a.md race/new/deep/a.md
rc_is "move: a move that fails gives exit 1" 1
err_has "move: says that nothing was changed" "nothing was changed"
absent "move: the folders made for it are taken back" "$vault/race/new"
exists "move: the note stays where it was, a third time" "$vault/race/a.md"
mkdir -p "$vault/race/kept"
run env PATH="$shim:$PATH" SHIM_MV_FAILS=1 "$SB" move race/a.md race/kept/more/a.md
exists "move: a folder that was there before a failed move is kept" "$vault/race/kept"
absent "move: and only the one made for the move is taken back" "$vault/race/kept/more"

# ---------------------------------------------------------------- move, a note that is edited while the command runs
# The stand-in for mv edits a note after the move and before the links are put in place.
note "ed/target.md" '# The target'
note "ed/ref.md" 'line 1 keep' 'see [[ed/target]]' 'line 3 keep'
note "ed/other.md" '[[ed/target]]'
export SHIM_FILE="$vault/ed/ref.md"
run env PATH="$shim:$PATH" SHIM_AFTER_MV='{ printf "a line added meanwhile\n"; cat "$SHIM_FILE"; } >"$SHIM_FILE.new" && cat "$SHIM_FILE.new" >"$SHIM_FILE" && rm "$SHIM_FILE.new"' \
  "$SB" move ed/target.md ed/moved.md
rc_is "move: a note that got a line while the command ran gives exit 1" 1
is "move: that note is left exactly as it was edited" "$(cat "$vault/ed/ref.md")" \
  "a line added meanwhile${NL}line 1 keep${NL}see [[ed/target]]${NL}line 3 keep"
err_has "move: names it as changed, with its old link" "note: ed/ref.md changed while the command ran: it is left as it is, and still holds an old link"
out_is "move: reports the move and the note it did rewrite" "moved: ed/target.md -> ed/moved.md${NL}links: ed/other.md | 1"
is "move: the other note is rewritten" "$(line ed/other.md 1)" '[[ed/moved]]'
note "ed/ref.md" 'line 1 keep' 'see [[ed/moved]]' 'line 3 keep'
run env PATH="$shim:$PATH" SHIM_AFTER_MV='sed "s/^see /SEE /" "$SHIM_FILE" >"$SHIM_FILE.new" && cat "$SHIM_FILE.new" >"$SHIM_FILE" && rm "$SHIM_FILE.new"' \
  "$SB" move ed/moved.md ed/target.md
rc_is "move: a line to rewrite that was edited, the note keeping its length, gives exit 1" 1
is "move: that edit is kept, and the note is left with its old link" "$(line ed/ref.md 2)" 'SEE [[ed/moved]]'
is "move: the other note is rewritten again" "$(line ed/other.md 1)" '[[ed/target]]'
note "ed/ref.md" 'line 1 keep' 'see [[ed/target]]' 'line 3 keep'
run env PATH="$shim:$PATH" SHIM_AFTER_MV='sed "s/^line 3 keep/LINE 3 KEEP/" "$SHIM_FILE" >"$SHIM_FILE.new" && cat "$SHIM_FILE.new" >"$SHIM_FILE" && rm "$SHIM_FILE.new"' \
  "$SB" move ed/target.md ed/moved.md
rc_is "move: an edit of another line that keeps the length does not stop the rewrite" 0
is "move: that edit is kept and the link is rewritten" "$(cat "$vault/ed/ref.md")" "line 1 keep${NL}see [[ed/moved]]${NL}LINE 3 KEEP"
unset SHIM_FILE

# ---------------------------------------------------------------- move, a note that awk cannot hand back whole
note "nul/nulnote.md" '# A note'
printf 'line one [[nulnote]]\nbinary \0 middle\nlast line with more text\n' >"$vault/nul/ref.md"
tree >"$tmp/tree.before"
sb move nul/nulnote.md nul/nulmoved.md
if [ "$RC" -eq 0 ]; then
  printf 'line one [[nulmoved]]\nbinary \0 middle\nlast line with more text\n' >"$tmp/ref.want"
  same "move: a note that holds a NUL byte is rewritten whole by an awk that reads it whole" "$tmp/ref.want" "$vault/nul/ref.md"
  sb move nul/nulmoved.md nul/nulnote.md
else
  rc_is "move: a note that awk cuts at a NUL byte stops the move, exit 1" 1
  err_has "move: names the note it cannot read whole" "note: nul/ref.md holds bytes"
  tree >"$tmp/tree.after"
  same "move: nothing is moved or written then" "$tmp/tree.before" "$tmp/tree.after"
fi
rm "$vault/nul/ref.md"
printf 'binary \0 first\nthen a link, [[nulnote]]\n' >"$vault/nul/late.md"
tree >"$tmp/tree.before"
sb move nul/nulnote.md nul/nulmoved.md
if [ "$RC" -eq 0 ]; then
  printf 'binary \0 first\nthen a link, [[nulmoved]]\n' >"$tmp/late.want"
  same "move: a link after a NUL byte is rewritten by an awk that reads the note whole" "$tmp/late.want" "$vault/nul/late.md"
  sb move nul/nulmoved.md nul/nulnote.md
else
  rc_is "move: a note cut at a NUL byte before its link stops the move too, exit 1" 1
  err_has "move: names the note whose link it could not see" "note: nul/late.md holds bytes"
  tree >"$tmp/tree.after"
  same "move: nothing is moved, so that link is not left behind" "$tmp/tree.before" "$tmp/tree.after"
fi
rm "$vault/nul/late.md"
printf 'no link here, only a control \001 byte\n' >"$vault/nul/plain.md"
sb move nul/nulnote.md nul/nulmoved.md
rc_is "move: a note with that byte and no link to rewrite does not stop a move" 0
sb move nul/nulmoved.md nul/nulnote.md
rm "$vault/nul/plain.md"
note "nul/ctlnote.md" '# A note'
printf 'line one [[ctlnote]]\ncontrol \001 byte\nlast line\n' >"$vault/nul/ctl.md"
tree >"$tmp/tree.before"
sb move nul/ctlnote.md nul/ctlmoved.md
rc_is "move: a note that holds the byte the helper splits a file at stops the move, exit 1" 1
err_has "move: names that note" "note: nul/ctl.md holds bytes"
sb move nul/ctlnote.md nul/ctlmoved.md --dry-run
rc_is "move --dry-run: says the same, exit 1" 1
tree >"$tmp/tree.after"
same "move: nothing is moved or written for that note either" "$tmp/tree.before" "$tmp/tree.after"
rm "$vault/nul/ctl.md"

# ---------------------------------------------------------------- move, a note that cannot be written or read
note "wr/target.md" '# The target'
note "wr/a1.md" '[[wr/target]]'
note "wr/b2.md" '[[wr/target]]'
note "wr/c3.md" '[[wr/target]]'
if [ "$modes" -eq 1 ]; then
  chmod 444 "$vault/wr/b2.md"
  tree >"$tmp/tree.before"
  sb move wr/target.md wr/moved.md
  rc_is "move: a note that cannot be written stops the move before it starts, exit 1" 1
  err_has "move: names the note that cannot be written" "note: wr/b2.md cannot be written"
  tree >"$tmp/tree.after"
  same "move: nothing is moved, and no other note is rewritten" "$tmp/tree.before" "$tmp/tree.after"
  chmod 644 "$vault/wr/b2.md"
  run env PATH="$shim:$PATH" SHIM_LOCK="$vault/wr/b2.md" "$SB" move wr/target.md wr/moved.md
  rc_is "move: a write that fails after the move gives exit 1" 1
  out_is "move: it reports the move and the notes it did rewrite" "moved: wr/target.md -> wr/moved.md${NL}links: wr/a1.md | 1${NL}links: wr/c3.md | 1"
  err_has "move: names the note that still holds an old link" "note: wr/b2.md could not be written, and still holds an old link"
  is "move: the notes before and after that one are rewritten" "$(line wr/a1.md 1)$(line wr/c3.md 1)" '[[wr/moved]][[wr/moved]]'
  is "move: that note is as it was" "$(line wr/b2.md 1)" '[[wr/target]]'
  chmod 644 "$vault/wr/b2.md"
  sb unresolved
  out_has "move: unresolved lists the link that is left" "wr/b2.md:1: [[wr/target]]"
  note "wr/b2.md" '[[wr/moved]]'
  chmod 000 "$vault/wr/b2.md"
  sb move wr/moved.md wr/target.md
  rc_is "move: a note that cannot be read stops the move, exit 1" 1
  err_has "move: names the note that cannot be read" "note: wr/b2.md could not be read"
  exists "move: nothing is moved then" "$vault/wr/moved.md"
  is "move: and no note is rewritten" "$(line wr/a1.md 1)" '[[wr/moved]]'
  sb backlinks wr/moved.md
  rc_is "backlinks: a note that cannot be read leaves exit 0" 0
  out_is "backlinks: the notes it could read are listed" "wr/a1.md:1: [[wr/moved]]${NL}wr/c3.md:1: [[wr/moved]]"
  err_is "backlinks: the note it could not read is named" "note: wr/b2.md could not be read"
  sb unresolved
  rc_is "unresolved: a note that cannot be read leaves exit 0" 0
  err_is "unresolved: the note it could not read is named" "note: wr/b2.md could not be read"
  chmod 644 "$vault/wr/b2.md"
  mkdir -p "$vault/wr/sealed"
  note "wr/sealed/inside.md" '[[wr/moved]]'
  chmod 000 "$vault/wr/sealed"
  sb move wr/moved.md wr/target.md
  rc_is "move: a folder that cannot be opened stops the move, exit 1" 1
  exists "move: nothing is moved then either" "$vault/wr/moved.md"
  chmod 755 "$vault/wr/sealed"
  sb move wr/moved.md wr/target.md
  out_is "move: once every note can be read and written, the move goes through" \
    "moved: wr/moved.md -> wr/target.md${NL}links: wr/a1.md | 1${NL}links: wr/b2.md | 1${NL}links: wr/c3.md | 1${NL}links: wr/sealed/inside.md | 1"
else
  printf 'note: file modes do not bind this user, so the notes that cannot be read or written are not tried\n'
fi

# ---------------------------------------------------------------- move, a symlink in the vault
mkdir -p "$tmp/elsewhere"
printf '# Far away\n' >"$tmp/elsewhere/farnote.md"
note "sym/reader.md" '[[farnote]]'
ln -s "$tmp/elsewhere" "$vault/sym/linked" 2>/dev/null
if [ -L "$vault/sym/linked" ]; then
  sb unresolved
  out_has "symlink: a note behind one is not a file of the vault" "sym/reader.md:1: [[farnote]]"
  sb move sym/linked/farnote.md sym/farnote.md
  rc_is "move: a source behind a symlinked folder gives exit 5" 5
  err_has "move: names the symlink" "sym/linked is a symlink"
  sb move sym/reader.md sym/linked/reader.md
  rc_is "move: a destination behind a symlinked folder gives exit 5" 5
  sb move sym/reader.md sym/linked/
  rc_is "move: into a symlinked folder gives exit 5" 5
  sb move sym/reader.md sym/linked
  rc_is "move: onto a symlinked folder, which would take the note, gives exit 5" 5
  sb move sym/linked sym/renamed
  rc_is "move: the symlink itself gives exit 5" 5
  sb rename sym/linked/farnote.md near
  rc_is "rename: a note behind a symlinked folder gives exit 5" 5
  sb outline sym/linked/farnote.md
  rc_is "outline: a note behind a symlinked folder is not a note of the vault, exit 1" 1
  out_is "outline: and nothing is read through the symlink" ""
  sb backlinks sym/linked/farnote.md
  rc_is "backlinks: the same, exit 1" 1
  exists "symlink: the file behind it is where it was" "$tmp/elsewhere/farnote.md"
  exists "symlink: the note in the vault is where it was" "$vault/sym/reader.md"
  rm "$vault/sym/linked"
else
  printf 'note: this system makes no symlink to a folder, so the notes behind one are not tried\n'
  rm -rf "$vault/sym/linked"
fi

# ---------------------------------------------------------------- move, a path the vault lists under another spelling
# Some file systems find a file under a spelling their own list does not show: another Unicode
# form of a letter, or another case of a letter outside ASCII. No link would follow that move.
nfd="$(printf 'cafe\314\201')"
nfc="$(printf 'caf\303\251')"
note "uni/$nfd.md" '# Stored with a combining accent'
note "uni/reader.md" "[[uni/$nfd]]"
sb move "uni/$nfc.md" uni/moved.md
rc_is "move: a path typed in another Unicode form than the vault lists gives exit 1" 1
if [ -e "$vault/uni/$nfc.md" ]; then
  err_has "move: says to write the path as the vault lists it" "write the path as the vault lists it"
fi
absent "move: nothing is moved" "$vault/uni/moved.md"
is "move: and no link is touched" "$(line uni/reader.md 1)" "[[uni/$nfd]]"
mkfifo "$vault/uni/pipe.md" 2>/dev/null
if [ -p "$vault/uni/pipe.md" ]; then
  sb move uni/pipe.md uni/other.md
  rc_is "move: something at the path that the vault's list does not hold gives exit 1" 1
  err_has "move: says the vault does not list it" "the vault does not list it under that spelling"
  if [ -p "$vault/uni/pipe.md" ]; then pass "move: it is left where it was"; else fail "move: it is left where it was" "it was moved"; fi
else
  printf 'note: this system makes no named pipe, so a path outside the list is not tried that way\n'
fi
rm -f "$vault/uni/pipe.md"
mkdir -p "$vault/uni/empty"
sb move uni/empty uni/still-empty
out_is "move: a folder with no file in it is in no list, and moves" "moved: uni/empty -> uni/still-empty"

# ---------------------------------------------------------------- move, a canvas or a base that names the old path
mkdir -p "$vault/img" "$vault/cv"
printf 'png' >"$vault/img/pic.png"
printf '{"nodes":[{"type":"text","text":"imgur, assets/img/x.png, img.png and myimg/pic.png"}]}\n' >"$vault/cv/words.canvas"
printf '{"nodes":[{"type":"file","file":"img/pic.png"}]}\n' >"$vault/cv/file.canvas"
printf 'filters:\n  and:\n    - file.inFolder("img")\n' >"$vault/cv/folder.base"
sb move img pictures
rc_is "move: a folder with a short name moves" 0
err_is "move: a canvas or a base is named when it holds the old path as a whole path, not as a part of a word or of another path" \
  "note: cv/file.canvas mentions img${NL}note: cv/folder.base mentions img"
sb move pictures/pic.png pictures/shot.png
err_is "move: a file's old path is not found in a canvas that names another file" ""
printf '{"nodes":[{"type":"file","file":"pictures/shot.png.bak"},{"type":"file","file":"old/pictures/shot.png"}]}\n' >"$vault/cv/near.canvas"
printf '{"nodes":[{"type":"text","text":"see ![[pictures/shot.png]]"}]}\n' >"$vault/cv/text.canvas"
sb move pictures/shot.png pictures/pic.png
err_is "move: a longer name and a deeper path are other files; a link in a text card names this one" "note: cv/text.canvas mentions pictures/shot.png"

# ---------------------------------------------------------------- notes whose extension is in capitals
note "$P/docs/LOUD.MD" '---' 'aliases:' '  - Loud Note' '---' '# Loud' 'the word qloud is here'
note "ROOTLOUD.MD" '---' 'aliases: [Root Loud]' '---' '# At the root'
note "$P/docs/quiet.md" '[[LOUD]] and [[projects/example/docs/LOUD.MD|by path]]'
sb backlinks "$P/docs/LOUD.MD"
out_is "capitals: the link reader counts a .MD file as a note" \
  "$P/docs/quiet.md:1: [[LOUD]]${NL}$P/docs/quiet.md:1: [[projects/example/docs/LOUD.MD|by path]]"
sb search Example qloud
out_is "capitals: search reads it too" "$P/docs/LOUD.MD:6: the word qloud is here"
sb find "loud note"
out_is "capitals: find reads its aliases" "$P/docs/LOUD.MD"
sb find "root loud"
out_is "capitals: find reads the aliases of such a note at the vault root" "ROOTLOUD.MD"
sb snapshot capitals
is "capitals: the snapshot lists its aliases" "$(grep 'LOUD' "$vault/.second-brain/snapshots/capitals/aliases.txt" | tr '\t' '|')" \
  "Loud Note|$P/docs/LOUD.MD${NL}Root Loud|ROOTLOUD.MD"

# ---------------------------------------------------------------- a file system that ignores letter case
# Windows and macOS find a file whatever the letter case of its path; Linux does not.
note "ci/Mixed Case.md" '# Mixed'
note "ci/sub/deep.md" '# Deep'
note "ci/linker.md" '[[ci/Mixed Case]] and [[Mixed Case|shown]]' '[[ci/sub/deep]]'
if [ -e "$vault/CI/mixed case.md" ]; then
  sb backlinks "CI/MIXED CASE.md"
  out_is "ignoring case: the backlinks of a note named in another letter case" \
    "ci/linker.md:1: [[ci/Mixed Case]]${NL}ci/linker.md:1: [[Mixed Case|shown]]"
  sb outline "CI/mixed case.md"
  out_is "ignoring case: the outline of a note named in another letter case" "1: # Mixed"
  sb move "CI/mixed case.md" ci/shifted.md
  rc_is "ignoring case: a note named in another letter case is moved" 0
  out_is "ignoring case: the move is reported and its links counted" "moved: CI/mixed case.md -> ci/shifted.md${NL}links: ci/linker.md | 2"
  is "ignoring case: the folder holds the note under its new name alone" "$(LC_ALL=C ls "$vault/ci" | tr '\n' ' ')" "linker.md shifted.md sub "
  is "ignoring case: the links follow the note" "$(line ci/linker.md 1)" '[[ci/shifted]] and [[shifted|shown]]'
  sb rename ci/shifted.md SHIFTED
  rc_is "ignoring case: a rename that changes only the letter case gives exit 6" 6
  is "ignoring case: the note keeps its name" "$(LC_ALL=C ls "$vault/ci" | tr '\n' ' ')" "linker.md shifted.md sub "
  sb move ci/linker.md CI/Shifted.md
  rc_is "ignoring case: a destination that exists in another letter case gives exit 6" 6
  sb move CI/SUB ci/under
  rc_is "ignoring case: a folder named in another letter case is moved" 0
  out_is "ignoring case: the folder move is reported and its links counted" "moved: CI/SUB -> ci/under${NL}links: ci/linker.md | 1"
  exists "ignoring case: the folder's note is at its new place" "$vault/ci/under/deep.md"
  is "ignoring case: the link into the folder follows" "$(line ci/linker.md 2)" '[[ci/under/deep]]'
  sb unresolved
  is "ignoring case: none of these links is left unresolved" "$(printf '%s\n' "$OUT" | grep -c '^ci/' || true)" "0"
else
  sb move "CI/mixed case.md" ci/shifted.md
  rc_is "minding case: a note named in another letter case is not found, exit 1" 1
  sb backlinks "CI/MIXED CASE.md"
  rc_is "minding case: nor are its backlinks, exit 1" 1
  exists "minding case: the note is where it was" "$vault/ci/Mixed Case.md"
fi

# ---------------------------------------------------------------- vault paths on Windows
# There a backslash separates folders and a drive letter opens an absolute path: neither is a vault path.
if sb_is_windows; then
  tree >"$tmp/tree.before"
  sb outline 'mv\crlf.md'
  rc_is "Windows: outline refuses a path written with backslashes, exit 5" 5
  err_has "Windows: the message asks for forward slashes" "with forward slashes"
  sb backlinks 'mv\crlf.md'
  rc_is "Windows: backlinks refuses a path written with backslashes" 5
  sb move 'mv\solo.md' mv/there.md
  rc_is "Windows: move refuses a source written with backslashes" 5
  sb move mv/solo.md 'mv\..\..\outside.md'
  rc_is "Windows: move refuses a destination that leaves the vault by backslashes" 5
  absent "Windows: nothing is written outside the vault" "$tmp/outside.md"
  sb move mv/solo.md 'mv\.hidden\solo.md'
  rc_is "Windows: move refuses a destination that enters a dot folder by backslashes" 5
  sb rename mv/solo.md 'a\b'
  rc_is "Windows: rename refuses a name that holds a backslash" 5
  sb outline "$(cygpath -m "$vault/mv/solo.md")"
  rc_is "Windows: a path in the drive form is not a vault path, exit 5" 5
  tree >"$tmp/tree.after"
  same "Windows: the refusals leave the vault byte-identical" "$tmp/tree.before" "$tmp/tree.after"
fi

# ---------------------------------------------------------------- result
printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
