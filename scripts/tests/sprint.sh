#!/usr/bin/env bash
# Area sprint: sprint open, current, next, set and close, then edge cases of the task, sprint and
# index commands on what they leave, and a sprint with no tasks.
# Usage: bash scripts/test.sh sprint, or bash scripts/tests/sprint.sh
. "$(dirname "$0")/lib.sh"

# The tasks as board.sh leaves them.
fixture_board

# ---------------------------------------------------------------- sprint
sb sprint current Example
rc_is "sprint current: none gives exit 1" 1
sb sprint open Example
rc_is "sprint open: no anchor and no --end gives exit 5" 5
sb sprint next Example
rc_is "sprint next: no anchor in the profile gives exit 1" 1
sb sprint set Example goal=x
rc_is "sprint set: no sprint in progress gives exit 1" 1
sb sprint open Example --end 2026-02-30
rc_is "sprint open: an impossible date gives exit 5" 5
sb sprint open Example --end 2026-10-14 --goal "Ship: invoices"
rc_is "sprint open: exit 0" 0
out_is "sprint open: prints the note path" "$P/sprints/2026-10-14.md"
S1="$vault/$P/sprints/2026-10-14.md"
line_is "sprint note: alias" "$S1" '  - "Example Sprint 2026-10-14"'
line_is "sprint note: id quoted" "$S1" 'sprint: "2026-10-14"'
line_is "sprint note: start from the length" "$S1" "start: 2026-10-01"
line_is "sprint note: end" "$S1" "end: 2026-10-14"
line_is "sprint note: in progress" "$S1" "status: in-progress"
line_is "sprint note: goal quoted" "$S1" 'goal: "Ship: invoices"'
line_is "sprint note: up-link" "$S1" "> Up: [[$P/sprints/README|Example Sprints Hub]]"
line_is "sprint note: its dates and the board view of its tasks" "$S1" "2026-10-01 to 2026-10-14. Its tasks are the board's \`Current sprint\` view."
is "sprint note: body sections" "$(grep '^## ' "$S1" | tr '\n' '|')" "## Goal|## Notes|## Close|"
line_is "sprint open: hub gets one link line" "$vault/$P/sprints/README.md" "- [[$P/sprints/2026-10-14|Example Sprint 2026-10-14]] - 2026-10-01 to 2026-10-14"
line_is "sprint open: board literal rewritten" "$vault/$P/tasks/tasks.base" '        - sprint == "2026-10-14"'
file_lacks "sprint open: old literal gone" "$vault/$P/tasks/tasks.base" 'sprint == "none"'
line_is "sprint open: the first end date becomes the anchor" "$vault/$P/claude/profile.md" 'sprint_anchor_end: "2026-10-14"'
sb sprint open Example --end 2026-10-28
rc_is "sprint open: refused while one is in progress, exit 6" 6
absent "sprint open: nothing created on refusal" "$vault/$P/sprints/2026-10-28.md"
sb sprint current Example
rc_is "sprint current: exit 0" 0
out_is "sprint current: id, start, end, days left, goal" "2026-10-14${TAB}2026-10-01${TAB}2026-10-14${TAB}6${TAB}Ship: invoices"
sb context --cwd "$vault/$P"
out_has "context: sprint in progress" "sprint: 2026-10-14"
sb sprint set Example committed=5 "goal=Ship: invoices and credits"
rc_is "sprint set: exit 0" 0
out_is "sprint set: prints the changed keys" "committed: 5
goal: Ship: invoices and credits"
line_is "sprint set: committed is a number" "$S1" "committed: 5"
line_is "sprint set: goal quoted" "$S1" 'goal: "Ship: invoices and credits"'
sb sprint set Example committed=5
out_is "sprint set: nothing to change" "no change"
sb sprint current Example
out_has "sprint set: sprint current shows the new goal" "Ship: invoices and credits"
sb sprint set Example status=done
rc_is "sprint set: any other key gives exit 5" 5
line_is "sprint set: the refused key is not written" "$S1" "status: in-progress"
sb sprint set Example committed=many
rc_is "sprint set: committed must be a number, exit 5" 5
sb sprint set Example
rc_is "sprint set: no pair gives exit 5" 5
sb sprint set Nope goal=x
rc_is "sprint set: unknown project gives exit 1" 1
for t in EX-2 EX-3 EX-4 EX-5; do sb task set "$t" sprint=2026-10-14; done
sb board Example "Current sprint"
is "board Current sprint: the tasks of the sprint in progress" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | LC_ALL=C sort | tr '\n' ' ')" "EX-1 EX-2 EX-3 EX-4 EX-5 EX-6 "
sb sprint close Example --carry EX-1
rc_is "sprint close: open tasks left unnamed give exit 5" 5
is "sprint close: lists the missing ones" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | LC_ALL=C sort | tr '\n' ' ')" "EX-2 EX-5 EX-6 "
line_is "sprint close: nothing changed on refusal" "$S1" "status: in-progress"
line_is "sprint close: no task touched on refusal" "$T1" "carried_from: []"
sb sprint close Example --carry EX-1,EX-404 --backlog EX-2 --abandon EX-5,EX-6
rc_is "sprint close: an id outside the sprint gives exit 5" 5
sb sprint close Example --carry EX-1,EX-2 --backlog EX-2 --abandon EX-5,EX-6
rc_is "sprint close: an id named twice gives exit 5" 5
sb sprint close Example --carry EX-1 --backlog EX-2 --abandon EX-55 --abandon EX-6
rc_is "sprint close: exit 0, one task named by an alias" 0
out_is "sprint close: summary, six labelled lines in order" "sprint: 2026-10-14
done: EX-3
carried: EX-1
backlog: EX-2
abandoned: EX-4, EX-5, EX-6
next: 2026-10-28"
line_is "sprint close: carried task moves to the next sprint" "$T1" 'sprint: "2026-10-28"'
is "sprint close: carried_from records the old id" "$(SB_ROOT="$vault"; sb_fm_list "$T1" carried_from)" "2026-10-14"
line_is "sprint close: carried id quoted" "$T1" '  - "2026-10-14"'
file_lacks "sprint close: status notes are left to the caller" "$T1" "Carried"
file_lacks "sprint close: backlog task loses its sprint" "$T2" "sprint:"
line_is "sprint close: abandoned task status" "$vault/$P/tasks/EX-5/README.md" "status: abandoned"
line_is "sprint close: abandoned task tag" "$vault/$P/tasks/EX-5/README.md" "  - status/done"
line_is "sprint close: abandoned CRLF task keeps its endings" "$T6" "status: abandoned$CR"
line_is "sprint close: done task keeps its sprint" "$T3" 'sprint: "2026-10-14"'
line_is "sprint close: sprint note done" "$S1" "status: done"
line_is "sprint close: sprint note tag" "$S1" "  - status/done"
line_is "sprint close: completed count" "$S1" "completed: 1"
line_is "sprint close: carried count" "$S1" "carried_over: 1"
line_is "sprint close: committed left as planning froze it" "$S1" "committed: 5"
line_is "sprint close: close section links with a path" "$S1" "- [[$P/tasks/EX-3/README|EX-3]] - Untitled"
line_is "sprint close: close section counts" "$S1" "Counts: done 1, carried over 1, backlog 1, abandoned 3."
sb sprint current Example
rc_is "sprint current: none after the close" 1
sb sprint close Example
rc_is "sprint close: no sprint in progress gives exit 1" 1
ls "$vault/$P/sprints" >"$tmp/sprints.before"
sb sprint next Example
rc_is "sprint next: exit 0" 0
out_is "sprint next: id, start, end from the cadence" "2026-10-28${TAB}2026-10-15${TAB}2026-10-28"
NEXT_ID="$(printf '%s\n' "$OUT" | cut -f1)"
NEXT_START="$(printf '%s\n' "$OUT" | cut -f2)"
ls "$vault/$P/sprints" >"$tmp/sprints.after"
is "sprint next: writes nothing" "$(cmp -s "$tmp/sprints.before" "$tmp/sprints.after"; echo $?)" "0"
sb sprint open Example
rc_is "sprint open: next sprint from the cadence" 0
out_is "sprint open: creates exactly what sprint next printed" "$P/sprints/$NEXT_ID.md"
line_is "sprint open: with the start sprint next printed" "$vault/$P/sprints/$NEXT_ID.md" "start: $NEXT_START"
out_is "sprint open: skips the sprint that already ended" "$P/sprints/2026-10-28.md"
sb sprint next Example
out_is "sprint next: with a sprint in progress, the one after it" "2026-11-11${TAB}2026-10-29${TAB}2026-11-11"
sb sprint next
rc_is "sprint next: no project gives exit 5" 5
line_is "sprint open: start of the next sprint" "$vault/$P/sprints/2026-10-28.md" "start: 2026-10-15"
line_is "sprint open: board literal follows" "$vault/$P/tasks/tasks.base" '        - sprint == "2026-10-28"'
is "sprint open: hub lists the newest sprint first" "$(($(lineno "$vault/$P/sprints/README.md" 'sprints/2026-10-28|') + 1))" "$(lineno "$vault/$P/sprints/README.md" 'sprints/2026-10-14|')"
sb sprint close Example --carry EX-1
out_has "sprint close: next is what sprint next printed" "next: 2026-11-11"
is "sprint close: a second carry appends" "$(SB_ROOT="$vault"; sb_fm_list "$T1" carried_from | tr '\n' ' ')" "2026-10-14 2026-10-28 "
line_is "sprint close: the carried task waits on the computed next id" "$T1" 'sprint: "2026-11-11"'
sb task set EX-2 sprint=2030-01-01
sb task set EX-4 sprint=2031-01-01
sb sprint open Example --end 2026-11-05
out_is "sprint open: off cadence, then one line per task it re-pointed" "$P/sprints/2026-11-05.md
re-pointed: EX-1 from 2026-11-11 to 2026-11-05
re-pointed: EX-2 from 2030-01-01 to 2026-11-05"
line_is "sprint open: a carried task follows the sprint that opened" "$T1" 'sprint: "2026-11-05"'
line_is "sprint open: an open task on a sprint with no note follows too" "$T2" 'sprint: "2026-11-05"'
line_is "sprint open: a closed task is left where it is" "$T4" 'sprint: "2031-01-01"'
line_is "sprint open: a task on a sprint that has a note is left alone" "$T3" 'sprint: "2026-10-14"'
is "sprint open: re-pointing is not a carry" "$(SB_ROOT="$vault"; sb_fm_list "$T1" carried_from | tr '\n' ' ')" "2026-10-14 2026-10-28 "
sb board Example "Current sprint"
is "sprint open: the re-pointed tasks show in the sprint" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | LC_ALL=C sort | tr '\n' ' ')" "EX-1 EX-2 "
line_is "sprint open: an anchor that exists is not moved" "$vault/$P/claude/profile.md" 'sprint_anchor_end: "2026-10-14"'
sb sprint open "Example Two" --end 2028-03-05
line_is "sprint open: start over a leap day" "$vault/$P2/sprints/2028-03-05.md" "start: 2028-02-21"
run env SECOND_BRAIN_TODAY=2027-12-25 "$SB" sprint current "Example Two"
out_is "sprint current: days left across a year end, empty goal" "2028-03-05${TAB}2028-02-21${TAB}2028-03-05${TAB}71${TAB}-"
sb sprint
rc_is "sprint: no subcommand gives exit 5" 5
sb sprint open
rc_is "sprint open: no project gives exit 5" 5
sb sprint current Nope
rc_is "sprint current: unknown project gives exit 1" 1

# ---------------------------------------------------------------- edge cases
mkdir -p "$vault/$P/tasks/EX-20/queries"
printf 'select 1;\n' >"$vault/$P/tasks/EX-20/queries/check.sql"
sb task new EX-20 --project Example --title "Folder came first"
rc_is "task new: a folder with no README gets one" 0
out_is "task new: same output as a new task" "$P/tasks/EX-20/README.md"
line_is "task new: the README is the usual one" "$vault/$P/tasks/EX-20/README.md" 'title: "Folder came first"'
exists "task new: what was in the folder is kept" "$vault/$P/tasks/EX-20/queries/check.sql"
sb task new EX-20 --project Example
rc_is "task new: a second run still gives exit 6" 6
sb task head EX-2
out_has "task head: epic line, dash when it is empty" "epic: -"
sb task set EX-2 epic=EX-900
sb task head EX-2
out_has "task head: epic line" "epic: EX-900"
is "task head: epic comes after branch" "$(printf '%s\n' "$OUT" | grep -A1 '^branch:' | tail -1)" "epic: EX-900"
if [ "$(lines "$OUT")" -le 15 ]; then pass "task head: still at most 15 lines"; else fail "task head: still at most 15 lines" "$OUT"; fi
sb task set EX-3 type=bug
out_is "task set: type and its tag reported together" "type: bug
tags: type/bug"
line_is "task set: type written" "$T3" "type: bug"
line_is "task set: type tag follows" "$T3" "  - type/bug"
file_lacks "task set: the old type tag is replaced" "$T3" "type/task"
sb task set EX-3 type=task
line_is "task set: type tag follows back" "$T3" "  - type/task"
sb task set EX-3 type=
rc_is "task set: type cannot be removed, exit 5" 5
sb task set EX-3 "type=Bad Type"
rc_is "task set: a type that cannot be a tag gives exit 5" 5
line_is "task set: refused type not written" "$T3" "type: task"
mkdir -p "$vault/$P/tasks/bare-readme"
printf '# bare-readme - Bare\n\nText written by hand.\n' >"$vault/$P/tasks/bare-readme/README.md"
BR="$vault/$P/tasks/bare-readme/README.md"
sb task set bare-readme type=task status=planned "title=Bare one" --project Example
rc_is "task set: a bare README gets its frontmatter" 0
sb task alias bare-readme add bare-readme --project Example
is "bare README: frontmatter opens the file" "$(head -1 "$BR")" "---"
line_is "bare README: type" "$BR" "type: task"
line_is "bare README: status" "$BR" "status: planned"
line_is "bare README: title" "$BR" "title: Bare one"
line_is "bare README: type tag" "$BR" "  - type/task"
line_is "bare README: status tag" "$BR" "  - status/active"
is "bare README: the type tag sits before the status tag" "$(($(lineno "$BR" '  - type/task') < $(lineno "$BR" '  - status/active')))" "1"
is "bare README: first alias is the folder name" "$(SB_ROOT="$vault"; sb_fm_list "$BR" aliases | head -1)" "bare-readme"
file_has "bare README: the body is kept" "$BR" "Text written by hand."
sb board Example Active
out_has "bare README: now a board row" "bare-readme | Bare one | planned | - | - | - | - | -"
mkdir -p "$vault/$P2/tasks/legacy-task"
printf -- '---\naliases:\n  - legacy-task\nstatus: planned\n---\n\n# legacy-task - twin\n\n## Discovery log\n\nold finding\n' >"$vault/$P2/tasks/legacy-task/README.md"
sb task head legacy-task
rc_is "task: an id found in two projects gives exit 4" 4
is "task: prints both candidates" "$(lines "$OUT")" "2"
sb task head legacy-task --project "Example Two"
rc_is "task: --project settles it" 0
sb find legacy-task
is "find: prints every match" "$(lines "$OUT")" "2"
sb task note legacy-task "Before the log" --project "Example Two"
L2="$vault/$P2/tasks/legacy-task/README.md"
is "task note: a missing section goes in before the discovery log" "$(($(lineno "$L2" '## Status notes') < $(lineno "$L2" '## Discovery log')))" "1"
file_has "task note: the rest of the note is kept" "$L2" "old finding"
sb task new 2026-cleanup --project Example --title "Slug that looks like a date"
line_is "task new: an alias that needs quotes gets them" "$vault/$P/tasks/2026-cleanup/README.md" '  - "2026-cleanup"'
sb task head 2026-cleanup
out_has "task head: finds the quoted alias task" "id: 2026-cleanup"
sb scaffold project Four --path work/four --keys FOUR
edit "$vault/work/four/tasks/tasks.base" 's/sprint == "none"/sprint == date("none")/'
sb sprint open Four --end 2026-11-11
line_is "sprint open: keeps a date() literal form on the board" "$vault/work/four/tasks/tasks.base" '        - sprint == date("2026-11-11")'
sb scaffold project Five --path work/five
sb projects
out_has "projects: an empty keys cell prints a dash" "Five${TAB}work/five${TAB}-"
sb project --name five
out_is "project: an empty keys cell prints a dash" "Five${TAB}work/five${TAB}-"
edit "$vault/work/five/tasks/tasks.base" 's/name: Current sprint/name: Some other view/'
sb sprint open Five --end 2026-11-11
rc_is "sprint open: a board with no Current sprint view still opens" 0
err_has "sprint open: says the board was not updated" "no Current sprint view"
is "sb_today: today when no override is set" "$( (unset SECOND_BRAIN_TODAY; sb_today) | grep -c '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$')" "1"
mkdir -p "$tmp/vault3/.obsidian" "$tmp/vault4/.obsidian" "$tmp/vault5/.obsidian"
printf '# My index\r\n\r\n## Projects\r\n\r\n- an old nested list\r\n\r\n## Other\r\n' >"$tmp/vault3/CLAUDE.md"
run env SECOND_BRAIN_VAULT="$tmp/vault3" "$SB" scaffold project Legacy --path old/legacy --keys LEG
rc_is "index: a Projects section with no table gets one" 0
run env SECOND_BRAIN_VAULT="$tmp/vault3" "$SB" projects
out_is "index: the new table is readable" "Legacy${TAB}old/legacy${TAB}LEG"
is "index: CRLF kept on every line" "$(grep -c "$CR\$" "$tmp/vault3/CLAUDE.md")" "$(grep -c '' "$tmp/vault3/CLAUDE.md")"
file_has "index: the old content is kept" "$tmp/vault3/CLAUDE.md" "- an old nested list"
is "index: the table sits inside the Projects section" "$(($(lineno "$tmp/vault3/CLAUDE.md" '| Legacy |') < $(lineno "$tmp/vault3/CLAUDE.md" '## Other')))" "1"
printf '# My index\n\nNo project list yet.\n' >"$tmp/vault4/CLAUDE.md"
run env SECOND_BRAIN_VAULT="$tmp/vault4" "$SB" scaffold project Fresh --path fresh
run env SECOND_BRAIN_VAULT="$tmp/vault4" "$SB" projects
out_is "index: a missing Projects section is appended, empty keys print a dash" "Fresh${TAB}fresh${TAB}-"
file_has "index: text before it is kept" "$tmp/vault4/CLAUDE.md" "No project list yet."
run env SECOND_BRAIN_VAULT="$tmp/vault5" "$SB" projects
rc_is "projects: no index gives exit 1" 1
run env SECOND_BRAIN_VAULT="$tmp/vault5" "$SB" scaffold project X --path x
rc_is "scaffold project: no index gives exit 2" 2
absent "scaffold project: nothing created without an index" "$tmp/vault5/x"

# ---------------------------------------------------------------- a sprint with no tasks
sb sprint close Four
rc_is "sprint close: a sprint with no tasks closes" 0
file_has "sprint close: the board keeps the closed sprint's literal" "$vault/work/four/tasks/tasks.base" 'sprint == date("2026-11-11")'
sb board Four "Current sprint"
out_is "board Current sprint: no rows once the sprint is closed, whatever the board's literal says" ""

# ---------------------------------------------------------------- result
result
