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

result
