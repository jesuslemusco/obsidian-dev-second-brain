#!/usr/bin/env bash
# Area board: board, topic, find and search.
# Usage: bash scripts/test.sh board, or bash scripts/tests/board.sh
. "$(dirname "$0")/lib.sh"

# The tasks as tasks.sh leaves them.
fixture_tasks

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

# ---------------------------------------------------------------- result
result
