#!/usr/bin/env bash
# Scratch-vault tests for the links between notes: outline, backlinks, unresolved, move and rename.
# Usage: bash scripts/test-graph.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
SB="$here/bin/second-brain"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-graph-test.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

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
out_has "rename: digits after a dot are not an extension, so .md is kept" "moved: mv/dst/beta.md -> mv/dst/final v1.2 draft.md"
sb rename "mv/dst/final v1.2 draft.md" alpha
out_has "rename: back to the first name" "moved: mv/dst/final v1.2 draft.md -> mv/dst/alpha.md"
is "rename: .md stays where a link had it, through every rename" "$(line mv/linkers.md 4)" \
  '[[mv/dst/alpha]] bare, [[mv/dst/alpha#Part|shown]], ![[mv/dst/alpha]], [[mv/dst/alpha.md]], [[mv/dst/alpha]], [[mv/dst/alpha.md#^b1|x]]'
note "mv/ext.md" '# A note that becomes a text file'
note "mv/ext-reader.md" '[[mv/ext|Ext]] and [[ext]]'
sb rename mv/ext.md ext.txt
out_is "rename: a name with an extension keeps its own" "moved: mv/ext.md -> mv/ext.txt${NL}links: mv/ext-reader.md | 2"
is "rename: links to a file that is no longer a note carry its extension" "$(line mv/ext-reader.md 1)" '[[mv/ext.txt|Ext]] and [[ext.txt]]'
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
err_has "move: says why" "is a project of the index"
sb move "$P" projects/renamed --dry-run
rc_is "move --dry-run: the same refusal" 5
sb move projects archive
rc_is "move: a folder that holds a project gives exit 5" 5
sb move . elsewhere
rc_is "move: the vault root gives exit 5" 5
sb rename "$P" renamed
rc_is "rename: an index project's folder gives exit 5" 5
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
tree >"$tmp/tree.after"
same "move: the refusals, and the folder moved there and back, leave the vault byte-identical" "$tmp/tree.before" "$tmp/tree.after"

# ---------------------------------------------------------------- result
printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
