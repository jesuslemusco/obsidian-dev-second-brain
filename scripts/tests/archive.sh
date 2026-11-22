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

# ---------------------------------------------------------------- status folders: the lookup
# The tasks are written while the project is flat, then put by hand in the folder of their status.
# Their aliases lose the id, so find reaches them by their folder, not by the aliases of every note.
K="work/stack"
KT="$vault/$K/tasks"
sb scaffold project Stack --path "$K" --keys SK
i=0
for s in planned in-progress in-review done abandoned; do
  i=$((i + 1))
  sb task new "SK-$i" --project Stack --title "Stack SK-$i"
  sb task set "SK-$i" status="$s"
  edit "$KT/SK-$i/README.md" "/^  - SK-$i\$/d"
  mkdir -p "$KT/$s"
  mv "$KT/SK-$i" "$KT/$s/SK-$i"
done
sb task new SK-6 --project Stack --title "Stack SK-6"
printf '# Done\n\nThe done tasks.\n' >"$KT/done/README.md"
sb find SK-3
out_is "status folders: find sees a task in in-review/ of a flat project" "$K/tasks/in-review/SK-3/README.md"
sb task head SK-3
out_has "status folders: task head reads it in a flat project" "path: $K/tasks/in-review/SK-3/README.md"
sb board Stack All
out_has "status folders: the board of a flat project lists it" "SK-3 | Stack SK-3 | in-review |"
edit "$vault/$K/claude/profile.md" 's/^task_layout: flat$/task_layout: archive/'
sb find SK-3
out_is "status folders: find sees it in an archive project too" "$K/tasks/in-review/SK-3/README.md"
edit "$vault/$K/claude/profile.md" 's/^task_layout: archive$/task_layout: Status/'
i=0
for s in planned in-progress in-review done abandoned; do
  i=$((i + 1))
  sb find "SK-$i"
  out_is "status folders: find sees a task in $s/" "$K/tasks/$s/SK-$i/README.md"
  sb task head "SK-$i"
  out_has "status folders: task head reads a task in $s/" "path: $K/tasks/$s/SK-$i/README.md"
done
sb board Stack All
i=0
for s in planned in-progress in-review done abandoned; do
  i=$((i + 1))
  out_has "status folders: board All lists the task in $s/" "SK-$i | Stack SK-$i | $s |"
done
out_has "status folders: board All lists the task at the root too" "SK-6 | Stack SK-6 | planned |"
is "status folders: the README of a status folder is no task on the board" "$(lines "$OUT")" "6"
sb find done --project Stack
rc_is "status folders: a status folder is no task, exit 1" 1
sb task tag SK-4 add stacking
sb topic Stack stacking
out_is "status folders: topic lists a tagged task in done/" "$K/tasks/done/SK-4/README.md"
sb task alias SK-3 add stack-review
sb task head stack-review
out_has "status folders: an alias finds a task in a status folder" "path: $K/tasks/in-review/SK-3/README.md"
sb task set SK-2 next="Finish the stack"
out_is "status folders: task set edits a task in a status folder" "next: Finish the stack"
sb task archive SK-4
rc_is "status folders: task archive in a status project gives exit 5" 5
err_has "status folders: the message names the layout" "task_layout: status"
exists "status folders: nothing moved then" "$KT/done/SK-4/README.md"
mkdir -p "$KT/SK-4"
cp "$KT/done/SK-4/README.md" "$KT/SK-4/README.md"
sb task head SK-4
rc_is "status folders: the same id at the root and in a status folder is ambiguous, exit 4" 4
rm -r "$KT/SK-4"

# ---------------------------------------------------------------- status folders: reserved names
# The five status names, in any letter case, are no task id and no alias in any layout, as archive
# is not. The message names the folder as typed and the status lowercased.
stack_tree() { find "$vault/$K" | sort; find "$vault/$K" -type f -exec cksum {} + | sort; }
for layout in flat archive Status; do
  edit "$vault/$K/claude/profile.md" "s/^task_layout: .*\$/task_layout: $layout/"
  stack_tree >"$tmp/stack.before"
  sb task new done --project Stack
  rc_is "reserved: task new done gives exit 5 ($layout)" 5
  err_has "reserved: the message names the done folder ($layout)" "done is the folder of the done tasks, not a task id"
  sb task new In-Review --project Stack
  rc_is "reserved: task new In-Review gives exit 5 ($layout)" 5
  err_has "reserved: the name as typed, the status lowercased ($layout)" "In-Review is the folder of the in-review tasks, not a task id"
  for s in PLANNED In-Progress abandoned; do
    sb task new "$s" --project Stack
    rc_is "reserved: task new $s gives exit 5 ($layout)" 5
  done
  sb task alias SK-3 add planned
  rc_is "reserved: task alias add planned gives exit 5 ($layout)" 5
  err_has "reserved: the alias message names the planned folder ($layout)" "planned is the folder of the planned tasks, not a task alias"
  for s in Done in-review IN-PROGRESS Abandoned; do
    sb task alias SK-3 add "$s"
    rc_is "reserved: task alias add $s gives exit 5 ($layout)" 5
  done
  stack_tree >"$tmp/stack.after"
  is "reserved: nothing written ($layout)" "$(cmp -s "$tmp/stack.before" "$tmp/stack.after" && printf same)" "same"
done
sb task new done
rc_is "reserved: task new done, with no project, gives exit 5" 5
err_has "reserved: it is refused before the project is looked for" "done is the folder of the done tasks, not a task id"
sb task new Archive --project Stack
rc_is "reserved: archive is still no task id, exit 5" 5
err_has "reserved: archive keeps its message" "archive is the folder of the archived tasks, not a task id"
sb task alias SK-3 add ARCHIVE
rc_is "reserved: archive is still no task alias, exit 5" 5
err_has "reserved: archive keeps its alias message" "archive is the folder of the archived tasks, not a task alias"

# ---------------------------------------------------------------- status folders: task set
# In a status project a status change moves the task into the folder of its new status, through
# move. The tasks are written while the project is flat, then put in planned/ by hand.
F="work/flow"
FT="$vault/$F/tasks"
sb scaffold project Flow --path "$F" --keys FL
for t in FL-1 FL-2 FL-3 FL-4 FL-5 FL-6; do sb task new "$t" --project Flow --title "Flow $t"; done
mkdir -p "$FT/planned"
for t in FL-1 FL-2 FL-3 FL-4 FL-5 FL-6; do mv "$FT/$t" "$FT/planned/$t"; done
edit "$vault/$F/claude/profile.md" 's/^task_layout: flat$/task_layout: status/'
printf '# Links\n\nSee [[%s|FL-1]].\n' "$F/tasks/planned/FL-1/README" >"$vault/$F/links.md"
sb task set FL-1 status=in-progress
rc_is "task set: a status change in a status project, exit 0" 0
out_is "task set: the keys, then the new path and the notes whose links it rewrote" "status: in-progress
$F/tasks/in-progress/FL-1/README.md
links: $F/links.md | 1"
absent "task set: the planned folder of the task is gone" "$FT/planned/FL-1"
line_is "task set: the link now leads into in-progress/" "$vault/$F/links.md" "See [[$F/tasks/in-progress/FL-1/README|FL-1]]."
sb unresolved Flow
rc_is "task set: unresolved runs after the move, exit 0" 0
out_is "task set: unresolved lists nothing after the move" ""
for s in in-review done abandoned planned; do
  sb task set FL-1 status="$s"
  rc_is "task set: status=$s, exit 0" 0
  out_has "task set: status=$s prints the new path" "$F/tasks/$s/FL-1/README.md"
  out_has "task set: status=$s prints the links: line" "links: $F/links.md | 1"
  line_is "task set: status=$s moves the task into $s/" "$FT/$s/FL-1/README.md" "status: $s"
  is "task set: status=$s leaves it in no other folder" "$(find "$FT" -type d -name FL-1 | wc -l | tr -d ' ')" "1"
done
line_is "task set: the link followed each move" "$vault/$F/links.md" "See [[$F/tasks/planned/FL-1/README|FL-1]]."
sb unresolved Flow
out_is "task set: unresolved lists nothing after the five moves" ""
cp "$FT/planned/FL-1/README.md" "$tmp/FL-1.before"
sb task set FL-1 status=planned
out_is "task set: the same status prints no change" "no change"
is "task set: the same status moves and writes nothing" "$(cmp -s "$tmp/FL-1.before" "$FT/planned/FL-1/README.md" && printf same)" "same"
sb task set FL-1 status=done status=planned
out_has "task set: the last status pair wins" "status: planned"
exists "task set: so the task stays in planned/" "$FT/planned/FL-1/README.md"
mkdir -p "$FT/in-review"
mv "$FT/planned/FL-2" "$FT/in-review/FL-2"
sb task set FL-2 status=planned
out_is "task set: the same status in the wrong folder prints no change" "no change"
exists "task set: the same status in the wrong folder moves nothing" "$FT/in-review/FL-2/README.md"
sb task set FL-2 status=in-review
rc_is "task set: a task already in the folder of its new status, exit 0" 0
out_is "task set: its own folder is not in the way, and nothing moves" "status: in-review"
exists "task set: it stays in in-review/" "$FT/in-review/FL-2/README.md"
cp "$FT/planned/FL-3/README.md" "$tmp/FL-3.before"
mkdir -p "$FT/done/FL-3"
sb task set FL-3 status=done next="Ship it"
rc_is "task set: a folder at the destination, even empty, gives exit 6" 6
err_has "task set: the message names the destination" "the destination exists: $F/tasks/done/FL-3"
is "task set: no key is written then" "$(cmp -s "$tmp/FL-3.before" "$FT/planned/FL-3/README.md" && printf same)" "same"
is "task set: the destination is left as it was" "$(ls -A "$FT/done/FL-3")" ""
rmdir "$FT/done/FL-3"
printf 'x\n' >"$FT/done/FL-3"
sb task set FL-3 status=done
rc_is "task set: a file at the destination gives exit 6" 6
is "task set: no key is written for it either" "$(cmp -s "$tmp/FL-3.before" "$FT/planned/FL-3/README.md" && printf same)" "same"
rm "$FT/done/FL-3"
if ! sb_is_windows; then
  ln -s "$tmp/nowhere" "$FT/done/FL-3"
  sb task set FL-3 status=done
  rc_is "task set: a link at the destination, even a dead one, gives exit 6" 6
  is "task set: no key is written for a link" "$(cmp -s "$tmp/FL-3.before" "$FT/planned/FL-3/README.md" && printf same)" "same"
  rm "$FT/done/FL-3"
fi
# A move that fails after the keys are written: mv fails, or a linking note changes once mv ran.
shim="$tmp/shim"
mkdir -p "$shim"
REAL_MV="$(type -P mv)"
export REAL_MV
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
chmod +x "$shim/mv"
run env PATH="$shim:$PATH" SHIM_MV_FAILS=1 "$SB" task set FL-4 status=in-progress
rc_is "task set: a move that fails after the write exits as move does, 1" 1
err_has "task set: the failure is named on stderr" "cannot move $F/tasks/planned/FL-4 to $F/tasks/in-progress/FL-4"
out_is "task set: the keys written are printed, and no new path" "status: in-progress"
line_is "task set: the status is written" "$FT/planned/FL-4/README.md" "status: in-progress"
absent "task set: the task is not moved" "$FT/in-progress/FL-4"
printf '# Links five\n\nSee [[%s|FL-5]].\n' "$F/tasks/planned/FL-5/README" >"$vault/$F/links5.md"
run env PATH="$shim:$PATH" SHIM_AFTER_MV="printf 'edited\n' >>'$vault/$F/links5.md'" "$SB" task set FL-5 status=done
rc_is "task set: a link rewrite that fails after the move exits as move does, 1" 1
out_is "task set: the keys, then the new path" "status: done
tags: status/done
$F/tasks/done/FL-5/README.md"
err_has "task set: the note left with an old link is named" "note: $F/links5.md changed while the command ran"
err_has "task set: the move's failure is named" "moved $F/tasks/planned/FL-5 to $F/tasks/done/FL-5, but not every note could be rewritten"
exists "task set: the task is in done/" "$FT/done/FL-5/README.md"
# A task that leaves the archive loses archived; one that stays in it keeps it.
edit "$vault/$F/claude/profile.md" 's/^task_layout: status$/task_layout: archive/'
sb task set FL-6 status=done
sb task archive FL-6
exists "task set: FL-6 is archived while the project archives" "$FT/archive/2026/FL-6/README.md"
edit "$vault/$F/claude/profile.md" 's/^task_layout: archive$/task_layout: status/'
sb task set FL-6 status=done
out_is "task set: the same status in the archive prints no change" "no change"
file_has "task set: the task in the archive keeps archived" "$FT/archive/2026/FL-6/README.md" 'archived: "2026-10-08"'
sb task set FL-6 status=in-progress
rc_is "task set: a task leaves the archive, exit 0" 0
out_is "task set: the keys, then its path in in-progress/" "status: in-progress
tags: status/active
$F/tasks/in-progress/FL-6/README.md"
absent "task set: the archived folder is gone" "$FT/archive/2026/FL-6"
is "task set: archived is removed on leaving the archive" "$(grep -c '^archived:' "$FT/in-progress/FL-6/README.md" 2>&1)" "0"
cp "$FT/in-progress/FL-6/README.md" "$tmp/FL-6.before"
sb task set FL-6 status=in-review
is "task set: a move between status folders keeps every key, the status aside" \
  "$(sed 's/^status: in-review$/status: in-progress/' "$FT/in-review/FL-6/README.md" | cmp -s - "$tmp/FL-6.before" && printf same)" "same"
# In a flat or archive project a status change moves nothing, even a task in a status folder.
for layout in flat archive; do
  edit "$vault/$F/claude/profile.md" "s/^task_layout: .*\$/task_layout: $layout/"
  sb task set FL-3 status=in-review
  out_is "task set: a status change in a $layout project prints the keys only" "status: in-review"
  exists "task set: nothing moves in a $layout project" "$FT/planned/FL-3/README.md"
  sb task set FL-3 status=planned
done
sb task set SH-5 status=in-progress
out_is "task set: a task at the root of an archive project stays there" "status: in-progress
tags: status/active"
exists "task set: it is not moved into a status folder" "$AT/SH-5/README.md"
absent "task set: no status folder is made" "$AT/in-progress"

# ---------------------------------------------------------------- result
result
