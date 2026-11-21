#!/usr/bin/env bash
# Area archive: task archive, and the other commands on an archived task.
# Usage: bash scripts/test.sh archive, or bash scripts/tests/archive.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault

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

# ---------------------------------------------------------------- result
result
