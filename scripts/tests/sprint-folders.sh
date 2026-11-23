#!/usr/bin/env bash
# Area sprint-folders: the sprint layout, and the tasks found in backlog/ and the sprint folders.
# Usage: bash scripts/test.sh sprint-folders, or bash scripts/tests/sprint-folders.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault
B="work/board"
BT="$vault/$B/tasks"
BP="$vault/$B/claude/profile.md"
sb scaffold project Board --path "$B" --keys BRD

# layout_of: the task layout the helper reads from the profile of Board.
layout_of() { (SB_ROOT="$vault" SB_P_PATH="$B" sb_task_layout); }

# ---------------------------------------------------------------- the sprint layout
line_is "layout: a new profile uses sprints" "$BP" "uses_sprints: true"
edit "$BP" 's/^task_layout: flat$/task_layout: Sprint/'
is "layout: task_layout: Sprint, in any letter case, reads as sprint" "$(layout_of)" "sprint"
edit "$BP" 's/^task_layout: Sprint$/task_layout: SPRINT/'
edit "$BP" '/^uses_sprints: /d'
is "layout: sprint with no uses_sprints key reads as sprint" "$(layout_of)" "sprint"
edit "$BP" 's/^task_layout: SPRINT$/task_layout: sprint\
uses_sprints: False/'
is "layout: sprint with uses_sprints: false, in any letter case, reads as flat" "$(layout_of)" "flat"
edit "$BP" 's/^task_layout: sprint$/task_layout: status/'
is "layout: sprints off leave the status layout as it is" "$(layout_of)" "status"
edit "$BP" 's/^uses_sprints: False$/uses_sprints: true/'
for l in sprint archive status flat; do
  edit "$BP" "s/^task_layout: .*\$/task_layout: $l/"
  is "layout: $l with sprints on reads as $l" "$(layout_of)" "$l"
done

# ---------------------------------------------------------------- the group folders
# A folder directly in a tasks folder holds tasks when it has no README of its own; with one it is
# a task. backlog and the five status folders hold tasks with a README too, as no task takes their
# names. archive keeps its own rule and is no group folder.
G="$tmp/groups"
mkdir -p "$G/sprint-12" "$G/done" "$G/2026-12-04" "$G/backlog" "$G/planned" "$G/archive/2026" \
  "$G/BRD-9" "$G/Zeta"
printf '# BRD-9\n' >"$G/BRD-9/README.md"
printf '# Done\n' >"$G/done/README.md"
printf '# Backlog\n' >"$G/backlog/README.md"
printf 'not a folder\n' >"$G/in-review"
is "groups: the status folders in their order, backlog, then the others sorted" "$(sb_task_groups "$G")" "$G/planned
$G/done
$G/backlog
$G/2026-12-04
$G/Zeta
$G/sprint-12"
mkdir -p "$tmp/no-groups"
is "groups: none in a tasks folder with no folder" "$(sb_task_groups "$tmp/no-groups")" ""
is "groups: none in a tasks folder that is not there" "$(sb_task_groups "$tmp/not-there")" ""

# ---------------------------------------------------------------- the lookup in a flat project
# The tasks are written while the project is flat, then moved by hand into backlog/ and two sprint
# folders. Their aliases lose the id, so find reaches them by their folder, not by the aliases.
edit "$BP" 's/^task_layout: .*$/task_layout: flat/'
for t in BRD-1 BRD-2 BRD-3 BRD-4 BRD-5 BRD-6 BRD-7 BRD-8; do
  sb task new "$t" --project Board --title "Board $t"
done
mkdir -p "$BT/backlog" "$BT/2026-12-04" "$BT/sprint-12" "$BT/archive"
groups="backlog 2026-12-04 sprint-12"
i=0
for g in $groups; do
  i=$((i + 1))
  edit "$BT/BRD-$i/README.md" "/^  - BRD-$i\$/d"
  mv "$BT/BRD-$i" "$BT/$g/BRD-$i"
done
# A README inside a task is no task, in a sprint folder or at the root.
mv "$BT/BRD-7" "$BT/sprint-12/BRD-3/notes"
mv "$BT/BRD-8" "$BT/BRD-5/notes"
# A task directly in archive/ is no task: the archive holds archive/<YYYY>/<ID>/ alone.
edit "$BT/BRD-6/README.md" "/^  - BRD-6\$/d"
mv "$BT/BRD-6" "$BT/archive/BRD-6"
i=0
for g in $groups; do
  i=$((i + 1))
  sb find "BRD-$i"
  out_is "lookup: find sees a task in $g/ of a flat project" "$B/tasks/$g/BRD-$i/README.md"
  sb task head "BRD-$i"
  out_has "lookup: task head reads a task in $g/ of a flat project" "path: $B/tasks/$g/BRD-$i/README.md"
done
sb board Board All
i=0
for g in $groups; do
  i=$((i + 1))
  out_has "lookup: the board of a flat project lists the task in $g/" "BRD-$i | Board BRD-$i | planned |"
done
out_has "lookup: the board lists a task at the root too" "BRD-4 | Board BRD-4 | planned |"
out_lacks "lookup: no task inside a task in a sprint folder, sprint-12/BRD-3/notes/" "Board BRD-7"
out_lacks "lookup: no task inside a task at the root, BRD-5/notes/" "Board BRD-8"
out_lacks "lookup: no task directly in archive/" "Board BRD-6"
is "lookup: the board has a row for each task and none more" "$(lines "$OUT")" "5"
sb find BRD-6 --project Board
rc_is "lookup: find sees no task directly in archive/, exit 1" 1
sb task head BRD-6
rc_is "lookup: task head reads no task directly in archive/, exit 1" 1
sb find sprint-12 --project Board
rc_is "lookup: a sprint folder is no task, exit 1" 1
# backlog/ with a README of its own still holds tasks, and its README is no task.
printf '# Backlog hub\n\nThe tasks of no sprint.\n' >"$BT/backlog/README.md"
sb board Board All
is "lookup: a README in backlog/ leaves the board a row for each task" "$(lines "$OUT")" "5"
out_lacks "lookup: the board has no row for the README of backlog/" "Backlog hub"
sb task head backlog --project Board
rc_is "lookup: the README of backlog/ is no task, exit 1" 1
sb find BRD-1
out_is "lookup: find still sees the task in backlog/ with a README there" "$B/tasks/backlog/BRD-1/README.md"
rm "$BT/backlog/README.md"
sb task tag BRD-3 add stacking
sb topic Board stacking
out_is "lookup: topic lists a tagged task in a sprint folder" "$B/tasks/sprint-12/BRD-3/README.md"
for l in archive status sprint; do
  edit "$BP" "s/^task_layout: .*\$/task_layout: $l/"
  i=0
  for g in $groups; do
    i=$((i + 1))
    sb find "BRD-$i"
    out_is "lookup: find sees a task in $g/ of a $l project too" "$B/tasks/$g/BRD-$i/README.md"
  done
done
mkdir -p "$BT/2026-12-04/BRD-1"
cp "$BT/backlog/BRD-1/README.md" "$BT/2026-12-04/BRD-1/README.md"
sb task head BRD-1
rc_is "lookup: the same id in backlog/ and a sprint folder is ambiguous, exit 4" 4
rm -r "$BT/2026-12-04/BRD-1"

# ---------------------------------------------------------------- backlog refused
# backlog, in any letter case, is no task id and no alias in any layout, as archive and the five
# status names are not. The message names the backlog folder, lowercased.
board_tree() { find "$vault/$B" | sort; find "$vault/$B" -type f -exec cksum {} + | sort; }
for layout in flat archive status sprint; do
  edit "$BP" "s/^task_layout: .*\$/task_layout: $layout/"
  board_tree >"$tmp/board.before"
  sb task new Backlog --project Board
  rc_is "backlog refused: task new Backlog gives exit 5 ($layout)" 5
  err_has "backlog refused: the task id message names the backlog folder ($layout)" \
    "backlog is the folder of the backlog tasks, not a task id"
  for n in backlog BACKLOG bAcKlOg; do
    sb task new "$n" --project Board
    rc_is "backlog refused: task new $n gives exit 5 ($layout)" 5
  done
  sb task alias BRD-1 add backlog
  rc_is "backlog refused: task alias BRD-1 add backlog gives exit 5 ($layout)" 5
  err_has "backlog refused: the alias message names the backlog folder ($layout)" \
    "backlog is the folder of the backlog tasks, not a task alias"
  for n in Backlog BACKLOG; do
    sb task alias BRD-4 add "$n"
    rc_is "backlog refused: task alias BRD-4 add $n gives exit 5 ($layout)" 5
  done
  board_tree >"$tmp/board.after"
  is "backlog refused: nothing written ($layout)" \
    "$(cmp -s "$tmp/board.before" "$tmp/board.after" && printf same)" "same"
done
sb task new Backlog
rc_is "backlog refused: task new Backlog, with no project, gives exit 5" 5
err_has "backlog refused: it is refused before the project is looked for" \
  "backlog is the folder of the backlog tasks, not a task id"

# ---------------------------------------------------------------- task new: the sprint layout
# In a sprint project a new task starts in backlog/, with sprints on or with no uses_sprints key;
# with uses_sprints: false the project is flat, and the task is at the tasks root.
J="work/join"
JT="$vault/$J/tasks"
JP="$vault/$J/claude/profile.md"
sb scaffold project Join --path "$J" --keys JN
edit "$JP" 's/^task_layout: flat$/task_layout: Sprint/'
sb task new JN-1 --project Join --title "Join JN-1"
rc_is "task new: a sprint project, exit 0" 0
out_is "task new: task_layout: Sprint, in any letter case, writes the task in backlog/" \
  "$J/tasks/backlog/JN-1/README.md"
exists "task new: the README is in backlog/" "$JT/backlog/JN-1/README.md"
absent "task new: no folder at the root of the tasks" "$JT/JN-1"
line_is "task new: the up link of a task in backlog/ leads to the tasks hub" "$JT/backlog/JN-1/README.md" \
  "> Up: [[$J/tasks/README|Join Tasks Hub]]"
line_is "task new: the task in backlog/ is planned" "$JT/backlog/JN-1/README.md" "status: planned"
edit "$JP" '/^uses_sprints: /d'
sb task new JN-2 --project Join --title "Join JN-2"
rc_is "task new: sprint with no uses_sprints key, exit 0" 0
out_is "task new: sprint with no uses_sprints key writes the task in backlog/" \
  "$J/tasks/backlog/JN-2/README.md"
edit "$JP" 's/^task_layout: Sprint$/task_layout: sprint\
uses_sprints: false/'
sb task new JN-9 --project Join --title "Join JN-9"
rc_is "task new: sprint with uses_sprints: false, exit 0" 0
out_is "task new: sprint with uses_sprints: false writes the task at the tasks root" "$J/tasks/JN-9/README.md"
absent "task new: and nothing in backlog/ for it" "$JT/backlog/JN-9"
edit "$JP" 's/^uses_sprints: false$/uses_sprints: true/'
for t in JN-3 JN-4 JN-5 JN-6; do sb task new "$t" --project Join --title "Join $t"; done
exists "task new: the later tasks are in backlog/ too" "$JT/backlog/JN-6/README.md"

# ---------------------------------------------------------------- join and leave a sprint
# task set sprint=<id> moves the task to the folder of that sprint through move, so a link to it
# follows; sprint= takes it back to backlog/. With no sprint_folder key a sprint's folder is its id.
join_tree() { find "$vault/$J" | sort; find "$vault/$J" -type f -exec cksum {} + | sort; }
printf '# Links\n\nSee [[%s|JN-1]].\n' "$J/tasks/backlog/JN-1/README" >"$vault/$J/links.md"
sb task set JN-1 sprint=2026-12-04
rc_is "join: task set sprint=<id>, exit 0" 0
out_is "join: the key, then the new path in the sprint's folder and the notes whose links it rewrote" \
  "sprint: 2026-12-04
$J/tasks/2026-12-04/JN-1/README.md
links: $J/links.md | 1"
exists "join: with no sprint_folder key the sprint's folder is its id" "$JT/2026-12-04/JN-1/README.md"
absent "join: the task's folder in backlog/ is gone" "$JT/backlog/JN-1"
line_is "join: the sprint key is written" "$JT/2026-12-04/JN-1/README.md" 'sprint: "2026-12-04"'
line_is "join: the link now leads into the sprint's folder" "$vault/$J/links.md" \
  "See [[$J/tasks/2026-12-04/JN-1/README|JN-1]]."
sb unresolved Join
rc_is "join: unresolved runs after the move, exit 0" 0
out_is "join: unresolved lists nothing after the move" ""
sb task set JN-1 sprint=2026-12-18
rc_is "join: another sprint, exit 0" 0
out_is "join: another sprint moves the task to that sprint's folder" "sprint: 2026-12-18
$J/tasks/2026-12-18/JN-1/README.md
links: $J/links.md | 1"
absent "join: it leaves the folder of the sprint before" "$JT/2026-12-04/JN-1"
sb task set JN-1 sprint=
rc_is "leave: task set sprint=, exit 0" 0
out_is "leave: the removed key, then the path in backlog/ and the links: line" "sprint: (removed)
$J/tasks/backlog/JN-1/README.md
links: $J/links.md | 1"
exists "leave: the task is back in backlog/" "$JT/backlog/JN-1/README.md"
absent "leave: and no longer in the sprint's folder" "$JT/2026-12-18/JN-1"
line_is "leave: the link followed it back" "$vault/$J/links.md" "See [[$J/tasks/backlog/JN-1/README|JN-1]]."
exists "leave: the sprint folder it leaves empty stays" "$JT/2026-12-18"
cp "$JT/backlog/JN-1/README.md" "$tmp/JN-1.before"
sb task set JN-1 sprint=
rc_is "leave: no sprint again, exit 0" 0
out_is "leave: no sprint again prints no change" "no change"
is "leave: no sprint again moves and writes nothing" \
  "$(cmp -s "$tmp/JN-1.before" "$JT/backlog/JN-1/README.md" && printf same)" "same"
sb task set JN-1 sprint=2026-12-18 sprint=2026-12-04
rc_is "join: two sprint pairs, exit 0" 0
out_has "join: the last sprint pair wins" "sprint: 2026-12-04
$J/tasks/2026-12-04/JN-1/README.md
links: $J/links.md | 1"
absent "join: so the task is in no folder of the first" "$JT/2026-12-18/JN-1"
cp "$JT/2026-12-04/JN-1/README.md" "$tmp/JN-1.before"
sb task set JN-1 sprint=2026-12-04
out_is "join: the same sprint prints no change" "no change"
is "join: the same sprint moves and writes nothing" \
  "$(cmp -s "$tmp/JN-1.before" "$JT/2026-12-04/JN-1/README.md" && printf same)" "same"
# A status change in a sprint project moves nothing.
sb task set JN-1 status=done
rc_is "status: a status change in a sprint project, exit 0" 0
out_is "status: it prints the keys and no new path" "status: done
tags: status/done"
exists "status: the task stays in its sprint's folder" "$JT/2026-12-04/JN-1/README.md"
absent "status: no status folder is made" "$JT/done"
sb task set JN-1 status=planned
exists "status: back to planned, it stays in its sprint's folder" "$JT/2026-12-04/JN-1/README.md"
# A task already in the folder of its new sprint is not in its own way: only the key is written.
mv "$JT/backlog/JN-3" "$JT/2026-12-04/JN-3"
sb task set JN-3 sprint=2026-12-04
rc_is "join: a task already in the folder of its new sprint, exit 0" 0
out_is "join: its own folder is not in the way, and nothing moves" "sprint: 2026-12-04"
exists "join: it stays in the sprint's folder" "$JT/2026-12-04/JN-3/README.md"
sb task set JN-3 sprint=
out_has "leave: it goes back to backlog/" "$J/tasks/backlog/JN-3/README.md"
# Anything at the destination, an empty folder, a file or a link, gives exit 6 with nothing written.
cp "$JT/backlog/JN-4/README.md" "$tmp/JN-4.before"
mkdir -p "$JT/2026-12-04/JN-4"
join_tree >"$tmp/join.before"
sb task set JN-4 sprint=2026-12-04 next="Ship it"
rc_is "taken: an empty folder at the destination gives exit 6" 6
err_has "taken: the message names the destination" "the destination exists: $J/tasks/2026-12-04/JN-4"
is "taken: the task's sprint key is unchanged, and no key is written" \
  "$(cmp -s "$tmp/JN-4.before" "$JT/backlog/JN-4/README.md" && printf same)" "same"
join_tree >"$tmp/join.after"
is "taken: nothing written in the project" "$(cmp -s "$tmp/join.before" "$tmp/join.after" && printf same)" "same"
rmdir "$JT/2026-12-04/JN-4"
printf 'x\n' >"$JT/2026-12-04/JN-4"
sb task set JN-4 sprint=2026-12-04
rc_is "taken: a file at the destination gives exit 6" 6
is "taken: no key is written for a file" \
  "$(cmp -s "$tmp/JN-4.before" "$JT/backlog/JN-4/README.md" && printf same)" "same"
rm "$JT/2026-12-04/JN-4"
if ! sb_is_windows; then
  ln -s "$tmp/nowhere" "$JT/2026-12-04/JN-4"
  sb task set JN-4 sprint=2026-12-04
  rc_is "taken: a link at the destination, even a dead one, gives exit 6" 6
  is "taken: no key is written for a link" \
    "$(cmp -s "$tmp/JN-4.before" "$JT/backlog/JN-4/README.md" && printf same)" "same"
  rm "$JT/2026-12-04/JN-4"
fi
cp "$JT/2026-12-04/JN-1/README.md" "$tmp/JN-1.before"
mkdir -p "$JT/backlog/JN-1"
sb task set JN-1 sprint=
rc_is "taken: a folder in backlog/ in the way of leaving gives exit 6" 6
err_has "taken: the message names the backlog destination" "the destination exists: $J/tasks/backlog/JN-1"
line_is "taken: the task keeps its sprint" "$JT/2026-12-04/JN-1/README.md" 'sprint: "2026-12-04"'
is "taken: nothing is written for it" \
  "$(cmp -s "$tmp/JN-1.before" "$JT/2026-12-04/JN-1/README.md" && printf same)" "same"
rmdir "$JT/backlog/JN-1"

# ---------------------------------------------------------------- the sprint folder pattern
# sprint_folder names a sprint's folder: <end> is its id, <start> its first day, from its note or
# counted back from its id, and <n> one more than the count of the sprint notes with an earlier id.
# Three sprint notes; the second starts off the cadence, and the first has no start.
SN="$vault/$J/sprints"
printf -- '---\ntype: sprint\nsprint: "2026-10-23"\nstatus: done\n---\n\n# Join Sprint 2026-10-23\n' \
  >"$SN/2026-10-23.md"
printf -- '---\ntype: sprint\nsprint: "2026-11-06"\nstart: 2026-10-24\nend: 2026-11-06\nstatus: done\n---\n' \
  >"$SN/2026-11-06.md"
printf -- '---\ntype: sprint\nsprint: "2026-11-20"\nstart: 2026-11-09\nend: 2026-11-20\nstatus: done\n---\n' \
  >"$SN/2026-11-20.md"
# pattern_is [<pattern>]: Join's profile has the sprint_folder key with that pattern, or none.
pattern_is() {
  awk '!/^sprint_folder:/ { print } /^task_layout:/ && ENVIRON["SB_PAT_SET"] == 1 {
      print "sprint_folder: \"" ENVIRON["SB_PAT"] "\"" }' "$JP" >"$tmp/edit.tmp" &&
    cat "$tmp/edit.tmp" >"$JP"
}
set_pattern() { SB_PAT_SET=1 SB_PAT="$1" pattern_is; }
# joins <desc> <sprint id> <folder>: task set JN-5 sprint=<id> moves JN-5 into <folder>/, and
# sprint= takes it back to backlog/.
joins() {
  sb task set JN-5 sprint="$2"
  rc_is "pattern: $1, exit 0" 0
  out_has "pattern: $1, gives the folder $3/" "$J/tasks/$3/JN-5/README.md"
  exists "pattern: $1, the task is in $3/" "$JT/$3/JN-5/README.md"
  sb task set JN-5 sprint=
  exists "pattern: $1, then back in backlog/" "$JT/backlog/JN-5/README.md"
}
SB_PAT_SET=0 pattern_is
joins "no sprint_folder key" 2026-12-04 2026-12-04
# An empty sprint_folder key reads as no key, as every profile key with an empty value does.
set_pattern ""
line_is "pattern: the empty key is in the profile" "$JP" 'sprint_folder: ""'
joins "an empty sprint_folder key, as no key" 2026-12-04 2026-12-04
edit "$JP" 's/^sprint_folder: ""$/sprint_folder:/'
line_is "pattern: the bare key is in the profile" "$JP" 'sprint_folder:'
joins "a sprint_folder key with no value, as no key" 2026-12-04 2026-12-04
set_pattern "<end>"
line_is "pattern: the key is in the profile" "$JP" 'sprint_folder: "<end>"'
joins "<end>" 2026-12-04 2026-12-04
set_pattern "sprint-<n>"
joins "<n> of a sprint with no note, after three notes" 2026-12-04 sprint-4
joins "<n> of the second note" 2026-11-06 sprint-2
joins "<n> of the first note" 2026-10-23 sprint-1
set_pattern "<start>"
joins "<start> of a sprint with no note, its id less 13 days" 2026-12-04 2026-11-21
joins "<start> of a note, its start key" 2026-11-20 2026-11-09
edit "$JP" 's/^sprint_length_days: 14$/sprint_length_days: 7/'
joins "<start> with sprint_length_days: 7, its id less 6 days" 2026-12-04 2026-11-28
edit "$JP" 's/^sprint_length_days: 7$/sprint_length_days: 14/'
set_pattern "s<n>_<start>.<end>"
joins "all three placeholders" 2026-12-04 s4_2026-11-21.2026-12-04
# A sprint with no note shares <n> with the next one that gets a note: the same folder, and the
# task in it is not in its own way.
set_pattern "sprint-<n>"
sb task set JN-5 sprint=2026-12-04
out_has "pattern: <n> of a sprint with no note" "$J/tasks/sprint-4/JN-5/README.md"
sb task set JN-5 sprint=2026-12-18
rc_is "pattern: a later sprint with no note shares <n>, exit 0" 0
out_is "pattern: so the task stays in the same folder" "sprint: 2026-12-18"
exists "pattern: it is still in sprint-4/" "$JT/sprint-4/JN-5/README.md"
sb task set JN-5 sprint=
exists "pattern: and back in backlog/ after" "$JT/backlog/JN-5/README.md"
# A sprint folder whose name is a task's folder, one with a README.md, gives exit 6: here a task
# sprint-4 at the tasks root, in the folder JN-5 left empty.
mkdir -p "$JT/sprint-4"
sed 's/^  - JN-6$/  - sprint-4/' "$JT/backlog/JN-6/README.md" >"$JT/sprint-4/README.md"
join_tree >"$tmp/join.before"
sb task set JN-5 sprint=2026-12-04
rc_is "pattern: a sprint folder that is a task gives exit 6" 6
err_has "pattern: the message names the task in the way" "the sprint folder is a task: $J/tasks/sprint-4"
join_tree >"$tmp/join.after"
is "pattern: nothing written for a sprint folder that is a task" \
  "$(cmp -s "$tmp/join.before" "$tmp/join.after" && printf same)" "same"
rm -r "$JT/sprint-4"
# Each pattern that gives no folder name, or has no placeholder, exits 5 naming it, with nothing
# written. 2026-10-23 has a note with no start, so its <start> is empty.
bad_pattern() { # bad_pattern <desc> <pattern> <sprint id>
  set_pattern "$2"
  join_tree >"$tmp/join.before"
  sb task set JN-5 sprint="$3" next="Not written"
  rc_is "invalid pattern: $1 gives exit 5" 5
  err_has "invalid pattern: $1, the message names the pattern" "sprint_folder pattern \"$2\""
  join_tree >"$tmp/join.after"
  is "invalid pattern: $1, nothing written" "$(cmp -s "$tmp/join.before" "$tmp/join.after" && printf same)" "same"
}
bad_pattern "no placeholder" "sprint" 2026-12-04
bad_pattern "a reserved name with no placeholder" "Backlog" 2026-12-04
bad_pattern "an unknown placeholder alone" "<N>" 2026-12-04
bad_pattern "an unknown placeholder with <n>" "<sprint>-<n>" 2026-12-04
bad_pattern "a space" "sprint <n>" 2026-12-04
bad_pattern "a slash" "sprints/<n>" 2026-12-04
bad_pattern "a character outside the set" "sprint:<n>" 2026-12-04
bad_pattern "a dot first" ".<end>" 2026-12-04
bad_pattern "a hyphen first" "-<end>" 2026-12-04
bad_pattern "an empty name, the <start> of a note with none" "<start>" 2026-10-23
bad_pattern "a name that is backlog" "BACKLOG<start>" 2026-10-23
bad_pattern "a name that is archive" "archive<start>" 2026-10-23
bad_pattern "a name that is a status" "In-Progress<start>" 2026-10-23
err_has "invalid pattern: the message names the name it gives" '"In-Progress"'
SB_PAT_SET=0 pattern_is
exists "invalid pattern: the task is still in backlog/" "$JT/backlog/JN-5/README.md"

# ---------------------------------------------------------------- sprint close: the sprint layout
# At close a done or abandoned task, and one named in --abandon, stays in the closed sprint's
# folder; each --carry task moves to the next sprint's folder and each --backlog task to backlog/,
# through move, once the sprint note is written, so the note's links follow. Every destination is
# looked at before anything is written.
C="work/close"
CT="$vault/$C/tasks"
CP="$vault/$C/claude/profile.md"
CS="$vault/$C/sprints/2026-10-14.md"
sb scaffold project Close --path "$C" --keys CL
edit "$CP" 's/^task_layout: flat$/task_layout: sprint/'
sb sprint open Close --end 2026-10-14
for t in CL-1 CL-2 CL-3 CL-4; do
  sb task new "$t" --project Close --title "Close $t"
  sb task set "$t" sprint=2026-10-14
done
sb task set CL-1 status=done
exists "close: the four tasks are in the folder of their sprint" "$CT/2026-10-14/CL-4/README.md"
printf '# Close links\n\nSee [[%s|CL-2]] and [[%s|CL-3]].\n' "$C/tasks/2026-10-14/CL-2/README" \
  "$C/tasks/2026-10-14/CL-3/README" >"$vault/$C/links.md"
close_tree() { find "$vault/$C" | sort; find "$vault/$C" -type f -exec cksum {} + | sort; }
# close_refused <desc> <code>: sprint close of the four tasks exits <code>, and writes nothing.
close_refused() {
  close_tree >"$tmp/close.before"
  sb sprint close Close --carry CL-2 --backlog CL-3 --abandon CL-4
  rc_is "close refused: $1 gives exit $2" "$2"
  close_tree >"$tmp/close.after"
  is "close refused: $1, no task and no sprint note written" \
    "$(cmp -s "$tmp/close.before" "$tmp/close.after" && printf same)" "same"
}
mkdir -p "$CT/2026-10-28/CL-2"
close_refused "an empty folder where the carried task would go" 6
err_has "close refused: the message names the folder in the next sprint's folder" \
  "the destination exists: $C/tasks/2026-10-28/CL-2"
rm -r "$CT/2026-10-28"
mkdir -p "$CT/backlog/CL-3"
close_refused "an empty folder where the backlog task would go" 6
err_has "close refused: the message names the folder in backlog/" "the destination exists: $C/tasks/backlog/CL-3"
rmdir "$CT/backlog/CL-3"
# The next sprint's folder is a task, 2026-10-28 at the tasks root, of no sprint.
mkdir -p "$CT/2026-10-28"
sed -e 's/^  - CL-4$/  - 2026-10-28/' -e '/^sprint: /d' "$CT/2026-10-14/CL-4/README.md" >"$CT/2026-10-28/README.md"
close_refused "a next sprint's folder that is a task" 6
err_has "close refused: the message names the task in the way" "the sprint folder is a task: $C/tasks/2026-10-28"
rm -r "$CT/2026-10-28"
edit "$CP" 's/^task_layout: sprint$/task_layout: sprint\
sprint_folder: "sprint"/'
close_refused "a sprint_folder pattern with no placeholder" 5
err_has "close refused: the message names the pattern" 'sprint_folder pattern "sprint"'
edit "$CP" '/^sprint_folder: /d'
sb sprint close Close --carry CL-2 --backlog CL-3 --abandon CL-4
rc_is "close: --carry, --backlog and --abandon in a sprint project, exit 0" 0
out_is "close: the six summary lines, then each moved task's path and links: lines" "sprint: 2026-10-14
done: CL-1
carried: CL-2
backlog: CL-3
abandoned: CL-4
next: 2026-10-28
$C/tasks/2026-10-28/CL-2/README.md
links: $C/links.md | 1
links: $C/sprints/2026-10-14.md | 1
$C/tasks/backlog/CL-3/README.md
links: $C/links.md | 1
links: $C/sprints/2026-10-14.md | 1"
exists "close: the done task stays in the closed sprint's folder" "$CT/2026-10-14/CL-1/README.md"
exists "close: the --abandon task stays in the closed sprint's folder" "$CT/2026-10-14/CL-4/README.md"
line_is "close: and it is abandoned" "$CT/2026-10-14/CL-4/README.md" "status: abandoned"
exists "close: the carried task is in the next sprint's folder" "$CT/2026-10-28/CL-2/README.md"
absent "close: and no longer in the closed sprint's folder" "$CT/2026-10-14/CL-2"
line_is "close: the carried task's sprint is the next" "$CT/2026-10-28/CL-2/README.md" 'sprint: "2026-10-28"'
is "close: carried_from names the closed sprint" \
  "$(SB_ROOT="$vault"; sb_fm_list "$CT/2026-10-28/CL-2/README.md" carried_from)" "2026-10-14"
exists "close: the backlog task is in backlog/" "$CT/backlog/CL-3/README.md"
absent "close: and no longer in the closed sprint's folder" "$CT/2026-10-14/CL-3"
file_lacks "close: the backlog task has no sprint" "$CT/backlog/CL-3/README.md" "sprint:"
line_is "close: the sprint note lists the done task" "$CS" "- [[$C/tasks/2026-10-14/CL-1/README|CL-1]] - Close CL-1"
line_is "close: its link to the carried task leads to its new path" "$CS" \
  "- [[$C/tasks/2026-10-28/CL-2/README|CL-2]] - Close CL-2"
line_is "close: its link to the backlog task leads into backlog/" "$CS" \
  "- [[$C/tasks/backlog/CL-3/README|CL-3]] - Close CL-3"
line_is "close: it lists the abandoned task" "$CS" "- [[$C/tasks/2026-10-14/CL-4/README|CL-4]] - Close CL-4"
line_is "close: the counts are as before" "$CS" "Counts: done 1, carried over 1, backlog 1, abandoned 1."
line_is "close: another note's links follow too" "$vault/$C/links.md" \
  "See [[$C/tasks/2026-10-28/CL-2/README|CL-2]] and [[$C/tasks/backlog/CL-3/README|CL-3]]."
sb unresolved Close
rc_is "close: unresolved runs after the moves, exit 0" 0
out_is "close: unresolved names none of the four tasks" ""
# A task already where it would go is not in its own way and moves nothing: CL-5 is in the next
# sprint's folder by hand, and CL-6 in backlog/. CL-2 is carried from the sprint before.
sb sprint open Close
for t in CL-5 CL-6; do
  sb task new "$t" --project Close --title "Close $t"
  sb task set "$t" sprint=2026-10-28
done
mkdir -p "$CT/2026-11-11"
mv "$CT/2026-10-28/CL-5" "$CT/2026-11-11/CL-5"
mv "$CT/2026-10-28/CL-6" "$CT/backlog/CL-6"
sb sprint close Close --carry CL-5 --backlog CL-2,CL-6
rc_is "close: tasks already where they go, exit 0" 0
out_is "close: only the task that is not where it goes moves" "sprint: 2026-10-28
done: -
carried: CL-5
backlog: CL-6, CL-2
abandoned: -
next: 2026-11-11
$C/tasks/backlog/CL-2/README.md
links: $C/links.md | 1
links: $C/sprints/2026-10-14.md | 1
links: $C/sprints/2026-10-28.md | 1"
exists "close: the carried task already in the next sprint's folder stays" "$CT/2026-11-11/CL-5/README.md"
line_is "close: and its sprint is the next" "$CT/2026-11-11/CL-5/README.md" 'sprint: "2026-11-11"'
exists "close: the backlog task already in backlog/ stays" "$CT/backlog/CL-6/README.md"
exists "close: a carried task sent to the backlog is in backlog/" "$CT/backlog/CL-2/README.md"
exists "close: the folder it leaves empty stays" "$CT/2026-10-28"
sb unresolved Close
out_is "close: unresolved lists nothing after the second close" ""

result
