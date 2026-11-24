#!/usr/bin/env bash
# Area epic-folders: a child task inside its parent's folder, in the status and sprint layouts, and
# the word a project names its parent stories by.
# Usage: bash scripts/test.sh epic-folders, or bash scripts/tests/epic-folders.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault
# project_tree <folder>: every path in a folder, then the checksum of each file, to compare.
project_tree() { find "$1" | sort; find "$1" -type f -exec cksum {} + | sort; }
# same <desc> <before> <after>: two trees are the same.
same() { is "$1" "$(cmp -s "$2" "$3" && printf same)" "same"; }

# ---------------------------------------------------------------- parent_label
L="work/label"
LP="$vault/$L/claude/profile.md"
sb scaffold project Label --path "$L" --keys LB
# label_of: the word the helper reads from the profile of Label.
label_of() { (SB_ROOT="$vault" SB_P_PATH="$L" sb_parent_label); }
is "label: a profile with no parent_label key names parent stories epic" "$(label_of)" "epic"
is "label: a new profile has no parent_label key" "$(grep -c '^parent_label:' "$LP" || true)" "0"
line_is "label: the board names the epic column Epic by default" "$vault/$L/tasks/tasks.base" "    displayName: Epic"
file_has "label: the profile says what parent_label does" "$LP" \
  '- A `parent_label:` key added above names the project'"'"'s parent stories: `feature`, or `epic` with'
for v in feature Feature FEATURE; do
  edit "$LP" '/^parent_label:/d'
  edit "$LP" "s/^persona: \(.*\)\$/persona: \1\\
parent_label: $v/"
  is "label: parent_label: $v, in any letter case, is feature" "$(label_of)" "feature"
done
for v in epic Epic '""' story; do
  edit "$LP" "s/^parent_label: .*\$/parent_label: $v/"
  is "label: parent_label: $v is epic" "$(label_of)" "epic"
done
edit "$LP" '/^parent_label:/d'
sb task new LB-1 --project Label --title "Label LB-1"
sb task set LB-1 epic=LB-9
sb task head LB-1
out_has "label: task head prints the epic line with no key" "epic: LB-9"
edit "$LP" "s/^persona: \(.*\)\$/persona: \1\\
parent_label: Feature/"
sb task head LB-1
rc_is "label: task head in a feature project, exit 0" 0
out_has "label: task head prints the parent as feature" "feature: LB-9"
out_lacks "label: and no epic line" "epic:"
is "label: the feature line comes after branch" "$(printf '%s\n' "$OUT" | grep -A1 '^branch:' | tail -1)" "feature: LB-9"
line_is "label: the frontmatter key stays epic" "$vault/$L/tasks/LB-1/README.md" "epic: LB-9"
sb task head LB-1 --json
json_ok "label: task head --json parses in a feature project"
json_is "label: task head --json takes the feature key" 'print(d["feature"], "epic" in d)' "LB-9 False"
sb task set LB-1 epic=LB-8
out_is "label: task set names the frontmatter key, epic" "epic: LB-8"
# scaffold project --parent-label writes the key into a new profile, and the board's column.
F="work/feat"
sb scaffold project Feat --path "$F" --keys FT --parent-label Feature
rc_is "label: scaffold project --parent-label Feature, exit 0" 0
line_is "label: the new profile has parent_label: feature, in lower case" "$vault/$F/claude/profile.md" "parent_label: feature"
line_is "label: the board names the epic column Feature" "$vault/$F/tasks/tasks.base" "    displayName: Feature"
file_lacks "label: and not Epic" "$vault/$F/tasks/tasks.base" "displayName: Epic"
sb scaffold project Feat --path "$F" --keys FT --parent-label epic
err_has "label: an existing profile wins over the flag, and says so" \
  "the profile exists: its parent_label is used and --parent-label is ignored"
line_is "label: the profile keeps feature" "$vault/$F/claude/profile.md" "parent_label: feature"
E="work/epics"
sb scaffold project Epics --path "$E" --keys EP --parent-label EPIC
line_is "label: --parent-label EPIC writes epic" "$vault/$E/claude/profile.md" "parent_label: epic"
line_is "label: and the board names the column Epic" "$vault/$E/tasks/tasks.base" "    displayName: Epic"
project_tree "$vault" >"$tmp/vault.before"
sb scaffold project Stories --path work/stories --keys SR --parent-label story
rc_is "label: --parent-label with another word gives exit 5" 5
err_has "label: the message names the two words" "--parent-label is feature or epic: story"
project_tree "$vault" >"$tmp/vault.after"
same "label: nothing written for another word" "$tmp/vault.before" "$tmp/vault.after"

# ---------------------------------------------------------------- the board's branch for a child
# A child, <tasks_root>/<folder>/<parent>/<ID>/, has its folder three below the tasks root: seven
# folder parts here, and its ID is part 6, counted from 0.
is "board: a new board holds the branch that takes a task one level deeper, last of its filters" \
  "$(awk '/^formulas:/ { exit } /^        - and:$/ { n++ } n == 4' "$vault/$L/tasks/tasks.base")" \
  "$(printf '%s\n' "        - and:" '            - file.folder.split("/").length == 6' \
    '            - file.folder.split("/")[5] == aliases[0]')"
is "board: four folders deep is a child's folder in work/label/tasks" \
  "$(printf '%s\n' "$L/tasks/backlog/LB-1/LB-2" | awk -F/ '{ print NF }')" "6"

# ---------------------------------------------------------------- a status project
S="work/stat"
ST="$vault/$S/tasks"
SP="$vault/$S/claude/profile.md"
sb scaffold project Stat --path "$S" --keys ST
edit "$SP" 's/^task_layout: flat$/task_layout: status/'
for t in ST-1 ST-2 ST-3 ST-4 ST-5 ST-6 ST-7; do sb task new "$t" --project Stat --title "Stat $t"; done
sb task alias ST-1 add "Billing parent"
mkdir -p "$ST/planned/ST-1/spec"
printf -- '---\naliases:\n  - "ST-1 Design"\ntype: spec\n---\n\n> Up: [[%s|ST-1]]\n' "$S/tasks/planned/ST-1/README" \
  >"$ST/planned/ST-1/spec/design.md"
printf '# Stat links\n\nSee [[%s|ST-2]], [[%s|ST-1]] and [[%s|ST-1 Design]].\n' "$S/tasks/planned/ST-2/README" \
  "$S/tasks/planned/ST-1/README" "$S/tasks/planned/ST-1/spec/design" >"$vault/$S/links.md"
sb task set ST-2 epic=ST-1
rc_is "status child: task set epic=<parent>, exit 0" 0
out_is "status child: the key, then the path inside the parent's folder and the links: line" "epic: ST-1
$S/tasks/planned/ST-1/ST-2/README.md
links: $S/links.md | 1"
exists "status child: the child is inside its parent's folder in planned/" "$ST/planned/ST-1/ST-2/README.md"
absent "status child: and no longer beside it" "$ST/planned/ST-2"
exists "status child: the parent's README stays where it was" "$ST/planned/ST-1/README.md"
line_is "status child: the link followed the child" "$vault/$S/links.md" \
  "See [[$S/tasks/planned/ST-1/ST-2/README|ST-2]], [[$S/tasks/planned/ST-1/README|ST-1]] and [[$S/tasks/planned/ST-1/spec/design|ST-1 Design]]."
sb task set ST-3 epic="billing PARENT"
out_has "status child: an epic that names the parent by an alias, in any letter case, moves it in" \
  "$S/tasks/planned/ST-1/ST-3/README.md"
# The lookup finds a child at that depth: find, task head, board and topic.
sb find ST-2
out_is "status lookup: find sees a child in its parent's folder" "$S/tasks/planned/ST-1/ST-2/README.md"
sb task head ST-2
out_has "status lookup: task head reads a child" "path: $S/tasks/planned/ST-1/ST-2/README.md"
out_has "status lookup: and its epic line" "epic: ST-1"
sb task tag ST-2 add stacking
sb topic Stat stacking
out_is "status lookup: topic lists a tagged child" "$S/tasks/planned/ST-1/ST-2/README.md"
sb board Stat All
out_has "status lookup: the board lists the child" "ST-2 | Stat ST-2 | planned |"
out_has "status lookup: and the parent" "ST-1 | Stat ST-1 | planned |"
is "status lookup: the board has a row for each task and none more" "$(lines "$OUT")" "7"
sb find "Stat ST-3" --project Stat
rc_is "status lookup: find by the title alone is no lookup, exit 1" 1
sb unresolved Stat
out_is "status lookup: unresolved lists nothing" ""
# A README inside a task is no task unless its epic names that task.
mkdir -p "$ST/planned/ST-1/notes"
printf -- '---\naliases:\n  - notes\ntype: task\nstatus: planned\nepic: ST-7\n---\n\n# notes\n' >"$ST/planned/ST-1/notes/README.md"
sb board Stat All
is "status lookup: a README inside a task whose epic names another task is no task" "$(lines "$OUT")" "7"
out_lacks "status lookup: no row for it" "notes |"
sb find notes --project Stat
out_is "status lookup: find reaches it as a note by its alias, not as a task" "$S/tasks/planned/ST-1/notes/README.md"
rm -r "$ST/planned/ST-1/notes"
# A child in each status folder: its status change keeps it under its parent, and makes the folder
# named for the parent in the new status folder. The folder it leaves, with no README of its own,
# goes when it is empty.
prev="planned"
for s in in-progress in-review done abandoned; do
  sb task set ST-2 status="$s"
  rc_is "status child: status=$s, exit 0" 0
  want="status: $s"
  [ "$s" != "done" ] || want="$want${NL}tags: status/done"
  want="$want$NL$S/tasks/$s/ST-1/ST-2/README.md${NL}links: $S/links.md | 1"
  [ "$prev" = "planned" ] || want="$want${NL}removed: $S/tasks/$prev/ST-1"
  out_is "status child: status=$s moves it to $s/ST-1/ST-2/, removing the folder it left empty" "$want"
  exists "status child: the child is in $s/<parent>/" "$ST/$s/ST-1/ST-2/README.md"
  absent "status child: no $s/ README for the parent" "$ST/$s/ST-1/README.md"
  sb find ST-2
  out_is "status lookup: find sees the child in $s/<parent>/, with no README there" "$S/tasks/$s/ST-1/ST-2/README.md"
  sb task head ST-2
  out_has "status lookup: task head reads the child in $s/<parent>/" "path: $S/tasks/$s/ST-1/ST-2/README.md"
  sb board Stat All
  out_has "status lookup: the board lists the child in $s/<parent>/" "ST-2 | Stat ST-2 | $s |"
  prev="$s"
done
exists "status child: the parent's own folder in planned/ stays, with its other child" "$ST/planned/ST-1/ST-3/README.md"
absent "status child: in-review/ST-1, emptied, is gone" "$ST/in-review/ST-1"
exists "status child: the status folder itself stays" "$ST/in-review"
sb task set ST-2 status=planned
out_has "status child: back to planned, it goes into the parent's own folder" "$S/tasks/planned/ST-1/ST-2/README.md"
out_has "status child: and abandoned/ST-1 goes" "removed: $S/tasks/abandoned/ST-1"
sb unresolved Stat
out_is "status child: unresolved lists nothing after the moves" ""
# Clearing epic takes a child out to its folder; epic=- does too.
sb task set ST-3 epic=
rc_is "status clear: epic=, exit 0" 0
out_is "status clear: the removed key, then the path beside the parent" "epic: (removed)
$S/tasks/planned/ST-3/README.md"
sb task set ST-3 epic=ST-1
sb task set ST-3 epic=-
out_has "status clear: epic=- moves it out too" "$S/tasks/planned/ST-3/README.md"
# An epic that names no single task names no parent: the task moves out to its folder, with a note.
sb task set ST-5 epic=ST-900
rc_is "status unknown: an epic that names no single task, exit 0" 0
out_is "status unknown: it prints the key and moves nothing from its folder" "epic: ST-900"
err_has "status unknown: the note names the parent word and the project" "note: epic ST-900 names no single task of Stat"
exists "status unknown: the task stays in planned/" "$ST/planned/ST-5/README.md"
sb task set ST-5 epic=ST-5
out_is "status unknown: an epic that names the task itself names no parent" "epic: ST-5"
exists "status unknown: and it stays" "$ST/planned/ST-5/README.md"
sb task set ST-5 epic=-
# A taken destination gives exit 6 with nothing written.
mkdir -p "$ST/planned/ST-1/ST-4"
cp "$ST/planned/ST-4/README.md" "$tmp/ST-4.before"
project_tree "$vault/$S" >"$tmp/stat.before"
sb task set ST-4 epic=ST-1 next="Not written"
rc_is "status taken: an empty folder inside the parent's gives exit 6" 6
err_has "status taken: the message names it" "the destination exists: $S/tasks/planned/ST-1/ST-4"
project_tree "$vault/$S" >"$tmp/stat.after"
same "status taken: nothing written" "$tmp/stat.before" "$tmp/stat.after"
rmdir "$ST/planned/ST-1/ST-4"

# ---------------------------------------------------------------- a parent that changes status
# A parent's status change moves its own note and files alone, never its children's folders: the
# folder it leaves holds them, with no README of its own.
sb task set ST-4 epic=ST-1 status=in-progress
out_has "status parent: a child set in progress sits in in-progress/ST-1/" "$S/tasks/in-progress/ST-1/ST-4/README.md"
printf '# Notes of ST-1\n' >"$ST/planned/ST-1/notes.md"
printf 'hidden\n' >"$ST/planned/ST-1/.hidden"
sb task set ST-1 status=in-progress
rc_is "status parent: the parent set in progress, exit 0" 0
out_is "status parent: its new README path and one links: line per note, the counts added up" "status: in-progress
$S/tasks/in-progress/ST-1/README.md
links: $S/links.md | 2
links: $S/tasks/in-progress/ST-1/spec/design.md | 1"
exists "status parent: its README went into the folder that held its child" "$ST/in-progress/ST-1/README.md"
exists "status parent: its spec went with it" "$ST/in-progress/ST-1/spec/design.md"
exists "status parent: and its other files" "$ST/in-progress/ST-1/notes.md"
exists "status parent: the child already there stays" "$ST/in-progress/ST-1/ST-4/README.md"
exists "status parent: its planned child stays in planned/ST-1/" "$ST/planned/ST-1/ST-2/README.md"
is "status parent: planned/ST-1 holds the child alone, and no README" "$(ls -A "$ST/planned/ST-1" | tr '\n' ' ')" "ST-2 "
exists "status parent: an entry with a dot first moves with the parent" "$ST/in-progress/ST-1/.hidden"
line_is "status parent: the spec's up link follows the README" "$ST/in-progress/ST-1/spec/design.md" \
  "> Up: [[$S/tasks/in-progress/ST-1/README|ST-1]]"
line_is "status parent: the links to it and its spec follow" "$vault/$S/links.md" \
  "See [[$S/tasks/planned/ST-1/ST-2/README|ST-2]], [[$S/tasks/in-progress/ST-1/README|ST-1]] and [[$S/tasks/in-progress/ST-1/spec/design|ST-1 Design]]."
sb find ST-2
out_is "status parent: find still sees the child left in planned/ST-1/" "$S/tasks/planned/ST-1/ST-2/README.md"
sb board Stat All
is "status parent: the board still has a row for each task" "$(lines "$OUT")" "7"
sb unresolved Stat
out_is "status parent: unresolved lists nothing after the parent's move" ""
# A parent done, then abandoned, leaves its open children where they are.
sb task set ST-6 epic=ST-1
out_has "status parent: a child of the parent in progress goes inside its folder" "$S/tasks/planned/ST-1/ST-6/README.md"
sb task set ST-1 status=done
rc_is "status parent: the parent done with open children, exit 0" 0
out_has "status parent: it moves to done/ST-1/" "$S/tasks/done/ST-1/README.md"
exists "status parent: its child in progress stays" "$ST/in-progress/ST-1/ST-4/README.md"
absent "status parent: and no README is left there" "$ST/in-progress/ST-1/README.md"
for t in ST-2 ST-4 ST-6; do
  sb task head "$t"
  rc_is "status parent: task head still reads $t after the parent is done" 0
done
sb task set ST-1 status=abandoned
out_has "status parent: abandoned, it moves to abandoned/ST-1/" "$S/tasks/abandoned/ST-1/README.md"
absent "status parent: done/ST-1, which held nothing else, is gone" "$ST/done/ST-1"
sb board Stat Active
out_has "status parent: the board's Active view still lists an open child" "ST-4 | Stat ST-4 | in-progress |"
out_has "status parent: and the one in planned/" "ST-2 | Stat ST-2 | planned |"
sb unresolved Stat
out_is "status parent: unresolved lists nothing once the parent is abandoned" ""
# A merge that would put an entry on one already there gives exit 6 with nothing written.
sb task set ST-1 status=planned
out_has "status parent: back in planned, into the folder that holds its children" "$S/tasks/planned/ST-1/README.md"
sb task set ST-6 status=in-review
mkdir -p "$ST/in-review/ST-1/spec"
project_tree "$vault/$S" >"$tmp/stat.before"
sb task set ST-1 status=in-review
rc_is "status merge: an entry of the parent already in the folder it goes into gives exit 6" 6
err_has "status merge: the message names the entry" "the destination exists: $S/tasks/in-review/ST-1/spec"
project_tree "$vault/$S" >"$tmp/stat.after"
same "status merge: nothing written" "$tmp/stat.before" "$tmp/stat.after"
rmdir "$ST/in-review/ST-1/spec"
printf 'other\n' >"$ST/in-review/ST-1/.hidden"
project_tree "$vault/$S" >"$tmp/stat.before"
sb task set ST-1 status=in-review
rc_is "status merge: an entry with a dot first already in the folder it goes into gives exit 6" 6
err_has "status merge: the message names that entry" "the destination exists: $S/tasks/in-review/ST-1/.hidden"
project_tree "$vault/$S" >"$tmp/stat.after"
same "status merge: nothing written for it" "$tmp/stat.before" "$tmp/stat.after"
rm "$ST/in-review/ST-1/.hidden"
mkdir -p "$ST/done/ST-1"
sb task set ST-1 status=done
rc_is "status merge: an empty folder named for the parent, with no child in it, gives exit 6" 6
err_has "status merge: the message names the folder" "the destination exists: $S/tasks/done/ST-1"
rmdir "$ST/done/ST-1"

# ---------------------------------------------------------------- sprint close in a status project
# An abandoned child moves into its parent's folder in abandoned/; a parent abandoned with open
# children moves its own files alone.
sb sprint open Stat --end 2026-10-14
sb task set ST-1 sprint=2026-10-14
sb task set ST-7 sprint=2026-10-14 epic=ST-1
out_has "status close: the child joins its parent in planned/" "$S/tasks/planned/ST-1/ST-7/README.md"
sb sprint close Stat --abandon ST-1,ST-7
rc_is "status close: the parent and a child abandoned, exit 0" 0
out_has "status close: the parent moves its own files to abandoned/ST-1/" "$S/tasks/abandoned/ST-1/README.md"
out_has "status close: the child goes inside it" "$S/tasks/abandoned/ST-1/ST-7/README.md"
exists "status close: the open child that was not in the sprint stays in planned/ST-1/" "$ST/planned/ST-1/ST-2/README.md"
sb task head ST-2
rc_is "status close: and every command still finds it" 0
sb unresolved Stat
out_is "status close: unresolved lists nothing after the close" ""

# ---------------------------------------------------------------- a sprint project
R="work/spr"
RT="$vault/$R/tasks"
RP="$vault/$R/claude/profile.md"
sb scaffold project Spr --path "$R" --keys SP
edit "$RP" 's/^task_layout: flat$/task_layout: sprint/'
for t in SP-1 SP-2 SP-3 SP-4 SP-5; do sb task new "$t" --project Spr --title "Spr $t"; done
printf '# Spr links\n\nSee [[%s|SP-2]].\n' "$R/tasks/backlog/SP-2/README" >"$vault/$R/links.md"
sb task set SP-2 epic=SP-1
out_is "sprint child: a child in no sprint goes inside its parent's folder in backlog/" "epic: SP-1
$R/tasks/backlog/SP-1/SP-2/README.md
links: $R/links.md | 1"
sb find SP-2
out_is "sprint lookup: find sees a child in backlog/<parent>/" "$R/tasks/backlog/SP-1/SP-2/README.md"
sb task set SP-2 sprint=2026-12-04
rc_is "sprint child: the child joins a sprint, exit 0" 0
out_is "sprint child: it moves to <sprint folder>/<parent>/<ID>/" "sprint: 2026-12-04
$R/tasks/2026-12-04/SP-1/SP-2/README.md
links: $R/links.md | 1"
exists "sprint child: the parent's note stays in backlog/SP-1/" "$RT/backlog/SP-1/README.md"
absent "sprint child: no README for the parent in the sprint's folder" "$RT/2026-12-04/SP-1/README.md"
sb find SP-2
out_is "sprint lookup: find sees a child in a sprint's folder" "$R/tasks/2026-12-04/SP-1/SP-2/README.md"
sb task head SP-2
out_has "sprint lookup: task head reads it" "path: $R/tasks/2026-12-04/SP-1/SP-2/README.md"
out_has "sprint lookup: with its sprint" "sprint: 2026-12-04"
sb board Spr All
out_has "sprint lookup: the board lists it" "SP-2 | Spr SP-2 | planned | 2026-12-04 |"
is "sprint lookup: the board has a row for each task and none more" "$(lines "$OUT")" "5"
sb task set SP-2 status=done
out_is "sprint child: a status change moves nothing in a sprint project" "status: done
tags: status/done"
sb task set SP-2 status=planned
sb task set SP-2 sprint=
rc_is "sprint child: the child leaves the sprint, exit 0" 0
out_is "sprint child: back into its parent's folder in backlog/, and the folder it left goes" "sprint: (removed)
$R/tasks/backlog/SP-1/SP-2/README.md
links: $R/links.md | 1
removed: $R/tasks/2026-12-04/SP-1"
exists "sprint child: the sprint's folder itself stays, as a task's leave keeps it" "$RT/2026-12-04"
# The parent joins a sprint: its own files move, its child stays in backlog/SP-1/.
sb task set SP-1 sprint=2026-12-04
out_is "sprint parent: the parent's own files move to the sprint's folder" "sprint: 2026-12-04
$R/tasks/2026-12-04/SP-1/README.md"
is "sprint parent: backlog/SP-1 holds the child alone" "$(ls "$RT/backlog/SP-1" | tr '\n' ' ')" "SP-2 "
sb task head SP-2
out_has "sprint parent: the child is still found" "path: $R/tasks/backlog/SP-1/SP-2/README.md"
sb task set SP-2 sprint=2026-12-04
out_has "sprint parent: the child joins the parent's sprint, inside its folder there" "$R/tasks/2026-12-04/SP-1/SP-2/README.md"
out_has "sprint parent: and backlog/SP-1 goes" "removed: $R/tasks/backlog/SP-1"
# A child's sprint folder that is a task gives exit 6, but its parent's folder there may be a task.
mkdir -p "$RT/2026-12-18"
sed 's/^  - SP-5$/  - 2026-12-18/' "$RT/backlog/SP-5/README.md" >"$RT/2026-12-18/README.md"
project_tree "$vault/$R" >"$tmp/spr.before"
sb task set SP-2 sprint=2026-12-18
rc_is "sprint taken: a child's sprint folder that is a task gives exit 6" 6
err_has "sprint taken: the message names the sprint's folder, not the parent's" "the sprint folder is a task: $R/tasks/2026-12-18"
project_tree "$vault/$R" >"$tmp/spr.after"
same "sprint taken: nothing written" "$tmp/spr.before" "$tmp/spr.after"
rm -r "$RT/2026-12-18"
# sprint open re-points a child, which keeps its parent's folder in the new sprint's folder; sprint
# close carries one, and sends another to the backlog, each under its parent.
# The sprint ending today, 2026-10-08, opens; the cadence then gives 2026-10-22 as the next.
sb task set SP-3 epic=SP-1 sprint=2026-09-24
out_has "sprint open: a child in a sprint with no note" "$R/tasks/2026-09-24/SP-1/SP-3/README.md"
sb task set SP-1 sprint=2026-09-24
sb task set SP-2 sprint=2026-09-24
sb sprint open Spr --end 2026-10-08
rc_is "sprint open: re-points a parent and its children, exit 0" 0
out_has "sprint open: the parent moves to the new sprint's folder" "$R/tasks/2026-10-08/SP-1/README.md"
out_has "sprint open: each child goes inside it" "$R/tasks/2026-10-08/SP-1/SP-2/README.md"
out_has "sprint open: the other child too" "$R/tasks/2026-10-08/SP-1/SP-3/README.md"
absent "sprint open: the old sprint folder's parent folder is gone" "$RT/2026-09-24/SP-1"
sb task set SP-2 status=done
sb sprint close Spr --carry SP-3 --backlog SP-1
rc_is "sprint close: a child carried and its parent sent to the backlog, exit 0" 0
out_has "sprint close: the next sprint is 2026-10-22" "next: 2026-10-22"
out_has "sprint close: the carried child moves into a folder for its parent in the next sprint's folder" \
  "$R/tasks/2026-10-22/SP-1/SP-3/README.md"
out_has "sprint close: the parent moves its own files to backlog/" "$R/tasks/backlog/SP-1/README.md"
exists "sprint close: the done child stays in the closed sprint's folder, under its parent" "$RT/2026-10-08/SP-1/SP-2/README.md"
absent "sprint close: and no README is left there for the parent" "$RT/2026-10-08/SP-1/README.md"
sb sprint open Spr
out_has "sprint open: the carried child is in the folder of the sprint it opens already" "$R/sprints/2026-10-22.md"
sb task set SP-4 epic=SP-1 sprint=2026-10-22
sb sprint close Spr --backlog SP-3,SP-4
rc_is "sprint close: two children sent to the backlog, exit 0" 0
out_has "sprint close: a child sent to the backlog goes into its parent's folder there" "$R/tasks/backlog/SP-1/SP-3/README.md"
out_has "sprint close: the other one too" "$R/tasks/backlog/SP-1/SP-4/README.md"
out_has "sprint close: and the folder they left in the sprint goes" "removed: $R/tasks/2026-10-22/SP-1"
sb board Spr All
is "sprint close: the board still has a row for each task" "$(lines "$OUT")" "5"
sb unresolved Spr
out_is "sprint close: unresolved lists nothing after the moves" ""
# A child whose epic is an alias of its parent, in a folder named for the parent in backlog/ while
# the parent's note is in a sprint's folder, is a task.
sb task alias SP-1 add "Stack parent"
sb task set SP-1 sprint=2026-10-22
out_has "sprint holder: the parent joins a sprint, its children stay in backlog/SP-1/" "$R/tasks/2026-10-22/SP-1/README.md"
sb task set SP-4 epic="stack PARENT"
rc_is "sprint holder: an epic that names the parent by an alias, exit 0" 0
exists "sprint holder: the child stays in backlog/SP-1/" "$RT/backlog/SP-1/SP-4/README.md"
sb find SP-4
out_is "sprint holder: find takes it as a task" "$R/tasks/backlog/SP-1/SP-4/README.md"

# ---------------------------------------------------------------- a folder with no README
# A folder with no README of its own holds tasks one level deeper only when it is named for a task
# found elsewhere, by its folder name or an alias. A task folder that lost its README is named for
# no task: a README in it is no task, in every layout.
for l in flat sprint; do
  N="work/lost-$l"
  NT="$vault/$N/tasks"
  sb scaffold project "Lost $l" --path "$N" --keys "Q$(printf '%s' "$l" | cut -c1 | tr '[:lower:]' '[:upper:]')"
  edit "$vault/$N/claude/profile.md" "s/^task_layout: flat\$/task_layout: $l/"
  mkdir -p "$NT/planned/ST-9/notes"
  printf -- '---\ntype: note\n---\n\n# Notes\n' >"$NT/planned/ST-9/notes/README.md"
  sb find notes --project "Lost $l"
  rc_is "lost README: find sees no task in a folder named for no task, exit 1 ($l)" 1
  sb task head notes --project "Lost $l"
  rc_is "lost README: task head reads no task there, exit 1 ($l)" 1
  sb board "Lost $l" All
  out_is "lost README: the board lists nothing there ($l)" ""
done
# A folder named for an alias of a task found elsewhere holds tasks.
N="work/lost-flat"
NT="$vault/$N/tasks"
sb task new QF-1 --project "Lost flat" --title "Lost QF-1"
sb task alias QF-1 add notes-home
mkdir -p "$NT/planned/notes-home/QF-2"
sed 's/^  - QF-1$/  - QF-2/' "$NT/QF-1/README.md" >"$NT/planned/notes-home/QF-2/README.md"
sb find QF-2
out_is "lost README: a folder named for an alias of a task holds tasks" "$N/tasks/planned/notes-home/QF-2/README.md"

# ---------------------------------------------------------------- flat and archive change nothing
for l in flat archive; do
  W="work/$l"
  sb scaffold project "Lay $l" --path "$W" --keys "Z$(printf '%s' "$l" | cut -c1 | tr '[:lower:]' '[:upper:]')"
  edit "$vault/$W/claude/profile.md" "s/^task_layout: flat\$/task_layout: $l/"
  k="Z$(printf '%s' "$l" | cut -c1 | tr '[:lower:]' '[:upper:]')"
  sb task new "$k-1" --project "Lay $l"
  sb task new "$k-2" --project "Lay $l"
  sb task set "$k-2" epic="$k-1" status=in-progress
  out_is "$l: a child's epic and status move nothing" "epic: $k-1
status: in-progress"
  exists "$l: the child stays at the tasks root" "$vault/$W/tasks/$k-2/README.md"
done

result
