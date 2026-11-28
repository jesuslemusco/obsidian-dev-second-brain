#!/usr/bin/env bash
# Area docs: what the skills, agents, README, guide, contract and changelog say.
# Usage: bash scripts/test.sh docs, or bash scripts/tests/docs.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault

# ---------------------------------------------------------------- ticket text goes to story-tracker
ST="$here/skills/story-tracker/SKILL.md"
st_desc="$(grep -m1 '^description: ' "$ST")"
st_desc="${st_desc#description: }"
for word in "ticket text" summary description "acceptance criteria" draft "where a ticket stands" standup; do
  case "$st_desc" in *"$word"*) pass "story-tracker: the description names $word" ;; *) fail "story-tracker: the description names $word" "in: $st_desc" ;; esac
done
is "story-tracker: the description is under the doctor's 200 characters" "$((${#st_desc} < 200))" "1"
line_is "story-tracker: the name is the folder's" "$ST" "name: story-tracker"
draft_row="$(grep '^| draft |' "$ST")"
case "$draft_row" in
  *"with or without an id"*ticket-description.md.tmpl*"reply with the text"*"Write no file until the id arrives"*) pass "story-tracker: a draft mode row fills the template and writes no file" ;;
  *) fail "story-tracker: a draft mode row fills the template and writes no file" "got: $draft_row" ;;
esac
case "$draft_row" in
  *"as the ticket text rules below say"*) pass "story-tracker: draft mode finds its template as ticket text does" ;;
  *) fail "story-tracker: draft mode finds its template as ticket text does" "got: $draft_row" ;;
esac
line_is "story-tracker: ticket text fills the project's own template first" "$ST" \
  "- Fill the project's own template when it has one:"
line_is "story-tracker: the project's template is in its claude/templates folder" "$ST" \
  '  `<vault>/<project path>/claude/templates/ticket-description.md.tmpl`, with the `vault:` line'
line_is "story-tracker: else the plugin's template" "$ST" \
  '- Else fill `${CLAUDE_PLUGIN_ROOT}/templates/ticket-description.md.tmpl`. Never write it freehand.'
line_is "story-tracker: a new story keeps the shape of the project's README template" "$here/skills/story-tracker/create.md" \
  "   - Add no section the README lacks: a project's own template may leave some out."
file_lacks "vault-doctor: a request to check the vault may load it" "$here/skills/vault-doctor/SKILL.md" "disable-model-invocation"
line_is "vault-setup: it runs only by name" "$here/skills/vault-setup/SKILL.md" "disable-model-invocation: true"

# ---------------------------------------------------------------- docs-keeper on a ticket marked done
DK="$here/agents/docs-keeper.md"
desc="$(sed -n 's/^description: //p' "$DK")"
is "docs-keeper: the description is under 200 characters" "$((${#desc} < 200))" "1"
case "$desc" in *"a ticket is marked done"*) pass "docs-keeper: the description names a ticket marked done" ;;
  *) fail "docs-keeper: the description names a ticket marked done" "in: $desc" ;; esac
line_is "docs-keeper: Workflow 5 is there" "$DK" "## Workflow 5 - Ticket marked done"
file_has "docs-keeper: Workflow 5 runs step 7 on the docs to update" "$DK" 'run step 7 of Workflow 1 on them'
file_has "docs-keeper: Workflow 5 falls back to the code to doc map" "$DK" 'Then run Workflow 1 steps 3-5, as confirmed.'
file_has "docs-keeper: a gap not fixed goes to the debt file, as Boundaries says" "$DK" "A gap found but not fixed goes to the profile's debt file"
file_has "docs-keeper: Boundaries gives the debt line a shape" "$DK" '`<YYYY-MM-DD> <ID>: <doc path> - <the gap>`'
file_has "docs-keeper: Workflow 5 stops when every line is ticked" "$DK" 'With every line already ticked: go to step 6. Do not check the map again.'
file_has "docs-keeper: Workflow 5 diffs the merge commit" "$DK" 'diff <merge>^1 <merge>'
file_has "docs-keeper: Workflow 5 diffs a branch not merged yet" "$DK" 'diff origin/<production_branch>...<branch>'
file_has "docs-keeper: Workflow 5 stops when the change is not found" "$DK" 'report that the change was not found and stop'
file_has "docs-keeper: Workflow 5 reads the head with the project" "$DK" '`second-brain task head <ID> --project <project>`'
file_has "docs-keeper: Workflow 5 adds a status note" "$DK" 'Add a status note to the ticket naming what was updated'
line_is "docs-keeper: Workflow 6 is there, under the name the doctor's old-namespace fix gives" "$DK" "## Workflow 6 - A renamed command"
ST="$here/skills/story-tracker/SKILL.md"
file_has "story-tracker: a story in production starts docs-keeper" "$ST" 'start the `docs-keeper` agent'
file_has "story-tracker: it hands over the ticket id and the README path" "$ST" 'with the project, the ticket id and the README path'
file_lacks "story-tracker: no longer tells Claude not to start it" "$ST" 'Do not start it yourself.'
file_has "story-tracker: a session that cannot start an agent names docs-keeper" "$ST" 'When the session cannot start an agent, say so and'
file_has "sprint close: reports done tasks with unticked docs through the helper" "$here/skills/scrum-master/sprint-planning.md" '`second-brain task docs <done ids> --project <project>`'
file_lacks "sprint close: no Grep" "$here/skills/scrum-master/sprint-planning.md" 'Grep'
file_lacks "story-tracker: a done story logs no achievement" "$here/skills/story-tracker/SKILL.md" 'achievement'
file_has "sprint close: does not start docs-keeper" "$here/skills/scrum-master/sprint-planning.md" 'Do not start it here: the close only reports.'
file_has "index: names a ticket marked done for docs-keeper" "$vault/CLAUDE.md" '`docs-keeper` for docs that follow the code and for a ticket marked done.'

# ---------------------------------------------------------------- skills follow the layout standards
ST="$here/skills/story-tracker/SKILL.md"
STC="$here/skills/story-tracker/create.md"
CL="$here/skills/scrum-master/sprint-planning.md"
file_lacks "story-tracker create: task new takes no subproject" "$STC" '--subproject'
file_has "story-tracker: a story set done in an archive project gets one question" "$ST" 'the profile says `task_layout: archive`: after'
file_has "story-tracker: the question is asked once" "$ST" 'ask once whether to archive it now'
file_has "story-tracker: it archives through the helper" "$ST" '`second-brain task archive <ID>`'
file_has "story-tracker: never archives without a yes" "$ST" 'Never archive a story without that yes.'
file_has "story-tracker: an archived story is found by id, not by a built path" "$ST" "Take a story's path from \`find\` or \`task head\`; never build it from the id."
file_has "story-tracker status: what waits on docs comes from task docs" "$here/skills/story-tracker/status.md" '`second-brain task docs <their ids> --project <project>`'
file_lacks "story-tracker status: no Grep over the READMEs" "$here/skills/story-tracker/status.md" 'One Grep for'
file_has "sprint close: asks once whether to archive the sprint's done tasks" "$CL" 'once whether to archive those tasks now'
file_has "sprint close: it archives through the helper" "$CL" '`second-brain task archive <ID> --project <project>`'
file_has "sprint close: never archives without a yes" "$CL" 'Never archive a task without that yes.'
is "sprint close: the archive question comes after the status notes and before the report" \
  "$(($(lineno "$CL" '7. Add one status note per touched task') < $(lineno "$CL" '8. `task_layout: archive`') && $(lineno "$CL" '8. `task_layout: archive`') < $(lineno "$CL" '9. Report the summary')))" "1"
file_lacks "sprint close: logs no achievement" "$CL" 'achievement'
file_has "sprint close: the archive question reads Step 0's profile keys" "$CL" \
  '8. `task_layout: archive` in Step 0'"'"'s `second-brain profile <project> --keys`, and a `done:` or'
file_has "sprint-planning: its rules allow task archive after a yes at close" "$here/skills/scrum-master/sprint-planning.md" 'a yes at close, `second-brain task archive`'
file_has "vault-setup: the profile interview asks for task_layout" "$here/skills/vault-setup/SKILL.md" '| `task_layout` |'
file_has "vault-setup: and for archive_after_days" "$here/skills/vault-setup/SKILL.md" '| `archive_after_days` | with `archive` only'
file_has "vault-setup adopt: asks for task_layout through the project interview" "$here/skills/vault-setup/adopt.md" 'Fill the frontmatter keys as steps 3 to 6 of `## project <name>` in `SKILL.md` say.'
file_has "vault-setup adopt: moves nothing under task_layout archive" "$here/skills/vault-setup/adopt.md" 'With `task_layout: archive`, the done tasks already there stay where they are.'
file_has "vault-setup adopt: names the task-layout check" "$here/skills/vault-setup/adopt.md" '`flat` project: `task-layout`.'
absent "vault-setup: no subproject mode" "$here/skills/vault-setup/subproject.md"
file_has "docs-keeper: the path task head prints wins" "$DK" 'The `path:` line wins over the path'
file_has "docs-keeper: a task is found at both depths" "$DK" '`<tasks_root>/archive/<YYYY>/<ID>/README.md` once'
file_has "docs-keeper: docs to update go into the README find names" "$DK" 'the path `second-brain find <ID> --project <project>` prints'
line_is "sprint close: exit 6 is a taken abandoned folder in a status project" "$CL" \
  '   - Exit 6, with `task_layout: status`: the folder `abandoned/<ID>` of a task in `--abandon` is'
line_is "sprint close: exit 6 wrote nothing, and the folder is the user's" "$CL" \
  '     taken, and nothing was written. Show that folder to the user: it is theirs to move away or'
line_is "sprint close: the call runs again once the folder is gone" "$CL" \
  '     delete. Then run the call again.'
line_is "sprint close: a status project's close moves each abandoned task" "$CL" \
  '   - With `task_layout: status`, the call also moves each task in `--abandon` into `abandoned/`.'
line_is "sprint close: the moved paths and links come after the summary" "$CL" \
  '     After the six summary lines it prints each moved task'"'"'s new README path and its `links:` lines.'
line_is "sprint close: a failed move is named on stderr" "$CL" \
  '   - A move that fails is named on stderr, and the call exits with its code. The sprint is closed'
line_is "sprint close: a closed sprint is never closed again" "$CL" \
  '     all the same: never run the call again. Tell the user the task and the reason:'
line_is "sprint close: the doctor moves the task later" "$CL" \
  '     `second-brain doctor --fix` moves it to `abandoned/` once the reason is handled.'
cl_e5="$(lineno "$CL" '5. Exit 5 names the problem')"
cl_e6="$(lineno "$CL" '   - Exit 6, with `task_layout: status`')"
cl_s6="$(lineno "$CL" '6. The same call closes the sprint note.')"
cl_mv="$(lineno "$CL" '   - With `task_layout: status`, the call also moves')"
cl_s7="$(lineno "$CL" '7. Add one status note per touched task')"
is "sprint close: exit 6 is under step 5 and the move under step 6" \
  "$((${cl_e5:-0} < ${cl_e6:-0} && ${cl_e6:-0} < ${cl_s6:-0} && ${cl_s6:-0} < ${cl_mv:-0} && ${cl_mv:-0} < ${cl_s7:-0}))" "1"
absent "scrum-master: the agent is gone" "$here/agents/scrum-master.md"
absent "scrum-master: the sprint skill is gone" "$here/skills/sprint"
line_is "contract: the search rule names a task note in a status folder" "$here/docs/contract.md" \
  '  `tasks/<ID>/README.md`, `tasks/<status>/<ID>/README.md` or `tasks/archive/<YYYY>/<ID>/README.md`'
line_is "contract: the search rule names a task note one group folder down" "$here/docs/contract.md" \
  '- A whole task note is also a `tasks/<folder>/<ID>/README.md` one group folder down, such as'
line_is "contract: in backlog/ or a sprint's folder" "$here/docs/contract.md" \
  '  `tasks/backlog/<ID>/README.md` or one in a sprint'"'"'s folder. The hook takes a status folder,'
line_is "contract: the hook takes a folder with no README of its own" "$here/docs/contract.md" \
  '  `backlog` or a folder with no `README.md` of its own, looked up in the letter case of the path.'
line_is "contract: a README in a folder inside a task is no task note" "$here/docs/contract.md" \
  '- A README in a folder inside a task, such as `tasks/<ID>/notes/README.md`, is no task note, and'
file_lacks "contract: the hook no longer takes any folder" "$here/docs/contract.md" 'The hook cannot see whether a folder'
file_has "index: an archived task's path" "$vault/CLAUDE.md" 'under `tasks/archive/<YYYY>/`'
file_has "index: a task names its repo" "$vault/CLAUDE.md" 'to the one repo it changes with the `repo` property.'
file_has "conventions: the short version names repo on a task" "$vault/obsidian-conventions.md" \
  '`branch` and `epic`, and `repo`, the one repo it changes, where the project has more'
line_is "conventions: repo is a repo second-brain repo lists" "$vault/obsidian-conventions.md" \
  '  - `repo` - the one repo it changes, as `second-brain repo <project>` lists it.'
VD="$here/skills/vault-doctor/SKILL.md"
file_has "vault-doctor fix: --fix repairs four checks" "$VD" 'repairs four checks only'
file_lacks "vault-doctor fix: no longer says three" "$VD" 'repairs three checks only'
file_has "vault-doctor fix: names the checks --fix repairs" "$VD" '`status-tag`, `pull-request`,'
file_has "vault-doctor checks: names the archive repair" "$here/skills/vault-doctor/checks.md" '`to-archive`: `second-brain doctor --fix` archives each one through `second-brain task archive <ID>`'
file_has "vault-doctor fix: a snapshot comes before an archive" "$VD" 'Then run `second-brain snapshot` before it.'
file_has "vault-doctor fix: compare proves the archive" "$VD" 'After an archive, run `second-brain compare` with that snapshot. It is the proof of the move.'
file_has "vault-doctor fix: an archive by --fix is a bulk change" "$VD" 'offenders makes the `--fix` run a bulk change: it moves'
file_has "vault-doctor fix: a foreign row lists every item, then takes one at a time" "$VD" \
  '7. A `foreign` row: run `second-brain link --foreign`, which lists every item. Take them one at'
file_has "vault-doctor fix: a foreign item is asked about with AskUserQuestion" "$VD" '- Ask the user with AskUserQuestion where it goes.'
file_has "vault-doctor fix: the answers are the vault, a project, or it stays" "$VD" \
  '- Options: the vault'"'"'s general `claude/`, the one or two projects of `second-brain projects`'
file_has "vault-doctor fix: nothing moves without the answer" "$VD" '- Nothing moves without that answer.'
file_has "vault-doctor fix: the move is link move, with --project for a project" "$VD" \
  '- Otherwise run `second-brain link move <skill or agent> <name>`, with `--project "<project>"`'
file_has "vault-doctor checks: the foreign fix points to the skill's fix steps" "$here/skills/vault-doctor/checks.md" \
  'as `## fix` in `skills/vault-doctor/SKILL.md` says. Nothing moves without the answer.'
file_has "vault-setup link: points to the doctor's foreign check" "$here/skills/vault-setup/SKILL.md" \
  '- The doctor'"'"'s `foreign` check warns on each skill or agent among them.'
file_has "vault-doctor fix: after a copy, asks whether to delete the original" "$VD" \
  '- A `copied:` line: the original stays where it was. Once the item'"'"'s row is `linked`, ask with'
file_has "vault-doctor fix: a yes runs link drop-original" "$VD" \
  '- On a yes, run `second-brain link drop-original <skill or agent> <name> "<path>"`. It removes'
file_has "vault-doctor fix: a no keeps the original and names it" "$VD" \
  'On a no, the original stays: name its path in the'
file_has "vault-doctor fix: an exit 5 is read for a message on the frontmatter name" "$VD" \
  '- Exit 5: read the message. Only one on the `name in its frontmatter`, missing or not the folder'
file_lacks "vault-doctor fix: not every exit 5 is read as a name problem" "$VD" '- Exit 5 on its frontmatter `name`'
file_has "vault-doctor fix: any other exit 5, and exit 1, show the message and stop" "$VD" \
  '- Any other exit 5, and exit 1: show the message and stop.'
file_has "vault-doctor fix: drop-original refusing keeps the original" "$VD" \
  '- `link drop-original` exits 1 or 5: show the message. The original stays: name its path.'
file_has "contract: the drop-original row names a path that holds the link directory" "$here/docs/contract.md" \
  'a path inside the vault or one that holds it, a path that holds the link directory, and a path'
file_has "contract: drop-original never removes a folder that holds the link directory" "$here/docs/contract.md" \
  '  included, or a folder that holds the link directory: each exits 5.'
file_has "contract: link move writes a block scalar description as -" "$here/docs/contract.md" \
  '- A `description` written as a block scalar, `>` or `|` with its text on the lines below, is `-`.'

# ---------------------------------------------------------------- the status layout in the contract, the conventions and the guide
CS="$here/docs/contract.md"
file_has "contract: task_layout takes status and sprint" "$CS" '- `task_layout` is `flat`, `archive`, `status` or `sprint`, in any letter case.'
file_lacks "contract: task_layout is no longer flat or archive alone" "$CS" '`task_layout` is `flat` or `archive`'
file_has "contract: a status project keeps a task in the folder of its status" "$CS" \
  '- `status`: each task sits in the folder of its status, `<tasks_root>/<status>/<ID>/`'
file_has "contract: a project turned to status runs doctor --fix once" "$CS" 'then run `doctor --fix` once'
file_has "contract: a status task's path" "$CS" 'a task is `<project>/<tasks_root>/<status>/<ID>/README.md`'
file_has "contract: a status change moves the folder" "$CS" '- There, a status change moves the task'"'"'s folder with `move`'
file_has "contract: the six folders are never a task, nor their names an id or alias" "$CS" 'None of the six is a task'
file_has "contract: a task that leaves the archive loses archived" "$CS" 'into a status folder loses the key'
file_has "contract: the board takes the status folders" "$CS" \
  'filter takes `<tasks_root>/<ID>/`, `<tasks_root>/<status>/<ID>/` in each of the five status'
file_has "contract: task set moves a status task" "$CS" \
  'moves the task'"'"'s folder with `move` to `<tasks_root>/<status>/<ID>/` once the keys are written'
file_has "contract: task new writes into planned" "$CS" 'In a status project the README is `<tasks_root>/planned/<ID>/README.md`'
file_has "contract: task new finds the id in any folder" "$CS" 'at `<tasks_root>/<ID>/`, `<tasks_root>/<status>/<ID>/` or archived'
file_has "contract: task new refuses a status folder's name" "$CS" '`In-Review is the folder of the in-review tasks, not a task id`'
file_has "contract: task alias refuses a status folder's name" "$CS" \
  'exit 5 for an alias that names the folder `archive` or a status folder, in any letter case'
TN="$(grep '^| `task new ' "$CS")"
TA="$(grep '^| `task alias ' "$CS")"
for want in '`archive`, in any letter case, keeps the message `archive is the folder of the archived tasks, not a task id`' \
  'a status folder'"'"'s name says `<ID> is the folder of the <status> tasks, not a task id`, with `<ID>` as typed and `<status>` lowercased'; do
  case "$TN" in *"$want"*) pass "contract: the task new row gives the message: $want" ;; *) fail "contract: the task new row gives the message: $want" "in: $TN" ;; esac
done
case "$TN" in *'not a task id`, the id as typed'*) fail "contract: the task new row no longer gives archive the status message" "in: $TN" ;; *) pass "contract: the task new row no longer gives archive the status message" ;; esac
for want in '`archive`, in any letter case, keeps the message `archive is the folder of the archived tasks, not a task alias`' \
  'a status folder'"'"'s name says `<alias> is the folder of the <status> tasks, not a task alias`, with `<alias>` as typed and `<status>` lowercased'; do
  case "$TA" in *"$want"*) pass "contract: the task alias row gives the message: $want" ;; *) fail "contract: the task alias row gives the message: $want" "in: $TA" ;; esac
done
file_has "contract: sprint close moves each abandoned task" "$CS" \
  'moves each task named in `--abandon` to `<tasks_root>/<status>/<ID>/` for its new status, `abandoned`'
file_has "contract: the board check names a board with no status filter" "$CS" '(`tasks.base:no-status-filter`)'
file_has "contract: no-readme reads the status folders" "$CS" 'one directly under a status folder'
file_has "contract: task-location takes a task in a status folder" "$CS" '`<tasks_root>/<status>/<ID>/README.md` in one of the five status folders'
file_has "contract: task-layout names a task out of its status folder" "$CS" '(`<ID>:<status>`; `--fix` moves it)'
file_has "contract: task-layout names a status folder in another layout" "$CS" '(`<status>:flat` or `<status>:archive`)'
file_has "contract: doctor --fix removes the archive's empty folders" "$CS" '`fixed: <path> -> removed (<project>)`'
file_has "contract: sb_task_files lists the status folders' tasks too" "$CS" \
  'task READMEs directly under it, in each of the five status folders and in the archive, and'
file_has "contract: sb_task_readme finds a task's README in any of them" "$CS" \
  '`sb_task_readme`, which finds one task folder'"'"'s README in any of them.'
file_lacks "contract: the lookup no longer names two depths alone" "$CS" 'task READMEs at both depths'
line_is "contract: the board template's placeholders take STATUS_DEPTH" "$CS" \
  '| `tasks.base.tmpl` | `<project>/tasks/tasks.base` | `TASKS_PATH`, `TASK_DEPTH`, `ARCHIVE_DEPTH`, `STATUS_DEPTH`, `CHILD_DEPTH`, `SPRINT_ID`, `PARENT_LABEL` |'
CV="$here/templates/obsidian-conventions.md.tmpl"
file_has "conventions: task_layout takes status and sprint" "$CV" '- The profile'"'"'s `task_layout` is `flat`, the default, `archive`, `status` or `sprint`.'
file_has "conventions: the short version names the status folders" "$CV" 'With `status`, each'
file_has "conventions: the path of a task in a status project" "$CV" '<project>/tasks/<status>/<TICKET-ID>/README.md'
file_has "conventions: task set moves a status task" "$CV" '`second-brain task set <ID> status=<status>` moves it to `tasks/<status>/<ID>/`'
file_has "conventions: a status edited in the board moves nothing" "$CV" 'the folder stays too, until `second-brain doctor --fix` moves it'
file_has "conventions: no task is named after a status folder" "$CV" '- No task is named `archive` or after a status folder.'
GS="$here/docs/guide.md"
line_is "guide: a section on the status folders" "$GS" '### Status folders'
file_has "guide: status keeps a task in the folder of its status" "$GS" '`task_layout: status` in the profile keeps each task in the folder of its status'
file_has "guide: task set moves the folder" "$GS" '`second-brain task set` moves the folder to `tasks/<status>/<ID>/`'
file_has "guide: a sprint close moves the tasks it abandons" "$GS" 'each task it abandons moves to `tasks/abandoned/<ID>/`'
file_has "guide: a project turned to status runs doctor --fix once" "$GS" 'then run `second-brain doctor --fix` once'

# ---------------------------------------------------------------- the sprint layout in the contract, the conventions, the guide and the templates
CS="$here/docs/contract.md"
line_is "contract: the project tree names a task in backlog/" "$CS" \
  '  tasks/backlog/<TICKET-ID>/README.md          a task in no sprint, with task_layout: sprint'
line_is "contract: the project tree names a task in a sprint's folder" "$CS" \
  '  tasks/<sprint folder>/<TICKET-ID>/README.md  a task in a sprint, with task_layout: sprint'
file_has "contract: sprint with sprints off is flat" "$CS" 'and so is `sprint` with `uses_sprints: false`.'
file_has "contract: a sprint project keeps a task in the folder of its sprint" "$CS" \
  '- `sprint`: each task sits in the folder of its sprint, `<tasks_root>/<sprint folder>/<ID>/`, or'
file_has "contract: or in backlog/ with no sprint, and moves when its sprint changes" "$CS" \
  'in `<tasks_root>/backlog/<ID>/` with no sprint, and moves when its sprint changes'
file_has "contract: sprint_folder is the pattern of a sprint's folder" "$CS" \
  '- `sprint_folder` is the pattern that names a sprint'"'"'s folder in the sprint layout.'
file_has "contract: no sprint_folder, or an empty one, is <end>" "$CS" \
  'empty key is `"<end>"`, so the folder of sprint `2026-10-14` is `2026-10-14`.'
file_has "contract: the three placeholders of the pattern" "$CS" \
  '- In the pattern, `<end>` is the sprint id, `<start>` its first day and `<n>` its number.'
file_has "contract: <start> of a sprint with no note is counted back from its id" "$CS" \
  '`sprint_length_days` plus one day, as `sprint open` counts it.'
file_has "contract: <n> counts the earlier sprint notes" "$CS" \
  '- `<n>` is one more than the count of the project'"'"'s sprint notes with an earlier id'
file_has "contract: a pattern that gives no folder name exits 5 with nothing written" "$CS" \
  'would move a task there exits 5 naming the pattern, and nothing is written.'
file_has "contract: what a folder name is" "$CS" \
  '- A folder name is letters, digits, dots, hyphens and underscores, neither a dot nor a hyphen'
file_has "contract: a project turned to sprint, or a renamed pattern, runs doctor --fix once" "$CS" \
  '- To turn `sprint` on for a project that has tasks, or after a change to `sprint_folder`, set'
file_has "contract: commands find a task in backlog/ and the group folders" "$CS" \
  '- Commands find a task directly under the tasks root, in a status folder, in `backlog` or another'
file_has "contract: a sprint task's path" "$CS" \
  '`<project>/<tasks_root>/<sprint folder>/<ID>/README.md`, in the folder that `sprint_folder`'
file_has "contract: a backlog task's path" "$CS" 'a task in no sprint is `<project>/<tasks_root>/backlog/<ID>/README.md`.'
file_has "contract: a sprint change moves the folder" "$CS" '- There, a sprint change moves the task'"'"'s folder with `move`'
file_has "contract: sprint open and close move the tasks they re-point, carry or send to the backlog" "$CS" \
  'moves each task it re-points, and `sprint close` moves each task it carries or sends to the'
file_has "contract: a status change moves nothing in a sprint project" "$CS" \
  '- A done or abandoned task stays in the folder of its sprint, and a status change moves nothing.'
file_has "contract: a folder with no README is a group folder" "$CS" \
  'directly under the tasks root with no `README.md` of its own is a group folder'
file_has "contract: backlog is never a task, nor its name an id or alias" "$CS" \
  '`backlog` is no task either, and its name, in any letter case, is no task id and no alias.'
file_has "contract: a task out of the archive into backlog/ or a sprint folder loses archived" "$CS" \
  'into `backlog` or a sprint'"'"'s folder.'
file_has "contract: the board's branch for a task in a group folder" "$CS" '- A last branch takes a task in a group folder'
file_has "contract: a sprint project's board without the branch is named" "$CS" \
  'in a sprint project, the doctor'"'"'s `board` check names one without it.'
OUT="$(grep '^| `find ' "$CS")"
out_has "contract: find looks in backlog/ and the group folders" 'in a status folder, in `backlog` or another group folder, or archived'
OUT="$(grep '^| `task set ' "$CS")"
out_has "contract: task set moves a sprint task when its sprint changes" \
  'In a sprint project, a `sprint` other than the task'"'"'s own, the last `sprint=` pair winning, moves the task'"'"'s folder'
out_has "contract: task set's destination is the sprint's folder, or backlog/ for none" \
  'to the folder of that sprint, `<tasks_root>/<sprint folder>/<ID>/`, or to `<tasks_root>/backlog/<ID>/` for `sprint=`'
out_has "contract: task set: there a status change moves nothing" 'there a status change moves nothing'
out_has "contract: task set: a sprint folder that is a task gives exit 6" '(`the sprint folder is a task: <path>`)'
out_has "contract: task set: a pattern that gives no folder name gives exit 5" \
  'Exit 5, writing nothing, when `sprint_folder` gives the sprint no folder name'
OUT="$(grep '^| `task new ' "$CS")"
out_has "contract: task new writes into backlog/ in a sprint project" 'and in a sprint project `<tasks_root>/backlog/<ID>/README.md`'
out_has "contract: task new finds the id in backlog/ or a sprint's folder" 'or archived, or in `backlog/` or a sprint'"'"'s folder ('
out_has "contract: task new refuses backlog" 'Exit 5 too for `backlog`, in any letter case: `backlog is the folder of the backlog tasks, not a task id`'
OUT="$(grep '^| `task alias ' "$CS")"
out_has "contract: task alias refuses backlog" 'Exit 5 too for `backlog`, in any letter case: `backlog is the folder of the backlog tasks, not a task alias`'
OUT="$(grep '^| `sprint open ' "$CS")"
out_has "contract: sprint open moves each task it re-points" \
  'In a sprint project each task it re-points then moves to the new sprint'"'"'s folder with `move`'
out_has "contract: sprint open looks at each destination first" 'or when that folder is a task (`the sprint folder is a task: <path>`)'
out_has "contract: sprint open: a task already in the folder is not moved" 'A task already in that folder is re-pointed and not moved'
OUT="$(grep '^| `sprint close ' "$CS")"
out_has "contract: sprint close moves each carried task to the next sprint's folder" \
  'In a sprint project it moves each task named in `--carry` to the next sprint'"'"'s folder'
out_has "contract: sprint close moves each backlog task to backlog/" 'each named in `--backlog` to `<tasks_root>/backlog/<ID>/`'
out_has "contract: sprint close leaves a done or abandoned task where it is" 'stays in the closed sprint'"'"'s folder'
out_has "contract: sprint close: a next sprint's folder that is a task gives exit 6" \
  'a carried task also gives exit 6 when the next sprint'"'"'s folder is a task'
OUT="$(grep '^| `doctor \[' "$CS")"
out_has "contract: doctor --fix moves each task to the folder of its sprint" \
  'In a sprint project it moves each task to the folder of its sprint, or to `backlog/` with none'
out_has "contract: doctor --fix removes each empty group folder, emptied by a move or not" \
  'then removes each empty group folder, a status folder too, whether or not a move emptied it,'
out_lacks "contract: doctor --fix: not only the folders a move emptied" 'group folder left empty'
OUT="$(grep '^| project | `board` ' "$CS")"
out_has "contract: the board check names a sprint project's board with no sprint filter" \
  'For a project with `task_layout: sprint`, a board whose own filters have no line'
out_has "contract: the board check's row for it" '(`tasks.base:no-sprint-filter`) (warn)'
OUT="$(grep '^| project | `no-readme` ' "$CS")"
out_has "contract: no-readme reads backlog/ and the group folders" 'one directly under a status folder, `backlog` or a group folder'
out_has "contract: no-readme: a group folder needs no README" 'neither does `backlog` or a group folder'
OUT="$(grep '^| project | `task-location` ' "$CS")"
out_has "contract: task-location takes a task in a group folder" \
  '`<tasks_root>/<folder>/<ID>/README.md` in `backlog` or another group folder'
OUT="$(grep '^| project | `task-layout` ' "$CS")"
out_has "contract: task-layout names a task out of the folder of its sprint" '(`<ID>:<folder>`, the folder it belongs in; `--fix` moves it)'
out_has "contract: task-layout names a pattern that gives no folder name" '(`sprint_folder:invalid`)'
out_has "contract: task-layout names sprint with sprints off" '(`task_layout:no-sprints`'
out_has "contract: task-layout names a group folder in another layout" '(`<folder>:<layout>`'
out_has "contract: such as backlog/ in a flat project" '`backlog:flat`'
file_has "contract: the lookup goes through the group folders of sb_task_groups" "$CS" \
  '- Both also look in each group folder that `sb_task_groups` lists'
CV="$here/templates/obsidian-conventions.md.tmpl"
cv_version="$(sed -n 's/^conventions_version: *//p' "$CV" | head -1)"
is "conventions: the repo key and the retired subprojects raise conventions_version to 12" "$cv_version" "12"
file_lacks "conventions: no delivery key, as the spec flow is retired" "$CV" "delivery"
file_lacks "conventions: no spec note type" "$CV" '`spec`'
file_has "conventions: the short version names the sprint folders" "$CV" 'With `sprint`,'
line_is "conventions: the path of a task in backlog/" "$CV" \
  '<project>/tasks/backlog/<TICKET-ID>/README.md          # a task in no sprint, in the sprint layout'
line_is "conventions: the path of a task in a sprint's folder" "$CV" \
  '<project>/tasks/<sprint folder>/<TICKET-ID>/README.md  # a task, in the folder of its sprint'
file_has "conventions: the sprint folder is named by sprint_folder" "$CV" 'named by the profile'"'"'s `sprint_folder`'
file_has "conventions: task set moves a sprint task" "$CV" '`second-brain task set <ID> sprint=<id>` moves it'
file_has "conventions: no task is named backlog" "$CV" 'None is named `backlog` either.'
file_has "conventions: a sprint edited in the board moves nothing" "$CV" '- With `sprint`, a sprint edited in the board moves nothing'
line_is "guide: a section on the sprint folders" "$GS" '### Sprint folders'
file_has "guide: sprint keeps a task in the folder of its sprint" "$GS" \
  '`task_layout: sprint` in the profile keeps each task in the folder of its sprint'
file_has "guide: a new story starts in backlog/" "$GS" '- A new story starts in `tasks/backlog/<ID>/`.'
file_has "guide: sprint_folder names a sprint's folder" "$GS" 'A sprint'"'"'s folder is named by `sprint_folder` in the profile'
file_has "guide: task set moves the folder when the sprint changes" "$GS" \
  '`second-brain task set` moves the folder to that sprint'"'"'s folder'
file_has "guide: a sprint close moves the carried and backlog tasks" "$GS" \
  'each carried task moves to the next sprint'"'"'s folder'
file_has "guide: doctor --fix moves a sprint edited in the board" "$GS" \
  'A sprint edited in the board moves nothing: `second-brain doctor --fix` moves each task to the'
VI="$here/templates/vault-index.md.tmpl"
line_is "index template: a task note's place names the sprint folders" "$VI" \
  '  With `task_layout: sprint`, it is under the folder of its sprint, or `tasks/backlog/` in none.'

# ---------------------------------------------------------------- the status layout in the skill text and the changelog
ST="$here/skills/story-tracker/SKILL.md"
line_is "story-tracker: task_layout takes status and sprint" "$ST" \
  '   - `task_layout` is `flat`, `archive`, `status` or `sprint`. A profile with no such line is'
file_lacks "story-tracker: task_layout is no longer flat or archive alone" "$ST" '`task_layout` is `flat` or `archive`'
line_is "story-tracker: a status project's folder follows the status, with nothing to archive" "$ST" \
  '   - With `status`, a story'"'"'s folder follows its status, so there is nothing to archive and'
line_is "story-tracker: nothing to ask, as task set moves the folder" "$ST" \
  '     nothing to ask: `second-brain task set` moves it to `<tasks_root>/<status>/<ID>/`.'
line_is "story-tracker: an archived story set back in a status project is moved already" "$ST" \
  '  - With `task_layout: status`, `task set` has moved it already: ask nothing.'
line_is "story-tracker: a status project's story path is the one find prints" "$ST" \
  '  - An archived story'"'"'s path, or one in a `status` project, is the one `find` prints.'
# check_line <check> <field>: the Means, Why or Fix line of one entry of checks.md.
check_line() {
  awk -v h="### $1" -v f="- $2: " '/^### / { on = ($0 == h) } on && index($0, f) == 1 { print; exit }' \
    "$here/skills/vault-doctor/checks.md"
}
OUT="$(check_line board Means)"
out_has "checks board: names a status project's board with no status filter" \
  'the project has `task_layout: status` and the board'"'"'s own `filters` block does not take each of the five status folders (`tasks.base:no-status-filter`)'
OUT="$(check_line board Why)"
out_has "checks board: says why the status filter matters" 'Without the status filter, Obsidian shows no task in a status folder'
OUT="$(check_line board Fix)"
out_has "checks board: the status filter's fix" '`no-status-filter`: replace the `filters` block as for `no-archive-filter`'
out_has "checks board: STATUS_DEPTH is one more than TASK_DEPTH" '`{{STATUS_DEPTH}}` the `{{TASK_DEPTH}}` number plus 1'
OUT="$(check_line no-readme Means)"
out_has "checks no-readme: the status folders are no task folder" 'other than `archive` and the five status folders'
out_has "checks no-readme: reads each folder under a status folder" 'one directly under a status folder'
out_has "checks no-readme: a status folder needs no README" 'A status folder itself never needs a README, in every layout.'
OUT="$(check_line no-readme Fix)"
out_has "checks no-readme: a folder under a status folder is moved where task new writes" \
  'A folder under a status folder: `task new` writes into `<tasks root>/<ID>/`, or `<tasks root>/planned/<ID>/` in a status project'
out_has "checks no-readme: then task set moves it to the folder of its status" \
  '`second-brain task set <ID> status=<status>` then moves it to the folder of its status'
OUT="$(check_line task-location Means)"
out_has "checks task-location: a task's place in a status folder" '`<tasks root>/<status>/<ID>/README.md` in one of the five status folders'
OUT="$(check_line task-location Fix)"
out_has "checks task-location: a status project's task goes to the folder of its status" \
  'In a status project, move it to `<project path>/<tasks root>/<status>/<ID>/README.md`'
OUT="$(check_line task-layout Means)"
out_has "checks task-layout: a status folder in another layout" '(`<status>:flat` or `<status>:archive`'
out_has "checks task-layout: a task out of the folder of its status" '(`<ID>:<status>`'
out_has "checks task-layout: a task in a status project's archive" '(`archive:status`)'
out_has "checks task-layout: no status of the five is needs-a-status's" 'is left to `needs-a-status`'
OUT="$(check_line task-layout Why)"
out_has "checks task-layout: says why a status project's folders matter" 'With `status`, the folder shows a task'"'"'s status'
OUT="$(check_line task-layout Fix)"
out_has "checks task-layout: doctor --fix moves a task to the folder of its status" \
  '`<ID>:<status>` and `archive:status`: `second-brain doctor --fix` moves each task to the folder of its status'
out_has "checks task-layout: and removes the archive's empty folders" 'then removes the archive'"'"'s empty folders'
out_has "checks task-layout: a status folder in another layout asks first" '`<status>:flat` or `<status>:archive`: ask whether'
out_has "checks task-layout: on a yes the profile takes status" 'set `task_layout: status` in the profile'
AD="$here/skills/vault-setup/adopt.md"
line_is "vault-setup adopt: a status project's tasks wait for doctor --fix" "$AD" \
  '- With `task_layout: status`, the tasks already there stay where they are until'
line_is "vault-setup adopt: doctor --fix runs once" "$AD" \
  '  `second-brain doctor <project> --fix` runs once. The doctor'"'"'s `task-layout` row names each task'
file_has "vault-setup adopt: the run is a bulk move, made on a yes" "$AD" '- Offer that run, as a bulk move, and make it only on a yes:'
file_has "vault-setup adopt: a task's place in a status folder" "$AD" '`<tasks_root>/<status>/<ID>/README.md` in a status'
VS="$here/skills/vault-setup/SKILL.md"
line_is "vault-setup: the task_layout row offers status and sprint" "$VS" \
  '   | `task_layout` | whether a done or abandoned task moves once to `<tasks_root>/archive/<YYYY>/<ID>/`, every task stays in its folder, each task lives in `<tasks_root>/<status>/<ID>/` and moves when its status changes, or each task lives in the folder of its sprint, or `<tasks_root>/backlog/<ID>/` in none, and moves when its sprint changes | `archive`, `flat`, `status` or `sprint` |'
file_lacks "vault-setup: task_layout is no longer archive or flat alone" "$VS" '| `archive` or `flat` |'
VD="$here/skills/vault-doctor/SKILL.md"
line_is "vault-doctor fix: a status move by --fix is a bulk change" "$VD" \
  '   - So does a row with `<ID>:<status>` or `archive:status` offenders, in a status project:'
line_is "vault-doctor fix: --fix moves each task to the folder of its status" "$VD" \
  '     `--fix` moves each task to the folder of its status.'
line_is "vault-doctor fix: names the tasks it will archive or move" "$VD" \
  '   - Say how many tasks it will archive or move, and name them: each `<ID>:to-archive` or'
line_is "vault-doctor fix: the tasks are the to-archive and status offenders" "$VD" '     `<ID>:<status>` offender.'
file_lacks "vault-doctor fix: no longer counts the archive alone" "$VD" 'Say how many tasks it will archive, the row'"'"'s count'
line_is "vault-doctor fix: the number is the row's count, less what is no task it moves" "$VD" \
  '   - The number is the row'"'"'s count, less each offender that is not a task it moves:'
line_is "vault-doctor fix: archive:status is no task, as its task is counted already" "$VD" \
  '     `archive:status`, whose task the row counts as `<ID>:<status>` too, and in an archive'
line_is "vault-doctor fix: nor the archive project's offenders --fix leaves" "$VD" \
  '     project `<ID>:open`, `archive_after_days:not-a-number` and `<status>:archive`.'
line_is "vault-doctor fix: over five, the doctor names only the first five" "$VD" \
  '   - The count is above five: say that the doctor names only the first five, and name those. The'
line_is "vault-doctor fix: over five, the count is the most it moves and fixed: names each" "$VD" \
  '     count is then the most it will move, and the `fixed:` lines of step 4 name every task moved.'
vd_name="$(lineno "$VD" '- Say how many tasks it will archive or move')"
vd_num="$(lineno "$VD" '- The number is the row'"'"'s count')"
vd_five="$(lineno "$VD" '- The count is above five')"
vd_snap="$(lineno "$VD" 'Then run `second-brain snapshot` before it.')"
is "vault-doctor fix: the number and the five come after the names and before the snapshot" \
  "$((${vd_name:-0} < ${vd_num:-0} && ${vd_num:-0} < ${vd_five:-0} && ${vd_five:-0} < ${vd_snap:-0}))" "1"
line_is "vault-doctor fix: compare proves a status move too" "$VD" \
  '   - After a move to the folders of their status, run it too. It lists the aliases of each moved'
line_is "vault-doctor fix: the aliases go under the status folders" "$VD" \
  '     task folder as removed at the old path and added under `<status>/`, and nothing else.'
vd_arch="$(lineno "$VD" '`archive/<YYYY>/`, and nothing else.')"
vd_move="$(lineno "$VD" '- After a move to the folders of their status')"
vd_broke="$(lineno "$VD" '- An `unresolved added:` line')"
is "vault-doctor fix: the status move's compare comes after the archive's and before the broken-link line" \
  "$((${vd_arch:-0} < ${vd_move:-0} && ${vd_move:-0} < ${vd_broke:-0}))" "1"
VI="$here/templates/vault-index.md.tmpl"
line_is "index template: a task note's place names the status folders" "$VI" \
  '  once archived, or under `tasks/<status>/` in a project with `task_layout: status`.'
vi_version="$(sed -n 's/^index_version: *//p' "$VI" | head -1)"
is "index template: the retired subprojects raise index_version to 10" "$vi_version" "10"
line_is "contract: the index example is at the template's version" "$here/docs/contract.md" "index_version: $vi_version"
line_is "docs-keeper: a task's place names the status folders" "$DK" \
  '- A task is `<tasks_root>/<ID>/README.md`, `<tasks_root>/<status>/<ID>/README.md` with'
line_is "docs-keeper: in a status project, or archived" "$DK" \
  '  `task_layout: status`, or `<tasks_root>/archive/<YYYY>/<ID>/README.md` once archived.'
CG="$here/CHANGELOG.md"
file_has "changelog: the index template is at version 6" "$CG" 'The plugin'"'"'s index template is now at `index_version: 6`'
file_has "changelog: the status layout" "$CG" '- A project can keep each task in the folder of its status:'
file_has "changelog: the index's status line" "$CG" \
  '- The vault index and docs-keeper name `tasks/<status>/` as a task'"'"'s place'
file_has "changelog: the search rule's status line" "$CG" \
  '- The search rule warns on a whole Read of a task note in a status folder too.'
cv_line="$(lineno "$CG" '- The conventions note is at version 8: it names the status layout.')"
cv_text="$(awk -v n="${cv_line:-0}" 'n && NR == n { t = $0; next } n && NR > n && !d && /^  / { t = t " " substr($0, 3); next } NR > n { d = 1 } END { print t }' "$CG")"
case "$cv_text" in
  *'The doctor'"'"'s `conventions` check warns about an older note.'*) pass "changelog: the version 8 line says the doctor warns on an older note" ;;
  *) fail "changelog: the version 8 line says the doctor warns on an older note" "in: $cv_text" ;;
esac
file_has "changelog: the sprint layout" "$CG" '- A project can keep each task in the folder of its sprint:'
file_has "changelog: sprint_folder" "$CG" '- `sprint_folder` in the profile names a sprint'"'"'s folder'
file_has "changelog: the conventions note at version 9" "$CG" \
  '- The conventions note is at version 9: it names the sprint layout. The doctor'"'"'s `conventions`'
file_has "changelog: the index's sprint line" "$CG" \
  '- The vault index names the sprint folders as a task'"'"'s place in a sprint project.'
file_has "changelog: the index template is at version 7" "$CG" 'index template is now at `index_version: 7`'
file_has "changelog: set index_version 7 once the task line is copied" "$CG" 'then set `index_version: 7`.'
file_has "changelog: a pattern with no folder name" "$CG" \
  '  `docs/contract.md` says. A pattern that gives a sprint no folder name makes each command that'
file_has "changelog: task new and task set in a sprint project" "$CG" \
  '- In a sprint project, `second-brain task new` writes a task into `backlog/`. `task set` with a'
file_has "changelog: task set's exit 6" "$CG" \
  'destination or the sprint'"'"'s folder is a task. A status change moves nothing.'
file_has "changelog: sprint open and sprint close moves" "$CG" \
  '- `sprint open` moves each task it re-points to the new sprint'"'"'s folder. `sprint close` moves each'
file_has "changelog: done and abandoned tasks stay" "$CG" \
  'done and abandoned tasks stay in the closed sprint'"'"'s folder.'
file_has "changelog: the lookup in backlog/ and the group folders" "$CG" \
  '- Commands find a task in `backlog/` and in every group folder, in every layout: a folder directly'
file_has "changelog: task new and task alias refuse backlog" "$CG" \
  '`task new` and `task alias` exit 5 for `backlog`, in any letter case, as they do for `archive`.'
file_has "changelog: the board's group folder branch" "$CG" \
  '- A new board'"'"'s filters take a task in a group folder. An existing board is not rewritten: in a'
file_has "changelog: tasks.base:no-sprint-filter" "$CG" \
  '  sprint project, the doctor'"'"'s `board` check warns on one without that branch,'
file_has "changelog: no-readme and task-location" "$CG" \
  '- The doctor'"'"'s `no-readme` check reads each folder under `backlog/` and a group folder, and'
file_has "changelog: task-layout's sprint rows" "$CG" \
  '  folder of its sprint or `backlog/` (`<ID>:<folder>`), a `sprint_folder` that gives no folder'
file_has "changelog: sprint_folder:invalid and task_layout:no-sprints" "$CG" \
  '  name (`sprint_folder:invalid`), `task_layout: sprint` with sprints off (`task_layout:no-sprints`),'
file_has "changelog: <folder>:<layout>" "$CG" \
  '  and a group folder that holds a task in another layout (`<folder>:<layout>`, as `backlog:flat`).'
file_has "changelog: doctor --fix in a sprint project" "$CG" \
  '- In a sprint project, `doctor --fix` moves each task to the folder of its sprint, or to'
file_has "changelog: turning the layout on with doctor --fix once" "$CG" \
  '  `sprint_folder`, set the key, then run `doctor --fix` once.'
file_has "changelog: the search rule's sprint line" "$CG" \
  '- The search rule warns on a whole Read of a task note in `backlog/` or a sprint'"'"'s folder too.'
file_lacks "changelog: the sprint layout line describes, not points" "$CG" \
  '`## 4. A task` in `docs/contract.md` and `### Sprint folders` in `docs/guide.md` say how.'
OUT="$(check_line unresolved-links Fix)"
out_has "checks unresolved-links: a task's link takes the path find prints" \
  'A task'"'"'s path is the one `second-brain find <ID> --project <project>` prints, written without `.md`: `[[<the path find prints, no .md>|EX-123]]`'
out_lacks "checks unresolved-links: the fix no longer builds the flat path" '/tasks/EX-123/README|'
RM="$here/README.md"
line_is "README: a ticket's note, in a flat project" "$RM" \
  '  stands. Each ticket is one note, `<project>/tasks/<ID>/README.md`, or'
line_is "README: a ticket's note, in a status project" "$RM" \
  '  `<project>/tasks/<status>/<ID>/README.md` in a project that keeps each task in the folder of its'
line_is "README: the first story's note, in a status project" "$RM" \
  '`<project>/tasks/EX-123/README.md`, or `<project>/tasks/planned/EX-123/README.md`'
line_is "contract: a depends_on link holds the README's vault path" "$here/docs/contract.md" \
  '  - "[[<vault path of its README, no .md>|<other ID>]]"'
file_lacks "contract: a depends_on link no longer builds the flat path" "$here/docs/contract.md" \
  '[[<project>/<tasks_root>/<other ID>/README|'

# ---------------------------------------------------------------- the sprint layout in the skills, the agents and the changelog
ST="$here/skills/story-tracker/SKILL.md"
line_is "story-tracker: sprint with sprints off is flat" "$ST" \
  '     `flat`, and so is `sprint` with `uses_sprints: false`.'
line_is "story-tracker: a sprint project's folder follows its sprint, with nothing to archive" "$ST" \
  '   - With `sprint`, a story'"'"'s folder follows its sprint, so there is nothing to archive and'
file_has "story-tracker: a new story is in backlog/" "$ST" 'A new story is in `<tasks_root>/backlog/<ID>/`;'
file_has "story-tracker: task set moves a story to the folder of its sprint" "$ST" \
  '`second-brain task set <ID> sprint=<id>` moves it to the folder of that sprint, and'
line_is "story-tracker: a status change moves nothing in a sprint project" "$ST" \
  '     `sprint=` back to `backlog/`. A status change moves nothing.'
line_is "story-tracker: an archived story in a sprint project is left to the doctor" "$ST" \
  '  - With `task_layout: sprint`, ask nothing and move nothing: the doctor'"'"'s `task-layout` row'
line_is "story-tracker: doctor --fix moves it to the folder of its sprint" "$ST" \
  '    names it, and `second-brain doctor --fix` moves it to the folder of its sprint, or `backlog/`.'
line_is "story-tracker: a sprint project's story path is the one find prints" "$ST" \
  '  - So is one in a `sprint` project, which changes when the story'"'"'s sprint does.'
line_is "docs-keeper: a task's place names the sprint folders" "$DK" \
  '  With `task_layout: sprint`, it is `<tasks_root>/<sprint folder>/<ID>/README.md` in a sprint,'
line_is "docs-keeper: or backlog/ in none" "$DK" '  or `<tasks_root>/backlog/<ID>/README.md` in none.'
CL="$here/skills/scrum-master/sprint-planning.md"
line_is "sprint close: exit 6 is a taken destination in a sprint project" "$CL" \
  '   - Exit 6, with `task_layout: sprint`: the folder a task in `--carry` or `--backlog` moves to is'
line_is "sprint close: or the next sprint's folder is a task" "$CL" \
  '     taken, or the next sprint'"'"'s folder is a task, and nothing was written. Show that path to the'
line_is "sprint close: exit 5 names the sprint_folder pattern" "$CL" \
  '   - Exit 5 that names the `sprint_folder` pattern, with `task_layout: sprint`: it gives the next'
line_is "sprint close: a sprint project's close moves the carried and backlog tasks" "$CL" \
  '   - With `task_layout: sprint`, it moves each task in `--carry` to the next sprint'"'"'s folder and'
file_has "sprint close: done, abandoned and --abandon tasks stay" "$CL" \
  'task, and one in `--abandon`, stays in the closed sprint'"'"'s folder.'
line_is "sprint close: the doctor moves a failed move later, in a sprint project" "$CL" \
  '     In a sprint project it moves it to the next sprint'"'"'s folder, or `backlog/`, instead.'
cl_s5="$(lineno "$CL" '5. Exit 5 names the problem')"
cl_sp6="$(lineno "$CL" '   - Exit 6, with `task_layout: sprint`')"
cl_sp5="$(lineno "$CL" '   - Exit 5 that names the `sprint_folder` pattern, with `task_layout: sprint`')"
cl_s6="$(lineno "$CL" '6. The same call closes the sprint note.')"
cl_spmv="$(lineno "$CL" '   - With `task_layout: sprint`, it moves each task')"
cl_s7="$(lineno "$CL" '7. Add one status note per touched task')"
is "sprint close: a sprint project's exits are under step 5 and its moves under step 6" \
  "$((${cl_s5:-0} < ${cl_sp6:-0} && ${cl_sp6:-0} < ${cl_sp5:-0} && ${cl_sp5:-0} < ${cl_s6:-0} && ${cl_s6:-0} < ${cl_spmv:-0} && ${cl_spmv:-0} < ${cl_s7:-0}))" "1"
VS="$here/skills/vault-setup/SKILL.md"
line_is "vault-setup: no sprints offers no sprint layout" "$VS" '     no `sprint` for `task_layout`.'
file_has "vault-setup: the sprint_folder row" "$VS" \
  '| `sprint_folder` | with `sprint` only: how a sprint'"'"'s folder is named, its end date with none, or a pattern of `<end>`, `<start>` and `<n>`'
AD="$here/skills/vault-setup/adopt.md"
line_is "vault-setup adopt: a sprint project's tasks wait for doctor --fix" "$AD" \
  '- With `task_layout: sprint`, the tasks already there stay where they are until'
line_is "vault-setup adopt: the row names each task outside the folder of its sprint" "$AD" \
  '  outside the folder of its sprint, or `backlog/` with no sprint.'
file_has "vault-setup adopt: the run removes each empty group folder" "$AD" \
  'It also removes each empty group folder, a status folder too,'
line_is "vault-setup adopt: whether or not a move emptied it" "$AD" '  whether or not a move emptied it.'
file_lacks "vault-setup adopt: not only the folders a move emptied" "$AD" 'group folder it leaves empty'
file_has "vault-setup adopt: a task's place in backlog/ or a group folder" "$AD" \
  '`<tasks_root>/<folder>/<ID>/README.md` in `backlog/` or another group folder'
OUT="$(check_line board Means)"
out_has "checks board: names a sprint project's board with no group folder branch" \
  'the project has `task_layout: sprint`, with sprints on, and the board'"'"'s own `filters` block has no line `file.folder.split("/")[<digits>] == aliases[0]`'
out_has "checks board: the row for it" '(`tasks.base:no-sprint-filter`)'
OUT="$(check_line board Why)"
out_has "checks board: says why the group folder branch matters" \
  'Without the group folder branch, Obsidian shows no task in `backlog/` or a sprint'"'"'s folder'
OUT="$(check_line board Fix)"
out_has "checks board: the sprint filter's fix" '`no-sprint-filter`: the same replacement'
OUT="$(check_line no-readme Means)"
out_has "checks no-readme: backlog and a group folder are no task folder" '`backlog` and a group folder;'
out_has "checks no-readme: reads each folder under backlog/ or a group folder" \
  'one directly under a status folder, `backlog` or a group folder'
out_has "checks no-readme: what a group folder is" \
  'A group folder is, in a sprint project, each folder directly under the tasks root with no README'
out_has "checks no-readme: backlog/ and a group folder need no README" 'Neither does `backlog` or a group folder.'
OUT="$(check_line no-readme Fix)"
out_has "checks no-readme: task new writes into backlog/ in a sprint project" \
  'or `<tasks root>/backlog/<ID>/` in a sprint project'
out_has "checks no-readme: then task set moves it to the folder of its sprint" \
  '`second-brain task set <ID> sprint=<id>`, with the sprint the user names, then moves it to the folder of that sprint'
OUT="$(check_line task-location Means)"
out_has "checks task-location: a task's place in backlog/ or a group folder" \
  '`<tasks root>/<folder>/<ID>/README.md` in `backlog` or another group folder'
OUT="$(check_line task-location Fix)"
out_has "checks task-location: a sprint project's task goes to backlog/" \
  'In a sprint project, move it to `<project path>/<tasks root>/backlog/<ID>/README.md`'
out_has "checks task-location: then the doctor moves it to the folder of its sprint" \
  '`second-brain doctor --fix` moves it to the folder of its sprint'
OUT="$(check_line task-layout Means)"
out_has "checks task-layout: a group folder in another layout" '(`<folder>:<layout>`, as `backlog:flat` or `2026-10-14:status`)'
out_has "checks task-layout: sprint with sprints off" '(`task_layout:no-sprints`)'
out_has "checks task-layout: a task out of the folder of its sprint" '(`<ID>:<folder>`'
out_has "checks task-layout: a pattern that gives no folder name" '(`sprint_folder:invalid`)'
OUT="$(check_line task-layout Why)"
out_has "checks task-layout: says why a sprint project's folders matter" 'With `sprint`, the folder shows a task'"'"'s sprint'
OUT="$(check_line task-layout Fix)"
out_has "checks task-layout: doctor --fix moves a task to the folder of its sprint" \
  '`<ID>:<folder>`: `second-brain doctor --fix` moves each task to the folder of its sprint, or to `backlog/` with none'
out_has "checks task-layout: and removes each empty group folder, emptied by a move or not" \
  'then removes each empty group folder, a status folder too, whether or not a move emptied it'
out_lacks "checks task-layout: not only the folders a move emptied" 'group folder it leaves empty'
out_has "checks task-layout: an invalid pattern is the user's to fix" '`sprint_folder:invalid`: ask the user for a pattern'
out_has "checks task-layout: no-sprints asks whether the project runs sprints" \
  '`task_layout:no-sprints`: ask whether the project runs sprints'
out_has "checks task-layout: on a yes the profile takes sprint" \
  'set `task_layout: sprint` in the profile, with `uses_sprints: true` when sprints are off'
VD="$here/skills/vault-doctor/SKILL.md"
line_is "vault-doctor fix: a sprint move by --fix is a bulk change" "$VD" \
  '   - So does a row with `<ID>:<folder>` offenders, in a sprint project: `--fix` moves each task to'
line_is "vault-doctor fix: names each <ID>:<folder> offender" "$VD" \
  '   - In a sprint project, name each `<ID>:<folder>` offender, with the folder it moves to.'
line_is "vault-doctor fix: an archive project's <folder>:archive is no task" "$VD" \
  '   - In an archive project, a `<folder>:archive` offender, such as `backlog:archive`, is no task'
vd_far="$(lineno "$VD" '- In an archive project, a `<folder>:archive` offender')"
is "vault-doctor fix: <folder>:archive comes after the archive project's list and before the five" \
  "$((${vd_num:-0} < ${vd_far:-0} && ${vd_far:-0} < ${vd_five:-0}))" "1"
line_is "vault-doctor fix: a sprint project's --fix removes each empty group folder" "$VD" \
  '   - In a sprint project, every `--fix` run also removes each empty group folder, a status folder'
line_is "vault-doctor fix: a sprint project's empty folders directly under the tasks root" "$VD" \
  '     too, whether or not a move emptied it: each empty folder directly under the tasks root. An'
line_is "vault-doctor fix: an empty folder inside one stays, said before the run" "$VD" \
  '     empty folder inside one, such as `backlog/<ID>/`, stays. Say so before it runs.'
file_lacks "vault-doctor fix: not only the folders a move emptied" "$VD" 'group folder it leaves empty'
line_is "vault-doctor fix: sprint_folder:invalid is no task" "$VD" \
  '   - In a sprint project, `sprint_folder:invalid` is no task either. In a status project, neither'
line_is "vault-doctor fix: compare proves a sprint move too" "$VD" \
  '   - After a move to the folders of their sprint, run it too. It lists the aliases of each moved'
vd_sname="$(lineno "$VD" '- In a sprint project, name each')"
vd_smove="$(lineno "$VD" '- After a move to the folders of their sprint')"
is "vault-doctor fix: the sprint names come after the others and before the snapshot" \
  "$((${vd_name:-0} < ${vd_sname:-0} && ${vd_sname:-0} < ${vd_snap:-0}))" "1"
is "vault-doctor fix: the sprint move's compare comes after the status move's and before the broken-link line" \
  "$((${vd_move:-0} < ${vd_smove:-0} && ${vd_smove:-0} < ${vd_broke:-0}))" "1"
file_has "changelog: story-tracker asks nothing in a sprint project" "$CG" \
  'Nothing is archived, and story-tracker asks'
file_has "changelog: the sprint skill and scrum-master" "$CG" \
  'sprint skill and scrum-master say what a sprint project'"'"'s close moves'
file_has "changelog: docs-keeper names the sprint folders" "$CG" \
  '- docs-keeper names `tasks/backlog/` and the sprint folders as a task'"'"'s place in a sprint'
file_has "changelog: vault-setup offers the sprint layout" "$CG" \
  '`vault-setup project` and `adopt` offer `task_layout: sprint`'
file_has "changelog: vault-doctor fix counts a sprint project's moves" "$CG" \
  '- The vault-doctor `fix` mode counts a sprint project'"'"'s moves as a bulk change'
RM="$here/README.md"
line_is "README: a ticket's note, in a sprint project" "$RM" \
  '  status. A project that keeps each task in the folder of its sprint has it at'
line_is "README: in a sprint's folder, or backlog/ in none" "$RM" \
  '  `<project>/tasks/<sprint folder>/<ID>/README.md`, or `<project>/tasks/backlog/<ID>/README.md`'
line_is "README: the first story's note, in a sprint project" "$RM" \
  '`<project>/tasks/backlog/EX-123/README.md` in one that keeps it in the folder of its sprint, with a'
SP="$here/skills/scrum-master/sprint-planning.md"
SPP="$here/skills/scrum-master/sprint-planning.md"
line_is "sprint open: exit 6 names a taken destination in a sprint project" "$SP" \
  '   - Exit 6 with `the destination exists: <path>` or `the sprint folder is a task: <path>`, in a'
line_is "sprint open: the folder a re-pointed task moves to, with nothing written" "$SP" \
  '     project with `task_layout: sprint`: the folder a re-pointed task moves to is taken, and'
line_is "sprint open: exit 5 names the sprint_folder pattern" "$SP" \
  '   - Exit 5 that names the `sprint_folder` pattern: it gives the new sprint no folder name, and'
line_is "sprint open: each re-pointed task moves in a sprint project" "$SP" \
  '   - With `task_layout: sprint`, each re-pointed task also moves to the new sprint'"'"'s folder. After'
line_is "sprint open: a failed move leaves the sprint open" "$SP" \
  '   - A move that fails is named on stderr, and the call exits with its code. The sprint is open'
line_is "sprint open: the doctor moves the task later" "$SP" \
  '     `second-brain doctor --fix` moves it to the folder of its sprint once the reason is handled.'
line_is "sprint pick: task set moves the folder in a sprint project" "$SPP" \
  '   - With `task_layout: sprint`, each call also moves the task'"'"'s folder, to the sprint'"'"'s folder or'
line_is "sprint pick: exit 6 there, as in open" "$SPP" \
  '   - Exit 6 there, as in open: the destination is taken, or the sprint'"'"'s folder is a task, and'
line_is "sprint pick: a failed move keeps the sprint written" "$SPP" \
  '   - A move that fails exits as `second-brain move` does, with the sprint written:'
sp_o6="$(lineno "$SP" '6. Run `second-brain sprint open')"
sp_oe6="$(lineno "$SP" '   - Exit 6 with `the destination exists: <path>`')"
sp_o7="$(lineno "$SP" '7. Report the note it created')"
sp_omv="$(lineno "$SP" '   - With `task_layout: sprint`, each re-pointed task')"
sp_o8="$(lineno "$SP" '8. A goal given or changed later')"
sp_p5="$(lineno "$SPP" '5. Set each answer:')"
sp_pmv="$(lineno "$SPP" '   - With `task_layout: sprint`, each call also moves')"
sp_p6="$(lineno "$SPP" '6. A task that does not exist yet')"
is "sprint open: the exits are under step 6 and the moves under step 7" \
  "$((${sp_o6:-0} < ${sp_oe6:-0} && ${sp_oe6:-0} < ${sp_o7:-0} && ${sp_o7:-0} < ${sp_omv:-0} && ${sp_omv:-0} < ${sp_o8:-0}))" "1"
is "sprint pick: the moves are under step 5" "$((${sp_p5:-0} < ${sp_pmv:-0} && ${sp_pmv:-0} < ${sp_p6:-0}))" "1"
file_has "changelog: the sprint skill's open and plan moves" "$CG" \
  'The sprint skill says the same of `sprint open` and of setting a task'"'"'s sprint in plan.'
file_has "changelog: doctor --fix removes each empty group folder" "$CG" \
  '  `backlog/` with none, then removes each empty group folder, a status folder too, whether or not'
file_lacks "changelog: doctor --fix: not only the folders a move emptied" "$CG" 'group folder it leaves empty'
file_has "guide: doctor --fix removes each empty group folder" "$GS" \
  'It also removes each empty group folder, a'
line_is "guide: whether or not a move emptied it" "$GS" '  status folder too, whether or not a move emptied it.'
file_lacks "guide: doctor --fix: not only the folders a move emptied" "$GS" 'removes the folders it leaves empty'
file_has "changelog: a status project's --fix removes each empty group folder" "$CG" \
  '- In a status project, `doctor --fix` now also removes each empty group folder other than the'
file_has "changelog: a status project's --fix removes an empty folder directly under the tasks root" "$CG" \
  '  five status folders, whether or not a move emptied it: an empty folder directly under the tasks'
file_has "changelog: such as a task folder with no README there" "$CG" \
  'a sprint'"'"'s folder or a task folder with no README there. An'
file_has "changelog: an empty status folder stays, and an empty folder inside one" "$CG" \
  '  empty status folder stays, and so does an empty folder inside one, such as `planned/<ID>/`.'
file_lacks "changelog: no task folder below the tasks root's top" "$CG" \
  '  README, whether or not a move emptied it. An empty status folder stays.'
line_is "guide: every --fix run in a status project removes each empty folder directly under the tasks root" "$GS" \
  '  Every run also removes the archive'"'"'s empty folders, and each empty folder directly under the'
line_is "guide: such as a task folder with no README there" "$GS" \
  '  a task folder with no README there, whether or not a move emptied it. An empty status folder'
line_is "guide: an empty folder inside a status folder stays" "$GS" \
  '  stays, and so does an empty folder inside one, such as `planned/<ID>/`.'
file_lacks "guide: no longer the archive's empty folders alone" "$GS" '  also removes the archive'"'"'s empty folders.'
line_is "vault-doctor fix: a status project's --fix removes each empty group folder" "$VD" \
  '   - In a status project, every `--fix` run also removes each empty group folder other than the'
line_is "vault-doctor fix: a status project's empty folders directly under the tasks root" "$VD" \
  '     five status folders, whether or not a move emptied it: an empty folder directly under the'
line_is "vault-doctor fix: an empty folder inside a status folder stays, said before the run" "$VD" \
  '     `planned/<ID>/`. Say so before it runs.'
file_lacks "vault-doctor fix: no task folder that no-readme names" "$VD" 'a task folder that'
vd_sgr="$(lineno "$VD" '- In a sprint project, every `--fix` run also removes')"
vd_tgr="$(lineno "$VD" '- In a status project, every `--fix` run also removes')"
is "vault-doctor fix: the status project's removal is beside the sprint project's, before the snapshot" \
  "$((${vd_sgr:-0} > 0 && ${vd_tgr:-0} == ${vd_sgr:-0} + 3 && ${vd_tgr:-0} < ${vd_snap:-0}))" "1"

# ---------------------------------------------------------------- the build agents
for a in implementer reviewer; do
  AF="$here/agents/$a.md"
  line_is "$a: named as its file" "$AF" "name: $a"
  ad="$(sed -n 's/^description: //p' "$AF")"
  is "$a: the description is under 200 characters" "$((${#ad} < 200))" "1"
  file_has "$a: carries the conventions pointer" "$AF" 'Conventions: before writing notes, run `second-brain conventions`'
  line_is "$a: sets omitClaudeMd, so no CLAUDE.md adds to what it is given" "$AF" 'omitClaudeMd: true'
done
file_has "contract: both build agents set omitClaudeMd" "$here/docs/contract.md" \
  '- `implementer` and `reviewer` set `omitClaudeMd: true`, so no `CLAUDE.md` adds to what they are'
for AF in "$here"/agents/*.md; do
  a="$(basename "$AF" .md)"
  if grep -q '^tools:.*Agent' "$AF"; then fail "$a: has no Agent tool"; else pass "$a: has no Agent tool"; fi
done
line_is "reviewer: edits no file, and has the Skill tool" "$here/agents/reviewer.md" "tools: Bash, Read, Glob, Grep, Skill"
for gone in "$here/agents/spec-checker.md" "$here/agents/spec-writer.md" "$here/skills/spec"; do
  absent "spec flow: ${gone#"$here"/} is gone" "$gone"
done
file_has "validation template: each user step names its tool" "$here/templates/validation-repo.md.tmpl" \
  "- <One line per step that uses the change as a user does: its tool, then what to look for, then when it runs.>"
file_has "validation template: a tool is a skill, a command, an API call or a query" "$here/templates/validation-repo.md.tmpl" \
  "a skill by name, such as a browser-testing skill, a command, an API call or a query."
file_has "reviewer: runs each user step with the tool its line names" "$here/agents/reviewer.md" "that runs it. Run the step with that tool."
file_has "reviewer: a skill runs through the Skill tool" "$here/agents/reviewer.md" "- A skill: call it with the Skill tool"
file_has "reviewer: a step whose tool it cannot run is BLOCKED and names the tool" "$here/agents/reviewer.md" "found, is BLOCKED. Name the tool."
file_has "reviewer: screenshots go in a temp folder outside the repo" "$here/agents/reviewer.md" "make one temp folder outside the repo with \`mktemp -d\`"
file_has "reviewer: names the screenshots folder" "$here/agents/reviewer.md" '- With browser steps, add `"screenshots": "<folder>"`: the temp folder that holds them.'
file_has "reviewer: keeps step 0's status output" "$here/agents/reviewer.md" "Keep the \`status --porcelain\` output: the user"
file_has "reviewer: removes only an untracked path step 0 did not list" "$here/agents/reviewer.md" "Remove only an untracked (\`??\`) path that step 0's output did not list, and name it."
file_has "reviewer: a tracked file a step changed is a finding, never deleted" "$here/agents/reviewer.md" "A tracked file a step changed is a finding. Never delete it."
file_has "reviewer: never resets the owner's work" "$here/agents/reviewer.md" "Never run \`git checkout\`, \`restore\`, \`reset\`, \`clean\` or \`stash\`."
file_has "reviewer: a line with no tool runs with Bash only when Bash can do it" "$here/agents/reviewer.md" "run it with Bash when Bash can do what it says."
file_has "reviewer: a browser line with no tool is BLOCKED" "$here/agents/reviewer.md" "A line that needs a browser and names no tool is BLOCKED. Name the step and ask for its tool."
file_has "reviewer: a BLOCKED verdict" "$here/agents/reviewer.md" '- `BLOCKED`: a step could not be run'
file_has "vault-setup: drafts each user step's tool from the repo" "$here/skills/vault-setup/validation.md" "Draft the tool from the repo"
file_has "reviewer: a step not run is never a pass" "$here/agents/reviewer.md" "A step that could not be run is never a PASS."
line_is "implementer: never writes the vault" "$here/agents/implementer.md" \
  '- Never write the vault: the build skill and the reviewer write the story'"'"'s notes.'
line_is "implementer: reads nothing outside the worktree but its story and the reviewer's file" "$here/agents/implementer.md" \
  '- Read nothing outside the worktree but your story'"'"'s sections and status notes, and the'
ST="$here/skills/story-tracker/SKILL.md"
STC="$here/skills/story-tracker/create.md"
line_is "story-tracker: has a section on building a story" "$ST" '## Building a story'
file_lacks "story-tracker: no spec-driven section is left" "$ST" '## Spec-driven stories'
file_has "story-tracker: the build skill builds a story" "$ST" \
  'This skill writes no code: the `build` skill builds a story, from its README.'
file_has "story-tracker: offers the build when work starts" "$ST" '`in-progress`, offer `/odsb:build <ID>`.'
file_has "story-tracker: the build takes an approved story" "$ST" \
  '- The build takes only a story whose status notes hold `Planned: the owner approved this text.`.'
file_has "story-tracker: an unapproved story goes to refinement first" "$ST" '`/odsb:scrum-master refinement` first.'
file_has "story-tracker: weighs nothing" "$ST" \
  '- Weigh nothing, and write no key on how the story is built: every story is built the same way.'
for w in delivery 'odsb:spec' 'spec-driven' 'Spec-driven' 'second-brain spec'; do
  file_lacks "story-tracker: names no $w" "$ST" "$w"
  file_lacks "story-tracker create: names no $w" "$STC" "$w"
done
file_has "story-tracker create: start mode offers the build" "$STC" \
  '6. Offer the build, as `## Building a story` in `SKILL.md` says.'
file_lacks "guide: the profile's delivery is no default" "$here/docs/guide.md" \
  "A project's default, and where"
for sk in story-tracker scrum-master; do
  st_desc="$(sed -n 's/^description: //p' "$here/skills/$sk/SKILL.md")"
  st_check="$sk: the description names no spec"
  case "$st_desc" in
    *[Ss][Pp][Ee][Cc]*) fail "$st_check" "in: $st_desc" ;;
    *) pass "$st_check" ;;
  esac
done
file_lacks "guide: no spec request is under What to say" "$here/docs/guide.md" 'spec-driven, starting with its requirements'
file_has "guide: the build request is under What to say" "$here/docs/guide.md" '| Build the approved stories of EX-1. | `build` |'
file_has "e2e: asks the same build request" "$here/scripts/e2e-claude.sh" '"Build the approved stories of EX-1."'

# ---------------------------------------------------------------- the build agents' checks and reports
lead="spec""-lead"
absent "$lead: the agent is gone" "$here/agents/$lead.md"
named="$(cd "$here" && find . -type f -not -path './.git' -not -path './.git/*' -not -path './.scratch/*' -not -path './tmp/*' \
  -not -path './.omc/*' -not -path './.claude/*' -not -name CHANGELOG.md -exec grep -lF -- "$lead" {} + 2>/dev/null)"
is "$lead: no file but CHANGELOG.md names it" "$named" ""
file_has "changelog: says $lead is gone" "$here/CHANGELOG.md" "The \`$lead\` agent is gone."
file_has "contract: the skill runs a release check in the background" "$here/docs/contract.md" \
  '- The skill runs a `release` check only when the owner asks, with the Bash tool'"'"'s'
file_lacks "contract: no helper that a timeout kills" "$here/docs/contract.md" 'a helper that a timeout kills'
file_has "contract: implementer and reviewer run each check in the foreground" "$here/docs/contract.md" \
  '- `implementer` and `reviewer` run each check in the foreground, with the Bash tool'"'"'s longest'
file_has "contract: a background agent's call may move after 3 minutes" "$here/docs/contract.md" \
  '- In a background agent, such as each one the skill launches, a call may move to the background'
file_has "contract: the end line goes on a line of its own" "$here/docs/contract.md" \
  '- Each check'"'"'s command is followed by `echo "check ended: exit $?"` on a line of its own, a marker'
file_has "contract: a marker rarer than a bare exit" "$here/docs/contract.md" \
  '  rarer than a bare `exit:` in a check'"'"'s output. A check that outlasts its call moves to the'
file_lacks "contract: the end line is never added to the command's own line" "$here/docs/contract.md" \
  '; echo "check ended: exit $?"'
file_lacks "contract: no bare exit marker is left" "$here/docs/contract.md" 'echo "exit: $?"'
file_has "contract: a message may move a check to the background" "$here/docs/contract.md" \
  '  background and still runs. A message that reaches the agent may move it there too.'
file_has "contract: the agent waits in calls under 3 minutes" "$here/docs/contract.md" \
  '- The agent waits for it in the foreground, in calls under 3 minutes, until its output file holds'
file_has "contract: a notice that the check ended ends the wait" "$here/docs/contract.md" \
  '  the `check ended:` line, or a notice says the check ended. A check the harness stops never'
line_is "contract: the wait reads with grep -qs" "$here/docs/contract.md" \
  '- The wait reads the file with `grep -qs`, so a file not written yet is no error.'
file_has "changelog: the rarer end line, grep -qs and the notice" "$here/CHANGELOG.md" \
  '- A build agent ends each check with `echo "check ended: exit $?"`, rarer in a check'"'"'s output than'
file_has "contract: no agent replies while a check it started runs" "$here/docs/contract.md" \
  '- No agent replies while a check it started still runs: once it replies, the notice may never'
file_has "contract: fix rounds 1 to 3 go to the same implementer" "$here/docs/contract.md" \
  '- `reviewer` runs on `opus`. `implementer` builds the story and takes fix rounds 1 to 3 on `opus`,'
file_has "changelog: build agents run each check in the foreground" "$here/CHANGELOG.md" \
  '- `implementer` and `reviewer` run each check in the foreground, with a timeout of 10 minutes,'
file_has "changelog: and a background agent's call moves after 3 minutes" "$here/CHANGELOG.md" \
  '  and wait for one that outlasts its call, 3 minutes in a background agent: no agent replies'
# Each build agent runs each check in the foreground, and never replies while one it started runs.
for ag in implementer reviewer; do
  AF="$here/agents/$ag.md"
  file_lacks "$ag: runs no check in the background" "$AF" 'run_in_background: true'
  file_has "$ag: runs each check in the foreground, with the longest timeout" "$AF" \
    '`timeout: 600000`, 10 minutes. Never with `run_in_background`.'
  line_is "$ag: a background agent's call may move after 3 minutes" "$AF" \
    '- In a background agent, a call may move to the background after 3 minutes, whatever its timeout.'
  file_has "$ag: puts the end line on a line of its own" "$AF" \
    '- Put `echo "check ended: exit $?"` on a line of its own after each check'"'"'s command, so that its'
  file_lacks "$ag: never adds the end line to the command's own line" "$AF" '; echo "check ended: exit $?"'
  file_lacks "$ag: no bare exit marker is left" "$AF" 'echo "exit: $?"'
  file_lacks "$ag: no wait on a bare exit line" "$AF" "grep -q '^exit: '"
  file_has "$ag: a check moved to the background still runs" "$AF" \
    '- A check that outlasts its call moves to the background and still runs. A message that reaches'
  file_has "$ag: a message may move it there too" "$AF" '  you while it runs may move it there too.'
  file_lacks "$ag: no claim that a message always moves it" "$AF" 'moves it there too'
  file_has "$ag: waits for it in the foreground, with grep -qs" "$AF" \
    '`for i in $(seq 17); do grep -qs '"'"'^check ended: exit '"'"' "<file>" && break; sleep 10; done`. It'
  file_has "$ag: a notice that the check ended ends the wait" "$AF" \
    '- A notice that the check ended ends the wait too, such as when the harness stops it. Read the'
  file_has "$ag: a check the harness stops never writes the line" "$AF" \
    '  file then: a check the harness stops never writes its `check ended:` line.'
  # The wait must return before a background agent's call moves, at 180 seconds.
  wl="$(grep -m1 -F 'grep -qs '"'"'^check ended: exit '"'"'' "$AF")"
  wn="$(printf '%s\n' "$wl" | sed -n 's/.*\$(seq \([0-9][0-9]*\)).*/\1/p')"
  ws="$(printf '%s\n' "$wl" | sed -n 's/.*sleep \([0-9][0-9]*\);.*/\1/p')"
  is "$ag: the wait loop's count times its sleep stays under 180 seconds" \
    "$(( ${wn:-999} * ${ws:-999} < 180 ))" "1"
  file_has "$ag: a check with no end line is no pass" "$AF" \
    '- A check with no `check ended:` line has not finished, whatever its output shows: it is no pass.'
  file_has "$ag: one the harness stops failed" "$AF" \
    '  One stopped before that line, such as at a time limit or by the harness, failed.'
  file_has "$ag: never replies while a check it started runs" "$AF" \
    '- Never reply while a check you started still runs. Once you reply, its notice may never reach'
  for w in 'spec packet' 'spec issue' 'spec status' 'spec tick' 'skills/spec/' 'tasks.md' 'Bundle:' 'packet'; do
    file_lacks "$ag: names no $w, as the spec flow is retired" "$AF" "$w"
  done
done
file_has "reviewer: a server a step needs is no check" "$here/agents/reviewer.md" \
  '- A server a step needs is no check: start it as `### Set up and start` says.'
IM="$here/agents/implementer.md"
line_is "implementer: replies with its commit first" "$IM" '1. `Commit: <short hash>`.'
line_is "implementer: then one line on what it built" "$IM" '2. One line on what you built. It also names anything the story asks that you could not do, and'
line_is "implementer: then its test" "$IM" \
  '3. `Test: <the test you wrote> - failed first, then passed`, or `Test: none - <why>` for a change'
line_is "implementer: then each check's result" "$IM" \
  '4. One line per check you ran: `Check: <the command or step> - <pass, fail or skipped>`.'
file_has "implementer: a stop names the checks it ran" "$IM" \
  '- You stop without a commit: the first line is `BLOCKED: <why>`, then the `Check:` lines of the'
file_lacks "implementer: no longer runs no check" "$IM" "Run no check"
file_lacks "implementer: and its description no longer says so" "$IM" "runs no check"
file_has "implementer: writes a test that fails for a criterion first" "$IM" \
  '1. Write a test that fails for an acceptance criterion first, where the story'"'"'s Approach and the'
file_has "implementer: sees it fail before the change" "$IM" '- Run it and see it fail, for the reason the criterion gives.'
line_is "implementer: then makes it pass" "$IM" '2. Then make the change, until the test passes.'
line_is "implementer: runs its own test narrowly, never every suite" "$IM" \
  '   that holds it. Never every suite.'
line_is "implementer: a change with nothing to test says why" "$IM" \
  '4. A change with nothing to test, such as a doc change, gets no test. Your reply says why.'
line_is "implementer: has a check step" "$IM" "## 2. Check"
file_has "implementer: runs its test and the each-story checks its change touches before it commits" "$IM" \
  "Before you commit, run your test and the repo's \`each story\` checks that your change touches,"
file_has "implementer: the each-story checks through validation run in the worktree, from the story's base" "$IM" \
  '`second-brain validation run "<project>" <repo> --when each-story --changed <base> --path "<worktree>"`,'
file_has "implementer: with the base of its prompt" "$IM" '  with the base of your prompt. Each row it prints is one result.'
file_has "implementer: runs each test and check in the foreground" "$IM" \
  '- Run each test and check in the foreground, with the Bash tool'"'"'s longest timeout:'
line_is "implementer: runs no release check, no user step and no each-merge check" "$IM" \
  '- Run no other check: no `release` check, no user step, and no `each merge` check but the one'
line_is "implementer: but the suite that holds its own test" "$IM" \
  '  suite that holds your own test. `reviewer` runs the rest in its review.'
line_is "implementer: only a command it cannot pass or run blocks" "$IM" \
  '- A command you cannot make pass, or cannot run, such as one that is not found: commit nothing,'
line_is "implementer: commits only when every check passed or was skipped" "$IM" \
  '- Commit only when the checks of step 5 of `## Story mode` passed: your test, and every row'
file_has "implementer: never changes a test so that it passes" "$IM" \
  'Never change a test or a check'
is "implementer: checks before it commits" \
  "$(($(linex "$IM" '## 1. Build test-first') < $(linex "$IM" '## 2. Check') && $(linex "$IM" '## 2. Check') < $(linex "$IM" '## 3. Commit')))" "1"
RV="$here/agents/reviewer.md"
file_has "reviewer: replies with its verdict and the number of issues" "$RV" '- `issues`: the number of defects, those you logged and those in the reply. A follow-up is not'
file_lacks "reviewer: no longer says the implementer runs no check" "$RV" "the implementer runs none"
file_has "reviewer: runs the checks again" "$RV" \
  "The implementer runs its test and the \`each story\` checks before it commits. You run the checks"
file_has "reviewer: the caller names story or baseline mode" "$RV" 'The caller names the mode: story or baseline.'
for h in '## Task mode' '### A bundle' '## User mode' '## Branch mode' '## Findings on a finished branch'; do
  file_lacks "reviewer: no $h, which only the spec build used" "$RV" "$h"
done
for h in '## 0. Get your packet' '## A bundle' '## A fix message'; do
  file_lacks "implementer: no $h, which only the spec build used" "$IM" "$h"
done
CT="$here/docs/contract.md"
line_is "contract: the skill takes each report from the agent's result" "$CT" \
  '- The skill takes each report from the agent'"'"'s result. Nothing is relayed by hand.'
file_has "guide: progress is in the story's status notes" "$here/docs/guide.md" \
  "- Progress is kept in the story's status notes, so a new session goes on where the build stopped."

# ---------------------------------------------------------------- README: each rule it points to has a home
RM="$here/README.md"
line_is "README: keeps the Update heading that docs/guide.md links to" "$RM" "## Update"
for ptr in 'docs/contract.md|### Profile frontmatter' 'docs/contract.md|### Validation' \
  'skills/vault-doctor/SKILL.md|## fix' 'docs/guide.md|## Other ways to install' 'docs/guide.md|## Updating' 'docs/guide.md|## What to say' 'docs/contract.md|## 9. Skills and agents' \
  'skills/vault-setup/SKILL.md|## link' 'templates/vault-claude-hub.md.tmpl|## Adding a skill or agent'; do
  pf="${ptr%%|*}" ph="${ptr#*|}"
  file_has "README: points to $ph in $pf" "$RM" "\`$ph\` in \`$pf\`"
  line_is "README: $pf has the heading $ph" "$here/$pf" "$ph"
done
for ptr in 'docs/guide.md|## Building a story' 'docs/guide.md|### A vault with specs'; do
  pf="${ptr%%|*}" ph="${ptr#*|}"
  file_has "README: points to $ph in $pf" "$RM" "\`$ph\` in"
  line_is "README: $pf has the heading $ph" "$here/$pf" "$ph"
done
line_is "README: says how a vault with specs moves on" "$RM" "### A vault with specs"
file_has "README: the spec flow is retired, and every story goes to the build" "$RM" \
  'Version 0.12.0 retires the spec flow: every story is built with `/odsb:build`.'
file_has "README: a story's spec folder and build.json stay as plain notes" "$RM" \
  "- A story's \`spec/\` folder and \`build.json\` stay in its task folder as plain notes, which nothing"
line_is "README: has ## Story templates" "$RM" "## Story templates"
file_has "README: a project's own templates go in its claude/templates folder" "$RM" '`<project>/claude/templates/` in your vault'
file_has "README: points to the contract's rules for a project's own templates" "$RM" \
  "\`### A project's own templates\` in"
line_is "README: docs/contract.md has the heading ### A project's own templates" "$here/docs/contract.md" \
  "### A project's own templates"
file_has "README: names the doctor's task-template check" "$RM" "The doctor's \`task-template\` check warns"
for pf in skills/build/story.md skills/vault-doctor/checks.md templates/pull-request.md.tmpl \
  templates/task-readme.md.tmpl templates/ticket-description.md.tmpl; do
  file_has "README: points to $pf" "$RM" "\`$pf\`"
  exists "README: $pf exists" "$here/$pf"
done
# The README is the home of the commands and the agents, in the shape of the official plugin READMEs.
for h in "## Overview" "## Quick start" "## Commands" "## Agents" "## Examples"; do
  line_is "README: has $h" "$RM" "$h"
done
for d in "$here"/skills/*/; do
  sk="$(basename "$d")"
  line_is "README: a section for /odsb:$sk" "$RM" "### \`/odsb:$sk\`"
done
for f in "$here"/agents/*.md; do
  ag="$(basename "$f" .md)"
  is "README: the agents table has $ag" "$(grep -c "^| \`$ag\` | " "$RM")" "1"
done
for h in "### Start a ticket" "### Ask where things stand" "### Build a story" "### Check the vault"; do
  line_is "README: the example $h" "$RM" "$h"
done
file_has "README: the build is test-first" "$RM" '- One `implementer` builds each story test-first and checks its own change. Then a `reviewer`'
file_has "README: the fix rounds are capped" "$RM" \
  '- A failed review sends its defects back to the same `implementer`, in a capped number of rounds.'
file_has "README: story-tracker offers the build" "$RM" '- When work starts on a story you approved, it offers `/odsb:build` to build it.'
file_has "README: the shell form of the marketplace refresh" "$RM" '`claude plugin marketplace update second-brain` in your shell'
file_has "README: the reviewer row names the baseline" "$RM" 'on the branch as a baseline when a build needs one'
file_lacks "README: no note on an early 0.2.0 copy" "$RM" 'An early copy of 0.2.0'
file_lacks "README: no feature bullet ends in a pointer" "$RM" 'runs none, as `### Profile frontmatter`'
line_is "guide: has ## Updating" "$here/docs/guide.md" "## Updating"
file_has "guide: an update that does not take" "$here/docs/guide.md" 'claude plugin uninstall obsidian-dev-second-brain@second-brain'
file_has "guide: auto-update" "$here/docs/guide.md" 'choose Enable auto-update.'
file_has "guide: What you get links to the README's commands" "$here/docs/guide.md" '[Commands](../README.md#commands)'
file_has "README: the hand-off to docs-keeper is in story-tracker" "$here/skills/story-tracker/SKILL.md" \
  'The story reaches production: start the `docs-keeper` agent'
file_has "README: vault-setup link leaves a foreign entry alone" "$here/skills/vault-setup/SKILL.md" \
  'It is normal and never touched'
file_has "README: --fix changes four checks without asking" "$here/skills/vault-doctor/SKILL.md" \
  '`second-brain doctor --fix` repairs four checks only'

# ---------------------------------------------------------------- guide: each rule it points to has a home
GD="$here/docs/guide.md"
line_is "guide: keeps the What to say heading that its links name" "$GD" "## What to say"
for ptr in 'docs/contract.md|## 1. Words and paths' 'docs/contract.md|## 2. The index' \
  'docs/contract.md|## 3. The project' 'docs/contract.md|### Profile frontmatter' \
  'docs/contract.md|### Validation' 'docs/contract.md|## 4. A task' \
  'docs/contract.md|### Links between notes' 'docs/contract.md|### link, doctor, snapshot' \
  'docs/contract.md|## 9. Skills and agents' 'templates/obsidian-conventions.md.tmpl|## The short version' \
  'skills/vault-setup/adopt.md|## 2. Scaffold only what is missing' 'skills/vault-setup/SKILL.md|## project <name>' \
  'skills/story-tracker/create.md|## 3. Create the story' 'skills/story-tracker/status.md|## Render' \
  'skills/story-tracker/SKILL.md|## Edit an existing story' 'skills/vault-doctor/SKILL.md|## fix' \
  'skills/build/story.md|### The fix loop' 'skills/build/story.md|## 8. When to ask the owner' \
  'skills/build/story.md|## 2. The worktree' 'skills/build/story.md|### Reading a verdict' \
  "skills/build/lead.md|## The owner's open orders" "skills/build/lead.md|## The lead's check" \
  'agents/reviewer.md|## Defects and follow-ups'; do
  pf="${ptr%%|*}" ph="${ptr#*|}"
  file_has "guide: points to $ph in $pf" "$GD" "\`$ph\` in \`$pf\`"
  line_is "guide: $pf has the heading $ph" "$here/$pf" "$ph"
done
for pf in skills/scrum-master/sprint-planning.md skills/build/SKILL.md skills/build/story.md .github/workflows/test.yml \
  .github/workflows/e2e.yml scripts/e2e-claude.sh .claude-plugin/plugin.json CHANGELOG.md; do
  file_has "guide: points to $pf" "$GD" "\`$pf\`"
  exists "guide: $pf exists" "$here/$pf"
done
for s in test test-link test-graph test-doctor test-snapshot leak-check; do
  line_is "guide: Development lists scripts/$s.sh" "$GD" "bash scripts/$s.sh"
done
line_is "guide: Development lists the plugin validation" "$GD" "claude plugin validate . --strict"
file_has "guide: version changes only at the end of a release" "$GD" \
  'Neither a feature branch nor the release branch changes `version`.'
file_has "guide: a failing e2e request is fixed in the description" "$GD" \
  "fixed in the skill's \`description\`, in the user's words"
file_has "guide: a task is never filed in its topic" "$here/templates/obsidian-conventions.md.tmpl" \
  'Never file a task inside the topic it is'
file_has "guide: vault-setup runs only by name" "$here/docs/contract.md" \
  '`vault-setup` is the one: it writes the pointer and the links'
file_has "guide: adopt writes the roots into the profile" "$here/skills/vault-setup/adopt.md" \
  'It writes the roots into the new profile'
file_has "guide: vault-setup asks whether the project runs sprints" "$here/skills/vault-setup/SKILL.md" \
  '- No sprints: add `--no-sprints`'
file_has "guide: vault-setup asks for the task layout" "$here/skills/vault-setup/SKILL.md" \
  '| `task_layout` | whether a done or abandoned task moves once'
file_has "guide: the status overview flags a story waiting on a task not done" "$here/skills/story-tracker/status.md" \
  'story waits on each task in its `depends_on` cell that is not `done`'
file_has "guide: no build starts without the repo's steps" "$here/skills/build/story.md" \
  '`second-brain validation "<project>" <repo> --path "<worktree>"` must print the repo'"'"'s steps'
line_is "guide: says how a vault with specs moves on" "$GD" "### A vault with specs"
file_has "guide: a story is built one way" "$GD" 'Version 0.12.0 retires the spec flow. A story is built one way: from its README, with'
file_has "guide: the spec folders and build.json stay, read by nothing" "$GD" \
  "- A story's \`spec/\` folder and \`build.json\` stay in its task folder, as plain notes and files of"
file_has "guide: the old keys are read by nothing" "$GD" \
  '- A `delivery` or `spec_home` key in a profile or a task is read by nothing,'
file_has "guide: a spec story is built once its text is approved" "$GD" \
  'its criteria into the README through `/odsb:scrum-master refinement`. Once you approve the text,'
file_lacks "guide: no spec-driven delivery section is left" "$GD" '## Spec-driven delivery'

# ---------------------------------------------------------------- a new story's branch is cut from the base branch
line_is "guide: a release branch is cut from main" "$GD" \
  '- A release starts with a `release/<version>` branch cut from `main`, such as `release/0.3.0`.'
line_is "guide: a feature branch is cut from main and merges into the release" "$GD" \
  '- A feature branch is cut from `main` and merges into the release branch.'
line_is "guide: a story that needs another story's code is cut from its branch" "$GD" \
  "- A story that needs another story's code not yet in \`main\` is cut from that story's branch. It"
line_is "guide: that story merges after the one it needs" "$GD" '  merges into the release branch after that story.'
line_is "guide: the release goes to main in one pull request" "$GD" \
  '- One pull request takes the release branch into `main`.'
ST="$here/skills/story-tracker/SKILL.md"
line_is "story-tracker: a new story's branch is cut from the base branch" "$ST" \
  "- A new story's branch is cut from the base branch."
line_is "story-tracker: a story that needs another story's code is cut from its branch" "$ST" \
  "  - A story that needs another story's code not yet in the base branch is cut from that story's"
line_is "contract: base_branch is where a new story's branch is cut from" "$here/docs/contract.md" \
  "- \`base_branch\` is the branch a new story's branch is cut from, as"

# ---------------------------------------------------------------- the baseline of a story build
CT="$here/docs/contract.md"
file_has "contract: the baseline is skipped on a start on the base branch" "$CT" \
  '- The branch starts on the base branch when `git merge-base --is-ancestor <base> <base ref>`'
file_has "contract: names the skip note" "$CT" \
  '- When it does, the skill skips the baseline and writes its `Build: baseline skipped:` note.'
line_is "contract: a resumed build skips it" "$CT" '- A resumed build skips the baseline, whatever the start.'
file_has "contract: one story and one agent at a time with one pair" "$CT" \
  '`build_pairs` sets how many pairs build at once (section 3). With 1, the default, one story and'
file_has "changelog: the baseline skip" "$here/CHANGELOG.md" '- A new build skips the baseline when the story'"'"'s branch starts on the base branch'

# ---------------------------------------------------------------- the build asks only for a stop list, and rules on the rest
CT="$here/docs/contract.md"
IM="$here/agents/implementer.md"
RV="$here/agents/reviewer.md"
for f in "$IM" "$RV"; do
  file_has "${f##*/}: follows a ruling line" "$f" \
    "- A \`Ruling:\` line is the launching skill's ruling on what the story left open: follow it."
  file_has "${f##*/}: the owner's line wins over a ruling" "$f" '  Where it and an `Owner:` line differ, the `Owner:` line wins.'
done
file_has "implementer: puts a BLOCKED as one question" "$IM" 'stop with `BLOCKED:` and say what, as one question the'
file_has "reviewer: what a ruling decided is no finding" "$RV" '- What an `Owner:` or `Ruling:` line decided is never a finding.'
file_has "contract: the stop list" "$CT" \
  '- **The stop list.** Once the build has started, the skill stops and asks the owner with'
file_has "contract: names its six reasons" "$CT" \
  '  such as a push, a merge or a publish, a story too unclear to build, a story blocked or past its'
file_has "contract: the stop list's home" "$CT" \
  '  last fix round, and a failed baseline. `## 8. When to ask the owner` in `skills/build/story.md`'
line_is "contract: a story too unclear to build" "$CT" \
  '- A story is too unclear to build when going on would change, add or drop an acceptance'
file_has "contract: any other question is a ruling" "$CT" \
  '  `second-brain task note <ID> "Ruling: <the question> - <the decision and why>"`, before the next'
file_has "contract: a ruling never changes a criterion" "$CT" \
  '- A ruling never changes, adds or drops an acceptance criterion. It never lifts a stop: only the'
file_has "contract: the rulings of a build" "$CT" '- **The rulings of a build** are the status notes newer than its newest'
file_has "contract: every ruling goes into each later prompt" "$CT" \
  '- Every ruling of the build goes, as written and oldest first, into each later `implementer`'
file_has "contract: the list when the build finishes or stops" "$CT" \
  '- When the build finishes or stops, the skill lists every ruling of the build, as written, oldest'
file_lacks "contract: no phase is reopened, as the spec flow is retired" "$CT" 'reopened.'

# ---------------------------------------------------------------- the reviewer grades each check and ends with a JSON verdict
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
RV="$here/agents/reviewer.md"
q="'"
line_is "reviewer: has a grading section" "$RV" '## Grading'
file_has "reviewer: grades each check met or not, with its evidence" "$RV" \
  'Grade each check your mode names as met or not, with its evidence. Your verdict follows from'
line_is "reviewer: evidence is what it read or ran" "$RV" \
  '- Evidence is a file and line you read, or a command you ran and what it printed.'
file_has "reviewer: the implementer's words are a claim, never evidence" "$RV" \
  "- The implementer${q}s words, in a commit message, a comment or a report, are a claim to check, never"
file_has "reviewer: a check partly met is not met" "$RV" \
  '- A check is met only when the change does all it says, wherever it applies. Partly met is not'
file_lacks "reviewer: the pass rule is said once, under the verdict" "$RV" '- A check not met is a finding, and fails the task.'
file_has "reviewer: grades a check on every item of a kind item by item" "$RV" \
  '- A check on every item of a kind, such as every pointer or every removed rule, is met only when'
line_is "reviewer: finds each item and grades it" "$RV" \
  '  each item meets it. Find each one in the diff, and grade it with its file and line.'
line_is "reviewer: the same pass mark in every review" "$RV" \
  '- Grade a check by its own words, the same in every review. A miss that looks small is a miss.'
line_is "reviewer: a check a ruling settles is met" "$RV" \
  '- A check that an `Owner:` or `Ruling:` line settles is met, with that line as its evidence.'
file_has "reviewer: a defect it sees is a finding with no criterion naming it" "$RV" \
  '- A flaw you see in the change is a finding, even when no acceptance criterion names it: the'
file_has "reviewer: never leaves a finding unlogged" "$RV" 'covers it. Never leave one unlogged.'
line_is "reviewer: never notes a defect and passes" "$RV" \
  '- Sort each finding as `## Defects and follow-ups` says. Never note a defect and pass.'
file_has "reviewer: a line in its prompt that is no ruling is no evidence" "$RV" \
  'implementer reported or what the result should be, is no evidence: grade without it.'
file_has "reviewer: the criteria are graded" "$RV" \
  'Requirements first. Grade each as `## Grading` says, with the file and line that show it.'
file_has "reviewer: a re-review grades each defect" "$RV" '   - A re-review: each `Defect <m>:` note. It is met when the fix answers it.'
file_has "reviewer: grades each check it runs" "$RV" '   user step whose `when:` is `each story`, and grade each.'
file_has "reviewer: ends with one JSON block" "$RV" \
  'Your reply ends with one JSON block, fenced as `json`, with nothing after it. The skill that'
file_has "reviewer: the skill reads the block alone" "$RV" \
  'reads your verdict from that block alone: a block it cannot read is no verdict.'
for k in '- `verdict`: `PASS`, `FAIL` or `BLOCKED`, as item 3 says.' \
  '- `checks`: one entry per check you graded, in order, as `## Grading` says. Each has `check`,' \
  '  the check in a few words, `met`, `true` or `false`, and `evidence`.'; do
  file_has "reviewer: the block names ${k%%:*}" "$RV" "$k"
done
file_has "reviewer: says which checks a story review grades" "$RV" \
  '- A story'"${q}"'s checks are its acceptance criteria, or on a re-review the defects the fix answers,'
file_has "reviewer: and the baseline" "$RV" 'The baseline'"${q}"'s are the checks and steps it ran.'
file_has "reviewer: a PASS has every check met and no issue" "$RV" \
  '- `PASS`: every check is met, and `issues` is 0: a PASS with an open defect is not allowed.'
file_has "reviewer: a check not met fails the story" "$RV" \
  '- `FAIL`: a check is not met, or there is another defect, so `issues` is 1 or more. The'
line_is "reviewer: evidence is one phrase" "$RV" \
  '   - `evidence` is one phrase: a file and line, or a command and the line it printed. Never paste'
line_is "reviewer: never pastes output" "$RV" '     output.'
file_has "reviewer: the example bullets are the grading, not the reply" "$RV" \
  'Two story reviews, cut short. Grade as they do. Their bullets are the grading you do, not your'
line_is "reviewer: in story mode the reply is the block alone" "$RV" 'reply: in story mode the reply is the block alone.'
file_lacks "reviewer: no VERDICT line is left" "$RV" 'VERDICT:'
line_is "reviewer: has the worked examples" "$RV" '## Worked examples'
line_is "reviewer: a worked FAIL" "$RV" '### A FAIL'
line_is "reviewer: a worked PASS" "$RV" '### A PASS'
ex_fail="$(json_of 'A FAIL')"
ex_pass="$(json_of 'A PASS')"
case "$ex_fail" in *'"verdict": "FAIL"'*'"met": false'*) pass "reviewer: the worked FAIL ends with a FAIL block with a check not met" ;;
  *) fail "reviewer: the worked FAIL ends with a FAIL block with a check not met" "in: $ex_fail" ;; esac
case "$ex_fail" in *'"issues": 0'*) fail "reviewer: the worked FAIL counts its issues" "in: $ex_fail" ;;
  *'"issues": '[1-9]*) pass "reviewer: the worked FAIL counts its issues" ;;
  *) fail "reviewer: the worked FAIL counts its issues" "in: $ex_fail" ;; esac
case "$ex_pass" in *'"verdict": "PASS", "issues": 0, "checks": ['*) pass "reviewer: the worked PASS ends with a PASS block and no issue" ;;
  *) fail "reviewer: the worked PASS ends with a PASS block and no issue" "in: $ex_pass" ;; esac
case "$ex_pass" in *'"met": true'*'"evidence": "'*) pass "reviewer: the worked PASS gives its evidence" ;;
  *) fail "reviewer: the worked PASS gives its evidence" "in: $ex_pass" ;; esac
case "$ex_pass" in *'"met": false'*) fail "reviewer: the worked PASS has no check not met" "in: $ex_pass" ;;
  *) pass "reviewer: the worked PASS has no check not met" ;; esac
is "reviewer: the worked FAIL logs its defect as a Defect note" "$(example_of 'A FAIL' | grep -c 'goes in as a `Defect <n>:` note')" "1"
is "reviewer: the worked FAIL takes the commit message as a claim" "$(example_of 'A FAIL' | grep -c 'a claim, not evidence')" "1"
is "reviewer: the worked PASS meets a check through an Owner line" "$(example_of 'A PASS' | grep -c 'the `Owner:` line chose it: met')" "1"
is "reviewer: the worked examples name no ticket key but the example one" \
  "$(awk '/^## Worked examples$/ { on = 1; next } /^## / { on = 0 } on' "$RV" | grep -E '[A-Z][A-Z0-9]+-[0-9]+' | grep -cvE 'EX-[0-9]+')" "0"
file_has "contract: the reviewer grades each criterion with its evidence" "$CT" \
  '- `reviewer` grades each acceptance criterion, or on a re-review each defect the fix answers, and'
file_has "contract: the implementer's words are a claim" "$CT" \
  "- The implementer${q}s words, in its report, a commit message or a comment, are a claim to check,"
file_has "contract: a PASS with an open defect is not allowed" "$CT" \
  'defect, and any defect fails the story: a PASS with an open defect is not allowed.'
file_has "contract: names the worked examples" "$CT" '- `agents/reviewer.md` holds two short worked examples: a FAIL with its findings, and a PASS with'
file_has "contract: the JSON block" "$CT" \
  '`{"verdict": "FAIL", "issues": 1, "checks": [{"check": "...", "met": false, "evidence": "..."}]}`.'
file_has "contract: the skill reads the block alone" "$CT" \
  '- The skill reads each verdict from the block alone. A PASS needs one check or more, every `met`'
file_has "contract: a story PASS has no defect note of its round" "$CT" \
  '  true and `issues` 0, and in story mode no `Defect <n>:` note of its round. A FAIL needs'
line_is "contract: a bad block is never a PASS" "$CT" '- No block, or one that breaks these rules, is no verdict: never a PASS.'
file_lacks "contract: no issue count from the retired spec status" "$CT" 'spec status --json'
file_has "contract: only a missing or unparsed block is asked again" "$CT" \
  '- The skill asks the same reviewer once more only when the block is missing or does not parse.'
file_has "contract: the skill gives the reviewer no view of its own" "$CT" \
  'a view of its own on the result, and never the implementer'"${q}"'s report.'
file_has "guide: the reviewer ends with a JSON verdict" "$GD" \
  '- `reviewer` grades each check as met or not, with its evidence, and ends its reply with a JSON'
file_has "changelog: the reviewer grades each check" "$here/CHANGELOG.md" \
  '- `reviewer` grades each acceptance check, and each check and user step it runs, as met or not,'
file_has "changelog: the JSON verdict" "$here/CHANGELOG.md" \
  '- `reviewer` ends its reply with a JSON block, `{"verdict": ..., "issues": <n>, "checks": [...]}`,'
file_has "changelog: the worked examples" "$here/CHANGELOG.md" \
  '- `agents/reviewer.md` holds two worked examples, a FAIL with its findings and a PASS with its'

# ---------------------------------------------------------------- the reviewer grades code quality on a failing story too
CT="$here/docs/contract.md"
RV="$here/agents/reviewer.md"
q="'"
file_lacks "reviewer: a FAIL no longer skips the code quality pass" "$RV" 'skip step 6'
line_is "reviewer: has the code quality list" "$RV" '## Code quality'
line_is "reviewer: a FAIL still runs step 7" "$RV" \
  '   FAIL. Still run step 7, so that one fix round answers every defect.'
file_has "reviewer: step 7 grades by the code quality list" "$RV" \
  '7. Then code quality, in the change step 3 reads alone, by `## Code quality`. On a re-review that'
line_is "reviewer: a re-review grades the fix's commits alone" "$RV" \
  "   is the fix${q}s commits: grade those alone."
line_is "reviewer: the quality list sorts each finding" "$RV" \
  'Each of these is a finding, sorted as `## Defects and follow-ups` says:'
q6_line="$(lineno "$RV" 'Still run step 7')"
q7_line="$(lineno "$RV" '7. Then code quality, in the change step 3 reads alone')"
q9_line="$(lineno "$RV" '9. Log each defect on the story')"
is "reviewer: step 6's FAIL comes before the quality pass, then the log" \
  "$((${q6_line:-0} < ${q7_line:-0} && ${q7_line:-0} < ${q9_line:-0}))" "1"
is "reviewer: the worked FAIL still runs the quality pass" "$(example_of 'A FAIL' | grep -c '`## Code quality` still runs')" "1"
file_has "contract: code quality is graded on a FAIL too" "$CT" \
  '- It grades code quality on a FAIL too, so that one fix round answers every defect. A re-review'
line_is "contract: a re-review grades the fix's quality alone" "$CT" \
  "  grades the code quality of the fix${q}s commits alone."
file_has "changelog: quality on a failing story" "$here/CHANGELOG.md" \
  '- `reviewer` grades code quality on a failing story too, so that one fix round answers every'
file_has "changelog: a re-review grades the fix's quality" "$here/CHANGELOG.md" \
  "  defect. A re-review still grades the quality of the fix${q}s commits alone."

# ---------------------------------------------------------------- a review sorts each finding as a defect or a follow-up
CG="$here/CHANGELOG.md"
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
RV="$here/agents/reviewer.md"
SM="$here/skills/build/story.md"
q="'"
line_is "reviewer: has the defects and follow-ups section" "$RV" '## Defects and follow-ups'
df_gr="$(linex "$RV" '## Grading')"
df_hd="$(linex "$RV" '## Defects and follow-ups')"
df_cq="$(linex "$RV" '## Code quality')"
df_sm="$(linex "$RV" '## Story mode')"
is "reviewer: the section comes after grading, then code quality, before the modes" \
  "$((${df_gr:-0} < ${df_hd:-0} && ${df_hd:-0} < ${df_cq:-0} && ${df_cq:-0} < ${df_sm:-0}))" "1"
DF="$(section_of "$RV" 'Defects and follow-ups')"
in_df() { case "$DF" in *"$2"*) pass "$1" ;; *) fail "$1" "missing: $2" ;; esac; }
in_df "reviewer: only a defect fails the story" 'Sort each finding as a defect or a follow-up. Only a defect fails the story.'
in_df "reviewer: a follow-up is one of three kinds" '- A follow-up is one of three kinds:'
is "reviewer: the three follow-up kinds, in order" \
  "$(printf '%s\n' "$DF" | awk '/^- A follow-up is one of three kinds:$/ { on = 1; next } /^- / { on = 0 } on')" \
  "$(printf '%s\n' '  - A name that misleads.' '  - Code repeated where it could be shared.' '  - Code against the conventions the diff shows around it.')"
in_df "reviewer: any other finding is a defect" '- Any other finding is a defect.'
in_df "reviewer: the defect list wins over the kinds" '- Each of these is a defect too, whatever its kind:'
for k in '  - An acceptance criterion not met, or a defect not answered.' \
  '  - A check or a step that fails, or could not be run.' \
  '  - What a user would hit, such as a wrong behaviour, or an error or edge case left unhandled.' \
  '  - A doc the change makes wrong.' \
  '  - What the story'"${q}"'s criteria or Approach, or a rule written in the repo, names, such as a rule'; do
  in_df "reviewer: a defect whatever its kind:${k#  -}" "$k"
done
in_df "reviewer: a finding it cannot place is a defect" '- A finding you cannot place for sure is a defect.'
in_df "reviewer: a defect goes in as step 9 says" '- Log each defect as step 9 of `## Story mode` says. Only defects count in `issues`.'
in_df "reviewer: a follow-up is a status note" '- Log a follow-up as a status note on the story:'
in_df "reviewer: the follow-up note's text" \
  '`second-brain task note <story> "Follow-up: <what could be better, at file:line> - <the change you propose>" --session <id>`.'
in_df "reviewer: a follow-up fails nothing" '  - A follow-up fails nothing and goes to no fix round. The build lists it for the owner when it'
in_df "reviewer: the build lists it when it finishes or stops" '    finishes or stops.'
line_is "reviewer: step 9 logs each defect" "$RV" '9. Log each defect on the story, with how to fix it, before you reply:'
line_is "reviewer: and each follow-up" "$RV" '   - Log each follow-up too, before you reply, as `## Defects and follow-ups` says.'
file_has "reviewer: a story review's findings are notes" "$RV" 'Your findings are in the story, through `task note`.'
line_is "reviewer: a follow-up is not counted in issues" "$RV" '     one.'
file_has "reviewer: a follow-up never stops a PASS" "$RV" 'A step that could not be run is never a PASS. A follow-up never stops one.'
line_is "reviewer: its only write is a note" "$RV" \
  '- The `task note` of a story'"${q}"'s defect or of a follow-up is your only write to the vault.'
is "reviewer: the worked FAIL credits its repeat to the quality pass" \
  "$(example_of 'A FAIL' | grep -c '  repeats half of lines 85 and 86: code repeated where it could be shared.')" "1"
is "reviewer: the worked FAIL sorts the repeat as a follow-up" \
  "$(example_of 'A FAIL' | grep -c 'No criterion or rule names the repeat, so it is a follow-up.')" "1"
is "reviewer: the worked FAIL logs the repeat as a Follow-up note" "$(example_of 'A FAIL' | grep -c '^  `Follow-up:` note, to cut it.$')" "1"
case "$(json_of 'A FAIL')" in *'"verdict": "FAIL", "issues": 1,'*) pass "reviewer: the worked FAIL counts no follow-up" ;;
  *) fail "reviewer: the worked FAIL counts no follow-up" "in: $(json_of 'A FAIL')" ;; esac
file_has "reviewer: the worked FAIL logs its defect and its follow-up as notes" "$RV" \
  '- Line 96 goes in as a `Defect <n>:` note, with its fix, to name the heading. Line 87 goes in as a'
file_has "reviewer: the worked FAIL's follow-up note cuts the repeat" "$RV" '  `Follow-up:` note, to cut it.'
file_has "reviewer: the worked PASS sorts the misleading name as a follow-up" "$RV" \
  '  named `tmp`: a name that misleads. No criterion or rule names it, so it is a follow-up. It goes'
file_has "reviewer: the worked PASS logs it as a Follow-up note that fails nothing" "$RV" \
  '  in as a `Follow-up:` note, and fails nothing.'
is "reviewer: the worked PASS logs a follow-up as a note" "$(example_of 'A PASS' | grep -c '^  in as a `Follow-up:` note, and fails nothing.$')" "1"
is "reviewer: the worked PASS's follow-up is a name in code" "$(example_of 'A PASS' | grep -c '^  named `tmp`: a name that misleads.')" "1"
case "$(json_of 'A PASS')" in *'"verdict": "PASS", "issues": 0,'*) pass "reviewer: the worked PASS still passes with its follow-up" ;;
  *) fail "reviewer: the worked PASS still passes with its follow-up" "in: $(json_of 'A PASS')" ;; esac
line_is "contract: the two kinds" "$CT" \
  '- **Defects and follow-ups.** `reviewer` sorts each finding as a defect, which fails the story, or'
file_has "contract: the follow-up kinds" "$CT" \
  '- A follow-up is a name that misleads, code repeated where it could be shared, or code against'
line_is "contract: any other finding is a defect" "$CT" '  the conventions the diff shows around it. Any other finding is a defect.'
file_has "contract: the defects whatever their kind" "$CT" \
  '  what the story'"${q}"'s criteria or Approach, or a rule written in the repo, names.'
line_is "contract: a finding not placed for sure is a defect" "$CT" '- A finding `reviewer` cannot place for sure is a defect.'
line_is "contract: only defects count and go to the fix loop" "$CT" \
  '- `reviewer` logs each defect as a `Defect <n>:` status note. Only defects count in `issues` and'
file_has "contract: a follow-up is a status note that fails nothing" "$CT" \
  '- It logs a follow-up as a `Follow-up:` status note. A follow-up changes no count, fails no story'
file_has "contract: the build lists the follow-ups when it finishes or stops" "$CT" \
  '- When the build finishes or stops, the skill lists each follow-up of the build so far, oldest'
line_is "contract: issues counts defects" "$CT" \
  '- `verdict` is `PASS`, `FAIL` or `BLOCKED`, `issues` the number of defects, and `checks` one'
file_lacks "contract: no finding fails a task by itself" "$CT" 'any finding fails the task'
file_has "build: points to the line between the kinds" "$SM" \
  'A review sorts each finding as a defect or a follow-up, as `## Defects and follow-ups` in'
line_is "build: has the list of follow-ups" "$SM" '### The list of follow-ups'
file_has "guide: points to the line" "$GD" '  `## Defects and follow-ups` in `agents/reviewer.md` draws the line.'
file_has "changelog: a review sorts defects and follow-ups" "$CG" \
  '- `reviewer` sorts each finding as a defect or a follow-up, as `## Defects and follow-ups` in'

# ---------------------------------------------------------------- the build catches an agent with no report, and checks on the owner's orders
CT="$here/docs/contract.md"
CG="$here/CHANGELOG.md"
q="'"
line_is "contract: the orders note is an optional file of the project" "$CT" \
  "  claude/lead-agent-task-memory.md  optional; the owner${q}s open orders, which the lead of a build writes (section 9)"
file_has "contract: an agent with no report" "$CT" '- **An agent with no report.** An agent can go idle before its report, such as on a reply that'
file_has "contract: one message, then the next reply is final" "$CT" \
  '- A check that still runs is waited for. With none, the skill sends the agent one message to'
file_has "contract: a repeated reply is no new event" "$CT" \
  '- A notice that repeats a reply the skill took already, such as a named agent'"${q}"'s last reply sent'
file_has "contract: the owner's open orders" "$CT" \
  "- **The owner${q}s open orders.** The skill keeps the owner${q}s open orders of a build in"
file_has "contract: the lead's check" "$CT" \
  "- **The lead${q}s check.** While an order of its story is open, the skill checks on the agents, the"
file_has "contract: at the pace of the profile's lead_check_minutes" "$CT" '  `lead_check_minutes` says (section 3). Of each order it tests the `Done when:` condition, and'
line_is "contract: the profile example has lead_check_minutes" "$CT" 'lead_check_minutes: 20'
file_has "contract: lead_check_minutes is described with the profile keys" "$CT" \
  '- `lead_check_minutes` is how many minutes the lead of a build waits between two checks on its'
file_has "contract: it takes the values that space the checks through the hour" "$CT" \
  '  or 60, the values that space the checks evenly through the hour. A missing or empty key, or any'
file_has "contract: the template leaves it out" "$CT" \
  '- `templates/profile.md.tmpl` leaves the key out. The doctor'"${q}"'s `settings` check warns on a value'
file_has "contract: the settings row names lead_check_minutes:invalid" "$CT" \
  'a profile `lead_check_minutes` that is not empty, 10, 12, 15, 20, 30 or 60 (`lead_check_minutes:invalid`), and'
file_lacks "profile template: leaves lead_check_minutes out" "$here/templates/profile.md.tmpl" 'lead_check_minutes'
file_has "vault-doctor checks: the settings check names lead_check_minutes:invalid" "$here/skills/vault-doctor/checks.md" \
  'Or a profile `lead_check_minutes` that is not empty, 10, 12, 15, 20, 30 or 60 (`lead_check_minutes:invalid`).'

file_has "contract: builds of one project only edit the shared note" "$CT" \
  '  note, so once it is there the skill changes it only with edits, never a whole rewrite.'
file_has "contract: the check stops with its story, the note with every story" "$CT" \
  '- Once no order of its story is open, the skill stops its check. Once no order of any story is'
file_has "contract: the check holds when the owner interrupts or says to hold" "$CT" \
  '- The check goes on with an order no one works toward only when the owner has not since'
file_has "contract: a process counts only under the worktree's path" "$CT" \
  '- A process counts as the agent'"${q}"'s check only when its working directory or command line is under'
file_lacks "contract: no task is set building, as a story build keeps no task states" "$CT" \
  'sets a task `building`'
file_lacks "contract: no bare It after the check's bullets" "$CT" '- It sets a task `building`'
file_has "contract: the check takes no outside action" "$CT" '- The check never pushes, merges or takes another outside action.'
file_has "contract: an order closes when its condition holds or the owner stops or drops it" "$CT" \
  '- An order closes when its `Done when:` condition holds, or when the owner stops the build or'
line_is "contract: the check's prompt is no order" "$CT" "  drops the order, at a stop or not. The check${q}s own prompt is no order."
file_has "contract: the check says a wait once" "$CT" 'Otherwise it waits for the owner and says so once,'
GD="$here/docs/guide.md"
line_is "guide: a build writes the orders note" "$GD" \
  "- A build writes your open orders to \`claude/lead-agent-task-memory.md\` in the project${q}s folder of"
line_is "guide: and a hub line, both removed once no order is open" "$GD" \
  "  your vault, with a line in the project${q}s \`claude/README.md\`, and removes both once no order is"
line_is "guide: and runs a check at the profile's pace" "$GD" \
  '- While one is open, it runs a check in your session, as often as `lead_check_minutes` in the'
for h in "## The owner${q}s open orders" "## The lead${q}s check"; do
  is "guide: the lead.md heading $h is under Building a story" \
    "$(awk '/^## Building a story$/ { on = 1; next } /^## / { on = 0 } on' "$GD" | grep -cF -- "\`$h\`")" "1"
done
file_has "changelog: the owner can stop the build or drop an order" "$CG" \
  'You can stop the build or drop an order at any time: it is then closed.'
lc_files="$(cd "$here" && find skills agents docs templates hooks README.md CHANGELOG.md -type f | sort)"
# The Bash tool's timeout of 10 minutes for a check names no pace: its three phrases are left out.
lc_ten="$(cd "$here" && printf '%s\n' "$lc_files" | tr '\n' '\0' | xargs -0 grep -nE '10 minutes|every 10\b|10-minute' 2>/dev/null \
  | grep -vE 'timeout(: 600000`)?(,| of) 10 minutes')"
is "the lead's check: no file names 10 minutes for it" "$lc_ten" ""
lc_cron="$(cd "$here" && printf '%s\n' "$lc_files" | tr '\n' '\0' | xargs -0 grep -nF '* * * *' 2>/dev/null)"
lc_ex='     minute 59, so no check falls on :00 or :30. With 20: `7,27,47 * * * *`.'
is "the lead's check: the only cron line is its example for the default" "$lc_cron" \
  'skills/build/lead.md:'"$(linex "$here/skills/build/lead.md" "$lc_ex")"":$lc_ex"
lc_min="$(grep -nE '[0-9]+ minutes' "$GD")"
is "the lead's check: the guide names no minutes" "$lc_min" ""
file_lacks "the lead's check: nor in the guide" "$GD" 'The check every'
file_lacks "the lead's check: nor in the contract" "$CT" 'The check every'
for l in '- A spec build agent that goes idle with no report, such as one that says its checks still run,' \
  '- An idle notice that repeats a reply the skill took already, as a named agent'"${q}"'s last reply comes' \
  '- The skill keeps your open orders of a build in `<project>/claude/lead-agent-task-memory.md`,' \
  '- While an order is open, the skill checks on the agents, the branch and the running checks' \
  '- A profile key, `lead_check_minutes`, sets the pace of that check in one place, as'; do
  line_is "changelog: ${l:2:48}" "$CG" "$l"
done

# ---------------------------------------------------------------- each order says when it is done, and the lead's check tests it
LD="$here/skills/build/lead.md"
SM="$here/skills/build/story.md"
CG="$here/CHANGELOG.md"
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
q="'"
oo="$(awk '/^## The owner'"${q}"'s open orders$/ { on = 1; next } /^## / { on = 0 } on' "$LD")"
lk="$(awk '/^## The lead'"${q}"'s check$/ { on = 1; next } /^## / { on = 0 } on' "$LD")"
in_oo() { case "$oo" in *"$2"*) pass "$1" ;; *) fail "$1" "missing in the orders section: $2" ;; esac; }
in_lk() { case "$lk" in *"$2"*) pass "$1" ;; *) fail "$1" "missing in the lead's check: $2" ;; esac; }
in_oo "build: done-when is one condition a command, a file or a branch state shows" \
  '- `Done when:` is one condition that a command, a file or a branch state shows to hold or not.'
in_oo "build: a condition names what shows it" \
  '  Name what shows it: a command and its exit code or what it prints, a file and the line it holds,'
in_oo "build: a judgement is no condition" '- A judgement, such as "the build looks good", is no condition.'
in_oo "build: a condition's command only reads" '- Its command only reads: never one that pushes, merges, fetches or writes.'
for c in '`git -C "<path>" merge-base --is-ancestor <branch> release/<version>` exits 0.' \
  '`git -C "<path>" ls-remote --tags origin v<version>` prints a line.' \
  'in `<path>`, `gh pr checks <number>` exits 0.' \
  '`grep -qxF "<line>" "<path>/<file>"` exits 0.' \
  'each story of the run holds a'; do
  in_oo "build: a condition a check can test: ${c:0:40}" "$c"
done
ex="$(printf '%s\n' "$oo" | awk '/^- Conditions that a check can test:$/ { on = 1; next } /^- / { on = 0 } on')"
is "build: the example conditions are five" "$(printf '%s\n' "$ex" | grep -c '^  - ')" "5"
is "build: no example condition writes" "$(printf '%s\n' "$ex" | grep -cE 'git push|git merge |git fetch|gh pr merge|gh pr create')" "0"
in_oo "build: never changes a condition without the owner" \
  '- Never change or drop a `Done when:` line without the owner, even when it looks out of reach. A'
in_oo "build: the owner's condition replaces it" "  condition the owner gives replaces it, and their words join the order${q}s."
in_oo "build: the condition is written as the order is taken" \
  '   - Write its `Done when:` line from the owner'"${q}"'s words as you add it, for the order that ran the'
in_oo "build: asks the owner only when the words give none" \
  '   - Their words give no condition, such as "keep an eye on it": ask the owner for one in your'
in_oo "build: an order waiting on the owner never holds" \
  '     reply. Until they answer, its line is `Done when: asked the owner.`, which never holds.'
in_oo "build: an order is done when its condition holds" \
  '   - It is done when its `Done when:` condition holds. Name what showed it, such as the command'
line_is "build: the finish condition is anchored on this run's start" "$LD" \
  '    `Build: finished` status note newer than its run'"${q}"'s start. That is the newest of its'
line_is "build: a resumed run's note is its start too" "$LD" \
  '    `Build: started on <branch> at <short hash>.` and `Build: resumed on <branch> at <short hash>.`'
fl="$(awk '/^### The list of follow-ups$/ { on = 1; next } /^### |^## / { on = 0 } on' "$SM")"
case "$fl" in *'Build: resumed'*) fail "build: the follow-up list stays anchored on the started note" "in: $fl" ;;
  *'They are the `Follow-up:` notes of this build.'*) pass "build: the follow-up list stays anchored on the started note" ;;
  *) fail "build: the follow-up list stays anchored on the started note" "in: $fl" ;; esac
rb="$(awk '/^### The rulings of this build$/ { on = 1; next } /^### |^## / { on = 0 } on' "$SM")"
case "$rb" in *'Build: resumed'*) fail "build: the rulings stay anchored on the started note" "in: $rb" ;;
  *'`Build: started on <branch> at <short hash>.` note'*) pass "build: the rulings stay anchored on the started note" ;;
  *) fail "build: the rulings stay anchored on the started note" "in: $rb" ;; esac
tpl="$(awk '/^```markdown$/ { on = 1; next } /^```$/ { on = 0 } on' "$LD")"
tp_done="$(printf '%s\n' "$tpl" | awk '/^\t- Done when: / { print NR; exit }')"
tp_now="$(printf '%s\n' "$tpl" | awk '/^\t- Now: / { print NR; exit }')"
is "build: the note's done-when line is a tab-indented item before Now" "$((${tp_done:-0} > 0 && ${tp_done:-0} < ${tp_now:-0}))" "1"
in_lk "build: the check runs the command as written" \
  '   - Run the condition'"${q}"'s command as it is written, or read its file or branch. It holds only when'
in_lk "build: it holds only when what it names shows" '     what it names shows, such as exit 0 or the line.'
in_lk "build: a condition it cannot test does not hold" \
  '   - A condition you cannot test, such as one whose command is not found: it does not hold. Say'
in_lk "build: an order with no condition gets one" '   - An order with no `Done when:` line: write one from its words, as item 2 of'
in_lk "build: the check closes an order whose condition holds" \
  '   - Its condition holds: take it to `## Done`, as `## The owner'"${q}"'s open orders` says.'
in_lk "build: never closes one whose condition fails, nor changes it" \
  '   - Never close an order whose condition does not hold, and never change a condition to close'
in_lk "build: the check stays read-only" '5. The check never pushes, merges or takes another outside action.'
line_is "build: the ask for a condition is no stop" "$SM" \
  '- An order whose words give no `Done when:` condition: ask the owner in your reply, as item 2 of'
line_is "build: it stops nothing" "$SM" '  `## The owner'"${q}"'s open orders` in `lead.md` says. It stops nothing.'
ask_l="$(lineno "$SM" '- An order whose words give no `Done when:` condition')"
own_l="$(lineno "$SM" '- Any other question you decide yourself')"
is "build: the ask comes before any other question is decided" "$((${ask_l:-0} < ${own_l:-0} && ${ask_l:-0} > 0))" "1"
file_has "contract: the note holds each order's condition" "$CT" \
  '- The note holds each open order, with its date, its story, the owner'"${q}"'s words, its `Done when:`'
file_has "contract: done-when is one condition a command, a file or a branch state shows" "$CT" \
  '- `Done when:` is one condition that a command, a file or a branch state shows to hold or not,'
file_has "contract: with its example" "$CT" '  such as `git merge-base --is-ancestor <branch> release/<version>` exiting 0. A judgement is no'
file_has "contract: written from the owner's words" "$CT" \
  '- The skill writes it from the owner'"${q}"'s words when it takes the order. It asks the owner only when'
line_is "contract: a condition reads, and only the owner changes it" "$CT" \
  '- A condition'"${q}"'s command only reads. Only the owner changes or drops a condition.'
file_has "contract: the check closes an order whose condition holds" "$CT" \
  '- The check closes an order whose condition holds, and never one whose condition does not. It'
file_has "contract: a condition it cannot test does not hold" "$CT" \
  '- A condition the check cannot test, such as one whose command is not found, does not hold. The'
file_has "guide: each order has a done-when line" "$GD" \
  '- Each order has a `Done when:` line, a condition a command, a file or a branch state can test.'
file_has "guide: only you change a condition" "$GD" 'order when its condition holds, and only you change a condition.'
file_has "changelog: each order has a done-when line" "$CG" \
  '- Each order in `lead-agent-task-memory.md` has a `Done when:` line: one condition a command, a'
file_has "changelog: the check tests it at the profile's pace" "$CG" \
  '- The lead'"${q}"'s check tests each open order'"${q}"'s condition, at the pace `lead_check_minutes` sets. It'

# ---------------------------------------------------------------- the build skill builds each approved story in a worktree of its own
BS="$here/skills/build/SKILL.md"
BY="$here/skills/build/story.md"
BL="$here/skills/build/lead.md"
CG="$here/CHANGELOG.md"
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
IM="$here/agents/implementer.md"
RM="$here/README.md"
RV="$here/agents/reviewer.md"
q="'"
for f in "$BS" "$BY" "$BL"; do
  exists "build skill: ${f##*/} exists" "$f"
  file_has "build skill: ${f##*/} carries the conventions pointer" "$f" 'Conventions: before writing notes, run `second-brain conventions` and follow it.'
  file_lacks "build skill: ${f##*/} uses no spec command" "$f" 'spec status'
  file_lacks "build skill: ${f##*/} logs no spec issue" "$f" 'spec issue'
  file_lacks "build skill: ${f##*/} fetches no packet" "$f" 'spec packet'
  file_lacks "build skill: ${f##*/} keeps nothing in build.json" "$f" 'build.json'
  file_lacks "build skill: ${f##*/} points into no spec file" "$f" 'skills/spec/'
done
line_is "build skill: its name" "$BS" 'name: build'
line_is "build skill: it may read, edit and write the orders note, and run the helper" "$BS" \
  'allowed-tools: Read Edit Write Bash(second-brain *)'
bs_tools="$(sed -n 's/^allowed-tools: //p' "$BS")"
case "$bs_tools" in
  *'Bash(git'*) fail "allowed-tools: build has no git pattern, so its git commands prompt" "got: $bs_tools" ;;
  *) pass "allowed-tools: build has no git pattern, so its git commands prompt" ;;
esac
is "allowed-tools: build has no other command pattern" \
  "$(printf '%s\n' "$bs_tools" | grep -oE 'Bash\([^)]*\)' | grep -vxF -e 'Bash(second-brain *)')" ""
bs_git="$(grep -c '`git -C "<path>" worktree add' "$BY")"
is "build skill: its text runs git -C, which prompts" "$(( ${bs_git:-0} >= 1 ))" "1"
bs_desc="$(sed -n 's/^description: //p' "$BS")"
is "build skill: its description is under 200 characters" "$(( ${#bs_desc} < 200 ))" "1"
case "$bs_desc" in *worktree*implementer*reviewer*) pass "build skill: its description names the worktree and both agents" ;;
  *) fail "build skill: its description names the worktree and both agents" "in: $bs_desc" ;; esac
line_is "build skill: the context comes first" "$BS" '1. Your first tool call is `second-brain context`.'
for f in story.md lead.md; do
  is "build skill: its files table routes to $f" "$(grep -c "^| \`\${CLAUDE_SKILL_DIR}/$f\` | " "$BS")" "1"
done
file_has "build skill: an epic's stories are those that name it" "$BS" '- An epic'"${q}"'s stories are the tasks its README links whose `epic`, as'
line_is "build skill: only the open stories" "$BS" '- Take the open stories: `status` `planned` or `in-progress`. Leave the `in-review`, `done` and'
file_has "build skill: in the order depends_on sets" "$BS" '- A story goes after each story of the run it waits on, as the `depends_on` cell of'
line_is "build skill: a ring stops" "$BS" '- Stories that wait on each other in a ring: stop, and show the ring.'
file_has "build skill: approved means the approval note" "$BS" \
  '- A story is approved when its status notes hold `Planned: the owner approved this text.` Read'
line_is "build skill: no note, no build, and refinement is offered" "$BS" \
  '- A story with no such note is not built. Say so, and offer `/odsb:scrum-master refinement` for'
line_is "build skill: one story and one agent at a time in each pair" "$BS" \
  '- One story and one agent at a time in each pair, and at most `<pairs>` pairs at once, as Step 4'
# One story's build
line_is "story build: the worktree is named for the repo and the story" "$BY" \
  '- `<worktree>` is `<path>-<ID>`: a folder next to the repo'"${q}"'s, named for the repo and the story.'
for c in '`git -C "<path>" worktree list --porcelain`' \
  '`git -C "<path>" worktree add "<worktree>" <branch>`' \
  '`git -C "<path>" worktree add -b <branch> "<worktree>" <from>`' \
  '`second-brain validation "<project>" <repo> --path "<worktree>"`' \
  '`git -C "<path>" worktree remove "<worktree>"`'; do
  file_has "story build: runs $c" "$BY" "$c"
done
line_is "story build: a worktree removed only without --force" "$BY" \
  '   - Then `git -C "<path>" worktree remove "<worktree>"`. Never pass `--force`. It fails, as on a'
file_has "story build: the branch stays" "$BY" 'The branch stays, with'
for n in 'Build: started on <branch> at <short hash>.' 'Build: resumed on <branch> at <short hash>.' \
  'Build: review <n> passed at <short hash>.' 'Build: review <n> failed at <short hash>: <k> defects.' \
  'Build: review <n> blocked at <short hash>.' 'Build: stopped: <why>.' \
  'Build: finished; review <n> passed, the branch is at <short hash>.'; do
  file_has "story build: writes the note $n" "$BY" "\"$n\""
done
line_is "story build: fails come from the status notes" "$BY" \
  '- `fails` is the number of `Build: review <m> failed at <hash>` notes of this build.'
# The counts read the notes, so each shape is the same, word for word, in the contract and in the
# file that writes it.
while IFS='|' read -r nf shape; do
  [ -n "$shape" ] || continue
  file_has "contract: lists the note shape $shape" "$CT" "  - \`$shape\`"
  file_has "${nf##*/}: writes the note shape $shape" "$nf" "$shape"
done <<NOTES
$BY|Build: started on <branch> at <short hash>.
$BY|Build: resumed on <branch> at <short hash>.
$BY|Build: baseline skipped: the branch starts at <base> on <base ref>.
$BY|Build: the baseline passed at <short hash>.
$BY|Build: review <n> passed at <short hash>.
$BY|Build: review <n> failed at <short hash>: <k> defects.
$BY|Build: review <n> failed at <short hash>: the owner ruled a fix.
$BY|Build: review <n> blocked at <short hash>.
$BY|Build: review <n> gave no verdict at <short hash>.
$BY|Build: stopped: <why>.
$BY|Build: the owner ruled: <the ruling, as written>.
$BY|Build: finished; review <n> passed, the branch is at <short hash>.
$BY|Build: merged <branch> into <target> at <short hash>.
$BY|Build: pushed <target> at <short hash>.
$BY|Build: the owner kept <branch> unmerged.
$BY|Build: <branch> waits for <that branch> in <target>.
$BY|Ruling: <the question> - <the decision and why>
$RV|Defect <n>: <what is wrong, at file:line> - Fix: <the fix you propose>
$BY|Defect <n>: The owner ruled: <the ruling, as written> - Fix: <the fix it asks>
$RV|Follow-up: <what could be better, at file:line> - <the change you propose>
NOTES
file_has "contract: the notes of a build and the counts they give" "$CT" \
  '- The notes of a build are those newer than its newest `Build: started on` note. Its `fails` is'
file_has "story build: the follow-up list reads the reviewer's shape" "$BY" '- They are the `Follow-up:` notes of this build.'
file_has "story build: a fix reads the reviewer's defect shape" "$BY" 'Its defects are the story'"${q}"'s Defect <m>: status notes.'
file_has "implementer: a story fix reads the same defect shape" "$IM" 'Read the story'"${q}"'s `Defect <m>:` status notes'
file_has "contract: a new build never reuses the worktree path" "$CT" \
  '- A new build never reuses that path: when anything is there already, the skill says what it is'
file_has "story build: a new build stops on anything at the worktree path" "$BY" \
  '   - A new build, and anything is at `<worktree>`, a worktree or a folder: say what is there, from'
line_is "story build: never reuses or deletes it" "$BY" \
  '     that list or `ls -A "<worktree>"`, and stop. Never reuse it, and never delete it.'
file_has "story build: a resumed build says it goes on in its own worktree" "$BY" \
  '     `branch refs/heads/<branch>`. Say that you go on in it, at its `<short hash>`, then go on.'
file_has "story build: the steps before the start note ask as they say" "$BY" \
  '- The steps before the `Build: started` or `Build: resumed` note stop and ask as they say: the'
file_has "story build: the round is one more than the reviews so far" "$BY" \
  '- `<n>`, the round of the next review, is one more than the number of `Build: review <m>` notes'
file_has "story build: never counts a round from memory" "$BY" 'They are newest first.'
line_is "story build: the implementer on opus" "$BY" '  - `odsb:implementer`: `model: "opus"`. It builds the story, and takes fix rounds 1 to 3.'
line_is "story build: from fix round 4 on fable" "$BY" '  - `odsb:implementer` from fix round 4 on: `model: "fable"`, the stronger model.'
line_is "story build: the reviewer on opus" "$BY" '  - `odsb:reviewer`, in story or baseline mode: `model: "opus"`.'
line_is "story build: the implementer is named for the batch" "$BY" '  - The build and fix rounds 1 to 3: `name: "<batch>-implementer"`.'
line_is "story build: and from round 4" "$BY" '  - From fix round 4 on: `name: "<ID>-implementer-2"`.'
for l in '  - `Mode: story.`' '  - `Story: <ID>, project <project>.`' '  - `Repo: <repo>.`' \
  '  - `Worktree: <worktree>.`' '  - `Branch: <branch>.`' '  - `Base: <base>.`' '  - `Round: <n>.`'; do
  line_is "story build: a prompt line $l" "$BY" "$l"
done
line_is "story build: the fix message names the failed review" "$BY" \
  '  - `Fix: review <m> failed. Its defects are the story'"${q}"'s Defect <m>: status notes.`, with `<m>`'
line_is "story build: the fix message's review is the newest failed one" "$BY" \
  '    from the newest `Build: review <m> failed at <hash>` note.'
line_is "story build: a re-review names the review it follows" "$BY" \
  '  - A re-review: `Last failed: review <m> at <hash>.`, from the newest'
line_is "story build: has an agent with no report" "$BY" '### An agent with no report'
file_has "story build: counts only a process under the worktree" "$BY" '`<worktree>`: another build'"${q}"'s tests may run in another worktree.'
file_has "story build: a repeated notice is no new event" "$BY" \
  'notice that repeats a reply you took already is no new event: it changes no state, and gets no'
line_is "story build: a PASS logs no defect" "$BY" '     holds no `Defect <n>:` note too.'
file_has "story build: a post-pass fix comes back through the worktree" "$BY" '  may be gone. Then `## 2. The worktree`, as for a resumed build, and `### The fix loop`.'
file_has "build skill: an in-review story is built again only on a ruling to fix it" "$BS" \
  '- A story named alone that is `in-review` has passed: say so. Build it again only on the owner'"${q}"'s'
file_has "story build: a FAIL logs one defect or more" "$BY" \
  '   - A `FAIL` has `issues` 1 or more. In story mode the story holds one `Defect <n>:` note or'
line_is "story build: the cap" "$BY" '1. `fails` 6 or more, right after a FAIL: the cap is reached. Stop, as'
line_is "story build: rounds 1 to 3 go to the batch's implementer" "$BY" \
  '   - `fails` 1 to 3: the same `implementer`. Send the fix message to `<batch>-implementer`, and wait'
line_is "story build: a fresh one gets the fix line too" "$BY" \
  '     `implementer` in its place, with the build'"${q}"'s prompt and the fix message'"${q}"'s first line, its'
line_is "story build: round 4 on the stronger model" "$BY" \
  '   - `fails` 4: launch a fresh `implementer` on the stronger model, named from round 4 on, with'
line_is "story build: a passed story merges as the merge says" "$BY" '4. Merge it, as `### The merge` says.'
bm6="$(lineno "$BY" '4. Merge it, as `### The merge` says.')"
bm7="$(lineno "$BY" '5. Once the merge is done, or the owner says not to merge, remove the worktree')"
is "story build: the worktree goes once the merge is done, or not wanted" "$(( ${bm6:-0} > 0 && ${bm6:-0} < ${bm7:-0} ))" "1"
is "story build: the stop list has six items" \
  "$(awk '/^## 8\. When to ask the owner/ { on = 1; next } /^### / { on = 0 } on && /^[0-9]+\. /' "$BY" | grep -c '')" "6"
line_is "story build: a ruling never changes a criterion" "$BY" \
  '   - A ruling never changes, adds or drops an acceptance criterion. One that would is a story too'
line_is "story build: has the list of rulings" "$BY" '### The list of rulings'
line_is "story build: has the list of follow-ups" "$BY" '### The list of follow-ups'
is "story build: lists the rulings and follow-ups at the finish and at a stop" \
  "$(grep -c '`### The list of follow-ups` says' "$BY")" "2"
file_has "story build: the follow-ups are read from the status notes" "$BY" \
  '- Every session reads them from `## Status notes`, as the top of this file says: the reviews'
file_has "story build: a release check only on the owner's ask, in the worktree" "$BY" \
  '`second-brain validation run "<project>" <repo> --when release --path "<worktree>"`, with the'
# The lead's orders and check
line_is "build lead: the orders note" "$BL" '`<project path>/claude/lead-agent-task-memory.md`. It tells the lead'"${q}"'s check, and a new session,'
file_has "build lead: each order has a done-when line" "$BL" '- `Done when:` is one condition that a command, a file or a branch state shows to hold or not.'
file_has "build lead: the build's own order is done when each story finished" "$BL" \
  '  - The order that ran the build, in no other words: each story of the run holds a'
line_is "build lead: the check's prompt names lead.md of the build skill" "$BL" \
  '     `Check on the open orders of <ID>, as the lead'"${q}"'s check in lead.md of the build skill says.`'
file_has "build lead: the pace is lead_check_minutes" "$BL" '   - Its pace is the `lead_check_minutes` line of `second-brain profile "<project>" --keys`: 10,'
line_is "build lead: the check takes no outside action" "$BL" '5. The check never pushes, merges or takes another outside action.'
line_is "build lead: never closes an order whose condition fails" "$BL" \
  '   - Never close an order whose condition does not hold, and never change a condition to close'
file_has "build lead: the note template has the done-when item" "$BL" "$(printf '\t- Done when: <one condition that a command, a file or a branch state shows>.')"
# The agents' story mode
line_is "implementer: has a story mode" "$IM" '## Story mode'
line_is "implementer: checks its own change" "$IM" '### Check it yourself'
line_is "implementer: takes a story fix" "$IM" '### A story fix'
file_has "implementer: reads the story's parts" "$IM" '`## Acceptance criteria` and `## Approach / Key decisions`.'
file_has "implementer: runs the each-story checks in the worktree, from the story's base" "$IM" \
  '`second-brain validation run "<project>" <repo> --when each-story --changed <base> --path "<worktree>"`.'
file_has "implementer: reads the reviewer's defects and quality lists before it commits" "$IM" \
  '- Read `## Defects and follow-ups` and `## Code quality` in the reviewer'"${q}"'s agent file. Its path is'
file_has "implementer: finds the reviewer's file at the plugin's path" "$IM" \
  'what `printf '"${q}"'%s\n'"${q}"' "${CLAUDE_PLUGIN_ROOT}/agents/reviewer.md"` prints. Fix each defect they'
file_has "implementer: a story fix reads the failed review's defects" "$IM" '- Read the story'"${q}"'s `Defect <m>:` status notes, with a ranged read of `## Status notes`. Each is'
line_is "reviewer: has a story mode" "$RV" '## Story mode'
is "reviewer: story mode comes before baseline mode" "$(( $(linex "$RV" '## Story mode') < $(linex "$RV" '## Baseline mode') ))" "1"
line_is "reviewer: the worktree line sets where it checks" "$RV" \
  'the worktree of your prompt'"${q}"'s `Worktree:` line. Keep the `status --porcelain` output: the user'
file_has "reviewer: a worktree line adds --path to each validation" "$RV" \
  '- A prompt with a `Worktree:` line: add `--path "<worktree>"` to each `validation` and'
file_has "reviewer: a first review reads the story's whole change" "$RV" '`git -C "<worktree>" diff <base>...HEAD`.'
file_has "reviewer: a re-review reads the fix's commits alone" "$RV" '`git -C "<worktree>" diff <hash>..HEAD`, the fix'"${q}"'s commits alone.'
line_is "reviewer: a first review grades each acceptance criterion" "$RV" '   - A first review: each acceptance criterion of the story.'
file_has "reviewer: story mode runs the each-story checks from the story's base" "$RV" \
  '   the checks with `--when each-story --changed <base>`, with the base of your prompt, and each'
file_has "reviewer: baseline mode runs the each-merge checks and both stages' user steps" "$RV" \
  '  `--when each-merge`, then each user step whose `when:` is `each story` or `each merge`.'
file_has "reviewer: a check its change does not touch is skipped, no finding" "$RV" \
  '  That is no finding: the change cannot break it.'
file_has "reviewer: logs each story defect with its round" "$RV" \
  '`second-brain task note <story> "Defect <n>: <what is wrong, at file:line> - Fix: <the fix you propose>" --session <id>`.'
file_has "reviewer: a follow-up names no task" "$RV" '"Follow-up: <what could be better, at file:line> - <the change you propose>"'
line_is "reviewer: uncommitted changes fail a story" "$RV" '- In story mode, uncommitted changes are a finding, and the verdict is FAIL.'
# story-tracker writes the approval note in start mode too
line_is "story-tracker create: every story it writes gets the approval note first" \
  "$here/skills/story-tracker/create.md" '5. Every story written here was approved, here or in refinement: first'
file_has "story-tracker create: the approval note's exact text" "$here/skills/story-tracker/create.md" \
  '`second-brain task note EX-123 "Planned: the owner approved this text." --session'
is "story-tracker create: the approval note is one rule, in step 5" \
  "$(grep -c 'Planned: the owner approved this text.' "$here/skills/story-tracker/create.md")" "1"
file_has "contract: one rule for the approval note" "$CT" \
  '- Every story whose text the owner approved, in start mode or in refinement, gets the status note'
# The contract, the guide, the README and the changelog describe the flow
file_has "contract: the build skill" "$CT" '- **The `build` skill builds approved stories.** It takes one story, or an epic'"${q}"'s open stories in'
file_has "contract: a worktree of its own" "$CT" '- Each story is built in a git worktree of its own, `<repo path>-<ID>`, next to the repo'"${q}"'s'
line_is "contract: the story's progress is in its status notes" "$CT" '- The story'"${q}"'s progress is in its status notes. The counts read them, so each note has one of'
file_has "contract: a passed story merges only on the owner's go" "$CT" \
  '- **The merge.** A passed story merges into its target only on the owner'"${q}"'s go. The merge is'
file_lacks "contract: no spec build keeps a copy of the lead's rules" "$CT" 'keeps its own copy of these rules'
file_has "contract: the one flow" "$CT" \
  '- It is the one flow that builds a story: from its README, with no delivery mode. The spec flow'
file_has "contract: story mode" "$CT" '- **Story mode.** In a story build, a prompt with `Mode: story.` gives each agent the story, its'
file_has "contract: the implementer checks its change first" "$CT" '- Before it commits, it checks its whole change against the story'"${q}"'s criteria, and against'
line_is "guide: has Building a story" "$GD" '## Building a story'
file_has "guide: the build request is under What to say" "$GD" '| Build the approved stories of EX-1. | `build` |'
file_has "guide: a worktree of its own" "$GD" '- Each story is built in a git worktree of its own, next to the repo'"${q}"'s folder. The'
line_is "README: has the build section" "$RM" '### `/odsb:build`'
file_has "README: points to the guide's Building a story" "$RM" '`## Building a story` in `docs/guide.md`'
file_has "README: names the build skill on the implementer row" "$RM" 'test-first, runs its checks and commits it. | `build`. |'
file_has "changelog: the build skill" "$CG" '- A new `build` skill builds approved stories: one story, or an epic'"${q}"'s open stories in the order'
file_has "changelog: the agents' story mode" "$CG" '- `implementer` and `reviewer` build and review a whole story in its git worktree, in story mode.'

# ---------------------------------------------------------------- a passed story merges as the project's git flow says, on the owner's go
BY="$here/skills/build/story.md"
CG="$here/CHANGELOG.md"
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
q="'"
gf="$(awk '/^### The git flow$/ { on = 1; next } /^##+ / { on = 0 } on' "$BY")"
mg="$(awk '/^### The merge$/ { on = 1; next } /^##+ / { on = 0 } on' "$BY")"
in_gf() { case "$gf" in *"$2"*) pass "$1" ;; *) fail "$1" "missing in the git flow: $2" ;; esac; }
in_mg() { case "$mg" in *"$2"*) pass "$1" ;; *) fail "$1" "missing in the merge: $2" ;; esac; }
line_is "git flow: has its section" "$BY" '### The git flow'
gf_at="$(linex "$BY" '### The git flow')"
w2_at="$(linex "$BY" '## 2. The worktree')"
b3_at="$(linex "$BY" '## 3. The baseline')"
is "git flow: it sits in the worktree step, before the baseline" "$(( ${w2_at:-0} > 0 && ${w2_at:-0} < ${gf_at:-0} && ${gf_at:-0} < ${b3_at:-0} ))" "1"
in_gf "git flow: reads the project's rules" '1. Read `## Rules` in `<project path>/claude/README.md`, with `second-brain outline` and a ranged'
in_gf_lacks=$(printf '%s\n' "$gf" | grep -c 'subproject' || true)
is "git flow: reads no other rules" "$in_gf_lacks" "0"
in_gf "git flow: never guesses" "It is the project's own rules: read them, never guess them."
in_gf "git flow: a rule names a branch or a pattern" 'names a branch, such as `main`, or a pattern, such as `release/<version>`.'
in_gf "git flow: lists the branches a pattern matches by full ref, prefix stripped" "\`git -C \"<path>\" for-each-ref --format='%(refname)' 'refs/heads/<prefix>*' 'refs/remotes/*/<prefix>*' | sed -E 's#^refs/(heads|remotes/[^/]+)/##' | sort -rVu\`"
file_lacks "git flow: no lstrip that fits one slash alone" "$BY" 'refname:lstrip'
in_gf "git flow: the prefix keeps its slashes" "     with \`<prefix>\` the pattern's text before \`<version>\`, slashes and all. The version of each"
in_gf "git flow: a tag holds a shipped version, exactly" '`git -C "<path>" tag --list "<version>" "v<version>"` prints a line.'
file_lacks "git flow: no tag glob that matches a longer version" "$BY" 'tag --list "*<version>"'
in_gf "git flow: only the highest two count" 'highest two alone: an old branch left untagged below them is no open one.'
in_gf "git flow: none or two open asks the owner" 'Either way, ask the owner which.'
in_gf "git flow: no cut rule takes the branch check" '4. No rule says where a branch is cut: `<from>` is as `## Branch check (start, update, recall)` in'
in_gf "git flow: no merge rule asks the owner" '5. No rule says where a story merges: ask the owner, when `### The merge` asks for the go. Then'
in_gf "git flow: offers to write the answer under Rules" '   offer to write the answer as a rule under `## Rules` in `<project path>/claude/README.md`.'
in_gf "git flow: writes it only on the owner's yes" "   - Write it only on the owner's yes, in their words, with the Edit tool."
file_has "worktree: a new branch is cut where the git flow says" "$BY" '     `second-brain task set <ID> branch=<branch>`. Item 2 cuts it from `<from>`, as'
file_lacks "worktree: the cut is no longer the branch check's alone" "$BY" 'is cut from, as the branch check says.'
line_is "merge: has its section" "$BY" '### The merge'
in_mg "merge: local, and pushed only on the owner's word" 'merge is local. A push is another step, on the owner'"${q}"'s word alone.'
in_mg "merge: a story cut from another merges after it" '`git -C "<path>" merge-base --is-ancestor <that branch> <target>` must exit 0. Otherwise:'
in_mg "merge: with no target, item 1 asks where it merges before the check" \
  '   - No `<target>` found: ask where it merges first, as item 5 of `### The git flow` says, then'
mg_ask="$(lineno "$BY" 'No `<target>` found: ask where it merges first')"
mg_chk="$(lineno "$BY" '   - `git -C "<path>" merge-base --is-ancestor <that branch> <target>` must exit 0. Otherwise:')"
mg_two="$(lineno "$BY" '2. Ask the owner with AskUserQuestion: merge `<branch>` into `<target>` now, or keep it')"
is "merge: the ask comes before the check, both in item 1" \
  "$(( ${mg_ask:-0} > 0 && ${mg_ask:-0} < ${mg_chk:-0} && ${mg_chk:-0} < ${mg_two:-0} ))" "1"
in_mg "merge: the wait is noted" '   - `second-brain task note <ID> "Build: <branch> waits for <that branch> in <target>."`.'
in_mg "merge: and named in next" '   - `second-brain task set <ID> next="Waits for <that branch> in <target>, then the owner'"${q}"'s go to merge"`.'
in_mg "merge: a later run takes it up again" '     later run takes it up again, as Step 1 of `SKILL.md` says.'
in_mg "merge: asks the owner for the go" '2. Ask the owner with AskUserQuestion: merge `<branch>` into `<target>` now, or keep it'
in_mg "merge: no target asks where in the same question" '   - No `<target>` found: ask where it merges in the same question, as item 5 of'
in_mg "merge: the owner's checkout only when it holds the target and is clean" "   - It may be the owner's own checkout, \`<path>\`: merge there only when item 4 finds it clean."
file_lacks "merge: no rule against the owner's checkout that the contract does not share" "$BY" 'Never merge in the owner'"${q}"'s own checkout'
in_mg "merge: adds a worktree for the target when none holds it" '`git -C "<path>" worktree add "<path>-<ID>-merge" <target>`'
in_mg "merge: its own worktree goes whenever the merge ends" '   - The merge ends at item 9'"${q}"'s answer, at a stop, on a kept branch, or once the owner answers a'
in_mg "merge: and only a worktree it added" '     failing check. Then remove a worktree this item added, as item 5 of'
in_mg "merge: a clean target first" '4. `git -C "<where>" status --porcelain` must print nothing. Otherwise ask the owner: never merge'
in_mg "merge: runs with the merge base in each block" \
  '`git -C "<where>" -c merge.conflictStyle=diff3 merge --no-ff <branch> -m "Merge <branch> into <target>"`.'
in_mg "merge: how a block is read" '   one'"${q}"'s conflict blocks: `<<<<<<<`, then the target'"${q}"'s lines, `|||||||`, the merge base'"${q}"'s lines,'
in_mg "merge: an empty base part only adds lines" '   - A block whose base part is empty only adds lines: neither side removed or changed one there.'
in_mg "merge: keeps both, the target's lines first" '     Keep both: the target'"${q}"'s lines, then the story'"${q}"'s, with no marker left.'
in_mg "merge: any other conflict is shown" '   - Any other conflict, such as one of those, a block with base lines, or a file one side deleted'
in_mg "merge: a shared line is no add-only block" '   - Not when the two sides of that block share a line: keeping both would hold it twice.'
in_mg "merge: a file both sides added is no add-only block" '   - Not in a file with no base, one both sides added: `git -C "<where>" ls-files -u -- <file>`'
in_mg "merge: an undo goes on as for a kept branch" '   - Undone: `second-brain task note <ID> "Build: the owner kept <branch> unmerged."`, then go on'
file_has "story build: the merge rule offer stops nothing" "$BY" \
  '- The offer to write a merge rule under `## Rules`, as item 5 of `### The git flow` says, goes in'
file_has "story build: the story's worktree may be gone after a wait" "$BY" \
  '5. Once the merge is done, or the owner says not to merge, remove the worktree, when it is still'
file_has "build skill: a waiting story is taken up again" "$here/skills/build/SKILL.md" \
  '- An `in-review` story whose newest `Build:` note is `Build: <branch> waits for <that branch> in <target>.`'
file_has "build skill: straight to the merge once the branch is in the target found" "$here/skills/build/SKILL.md" \
  '    `<target>` found, take it to `### The merge` in `story.md`, from item 2. Else say it still'
file_has "build skill: the target is found again from the rules, never taken from the note" "$here/skills/build/SKILL.md" \
  '  waits to merge. Find its `<target>` again first, as items 1 to 3 of `### The git flow` in'
file_has "build skill: and the owner is asked when no rule names it" "$here/skills/build/SKILL.md" \
  '  `story.md` say, and item 5 when no rule names it, never from the note: the release it named'
file_lacks "build skill: the pickup reads the rules too" "$here/skills/build/SKILL.md" 'items 2 and 3 of `### The git flow`'
file_has "contract: with no rule, the target is asked before the check" "$CT" \
  '- With no rule that names its target, the skill asks the owner where it merges first, as for any'
file_has "contract: a later run reads the rules and asks when none names the target" "$CT" \
  '- It reads the project'"'"'s rules for that, and asks the owner where the story merges when no rule'
file_has "build skill: a shipped branch is no open one, so the owner is asked" "$here/skills/build/SKILL.md" \
  'a shipped branch is no open one, so the git flow asks the owner.'
wt_find="$(lineno "$here/skills/build/SKILL.md" 'waits to merge. Find its `<target>` again first')"
wt_merge="$(lineno "$here/skills/build/SKILL.md" '`<target>` found, take it to `### The merge`')"
is "build skill: the target is found before the ancestor check and the merge" "$(( ${wt_find:-0} > 0 && ${wt_find:-0} < ${wt_merge:-0} ))" "1"
file_has "contract: the wait is recorded" "$CT" '  then the skill writes `Build: <branch> waits for <that branch> in <target>.`, and sets `next`'
file_has "contract: a later run takes the waiting story up again" "$CT" \
  '- A later run takes up an `in-review` story whose newest `Build:` note is that wait. It finds the'
file_has "contract: and finds the target again, as a release may have shipped" "$CT" \
  '  target again, as the git flow says, since the release the wait named may have shipped: a'
file_has "contract: the owner's checkout only when it holds the target and is clean" "$CT" \
  '- That worktree may be the owner'"${q}"'s own checkout: the skill merges there only when it holds the'
file_lacks "contract: no never-in-the-owner's-checkout rule left" "$CT" '  owner'"${q}"'s own checkout.'
file_has "contract: the merge worktree goes whenever the merge ends" "$CT" \
  '- A worktree the skill adds for a merge is removed whenever the merge ends: pushed or not, kept,'
file_has "contract: a shared line or a file with no base is shown" "$CT" \
  '- Not when both sides share a line in that block, which would keep it twice, and not in a file'
file_has "contract: branches listed by full ref" "$CT" \
  '- The branches that match are listed by their full ref, local and remote, with the ref'"${q}"'s prefix'
in_mg "merge: and the merge aborted" '`git -C "<where>" merge --abort`, and stop, as `## 7. When the story stops` says.'
in_mg "merge: no marker is left" '   - Every block kept: no line in the files starts with a marker. Then'
in_mg "merge: runs every each-merge check, even on the reviewed tree" \
  '8. The checks on the merged tree: every `each merge` one, even on the tree the review read. A'
in_mg "merge: the each-merge checks run there" \
  '`second-brain validation run "<project>" <repo> --when each-merge --path "<where>"`'
mg_lacks="$(printf '%s\n' "$mg" | grep -c 'tree}' || true)"
is "merge: compares no tree, so the checks never skip" "$mg_lacks" "0"
in_mg "merge: runs no user step" '   - The merge runs no user step. Read the steps with'
in_mg "merge: names each each-merge user step to the owner" \
  '`second-brain validation "<project>" <repo> --path "<where>"`. Name to the owner each line'
in_mg "merge: a failing check pushes nothing" '   - A `fail` row: push nothing, and skip item 9.'
in_mg "merge: undoing it is the owner's word" '`git -C "<where>" reset --hard <before>`, is a destructive action: only'
in_mg "merge: a push only on the owner's yes, named first" '`<target>`. Name the push first: `git -C "<where>" push origin <target>`. Run it only on their'
mg7="$(printf '%s\n' "$mg" | grep -n '^7\. ' | cut -d: -f1)"
mg8="$(printf '%s\n' "$mg" | grep -n '^8\. The checks on the merged tree' | cut -d: -f1)"
mg9="$(printf '%s\n' "$mg" | grep -n '^9\. Every check passed or was skipped' | cut -d: -f1)"
is "merge: the note, then the checks, then the push" "$(( ${mg7:-0} > 0 && ${mg7:-0} < ${mg8:-0} && ${mg8:-0} < ${mg9:-0} ))" "1"
file_has "story build: a merge and a push wait for the owner's own answer" "$BY" \
  '- A merge and a push each wait for the owner'"${q}"'s own answer, as `### The merge` asks for it: never'
file_has "contract: the git flow is the project's rules" "$CT" \
  '- **The git flow.** Where a story'"${q}"'s branch is cut, and where a passed story merges, is the'
file_has "contract: no profile key holds the flow" "$CT" '  reads them there. No profile key holds the flow.'
file_has "contract: a pattern stands for its open branch" "$CT" '  stands for its open branch: the highest that matches it, when no tag `<version>` or'
file_has "contract: no merge rule asks, and offers to write one" "$CT" \
  '- No rule says where a story merges: the skill asks the owner, and offers to write the answer'
file_has "contract: an add-only conflict keeps both" "$CT" '- A conflict that only adds lines keeps both sides. The merge runs with'
file_has "contract: any other conflict is shown and aborted" "$CT" \
  '- Any other conflict, such as a block with base lines or a file one side deleted, is shown to the'
file_has "contract: every each-merge check runs on the merged tree" "$CT" \
  '- Then every `each merge` check of the repo runs on the merged tree, through'
file_has "contract: the merge names each each-merge user step it leaves" "$CT" \
  '- The merge runs no user step, as it launches no agent. The skill names each `each merge` user'
file_has "contract: the baseline runs the each-merge checks" "$CT" \
  '- The baseline runs the checks through `validation run --when each-merge`, and the `each story`'
line_is "contract: a push only on the owner's word" "$CT" \
  '- A push runs only on the owner'"${q}"'s word, asked for once the checks pass, and named before it runs.'
file_has "contract: the worktree goes once the merge is done" "$CT" \
  '- Once the merge is done, or the owner says not to merge, the skill removes the story'"${q}"'s worktree'
file_has "guide: a story merges where the git flow says" "$GD" \
  '- A passed story merges where your project'"${q}"'s git flow says, as you write it under `## Rules` in'
file_has "README: a passed story merges as the git flow says" "$here/README.md" \
  '- A passed story merges where your project'"${q}"'s git flow says, written under `## Rules` in its'
file_has "changelog: the git flow" "$CG" '- The build skill reads the project'"${q}"'s git flow from `## Rules` in its Claude hub: where a story'"${q}"'s'
file_has "changelog: the merge" "$CG" '- A passed story merges on the owner'"${q}"'s go, locally. A conflict where both sides only add lines,'

# ---------------------------------------------------------------- a story build resumes, relaunches and cleans up without losing its place
BS="$here/skills/build/SKILL.md"
BY="$here/skills/build/story.md"
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
IM="$here/agents/implementer.md"
RF="$here/skills/scrum-master/refinement.md"
q="'"
# A resume after a blocked review, or one with no verdict, reviews again.
file_has "story build: a resume after a blocked review goes to Review it" "$BY" \
  '  3. Its newest review note is `Build: review <m> blocked`, for a stop the owner answered, as'
r3="$(lineno "$BY" '  3. Its newest review note is `Build: review <m> blocked`')"
r4="$(lineno "$BY" '  4. Commits on the branch since the hash of its newest review note')"
r1="$(lineno "$BY" '  1. Its newest `Build:` note is `Build: stopped: <why>.`')"
is "story build: after the unanswered stop, before the commits rung" "$(( ${r1:-0} > 0 && ${r1:-0} < ${r3:-0} && ${r3:-0} < ${r4:-0} ))" "1"
# A fresh reviewer gets a round of its own.
file_has "story build: a block with no verdict is noted first" "$BY" \
  '`second-brain task note <ID> "Build: review <n> gave no verdict at <short hash>."`. The'
file_has "story build: the fresh reviewer takes the next round" "$BY" \
  'its place, with the same prompt but the next round, `<n>` plus one, as `## 1` counts it.'
file_has "contract: lists the no-verdict note" "$CT" '  - `Build: review <n> gave no verdict at <short hash>.`'
# The owner's fix after a pass takes its hash from the branch.
file_has "story build: the owner's fix note takes the branch's hash" "$BY" \
  'with `<short hash>` what `git -C "<path>" rev-parse --short <branch>` prints: the worktree'
# A worktree is removed only once its ignored files are shown.
file_has "story build: lists the ignored files before the removal" "$BY" \
  '   - First run `git -C "<worktree>" status --porcelain --ignored`. Each `!!` path is an ignored'
file_has "story build: and goes on only on the owner's word" "$BY" \
  '     file the removal deletes, such as a `.env`. Show the owner each one, and go on only on their'
file_lacks "story build: no claim that a removal keeps every file" "$BY" 'nothing that is not committed, or the command fails'
file_has "story build: removal deletes ignored files" "$BY" '- `git worktree remove` refuses a worktree with a change, but deletes its ignored files. Removing'
file_has "contract: the removal lists ignored files first" "$CT" \
  '- `git worktree remove` refuses a worktree with a change, but deletes its ignored files, such as a'
file_has "guide: the worktree goes after the merge, once its ignored files are shown" "$GD" \
  '- Once the merge is done, or you say not to merge, the story'"'"'s worktree is removed, after Claude'
# A session cut off before the removal ends it next time.
file_has "build skill: an in-review story with its worktree left ends the build" "$BS" \
  '- An `in-review` story with a `Build: finished` note whose worktree is still there, on its branch'
file_has "build skill: reads story.md, then finishes the leftover" "$BS" \
  '  `story.md` names them: its session ended before the worktree went. Read `story.md`, and'
file_has "build skill: merges a leftover first when no merge note settles it" "$BS" \
  '  - No `Build: merged` or `Build: the owner kept` note is newer than its `Build: finished` note:'
line_is "build skill: then removes the worktree by item 5, and back to Step 1" "$BS" \
  '  - Then remove the worktree as item 5 of `## 6. When the story passed` says, and go on with'
file_lacks "build skill: never jumps out of Step 1 to the next story" "$BS" 'items 5 to 7 of'
file_has "build skill: a waiting story comes back to Step 1 after its merge" "$BS" \
  '  - Then remove its worktree, when it is still there, as item 5 of `## 6. When the story passed`'
file_has "build skill: a merge taken from Step 1 comes back to it" "$BS" \
  '- A story that Step 1 takes to `### The merge` comes back to Step 1, with `story.md` read first.'
file_has "build skill: and takes item 5 alone, never 6 and 7" "$BS" \
  '  Where the merge says to go on at item 5 of `## 6. When the story passed`, take item 5 alone:'
gb_rule="$(lineno "$BS" '- A story that Step 1 takes to `### The merge` comes back to Step 1')"
gb_wait="$(lineno "$BS" 'waits to merge. Find its `<target>` again first')"
gb_left="$(lineno "$BS" 'its session ended before the worktree went. Read `story.md`, and')"
is "build skill: the come-back rule follows both entries it covers" "$(( ${gb_wait:-0} > 0 && ${gb_left:-0} > ${gb_wait:-0} && ${gb_rule:-0} > ${gb_left:-0} ))" "1"
file_has "story build: a no-verdict resume follows no stop" "$BY" \
  '     item 1 shows, or `Build: review <m> gave no verdict`: `### Review it`.'
file_has "contract: a cut-off session ends the removal" "$CT" \
  '- A session can end after a story passed and before its worktree is removed. An `in-review` story'
# A fresh implementer on a fix round takes the fix.
file_has "implementer: a prompt with a Fix line takes the story fix" "$IM" \
  '   - A prompt with a `Fix: review <m> failed` line, as a fresh `implementer` gets on a fix round:'
file_has "implementer: the story fix covers a prompt too" "$IM" \
  'A message that starts with `Fix: review <m> failed`, or a story prompt with that line, names a'
file_has "implementer: a fresh one reads the story first" "$IM" \
  '- A fresh `implementer`, launched with that line: read the story and the code first, as steps 2'
file_has "contract: a fresh implementer takes the fix from its prompt" "$CT" \
  'fixes each of its `Defect <m>:` notes. A fresh `implementer` gets that line in its prompt, and'
# The commit and read rules are story mode's alone: task mode is gone.
file_lacks "implementer: no task mode rule is left" "$IM" 'In task mode'
file_lacks "implementer: no commit message from a prompt line" "$IM" 'Commit with the message the prompt'"${q}"'s last line gives.'
line_is "implementer: stages the story's files in the worktree" "$IM" \
  '- Stage the story'"${q}"'s files by name: `git -C "<worktree>" add <file>...`.'
file_lacks "implementer: no packet-only read rule" "$IM" 'repo_path'
# Refinement has the approval note written on each story of the draft.
file_has "refinement: each existing story of the draft gets the approval note" "$RF" \
  '   - Each story of the draft that exists, changed or approved as it is, and has no status note'
file_has "refinement: story-tracker writes it" "$RF" '     `Planned: the owner approved this text.`: have story-tracker write it, with that id, in the'
file_has "contract: refinement writes the note on existing stories" "$CT" \
  '- Refinement writes it too on each story of an approved draft that exists and lacks it, changed'
file_has "guide: refinement writes the note on new and existing stories" "$GD" \
  '  it starts a story, and refinement has it written on each story you approve, new or not, as'
file_has "README: an existing story approved as it is" "$here/README.md" '  refinement, as it is or changed.'
file_has "README: the worktree goes once its ignored files are shown" "$here/README.md" \
  'without your word. Then its worktree is removed, once any ignored file in it is shown to you.'
file_has "story build: the merge's own worktree goes the same way" "$BY" \
  '`## 6. When the story passed` removes the story'"'"'s: its ignored files first.'

# ---------------------------------------------------------------- one implementer and reviewer pair builds a batch of related stories
BS="$here/skills/build/SKILL.md"
BY="$here/skills/build/story.md"
CG="$here/CHANGELOG.md"
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
IM="$here/agents/implementer.md"
RM="$here/README.md"
RV="$here/agents/reviewer.md"
q="'"
# The build skill cuts the run into batches of 1 to 3 related stories, in the run's order.
line_is "build skill: has a batches step" "$BS" '## Step 3 - Batches'
line_is "build skill: then builds the batches" "$BS" '## Step 4 - The batches'
file_lacks "build skill: no step says the batches go in turn, with pairs side by side" "$BS" '## Step 4 - Each batch in turn'
file_lacks "build skill: no step builds each story apart from its batch" "$BS" '## Step 3 - Each story in turn'
bt2="$(linex "$BS" '## Step 2 - Approved stories only')"
bt3="$(linex "$BS" '## Step 3 - Batches')"
bt4="$(linex "$BS" '## Step 4 - The batches')"
is "build skill: batches are cut after the approved stories are known, before the build" \
  "$(( ${bt2:-0} > 0 && ${bt3:-0} > ${bt2:-0} && ${bt4:-0} > ${bt3:-0} ))" "1"
line_is "build skill: a batch is 1 to 3 related stories that one pair builds" "$BS" \
  'A batch is 1 to 3 related stories of the run, which one `implementer` and one `reviewer` build in'
line_is "build skill: related means a shared epic" "$BS" \
  '- Two stories are related when they share an `epic` other than `-`, as `task head` prints it, or'
line_is "build skill: or the same files" "$BS" \
  '  touch the same files: their `## Acceptance criteria`, `## Approach / Key decisions` or'
file_has "build skill: the same files are a file their texts name in common" "$BS" \
  '`## Code verification (read-only)` name a file in common, such as `docs/billing/invoices.md`.'
line_is "build skill: the stories go in the order of Step 1" "$BS" \
  '- Take the stories in the order of Step 1. The first starts a batch. Each next one joins the batch'
line_is "build skill: a story joins the batch before it, up to 3 stories" "$BS" \
  '  of the story before it, when that batch holds fewer than 3 stories and one of them is related to'
line_is "build skill: a batch keeps the dependency order" "$BS" \
  '- So a batch keeps the order of Step 1: no story goes before one it waits on.'
line_is "build skill: a story with no related one builds alone" "$BS" \
  '- A story with no related story next to it in that order builds alone, as a batch of one.'
file_has "build skill: shows the owner the batches before the first story" "$BS" \
  '- Show the owner the batches, each with its stories in the order they will be built, before the'
file_has "build skill: a batch's stories share its two agents" "$BS" \
  'batch'"${q}"'s stories share its `implementer` and its `reviewer`, as `### A batch` there says.'
file_has "story build: a passed story goes on to the batch's next story" "$BY" \
  '7. Go on with the next story of the run, as Step 4 of `SKILL.md` says: the batch'"${q}"'s next story,'
# One implementer and one reviewer build the batch's stories in turn, each on its own branch.
line_is "story build: has a batch section" "$BY" '### A batch'
file_has "story build: builds the story with its batch's agents" "$BY" \
  'worktree of its own, with its batch'"${q}"'s `implementer` and `reviewer`, as `### A batch` says.'
file_lacks "story build: no fresh reviewer for each review" "$BY" 'a fresh `reviewer` for each review'
line_is "story build: <batch> is the id of the batch's first story" "$BY" \
  '- `<batch>` is the id of the first story of the story'"${q}"'s batch, as Step 3 of `SKILL.md` cuts it.'
line_is "story build: a story alone is its own batch" "$BY" \
  '  A story that builds alone is its own batch: `<batch>` is `<ID>`.'
line_is "story build: each story keeps its own branch, worktree and commits" "$BY" \
  '1. Each story keeps its own branch and worktree, with a commit series of its own, its own status'
line_is "story build: and passes or fails alone" "$BY" \
  '   notes, its own rounds and its own verdict. It passes or fails alone.'
line_is "story build: the batch's first story and review launch the pair" "$BY" \
  '2. The batch'"${q}"'s first story launches `implementer`, and its first review launches `reviewer`,'
line_is "story build: each named as the launch names say" "$BY" '   each named as `## 4. Launching an agent` says.'
line_is "story build: each later story and review goes to the same agent" "$BY" \
  '3. Each later story of the batch, and each later review, of the same story or the next, goes to'
line_is "story build: by its name with SendMessage" "$BY" \
  '   that agent by its name with SendMessage. The message holds the lines its prompt would: for'
file_has "story build: an agent out of reach is launched fresh with its name" "$BY" \
  '   - SendMessage is not there, or no agent has that name, as in a new session: launch a fresh one'
line_is "story build: a failed story goes back to the same implementer before the next starts" "$BY" \
  '4. A failed story goes back to the batch'"${q}"'s `implementer` before the batch'"${q}"'s next story starts,'
line_is "story build: from round 4 the fixes go to the stronger one, the next story does not" "$BY" \
  '   The batch'"${q}"'s next story still goes to `<batch>-implementer`.'
line_is "story build: a story-mode reviewer is named for the batch" "$BY" \
  '- Name each `reviewer` launch in story mode `name: "<batch>-reviewer"`, so that the batch'"${q}"'s next'
file_has "story build: a baseline reviewer has no name" "$BY" 'A `reviewer` in baseline mode has no name.'
line_is "story build: the fix message names its story" "$BY" \
  '  - The story, repo, worktree, branch and base lines of `implementer`'"${q}"'s prompt, for the story that'
file_has "story build: a batch's review message holds the prompt's lines alone" "$BY" \
  '- A `reviewer` prompt holds only these lines, and so does each next review that `### A batch`'
line_is "story build: the build starts the batch's implementer" "$BY" \
  '1. Start `implementer` on the story, as `### A batch` says.'
line_is "story build: the review starts the batch's reviewer" "$BY" \
  '2. Start `reviewer` in story mode, as `### A batch` says.'
line_is "story build: a fresh reviewer for no verdict takes the batch's name" "$BY" \
  '   - Name it `<batch>-reviewer`: the batch'"${q}"'s later reviews go to it.'
file_has "story build: the fix loop's cap is per story" "$BY" \
  'Each story of a batch has its own `fails`, so the cap counts per story. Its fix rounds all come'
file_has "story build: an agent with no report is asked once per launch or message" "$BY" \
  '   - Send it once per launch, or per message that starts a step, such as a fix message, never'
# The agents take the batch's next story or review as a new prompt.
line_is "implementer: has the next story of a batch" "$IM" '### The next story of a batch'
file_has "implementer: its intro names the batch" "$IM" \
  'In a batch, its next stories come one at a time, as `### The next story of a batch` says.'
line_is "implementer: takes the next story as a new prompt" "$IM" \
  '- Take it as a new prompt: `## Story mode` from step 1, with that message'"${q}"'s lines alone. Its'
line_is "implementer: an earlier story's ruling holds for it alone" "$IM" \
  '- An `Owner:` or `Ruling:` line of an earlier story holds for that story alone.'
file_has "implementer: an earlier story's change is here only when its base holds it" "$IM" \
  'An earlier story'"${q}"'s change is here only when this story'"${q}"'s base holds it: read each file'
line_is "implementer: commits each story in its own worktree" "$IM" \
  '- Commit this story'"${q}"'s change in its own worktree alone, as its own commits.'
file_has "implementer: a fix message names the story to fix" "$IM" \
  '- Its `Story:`, `Worktree:`, `Branch:` and `Base:` lines name the story to fix, and where.'
line_is "implementer: writes only in the worktree of the story it builds" "$IM" \
  '- Write only in the worktree of the story you build, on its branch.'
im_fix="$(linex "$IM" '### A story fix')"
im_next="$(linex "$IM" '### The next story of a batch')"
im_tf="$(linex "$IM" '## 1. Build test-first')"
is "implementer: the next story of a batch is part of story mode" \
  "$(( ${im_fix:-0} > 0 && ${im_next:-0} > ${im_fix:-0} && ${im_tf:-0} > ${im_next:-0} ))" "1"
line_is "reviewer: has the next review of a batch" "$RV" '### The next review of a batch'
line_is "reviewer: takes the next review as a new prompt" "$RV" \
  '- Take it as a new prompt: `## Story mode` from step 1, with that message'"${q}"'s lines alone, its'
line_is "reviewer: grades each story on its own" "$RV" \
  '- Grade each story on its own: by its criteria, its change and the checks you run again in this'
file_has "reviewer: an earlier review is no evidence" "$RV" \
  '- An earlier review'"${q}"'s verdict, findings and runs are no evidence here. An `Owner:` or `Ruling:`'
line_is "reviewer: logs on the story of this review alone" "$RV" \
  '- Log each defect and follow-up on the story of this review alone.'
rv_sm="$(linex "$RV" '## Story mode')"
rv_next="$(linex "$RV" '### The next review of a batch')"
rv_bm="$(linex "$RV" '## Baseline mode')"
is "reviewer: the next review of a batch is part of story mode" \
  "$(( ${rv_sm:-0} > 0 && ${rv_next:-0} > ${rv_sm:-0} && ${rv_bm:-0} > ${rv_next:-0} ))" "1"
# The contract, the changelog, the README and the guide describe batches.
file_has "contract: batches" "$CT" \
  '- **Batches.** Before the first story starts, the skill cuts the run into batches of 1 to 3'
file_has "contract: related stories share an epic or a file" "$CT" \
  'related when they share an `epic` other than `-`, or their texts name a file in common. A story'
line_is "contract: a batch keeps the run's order" "$CT" \
  '- A batch keeps the run'"${q}"'s order, so no story goes before one it waits on.'
line_is "contract: one pair builds a batch's stories in turn" "$CT" \
  '- One `implementer` and one `reviewer` build a batch'"${q}"'s stories in turn, as `<batch>-implementer`'
file_has "contract: a story passes or fails alone" "$CT" 'verdict: it passes or fails alone. The next story starts only once the one before it'
line_is "contract: the cap counts per story" "$CT" \
  '- Each story counts its own `fails` and rounds, so the cap counts per story, never per batch.'
file_lacks "contract: no fresh reviewer grades each fix" "$CT" 'and a fresh `reviewer` grades the fix'
file_has "contract: the batch's reviewer grades the fix" "$CT" \
  '  the review'"${q}"'s defects back to the same `implementer`, and the same `reviewer` grades the fix,'
file_has "contract: an agent takes a batch's next story or review as a new prompt" "$CT" \
  '- In a batch, an agent takes the message of its next story or review as a new prompt: each'
line_is "changelog: batches" "$CG" \
  '- The `build` skill cuts its run into batches of 1 to 3 related stories, in the run'"${q}"'s order:'
file_has "changelog: a story passes or fails on its own review" "$CG" \
  'passes or fails on its own review. A failed story goes back to the same `implementer` before'
file_has "changelog: the cap counts per story" "$CG" 'the cap of six failed reviews counts per story.'
file_has "README: related stories share one pair" "$RM" \
  '- Up to 3 related stories, such as those of one epic, share one `implementer` and one `reviewer`,'
file_has "guide: related stories share one pair" "$GD" \
  '- Up to 3 related stories, such as those of one epic, are built in turn by one `implementer` and'

# ---------------------------------------------------------------- the profile's build_pairs sets how many pairs build at once
BL="$here/skills/build/lead.md"
BS="$here/skills/build/SKILL.md"
BY="$here/skills/build/story.md"
CG="$here/CHANGELOG.md"
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
PT="$here/templates/profile.md.tmpl"
RM="$here/README.md"
q="'"
# The build skill takes the pairs from the profile, and runs side by side only batches that wait on
# no story of another batch that has not passed.
file_has "build skill: the profile's build_pairs sets the pairs, 1 by default" "$BS" \
  'The profile'"${q}"'s `build_pairs` sets how many such pairs build at once, as Step 4 says: 1 by default,'
file_has "build skill: the owner is shown how many pairs build the batches" "$BS" \
  '  first one starts, and how many pairs build them at once, as Step 4 says.'
line_is "build skill: <pairs> is the build_pairs line of profile --keys" "$BS" \
  '2. `<pairs>` is how many pairs build at once: the `build_pairs` line of'
line_is "build skill: from 1 to 5, a pair is one batch's two agents" "$BS" \
  '   `second-brain profile "<project>" --keys`, from 1 to 5. A pair is the `implementer` and the'
line_is "build skill: one batch at a time with 1 pair" "$BS" '   - `<pairs>` 1, the default: one batch at a time.'
line_is "build skill: up to <pairs> batches side by side with more" "$BS" \
  '   - More than 1: up to `<pairs>` batches side by side, as `### Pairs side by side` says.'
file_has "build skill: a stop stops the run with 1 pair, and no other pair with more" "$BS" \
  '   `<pairs>` 1 that stops the run. With more, the other pairs go on.'
line_is "build skill: has a pairs side by side section" "$BS" '### Pairs side by side'
ps4="$(linex "$BS" '## Step 4 - The batches')"
psx="$(linex "$BS" '### Pairs side by side')"
psr="$(linex "$BS" '## Rules')"
is "build skill: pairs side by side is part of Step 4" \
  "$(( ${ps4:-0} > 0 && ${psx:-0} > ${ps4:-0} && ${psr:-0} > ${psx:-0} ))" "1"
line_is "build skill: side by side go only stories that neither wait on each other nor sit in one batch" "$BS" \
  'side go only stories that neither wait on each other nor sit in one batch.'
line_is "build skill: a batch is ready once each story it waits on in another batch passed" "$BS" \
  '1. A batch is ready once each story it waits on in another batch has passed, and its merge has'
file_has "build skill: so no story builds beside one it waits on" "$BS" \
  '   - So no story builds beside one it waits on, or one that waits on it, and a batch'"${q}"'s own'
line_is "build skill: the first ready batch starts when a pair is free" "$BS" \
  '2. Start the first ready batch in the order of Step 3 each time fewer than `<pairs>` batches'
file_has "build skill: never more than <pairs> at once" "$BS" 'Never more than `<pairs>`'
line_is "build skill: a stopped batch holds its pair" "$BS" \
  '   its pair until the owner answers: no other batch takes its place.'
line_is "build skill: each pair in its own stories' worktrees" "$BS" \
  '4. Each pair builds in its own stories'"${q}"' worktrees alone, with its agents named for its batch, as'
file_has "build skill: no two pairs share a worktree or an agent" "$BS" 'No two pairs share a worktree or an agent.'
line_is "build skill: each agent runs in the background" "$BS" \
  '5. Launch each agent with the Agent tool'"${q}"'s `run_in_background: true`, so that the other pairs go'
line_is "build skill: a stop in one pair stops no other" "$BS" \
  '6. A stop in one pair stops no other. Its batch waits for the owner, with each batch that waits'
file_has "build skill: the other pairs go on" "$BS" 'The other pairs go on, and the next'
line_is "build skill: questions while another pair works go as the stop list says" "$BS" \
  '7. While another pair is at work, ask the owner as `## 8. When to ask the owner` in `story.md`'
line_is "build skill: one merge at a time" "$BS" \
  '8. One merge at a time: a story that passed while another'"${q}"'s `### The merge` is open, in'
line_is "build skill: the lead's one check watches every pair" "$BS" \
  '9. The lead'"${q}"'s one check watches every pair, as `## The lead'"${q}"'s check` in `lead.md` says.'
line_is "build skill: each line shown names its story" "$BS" \
  '10. Name the story in each line you show the owner: the pairs'"${q}"' lines come in no set order.'
file_lacks "build skill: no rule of one story at a time in the whole build" "$BS" '- One story at a time, and one agent at a time.'
line_is "build skill: one story and one agent at a time in each pair" "$BS" \
  '- One story and one agent at a time in each pair, and at most `<pairs>` pairs at once, as Step 4'
# One story's build knows the pairs, launches in the background and asks in its reply.
line_is "story build: <pairs> is Step 4's" "$BY" \
  '- `<pairs>` is how many pairs build at once, as Step 4 of `SKILL.md` says. With more than 1, other'
line_is "story build: one agent at a time in each pair" "$BY" \
  '- Launch one agent at a time in each pair with the Agent tool, and wait for its result before the'
line_is "story build: in the background with more than one pair" "$BY" \
  '- With `<pairs>` more than 1, launch it with `run_in_background: true`, and take its result from'
file_lacks "story build: no rule of one agent at a time in the whole build" "$BY" \
  '- One agent at a time: wait for each agent'"${q}"'s result or reply before the next step.'
line_is "story build: its rule is one agent at a time in each pair" "$BY" \
  '- One agent at a time in each pair: wait for its result or reply before the pair'"${q}"'s next step.'
file_has "story build: a passed story goes on to the first ready batch" "$BY" \
  'With `<pairs>` more than 1 that is the first'
line_is "story build: the merge goes one at a time" "$BY" \
  'With more than one pair, one merge runs at a time, as `### Pairs side by side` in `SKILL.md` says.'
line_is "story build: the stop list asks in the reply while another pair works" "$BY" \
  '- While another pair is at work, as `### Pairs side by side` in `SKILL.md` says, ask each'
file_has "story build: since AskUserQuestion would hold every pair" "$BY" \
  '  session until the owner answers, and every other pair with it. The owner'"${q}"'s answer comes in a'
is "story build: the stop, the merge and the push point to the stop list's rule" \
  "$(grep -cxF '   - While another pair is at work, ask in your reply, as `## 8. When to ask the owner` says.' "$BY")" "3"
file_has "story build: the owner's stop stops this batch alone" "$BY" \
  'With another pair at work, that stops this story'"${q}"'s batch alone, unless the owner stops'
# The lead's one check watches every pair.
line_is "build lead: <pairs> is Step 4's" "$BL" '- `<pairs>` is how many pairs build at once, as Step 4 of `SKILL.md` says.'
file_has "build lead: the Now line names each pair at work" "$BL" \
  '  - With more than one pair, its `Now:` line names each pair at work: its story and its agent.'
file_has "build lead: one check watches every pair" "$BL" 'One check watches every pair, however many build.'
line_is "build lead: keeps one check for every pair" "$BL" \
  '   says. Keep one check at a time, for every pair.'
line_is "build lead: looks at each pair at work" "$BL" \
  '   - With more than one pair, look at each pair at work: its agent, its story'"${q}"'s worktree and its'
file_has "build lead: one pair never stands for another" "$BL" 'What one pair shows never stands for another.'
line_is "build lead: a stopped pair holds no other" "$BL" \
  '   - Take each pair on its own. A pair whose story stopped waits for the owner, and holds no'
line_is "build lead: a free pair starts a ready batch" "$BL" \
  '   - Fewer than `<pairs>` batches build and one is ready: start it, as `### Pairs side by side` in'
# The contract, the template, the guide, the changelog and the README describe the key.
line_is "contract: the profile example has build_pairs" "$CT" 'build_pairs: 1'
line_is "contract: build_pairs is described with the profile keys" "$CT" \
  '- `build_pairs` is how many `implementer` and `reviewer` pairs a build runs at once, as'
file_has "contract: build_pairs is 1 to 5, else 1" "$CT" \
  '`### Pairs side by side` in `skills/build/SKILL.md` says. It is a whole number from 1 to 5. A'
line_is "contract: --keys always prints its line" "$CT" \
  '- `profile <project> --keys` always prints a `build_pairs` line, with the value the build takes.'
file_has "contract: the --keys row names the build_pairs line" "$CT" \
  '| `profile <project> --keys` | the profile frontmatter as `key: value` lines, and a `build_pairs` line always | the `build_pairs` line holds the value the build takes:'
file_lacks "contract: no rule of one story at a time in every build" "$CT" \
  '- **One story at a time.** One story and one agent at a time, never in parallel.'
line_is "contract: pairs" "$CT" \
  '- **Pairs.** A pair is the `implementer` and the `reviewer` of one batch. The profile'"${q}"'s'
file_has "contract: one story and one agent at a time with 1" "$CT" \
  '`build_pairs` sets how many pairs build at once (section 3). With 1, the default, one story and'
file_has "contract: side by side only stories that neither wait on each other nor sit in one batch" "$CT" \
  'Side by side go only stories that neither wait on each other nor'
line_is "contract: each pair in its own worktrees, in the background" "$CT" \
  '- Each pair builds in its own stories'"${q}"' worktrees alone, one agent at a time, and each agent is'
line_is "contract: the lead's check watches every pair, and a stop stops no other" "$CT" \
  '- One check of the lead watches every pair. A stop in one pair stops its batch alone, and the'
file_has "contract: questions go in the reply while another pair works" "$CT" \
  '- While another pair is at work, the skill asks the owner in its reply, never with'
file_has "contract: checks that cannot run twice at once keep 1" "$CT" \
  'cannot run twice at once, such as two runs on one port, keeps `build_pairs` at 1.'
file_has "contract: the lead's check looks at every pair" "$CT" \
  '- With more than one pair, the one check looks at every pair, each on its own: what one pair'
file_has "contract: agents launch one at a time in each pair" "$CT" '  one at a time in each pair, and names each launch'"${q}"'s model by role and round.'
line_is "profile template: describes build_pairs" "$PT" \
  '- A `build_pairs:` key added above sets how many `implementer` and `reviewer` pairs the build'
file_has "profile template: 1 to 5, else 1" "$PT" \
  'skill runs at once, side by side: a whole number from 1 to 5. With no key, or any other value,'
file_lacks "profile template: leaves the build_pairs key out of the frontmatter" "$PT" 'build_pairs: '
line_is "guide: describes build_pairs" "$GD" \
  '- The profile'"${q}"'s `build_pairs` key builds up to that many batches side by side, each by its own'
file_has "guide: a stop in one pair stops no other" "$GD" '- With more than one pair, a stop in one pair stops no other.'
line_is "guide: one check watches every pair" "$GD" '- One check watches every pair, however many build at once.'
line_is "changelog: build_pairs" "$CG" \
  '- A profile key, `build_pairs`, sets how many `implementer` and `reviewer` pairs the `build`'
file_has "changelog: batches build side by side" "$CG" '- With more than one pair, batches build side by side, each by its own pair in its own stories'"${q}"
file_has "changelog: a stop in one pair stops its batch alone" "$CG" \
  '- The lead'"${q}"'s one check watches every pair, and a stop in one pair stops its batch alone. While'
file_has "contract: the settings row names build_pairs:invalid" "$CT" \
  'and a profile `build_pairs` that is not empty, 1, 2, 3, 4 or 5 (`build_pairs:invalid`) (warn).'
line_is "contract: the doctor warns on a build_pairs value it does not take" "$CT" \
  '  frontmatter. The doctor'"${q}"'s `settings` check warns on a value it does not take.'
file_has "vault-doctor checks: the settings check names build_pairs:invalid" "$here/skills/vault-doctor/checks.md" \
  'Or a profile `build_pairs` that is not empty, 1, 2, 3, 4 or 5 (`build_pairs:invalid`).'
file_has "vault-doctor checks: a build_pairs not allowed means 1" "$here/skills/vault-doctor/checks.md" \
  'A `build_pairs` that is not allowed means 1, so a build runs one pair at a time where the owner'
file_has "changelog: the doctor warns on a build_pairs it does not take" "$CG" \
  '- The doctor'"${q}"'s `settings` check warns on a `build_pairs` it does not take, `build_pairs:invalid`.'
file_has "README: build_pairs builds batches side by side" "$RM" \
  '- A `build_pairs` key in the profile, 1 to 5, builds that many batches side by side, when none of'

# ---------------------------------------------------------------- the child folders and the parent word
CC="$here/docs/contract.md"
file_has "contract: a child task is a word of the contract" "$CC" \
  '| child task | A task whose `epic` names another task of its project, its parent.'
file_has "contract: the project tree names a child task" "$CC" \
  '  tasks/<status>/<parent>/<TICKET-ID>/README.md   a child task, with task_layout: status'
file_has "contract: parent_label is feature or epic" "$CC" \
  '- `parent_label` is the word for the project'"'"'s parent stories: `feature`, in any letter case, or'
file_has "contract: the word changes labels only" "$CC" \
  '- The word changes labels only: the skills, the board'"'"'s column and the helper'"'"'s output. A task'"'"'s'
file_has "contract: children nest in status and sprint alone" "$CC" \
  '- In `status` and `sprint`, a child task sits inside a folder named for its parent, one folder'
file_has "contract: a child's path in a status project" "$CC" '`<project>/<tasks_root>/<status>/<parent>/<ID>/README.md`'
file_has "contract: a child that joins a sprint leaves its parent's note in backlog/" "$CC" \
  '`<sprint folder>/<parent>/<ID>/` while its parent'"'"'s note stays in `backlog/<parent>/`.'
file_has "contract: a README inside a task is a child when its epic names the task" "$CC" \
  '- A README one folder inside a task folder in a group folder is a child task when its `epic` names'
file_has "contract: a parent's move takes its own files alone" "$CC" \
  '- A move of a parent takes its own note and files alone: every entry of its folder but its'
file_has "contract: a parent done or abandoned leaves its open children" "$CC" \
  '- A parent that is done or abandoned leaves its open children where they are, and every command'
file_has "contract: the board's branch for a task one level deeper" "$CC" '- A branch after it takes a task one level deeper'
OUT="$(grep '^| `task set ' "$CC")"
out_has "contract: task set moves a child into its parent's folder" \
  'into its parent'"'"'s folder in the folder of its status or sprint, `<tasks_root>/<folder>/<parent>/<ID>/`'
out_has "contract: task set prints the folder it removes" 'prints `removed: <path>` after the `links:` lines'
OUT="$(grep '^| `task head ' "$CC")"
out_has "contract: task head takes the parent word as the epic line's key" '`feature: <value>` where it is `feature`'
OUT="$(grep '^| `scaffold project ' "$CC")"
out_has "contract: scaffold project takes --parent-label" '[--parent-label feature\|epic]'
OUT="$(grep '^| project | `task-layout` ' "$CC")"
out_has "contract: task-layout names a child out of its parent's folder" '`<ID>:<status>/<parent>` or `<ID>:<folder>/<parent>`'
out_has "contract: task-layout names an epic that names no task" '`<ID>:unknown-<label>`'
out_has "contract: task-layout names a parent_label of neither word" '(`parent_label:invalid`)'
OUT="$(grep '^| project | `board` ' "$CC")"
out_has "contract: the board check names a board with no child branch" '(`tasks.base:no-child-filter`) (warn)'
line_is "contract: the hook takes a child task note" "$CC" \
  '- One level deeper in such a group folder, `tasks/<folder>/<parent>/<ID>/README.md` is a whole'
file_has "contract: a skill names parent stories by parent_label" "$CC" \
  '- A skill names a project'"'"'s parent stories by its `parent_label`: features or epics. The'
CVT="$here/templates/obsidian-conventions.md.tmpl"
file_has "conventions: the short version names a child's folder" "$CVT" \
  'In both, a task whose `epic` names another task sits inside a folder'
line_is "conventions: the tree names a child task" "$CVT" \
  '<project>/tasks/<status>/<parent>/<TICKET-ID>/README.md  # a child task, in the status layout'
file_has "conventions: the parent word changes labels only" "$CVT" \
  'calls its parent stories features or epics, as the profile'"'"'s `parent_label` says; the key stays'
GDC="$here/docs/guide.md"
line_is "guide: a section on the feature and epic folders" "$GDC" '### Feature and epic folders'
file_has "guide: a child sits inside a folder named for its parent" "$GDC" \
  '- In a status or sprint project, a child sits inside a folder named for its parent, in the folder'
file_has "guide: a parent done or abandoned leaves its open children" "$GDC" \
  '- A parent'"'"'s move takes its own files alone. A parent done or abandoned leaves its open children'
file_has "guide: vault-setup asks for the word" "$GDC" \
  '- `vault-setup` asks whether a project calls its parent stories features or epics, as'
file_has "README: names the feature and epic folders" "$here/README.md" '- **Features and epics.** In those two kinds of project'
VSK="$here/skills/vault-setup/SKILL.md"
line_is "vault-setup: asks for the parent word" "$VSK" '   - whether it calls its parent stories features or epics.'
line_is "vault-setup: features pass --parent-label feature" "$VSK" \
  '   - Features: add `--parent-label feature`. It writes `parent_label: feature` into the profile,'
file_has "vault-setup: adopt asks for the word too" "$VSK" '| `parent_label` | with adopt only, as step 1 asks it for a new project:'
file_has "vault-setup adopt: asks whether the project calls its parent stories features or epics" \
  "$here/skills/vault-setup/adopt.md" 'and whether it calls its parent stories features or'
STK="$here/skills/story-tracker/SKILL.md"
line_is "story-tracker: reads the parent word from the profile" "$STK" \
  '   - `parent_label` is the word for a parent story: `feature`, or `epic` when the line is absent'
file_has "story-tracker: epic= moves a story under its parent" "$STK" \
  'named for that parent: `second-brain task set <ID> epic=<parent>` moves it in, `epic=` moves'
file_has "story-tracker status: the Epic field takes the project's word" "$here/skills/story-tracker/status.md" \
  '  - Name the `Epic:` field after the project'"'"'s word, `Feature:` with `parent_label: feature`. The'
file_has "story-tracker create: the parent is the project's feature or epic" "$here/skills/story-tracker/create.md" \
  'feature or epic, as Step 0 of `SKILL.md` names it.'
SPK="$here/skills/scrum-master/SKILL.md"
file_has "scrum-master: calls a parent story by the project's word" "$SPK" \
  '- A task whose `epic` names another task is a child of that parent story. Call a parent story by'
file_has "sprint-planning: a move keeps a child under its parent" "$here/skills/scrum-master/sprint-planning.md" \
  'parent, in the folder it moves to, and a parent'"'"'s move takes its own files alone.'
file_has "sprint close: a child goes under its parent" "$here/skills/scrum-master/sprint-planning.md" \
  '   - In both, a child goes into a folder named for its parent in the folder it moves to, and a'
file_has "docs-keeper: a child task is one folder deeper" "$here/agents/docs-keeper.md" \
  '  In both, a child task, one whose `epic` names another task, is one folder deeper, inside a'
CHK="$here/skills/vault-doctor/checks.md"
file_has "checks board: no-child-filter" "$CHK" '(`tasks.base:no-child-filter`).'
file_has "checks task-layout: a child out of its parent's folder" "$CHK" '(`<ID>:<status>/<parent>` or `<ID>:<folder>/<parent>`)'
file_has "checks task-layout: an epic that names no task is left where it is" "$CHK" \
  '`<ID>:unknown-<word>`: `--fix` leaves the task where it is'
file_has "checks task-layout: parent_label:invalid is the user's to answer" "$CHK" \
  '`parent_label:invalid`: ask the user whether the project calls its parent stories features or epics'
line_is "vault-doctor fix: a child offender is a task it moves" "$here/skills/vault-doctor/SKILL.md" \
  '     offender is a child it moves into a folder named for its parent: name it with that folder.'
file_has "changelog: the child folders" "$CG" \
  '- In a status or sprint project, a child task, one whose `epic` names another task, sits inside a'
file_has "changelog: epic= moves a child" "$CG" \
  '- `task set <ID> epic=<parent>` moves a child into that folder, and `epic=` moves it out. A status'
file_has "changelog: parent_label" "$CG" \
  '- `parent_label` in the profile names a project'"'"'s parent stories `feature`, or `epic` with no key.'
file_has "changelog: the board's child branch" "$CG" \
  '- A new board'"'"'s filters take a task one level deeper. An existing board is not rewritten: in a'
file_has "changelog: the conventions note at version 10" "$CG" \
  '- The conventions note is at version 10: it names a child task'"'"'s folder. The doctor'"'"'s'
file_has "contract: a folder with no README holds tasks when it is named for a task found elsewhere" "$CC" \
  '  deeper, when it is named for a task found elsewhere, by its folder name or an alias, without'
file_has "contract: what a task found elsewhere is" "$CC" \
  '- A task found elsewhere is one directly under the tasks root, in a group folder or in the'
file_has "contract: a folder named for no task holds none" "$CC" \
  '- A folder with no `README.md` that is named for no task holds none: a README in it is no task,'
file_has "contract: a parent's entries with a dot first move too" "$CC" \
  '- An entry whose name starts with a dot moves too. `move` takes no such name, so it moves as it'
file_has "contract: an epic of none or several tasks names no parent" "$CC" \
  '- An `epic` that names no single task of the project, none or several, names no parent: a move'
file_has "contract: the hook takes a folder named for a task found elsewhere" "$CC" \
  '- With no `<parent>/README.md`, it is one when `<parent>` is named for a task found elsewhere in'
file_has "contract: the hook runs one find for it" "$CC" \
  '  deeper, in a folder with no `README.md` of its own, also runs one `find` over the tasks folder'
file_has "contract: the shell runs that find, and no path is text a shell reads" "$CC" \
  '- The shell runs that `find`, with the path in a variable as one argument. No path is ever text a'
file_has "changelog: the folder named for a task" "$CG" \
  '- A folder with no README of its own, one level deeper in a group folder, holds tasks only when it'

# ---------------------------------------------------------------- the orders note indents with a tab
LD="$here/skills/build/lead.md"
line_is "build: the orders note's nested item is indented with a tab" "$LD" \
  "$(printf '\t')- Now: <what works on it: you, an agent by its name, or a check that runs>."
line_is "build: the template says to indent with a tab" "$LD" \
  'The note, with each `<...>` filled. A nested item is indented with a tab, as the vault'"'"'s writing'
is "build: no nested item of the orders note is indented with spaces" \
  "$(awk '/^# <project> lead memory$/ { on = 1 } on && /^\`\`\`$/ { on = 0 } on && /^ +- /' "$LD" | wc -l | tr -d ' ')" "0"

# ---------------------------------------------------------------- the scrum-master skill and story-tracker's new steps
SMD="$here/skills/scrum-master"
SMS="$SMD/SKILL.md"
SMF="$SMD/refinement.md"
SMR="$SMD/release-planning.md"
SMG="$SMD/sprint-planning.md"
SMO="$SMD/organize-board.md"
STD="$here/skills/story-tracker"
STS="$STD/SKILL.md"
line_is "scrum-master: the name is the folder's" "$SMS" "name: scrum-master"
sm_desc="$(sed -n 's/^description: //p' "$SMS")"
is "scrum-master: the description is under 200 characters" "$((${#sm_desc} < 200))" "1"
for word in Refine stories epics sprint open pick close "carry over" release organize check board approval; do
  case "$sm_desc" in *"$word"*) pass "scrum-master: the description names $word" ;; *) fail "scrum-master: the description names $word" "in: $sm_desc" ;; esac
done
for word in ticket standup; do
  case "$sm_desc" in *"$word"*) fail "scrum-master: the description leaves $word to story-tracker" "in: $sm_desc" ;; *) pass "scrum-master: the description leaves $word to story-tracker" ;; esac
done
case "$sm_desc" in *': '*) fail "scrum-master: the description holds no colon and blank" "in: $sm_desc" ;; *) pass "scrum-master: the description holds no colon and blank" ;; esac
line_is "scrum-master: the argument hint lists the four workflows" "$SMS" \
  'argument-hint: "[refinement | sprint-planning | release-planning | organize-board] [project]"'
is "scrum-master: SKILL.md is under the doctor's 150 lines" "$(($(wc -l <"$SMS") <= 150))" "1"
is "scrum-master: the workflow table has four rows" \
  "$(grep -cE '^\| (refinement|sprint-planning|release-planning|organize-board) \| ' "$SMS")" "4"
for m in refinement sprint-planning release-planning organize-board; do
  row="$(grep "^| $m | " "$SMS")"
  case "$row" in
    *'| `${CLAUDE_SKILL_DIR}/'"$m"'.md` |') pass "scrum-master: $m reads $m.md" ;;
    *) fail "scrum-master: $m reads $m.md" "got: $row" ;;
  esac
  file_has "scrum-master: $m.md is read only when it runs" "$SMD/$m.md" "Read this in $m only"
  # A workflow file is read with the Read tool, which fills in no variable: only SKILL.md names one.
  file_lacks "scrum-master: $m.md names no path variable" "$SMD/$m.md" '${CLAUDE_'
  file_lacks "scrum-master: $m.md has no daily status" "$SMD/$m.md" 'daily status'
done
is "scrum-master: SKILL.md and the four workflow files" "$(ls "$SMD" | LC_ALL=C sort | tr '\n' ' ')" \
  "SKILL.md organize-board.md refinement.md release-planning.md sprint-planning.md "
file_has "scrum-master: SKILL.md gives the path of story-tracker's create.md" "$SMS" '`${CLAUDE_PLUGIN_ROOT}/skills/story-tracker/create.md`'
file_has "scrum-master: a ticket goes to the story-tracker skill" "$SMS" 'skill, with the Skill tool as `odsb:story-tracker`.'
file_lacks "scrum-master: no daily status" "$SMS" 'daily status'
is "story-tracker: SKILL.md and its three files" "$(ls "$STD" | LC_ALL=C sort | tr '\n' ' ')" "SKILL.md create.md env-split.md status.md "
file_has "story-tracker: the start row takes refinement's stories" "$STS" \
  'or the scrum-master'"'"'s refinement hands over a story the owner approved |'
line_is "story-tracker: it may edit notes and run ls -d" "$STS" \
  'allowed-tools: Read Grep Glob Edit Bash(second-brain *) Bash(ls -d *)'
line_is "scrum-master: it may edit and write notes, call story-tracker with an id and run ls -d" "$SMS" \
  'allowed-tools: Read Grep Glob Edit Write Skill(odsb:story-tracker *) Bash(second-brain *) Bash(ls -d *)'
# The commands the two skills' text runs, other than the helper: ls -d has a pattern, and git runs
# only inside the helper's branch command, as no git pattern is safe: a -c setting before its
# subcommand can run a program. Read line by line, so no glob in a command expands.
seen_ls=0
seen_git=0
while IFS= read -r c; do
  case "$c" in
    'ls -d '*) seen_ls=1 ;;
    'git '*) seen_git=1 ;;
  esac
done <<CMDS
$(cat "$STD"/*.md "$SMD"/*.md | grep -oE '`(git|ls -d) [^`]*`' | tr -d '`')
CMDS
is "allowed-tools: the skills' text runs ls -d" "$seen_ls" "1"
is "allowed-tools: the skills' text runs no git command, which would prompt" "$seen_git" "0"
for c in '`second-brain branch <project> <ID>` reads the ticket'"'"'s default repo: the story'"'"'s `repo`, else' \
  '  with `second-brain branch <project> <ID> --show <branch> <file>`, or tell the user.' \
  '- No id given: `second-brain session-check --cwd "<repo path>"` prints the repo'"'"'s `branch:` and'; do
  file_has "story-tracker: the branch check reads git through the helper: ${c:0:48}" "$STS" "$c"
done
file_has "story-tracker create: the work started comes from the helper" "$STD/create.md" \
  '- Work has started: `second-brain branch <project> <ID> --started` prints the log and the diff'
file_has "story-tracker create: a file at another ref comes from the helper" "$STD/create.md" \
  '  `second-brain branch <project> <ID> --show <ref> <file>`.'
file_has "refinement: reads git through the helper alone" "$SMD/refinement.md" \
  '  Read git there through `second-brain branch` alone, so the check asks nothing.'
for f in "$STS" "$SMS"; do
  sk="$(basename "$(dirname "$f")")"
  tools="$(sed -n 's/^allowed-tools: //p' "$f")"
  case " $tools " in
    *' Bash(ls -d *) '*) pass "allowed-tools: $sk may run the topic folder check" ;;
    *) fail "allowed-tools: $sk may run the topic folder check" "got: $tools" ;;
  esac
  case "$tools" in
    *'Bash(git'*) fail "allowed-tools: $sk has no git pattern, so its git commands prompt" "got: $tools" ;;
    *) pass "allowed-tools: $sk has no git pattern, so its git commands prompt" ;;
  esac
  extra="$(printf '%s\n' "$tools" | grep -oE 'Bash\([^)]*\)' | grep -vxF -e 'Bash(second-brain *)' -e 'Bash(ls -d *)')"
  is "allowed-tools: $sk has no other command pattern" "$extra" ""
done
# No skill pre-approves git: a -c setting can make any git command run a program.
for f in "$here"/skills/*/SKILL.md; do
  sk="$(basename "$(dirname "$f")")"
  case "$(sed -n 's/^allowed-tools: //p' "$f")" in
    *'Bash(git'*) fail "allowed-tools: $sk, like every skill, has no git pattern" "got: $(sed -n 's/^allowed-tools: //p' "$f")" ;;
    *) pass "allowed-tools: $sk, like every skill, has no git pattern" ;;
  esac
done
is "allowed-tools: the every-skill git check reads each skill" "$(ls "$here"/skills/*/SKILL.md | grep -c '')" "$(ls -d "$here"/skills/*/ | grep -c '')"
file_has "contract: a git -C pattern never qualifies" "$here/docs/contract.md" \
  '- Any other command prompts. A `git -C *` pattern never qualifies: the wildcard for the repo path'
file_has "contract: a skill call with an id needs the prefix form" "$here/docs/contract.md" \
  '`Skill(odsb:<that skill> *)`. `Skill(<name>)` matches only a call with no arguments, and the'
file_has "story-tracker create: the topic folder check is ls -d" "$STD/create.md" '`ls -d "<vault>/<project path>/<topics_root>/<folder>"`'
file_has "story-tracker: the sprint keys are the scrum-master's" "$STS" \
  '- Leave `sprint` and `carried_from` to the scrum-master'"'"'s sprint-planning unless the user asks.'
STC="$STD/create.md"
line_is "story-tracker create: a new story waits for the owner's approval" "$STC" \
  'Show the owner the text from section 1 first, and write nothing until they approve it:'
line_is "story-tracker create: a change is shown again" "$STC" '- A change: make it, show the changed text again, then ask again.'
line_is "story-tracker create: only the owner's approval counts" "$STC" \
  '- Only the owner'"'"'s approval counts. Never take a change, a question or silence for one.'
file_lacks "story-tracker create: no pointer into another skill's folder" "$STC" 'skills/scrum-master/'
line_is "story-tracker create: a story refinement got approved is approved already" "$STC" \
  'A story the scrum-master'"'"'s refinement got approved is approved already. Write it from that text,'
for f in refinement release-planning; do
  file_has "$f: asks for the approval as story-tracker's create.md says" "$here/skills/scrum-master/$f.md" \
    'as `## 3. Create the story` in'
  file_lacks "$f: does not restate the approval rules" "$here/skills/scrum-master/$f.md" 'Only the owner'"'"'s approval counts.'
done
file_has "scrum-master: release-planning reads create.md too" "$here/skills/scrum-master/SKILL.md" \
  '- refinement and release-planning also read story-tracker'"'"'s'
file_has "contract: the approval rules have one home" "$here/docs/contract.md" \
  '- Those approval rules have one home, `## 3. Create the story` in `skills/story-tracker/create.md`.'
is "story-tracker create: the approval comes before step 1" \
  "$(($(lineno "$STC" 'Show the owner the text from section 1 first') < $(lineno "$STC" '1. `second-brain task new EX-123')))" "1"
SMW="$here/skills/scrum-master/sprint-planning.md"
line_is "sprint-planning: a close request comes first" "$SMW" \
  '1. The user asks to close the sprint, with one in progress: `## Close`.'
line_is "sprint-planning: a close with no sprint says so and stops" "$SMW" \
  '2. The user asks to close the sprint, with none in progress: say no sprint is in progress, and'
line_is "sprint-planning: it opens one only when asked" "$SMW" \
  '   stop. Go to `## Open` only when the user asks for a new sprint.'
line_is "sprint-planning: an ended sprint closes only when nothing else is asked" "$SMW" \
  '4. The sprint'"'"'s days left are 0 or less, and the request asks for nothing else, such as a pick:'
is "sprint-planning: the close checks come before open" \
  "$(($(lineno "$SMW" '2. The user asks to close the sprint, with none') < $(lineno "$SMW" '3. No sprint in progress: `## Open`')))" "1"
file_lacks "sprint-planning: no achievement" "$SMW" 'achievement'
line_is "refinement: asks for the approval without showing the draft again" "$here/skills/scrum-master/refinement.md" \
  '  `create.md` says, without showing the draft again.'
file_has "contract: a story that refinement got approved gets the note too" "$here/docs/contract.md" \
  '- Every story whose text the owner approved, in start mode or in refinement, gets the status note'
file_lacks "profile template: no story is handed to it" "$here/templates/profile.md.tmpl" 'hand it to'
file_has "contract: a close with no sprint stops" "$here/docs/contract.md" \
  '- A request to close the sprint goes to its close. With no sprint in progress, it says so and'
absent "skills: the sprint skill is gone" "$here/skills/sprint"
absent "agents: the scrum-master agent is gone" "$here/agents/scrum-master.md"
line_is "refinement: nothing is written before the approval" "$SMF" \
  'Write nothing, no file, no key and no note, until the owner approves the draft.'
file_has "refinement: at most 4 acceptance criteria" "$SMF" 'at most 4 acceptance criteria.'
file_has "refinement: each story names its parent and what it waits on" "$SMF" '`Parent: <ID or ->` and `Waits on: <IDs or ->`'
file_has "refinement: the chunks end with a question" "$SMF" '- End each chunk with the line `What'"'"'s wrong or missing?` as plain text, not an AskUserQuestion'
line_is "refinement: a change is shown again before the next ask" "$SMF" \
  '- A change: make it in the draft, show each story it changed again in full, then ask again.'
file_has "refinement: a change while writing is shown first" "$SMF" 'stop. Show the change, and write it only once the owner approves'
file_has "refinement: a new story starts through story-tracker" "$SMF" \
  '1. Each new epic or story: invoke the story-tracker skill with the Skill tool, as'
file_has "refinement: a changed story is updated through story-tracker" "$SMF" \
  '2. Each story or epic that exists and changed: invoke the story-tracker skill with its id, to'
file_has "refinement: it invokes story-tracker, and says why" "$SMF" \
  '   - Invoke it, never Read its files: the Skill tool fills in the paths and the session id its'
file_has "refinement: links what a story waits on" "$SMF" '`second-brain task dep <ID> add <other ID>`'
is "refinement: the approval comes before the write" \
  "$(($(lineno "$SMF" '## 3. The approval') < $(lineno "$SMF" '## 4. Write')))" "1"
for h in '## Open' '## Pick' '## Close' '## Rules'; do
  line_is "sprint-planning: has $h" "$SMG" "$h"
done
is "sprint-planning: open, then pick, then close" \
  "$(($(linex "$SMG" '## Open') < $(linex "$SMG" '## Pick') && $(linex "$SMG" '## Pick') < $(linex "$SMG" '## Close')))" "1"
file_has "sprint-planning: reads the sprint rules and the sprint in progress" "$SMG" 'second-brain sprint current "<project>"'
file_has "sprint-planning: a task that does not exist yet starts through story-tracker" "$SMG" \
  '6. A task that does not exist yet: start it through the story-tracker skill, with the Skill tool'
line_is "release-planning: writes only its section and the Epics lines" "$SMR" \
  'note: its release'"'"'s section and the `## Epics` lines.'
file_has "release-planning: the note's path" "$SMR" '`<project path>/<topics_root>/planned-releases.md`'
file_has "release-planning: release goals in the draft" "$SMR" '- `Release goals:`, one to three bullets'
file_has "release-planning: a story or epic that does not exist goes through refinement first" "$SMR" \
  '- A story or epic that does not exist yet goes through refinement first. Read `refinement.md`, at'
line_is "release-planning: a change is shown again before the next ask" "$SMR" \
  '- A change: make it in the draft, show each part it changed again in full, then ask again.'
file_has "release-planning: never rewrites the note" "$SMR" 'Never rewrite the note.'
file_lacks "release-planning: writes no task" "$SMR" 'odsb:story-tracker'
is "release-planning: the approval comes before the write" \
  "$(($(lineno "$SMR" '## 3. The approval') < $(lineno "$SMR" '## 4. Write')))" "1"
for l in '## Epics' '## 0.2.0 - next' 'Release goals:'; do
  line_is "release-planning: the note's shape has $l" "$SMR" "$l"
done
is "release-planning: an epic's stories nest with a tab" "$(grep -c "$(printf '^\t- STORY: ')" "$SMR")" "2"
for l in '- Run `second-brain doctor <project>`.' '- Change nothing without asking. Never pass `--fix` on your own.' \
  '- A fix the user wants: offer `/odsb:vault-doctor fix`.' \
  '- Docs that have drifted from the code: recommend the `docs-keeper` agent. Do not spawn it.'; do
  line_is "organize-board: $l" "$SMO" "$l"
done
CT="$here/docs/contract.md"
line_is "contract: defines the planned-releases note" "$CT" "### Planned releases"
file_has "contract: the release in work is next" "$CT" '- The release in work is `## <version> - next`. Only one release is `next`.'
file_has "contract: a release once out is dated" "$CT" '- A release once out is `## <version> - released <YYYY-MM-DD>`.'
file_has "contract: the scrum-master writes nothing before the approval" "$CT" \
  '- The skill shows the owner the whole draft and writes nothing until the owner approves it.'
file_has "contract: the note is in the project's tree" "$CT" '  <topics_root>/planned-releases.md'
file_has "contract: two skills keep the work" "$CT" '- **Two skills keep the work.** `story-tracker` owns each ticket. `scrum-master` refines the'
file_has "contract: the scrum-master's four workflows" "$CT" '  skill. Its four workflows are `refinement.md`, `sprint-planning.md`, `release-planning.md` and'
file_has "contract: no daily status" "$CT" '- Neither skill has a daily status.'
sm_left="$(cd "$here" && grep -rnE 'story-track([^e]|$)|odsb:sprint([^-a-z]|$)|skills/sprint/|agents/scrum-master|the sprint skill|`sprint` skill|scrum-master (open|pick|close|status|done|hygiene|plan)([^-a-z]|$)|daily status' \
  README.md docs skills agents hooks templates bin scripts .claude-plugin .github 2>/dev/null | grep -v '^scripts/tests/docs.sh:' | grep -v '^docs/contract.md:.*- Neither skill has a daily status.')"
is "skills: no file outside the changelog names the sprint skill, the scrum-master agent, an old mode or a daily status" "$sm_left" ""
file_has "index template: names the scrum-master for planning" "$here/templates/vault-index.md.tmpl" \
  '`scrum-master` refines the stories and plans the sprints and releases'
file_lacks "index template: no scrum-master agent" "$here/templates/vault-index.md.tmpl" 'Agents: `scrum-master`'
file_has "index template: names the build skill for building a story" "$here/templates/vault-index.md.tmpl" \
  '`build`'
line_is "index template: what the build skill is for" "$here/templates/vault-index.md.tmpl" \
  '  builds an approved story or an epic'"'"'s stories, `vault-setup` sets up the vault or a project,'
line_is "index template: at version 10 in 0.14.0" "$here/templates/vault-index.md.tmpl" 'index_version: 10'
file_has "index: a scaffolded index names the build skill" "$vault/CLAUDE.md" '  builds an approved story or an epic'"'"'s stories,'
file_has "changelog: the index at 8 names the build skill" "$here/CHANGELOG.md" \
  '- The vault index names the scrum-master skill and the build skill, and no `sprint` skill or'
file_lacks "README: no scrum-master agent row" "$here/README.md" '| `scrum-master` |'
for w in refinement sprint-planning release-planning organize-board; do
  file_has "README: names the $w workflow" "$here/README.md" "- \`$w\`: "
done
file_has "guide: the refinement request is under What to say" "$here/docs/guide.md" \
  '| Refine EX-2 for the Example project: split it into two stories. | `scrum-master` |'
file_has "e2e: asks the same refinement request" "$here/scripts/e2e-claude.sh" \
  '"Refine EX-2 for the Example project: split it into two stories."'
file_has "guide: the release request is under What to say" "$here/docs/guide.md" \
  '| Plan the 0.2.0 release for the Example project: export the invoices as CSV, in three stories. | `scrum-master` |'
file_has "e2e: asks the same release request" "$here/scripts/e2e-claude.sh" \
  '"Plan the 0.2.0 release for the Example project: export the invoices as CSV, in three stories."'
file_has "guide: the board request is under What to say" "$here/docs/guide.md" '| Organize the board of the Example project. | `scrum-master` |'
file_has "e2e: asks the same board request" "$here/scripts/e2e-claude.sh" '"Organize the board of the Example project."'
file_has "guide: the sprint request loads scrum-master" "$here/docs/guide.md" '| Open a new sprint for the Mobile project. | `scrum-master` |'
for ph in '## 2. The draft' '## 3. The approval'; do
  file_has "guide: points to $ph in refinement" "$here/docs/guide.md" "\`$ph\` in"
  line_is "guide: refinement.md has the heading $ph" "$SMF" "$ph"
done
file_has "guide: points to the sprint-planning sections" "$here/docs/guide.md" \
  '`## Open`, `## Pick` and `## Close` in `skills/scrum-master/sprint-planning.md` say.'
file_has "guide: points to the contract's planned-releases shape" "$here/docs/guide.md" '`### Planned releases` in'
file_has "changelog: the scrum-master skill" "$CG" \
  '- The `scrum-master` skill replaces the `sprint` skill and the `scrum-master` agent. It has four'
file_has "changelog: /odsb:sprint moved to sprint-planning" "$CG" '- `/odsb:sprint` is now `/odsb:scrum-master sprint-planning`'
file_has "changelog: refinement" "$CG" '- `refinement` drafts or refines an epic and its stories'
file_has "changelog: release-planning" "$CG" '- `release-planning` sets a release'"'"'s goals, epics and stories with you'
file_has "changelog: organize-board" "$CG" '- `organize-board` is the agent'"'"'s hygiene pass'
file_has "changelog: no daily status" "$CG" '- The daily status is gone.'
file_has "changelog: story-tracker's approval" "$CG" '- story-tracker'"'"'s start mode shows a new story'"'"'s text'
file_has "changelog: no achievements logged" "$CG" '- story-tracker and the sprint close no longer log achievements'
file_has "changelog: a close with no sprint stops" "$CG" '- A sprint close asked for with no sprint in progress says so and stops.'
file_has "changelog: the skills' tools" "$CG" '- The scrum-master skill may edit and write notes and call story-tracker with no prompt, and'
file_has "changelog: index_version 8" "$CG" 'template is now at `index_version: 8`'
file_has "changelog: set index_version 8" "$CG" 'then set `index_version: 8`.'

# ---------------------------------------------------------------- the achievements skill gathers what done stories delivered, and the owner's proposals
AS="$here/skills/achievements/SKILL.md"
CG="$here/CHANGELOG.md"
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
RM="$here/README.md"
q="'"
exists "achievements: the skill exists" "$AS"
is "achievements: SKILL.md is its one file" "$(ls "$here/skills/achievements" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')" "SKILL.md "
line_is "achievements: its name" "$AS" 'name: achievements'
as_desc="$(sed -n 's/^description: //p' "$AS" 2>/dev/null)"
is "achievements: its description is under 200 characters" "$(( ${#as_desc} > 0 && ${#as_desc} < 200 ))" "1"
for w in "done stories" "date range" sprint proposals; do
  case "$as_desc" in *"$w"*) pass "achievements: the description names $w" ;;
    *) fail "achievements: the description names $w" "in: $as_desc" ;; esac
done
line_is "achievements: it may read, edit and write its note, and run the helper" "$AS" \
  'allowed-tools: Read Edit Write Bash(second-brain *)'
file_has "achievements: it carries the conventions pointer" "$AS" \
  'Conventions: before writing notes, run `second-brain conventions` and follow it.'
line_is "achievements: the context comes first" "$AS" '1. Your first tool call is `second-brain context`.'
is "achievements: SKILL.md is under the doctor's 150 lines" "$(($(wc -l <"$AS" 2>/dev/null || echo 999) <= 150))" "1"
# Each story set to done in the period, from its Summary and Changes, one achievement each, listed once.
line_is "achievements: the period is a date range or a sprint" "$AS" \
  '- The period is a date range or a sprint, from the request. With neither, ask which.'
line_is "achievements: one board call lists every task, archived or not" "$AS" \
  '1. List the project'"$q"'s tasks in one call: `second-brain board <project> All`.'
line_is "achievements: only the done stories" "$AS" '2. Keep the rows whose `status` is `done`.'
line_is "achievements: a sprint's stories are those whose sprint is its id" "$AS" \
  '3. A sprint: keep the rows whose `sprint` cell is its id. A done story keeps the sprint it'
line_is "achievements: a range's stories are those set to done in it" "$AS" \
  '4. A date range: keep each story set to `done` from `<from>` to `<to>`.'
line_is "achievements: a story records no done date" "$AS" \
  '   - A story records no date it was set to `done`. Only its dated status notes show it.'
file_has "achievements: a story whose newest note is older than the range is left out unread" "$AS" \
  'One dated before `<from>`: no note shows it set to `done` in the range, so leave it out.'
line_is "achievements: the done date is the note of the move to done" "$AS" \
  '   - Its done date is the date of the newest note that records its move to `done`. With none,'
line_is "achievements: else the newest note, and the result says so" "$AS" \
  '     it is the date of its newest note, and its line in the result says so.'
line_is "achievements: a story with no dated note goes to the owner" "$AS" \
  '   - No dated note at all: list it under `No done date:`, for the owner to keep or drop.'
line_is "achievements: a story is listed once" "$AS" \
  '5. List each story once, under its id, whatever its aliases or its notes say. An environment set'
file_has "achievements: reads the Summary and Changes cheapest first" "$AS" \
  'title to `## Description`, which holds its `**Summary:**` line, and one of `## Changes`.'
line_is "achievements: one achievement per story, from its Summary and Changes" "$AS" \
  '- Word one achievement per story, in one or two sentences: what the story delivered, from its'
line_is "achievements: claims nothing the story does not say" "$AS" \
  '- Say only what they say: add no number, effect or name they lack.'
line_is "achievements: each names its story" "$AS" '- Each achievement names its story, by its id.'
line_is "achievements: a part is empty when it still holds the template's text" "$AS" \
  '- A Summary or `## Changes` is empty when it is missing, blank, `None yet.`, or still the text of'
line_is "achievements: the plugin's task template or the project's own" "$AS" \
  '  the plugin'"$q"'s task template or the project'"$q"'s own, such as a line of `<...>` placeholders.'
line_is "achievements: an empty Changes is worded from the Summary alone" "$AS" \
  '- `## Changes` empty: word it from the Summary alone, and its line in the result says so.'
line_is "achievements: an empty Summary is worded from Changes alone" "$AS" \
  '- The Summary empty: word it from `## Changes` alone, and its line says so. Both empty: list the'
line_is "achievements: both empty go to the owner to word" "$AS" '  story under `To word:`, for the owner to word.'
# The owner's proposals, asked for and worded from the context, never made up.
line_is "achievements: asks for the owner's proposals in the period" "$AS" \
  '- Ask the owner whether they made any proposals to their company or project in the period: from'
line_is "achievements: waits for the owner's answer" "$AS" \
  '- Ask it as plain text, not with AskUserQuestion, and stop for the answer: only the owner knows'
line_is "achievements: words each from the owner's words" "$AS" \
  '- Word each one as an achievement, in one or two sentences, from the owner'"$q"'s words. Draw on the'
line_is "achievements: with the project's and the stories' context" "$AS" \
  '  project'"$q"'s context, a ranged read of `<project path>/README.md`, and the stories of step 2.'
line_is "achievements: makes up no proposal" "$AS" \
  '- Make up no proposal. Never take one from a story'"$q"'s notes, a build note or the code, and add no'
as_story="$(lineno "$AS" '## 3. One achievement per story' 2>/dev/null)"
as_prop="$(lineno "$AS" '## 4. The proposals' 2>/dev/null)"
is "achievements: the proposals come after the stories" "$((${as_story:-0} > 0 && ${as_story:-0} < ${as_prop:-0}))" "1"
# The result in the reply, a note only on the owner's ask.
line_is "achievements: the result is in the reply" "$AS" 'Show the result in your reply, in this shape:'
line_is "achievements: has ## 6. The note" "$AS" '## 6. The note'
line_is "achievements: a note only on the owner's ask" "$AS" \
  'Only on the owner'"$q"'s ask, write the result to `<project path>/<topics_root>/achievements.md`.'
file_has "achievements: adds a period's section and never rewrites the note" "$AS" \
  'last one, with the Edit tool. Never rewrite the note.'
line_is "achievements: a period's section is replaced only on a yes" "$AS" \
  '- The period has a section already: show it, and replace it only on the owner'"$q"'s yes.'
file_has "achievements: the note's alias" "$AS" '  - "<Project> Achievements"'
file_has "achievements: the note's up-link" "$AS" '> Up: [[<project path>/<topics_root>/README|<Project> Docs Hub]]'
# The vault index names the skill once, to send a request for achievements to it.
ac_hits="$(cd "$here" && grep -rlis 'achievement' skills agents hooks templates bin scripts/lib |
  grep -v -e '^skills/achievements/' -e '^templates/vault-index\.md\.tmpl$')"
is "achievements: no other skill, agent, template or helper file names an achievement" "$ac_hits" ""
is "achievements: the vault index names one only to send it to the skill" \
  "$(grep -ci 'achievement' "$here/templates/vault-index.md.tmpl")" "1"
# The docs describe the skill, and achievements_skill is gone.
line_is "README: a section for the achievements skill" "$RM" '### `/odsb:achievements`'
file_has "README: it asks for the proposals and makes up none" "$RM" \
  '- It asks you about the proposals you made to your company or project then, and helps you word'
file_has "README: the result is in the reply, a note only on your ask" "$RM" \
  '- The result is in its reply. It writes it to the project'"$q"'s `achievements.md` note only when you'
file_has "guide: the achievements request is under What to say" "$GD" \
  '| List my achievements on the Example project from 2026-11-01 to 2026-11-30. | `achievements` |'
file_has "e2e: asks the same achievements request" "$here/scripts/e2e-claude.sh" \
  '"List my achievements on the Example project from 2026-11-01 to 2026-11-30."'
line_is "guide: has ## Achievements" "$GD" '## Achievements'
line_is "contract: the achievements skill" "$CT" \
  '- **The `achievements` skill gathers the owner'"$q"'s achievements.** It is the one skill or agent'
file_has "contract: a part still the template's text is left out" "$CT" \
  '- A part that is missing, blank, `None yet.` or still the task template'"$q"'s text is left out, and'
file_has "contract: the note's shape has its home in the skill" "$CT" '`## 6. The note` in `skills/achievements/SKILL.md`'
file_has "contract: the project holds the achievements note" "$CT" \
  '  <topics_root>/achievements.md   optional; the owner'"$q"'s achievements (section 9)'
file_has "contract: story-tracker and the sprint close leave achievements to the skill" "$CT" \
  'does the sprint close: the `achievements` skill gathers them, as below.'
file_lacks "contract: the profile example has no achievements_skill" "$CT" 'achievements_skill: ""'
file_has "contract: a profile that still has achievements_skill keeps it" "$CT" \
  '- `achievements_skill` is no key of the profile. Versions before 0.13.0 wrote it. A profile that'
line_is "index template: names the achievements skill among the plugin's skills" "$here/templates/vault-index.md.tmpl" \
  '  `achievements` gathers a date range'"$q"'s or a sprint'"$q"'s achievements. Agent:'
file_has "index: a scaffolded index names the achievements skill" "$vault/CLAUDE.md" \
  '`achievements` gathers a date range'"$q"'s or a sprint'"$q"'s achievements.'
for f in templates/profile.md.tmpl skills/vault-setup/SKILL.md scripts/lib/doctor.sh; do
  file_lacks "achievements_skill: gone from $f" "$here/$f" 'achievements_skill'
done
for l in '- The `achievements` skill gathers your achievements for a date range or a sprint: one for each' \
  '- It asks you about the proposals you made to your company or project in that time, and helps' \
  '- It shows the result in its reply, and writes it to `achievements.md` in the project'"$q"'s topics' \
  '- `achievements_skill` is gone from the profile template, vault-setup and the doctor'"$q"'s `profile`' \
  '- The vault index names the define-validation-scope and achievements skills. The plugin'"$q"'s index' \
  '  `templates/vault-index.md.tmpl` into your vault'"$q"'s `CLAUDE.md`, then set `index_version: 9`.'; do
  file_has "changelog: ${l:2:48}" "$CG" "$l"
done

# ---------------------------------------------------------------- a description with a colon and a blank is quoted
for f in "$here"/skills/*/SKILL.md "$here"/agents/*.md; do
  d="$(awk 'NR == 1 && $0 == "---" { on = 1; next } on && $0 == "---" { exit } on && /^description: / { sub(/^description: /, ""); print; exit }' "$f")"
  n="${f#"$here"/}"
  case "$d" in
    *': '*)
      case "$d" in
        \"*\" | \'*\') pass "frontmatter: $n quotes its description, which holds a colon and a blank" ;;
        *) fail "frontmatter: $n quotes its description, which holds a colon and a blank" "got: $d" ;;
      esac ;;
    '') fail "frontmatter: $n has a description" ;;
    *) pass "frontmatter: $n has a description with no colon and blank" ;;
  esac
done

# ---------------------------------------------------------------- nothing names the retired spec flow
# The spec skill, spec-checker and the helper's spec commands are gone. Only the changelog's released
# sections, which are history, may name them.
sp_re='odsb:spec([^a-z0-9_-]|$)|skills/spec([^a-z0-9_-]|$)|spec-checker|second-brain spec([^a-z0-9_-]|$)'
sp_re="$sp_re"'|`spec (<|new|tasks|tick|packet|link|status|issue)|cmd_spec|sb_spec_|lib/spec\.sh'
sp_re="$sp_re"'|spec-(requirements|design|tasks)\.md\.tmpl'
is "spec flow: the guard catches each way of naming it" \
  "$(printf '%s\n' 'Run `/odsb:spec EX-1`.' 'See skills/spec/build.md.' 'Launch `spec-checker`.' \
    'Run `second-brain spec EX-1`.' 'Then `spec status <ID>`.' 'cmd_spec' 'sb_spec_value' 'scripts/lib/spec.sh' \
    'templates/spec-tasks.md.tmpl' | grep -cE -- "$sp_re")" "9"
is "spec flow: and lets the words that stay pass" \
  "$(printf '%s\n' 'A `spec/` folder stays.' 'The `spec_home` key.' 'The retired spec flow.' 'odsb:spec-trace-x' \
    'the `spec-trace` check is gone' 'skills/spec-like' | grep -cE -- "$sp_re" || true)" "0"
sp_files="$(cd "$here" && find README.md docs skills agents hooks templates bin scripts/lib scripts/e2e-claude.sh \
  scripts/leak-check.sh .claude-plugin .github -type f 2>/dev/null | LC_ALL=C sort)"
sp_hits="$(cd "$here" && printf '%s\n' "$sp_files" | tr '\n' '\0' | xargs -0 grep -nE -- "$sp_re" 2>/dev/null)"
is "spec flow: no file names the spec skill, spec-checker or a spec command" "$sp_hits" ""
is "spec flow: the scan reads the skills, the agents and the docs" \
  "$(printf '%s\n' "$sp_files" | grep -cE '^(skills/build/SKILL\.md|agents/reviewer\.md|docs/contract\.md|README\.md)$')" "4"
dl_hits="$(cd "$here" && grep -rnw -- 'delivery' skills agents hooks templates bin scripts/lib 2>/dev/null |
  grep -v 'is not read' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#')"
is "spec flow: no skill, agent, template or helper reads a delivery key, and the one that names it says so" "$dl_hits" ""
CG="$here/CHANGELOG.md"
for l in '- The spec flow is retired, so there is one flow to learn: the `build` skill builds every approved' \
  '- A vault with specs moves on as it is. A story'"'"'s `spec/` folder and `build.json` stay in its task' \
  '- To build a story you started from a spec, bring what its spec settled into the README'"'"'s' \
  '- The doctor'"'"'s `delivery` check is now `settings`: it names a `validation_home` or a'; do
  line_is "changelog: ${l:2:48}" "$CG" "$l"
done
file_has "contract: an old spec folder and build.json stay as plain files of the task" "$here/docs/contract.md" \
  '  retired spec flow wrote, before 0.12.0, stay there as plain files of the task.'
file_has "contract: the delivery and spec_home keys are no keys" "$here/docs/contract.md" \
  '- `delivery` and `spec_home` are no keys of the profile or a task. Versions'

# ---------------------------------------------------------------- docs-keeper sets up a project's docs, for the user to approve
DK="$here/agents/docs-keeper.md"
VSD="$here/skills/vault-setup"
VSO="$VSD/docs.md"
q="'"
w7="## Workflow 7 - Set up a project${q}s docs"
line_is "docs-keeper: Workflow 7 sets up a project's docs" "$DK" "$w7"
w6_line="$(lineno "$DK" '## Workflow 6 - ')"
w7_line="$(linex "$DK" "$w7")"
wv_line="$(linex "$DK" '## Working in the vault')"
is "docs-keeper: Workflow 7 comes after Workflow 6 and before the vault rules" \
  "$((${w6_line:-0} > 0 && ${w6_line:-0} < ${w7_line:-0} && ${w7_line:-0} < ${wv_line:-0}))" "1"
file_has "docs-keeper: vault-setup starts it with the project and the repositories" "$DK" \
  'The caller, the `vault-setup` skill, gives the project and the repositories to set up: each one'
file_has "docs-keeper: the caller holds the approval, as the agent cannot ask" "$DK" \
  'when it adds a project, the new one when it adds a repository. You cannot ask the user, so the'
line_is "docs-keeper: Workflow 7 has a draft round" "$DK" "### The draft"
line_is "docs-keeper: and a write round" "$DK" "### The write"
file_has "docs-keeper: the draft reads the code at the code ref" "$DK" \
  '1. Read each repository at the code ref, as `## The code ref` says. The draft describes that code'
line_is "docs-keeper: the draft reads the README" "$DK" '   - Its README: `git -C "<path>" show <ref>:README.md`.'
line_is "docs-keeper: the draft reads the layout" "$DK" '   - Its layout: `git -C "<path>" ls-tree -r --name-only <ref>`.'
line_is "docs-keeper: the draft reads the code the layout shows" "$DK" \
  '   - Its code: the entry points, modules and config the layout shows.'
file_has "docs-keeper: the draft keeps a topic folder that exists" "$DK" \
  '   - Draft nothing in a topic folder that exists. Workflow 4 gives it a hub.'
line_is "docs-keeper: the draft reads the topic folders and the map" "$DK" \
  '   `ls -d "<vault>/<project path>/<topics_root>"/*/`, and the rows under `### Code to doc map`.'
file_has "docs-keeper: drafts the topic folders" "$DK" \
  '3. Draft one topic per part of the code a reader asks about, such as a module, a service or a'
file_has "docs-keeper: a topic folder's tag is its path" "$DK" 'so that its topic tag is its path'
file_has "docs-keeper: a hub for each topic folder" "$DK" '   - Its hub, `<topic>/README.md`, as Workflow 4 says: a unique alias, `type: moc`, an up link to'
file_has "docs-keeper: a first note per topic" "$DK" '   - Its first note, such as `<topic>/overview.md`: a unique alias, a `title`, a `type` from the'
file_has "docs-keeper: the first note's claims come from the code" "$DK" \
  'then what the code confirms, each claim with the file it comes from.'
line_is "docs-keeper: a topic's hub links up to its parent hub" "$DK" \
  '     its parent hub and a link down to its first note.'
file_lacks "docs-keeper: not to the topics hub, whatever its parent" "$DK" \
  'the topics hub and a link down to its first note.'
line_is "docs-keeper: its parent hub links each new hub" "$DK" '   - The line that links its hub from its parent hub.'
file_has "docs-keeper: the parent hub is the topics hub" "$DK" \
  '   - The parent hub is the topics hub, with the line under `## Topics`. With `topics_root: "."`'
file_has "docs-keeper: the write edits each parent hub" "$DK" \
  '   - The parent hubs'"${q}"' lines and the map rows with the Edit tool.'
line_is "docs-keeper: every link carries a path" "$DK" \
  '   - Every link carries its full vault path: `[[<vault path>|<alias>]]`.'
file_has "docs-keeper: drafts the Code to doc map rows" "$DK" \
  '5. Draft the Code to doc map rows: for each repository, one row per kind of change that alters a'
line_is "docs-keeper: the draft writes nothing" "$DK" \
  '6. Return the draft, as `## Output` says, and write nothing: no folder, no note and no line of'
file_has "docs-keeper: an asked change is checked against the code and drafted again" "$DK" \
  '7. A caller that gives a draft and a change the user asked for: check the change against the'
line_is "docs-keeper: the write takes the draft the user approved" "$DK" \
  '1. The caller gives the draft the user approved, with each change the user asked for in it.'
line_is "docs-keeper: the write adds nothing to the draft" "$DK" '2. Write it as approved, and nothing more.'
file_has "docs-keeper: the write overwrites no file" "$DK" '     A file that exists is kept: report it, and never overwrite it.'
file_has "docs-keeper: the write checks its links" "$DK" \
  '3. Run `second-brain unresolved <project>`. It must list no link you wrote: fix the path of each'
file_has "docs-keeper: the write runs the doctor" "$DK" '4. Run `second-brain doctor <project>`, and report each row that is not `ok`.'
file_has "docs-keeper: the output of a draft" "$DK" '- A docs setup draft: each folder, each hub and note with its whole text, each line for a parent'
file_has "docs-keeper: the output of a write" "$DK" '- A docs setup written: each file written, each file kept as it was, the rows added, and each'
exists "vault-setup: the docs setup has a file of its own" "$VSO"
line_is "vault-setup docs: its title" "$VSO" "# Set up a project${q}s docs from its code"
file_has "vault-setup docs: the skill holds the approval, as docs-keeper cannot ask" "$VSO" \
  'draft. It is an agent and cannot ask the user, so this skill holds the approval. Nothing is written'
file_has "vault-setup docs: project mode offers it when no topic folder exists" "$VSO" \
  '- Project mode, at step 7 of `## project <name>` in `SKILL.md`: offer it when the topics root holds'
file_has "vault-setup docs: repo mode offers it for the new repository" "$VSO" \
  '- Repo mode, at `## 2. The docs that follow it` in `repo.md`: offer it for the new repository.'
file_has "vault-setup docs: starts docs-keeper by its plugin name" "$VSO" '1. Start the `docs-keeper` agent (`odsb:docs-keeper`) with the project and the repositories, and'
line_is "vault-setup docs: asks for Workflow 7's draft, by the heading's name" "$VSO" \
  "   ask it for the draft of \`${w7#\#\# }\`."
line_is "vault-setup docs: the draft writes nothing" "$VSO" '2. It returns the draft and writes nothing.'
file_has "vault-setup docs: shows the user the whole draft" "$VSO" '3. Show the user the whole draft, as it came:'
file_has "vault-setup docs: an asked change goes back to docs-keeper" "$VSO" \
  '1. A change the user asks for goes to `docs-keeper` with the draft, for a new draft. It checks the'
line_is "vault-setup docs: each change is shown" "$VSO" '2. Show the user each part that changed, then ask again.'
line_is "vault-setup docs: nothing is written before the approval" "$VSO" '3. Nothing is written until the user approves the draft as shown.'
file_has "vault-setup docs: docs-keeper writes on the approval" "$VSO" \
  '1. On the user'"${q}"'s approval, start `docs-keeper` again for the write of Workflow 7, with the draft as'
for ptr in 'SKILL.md|## project <name>' 'repo.md|## 2. The docs that follow it'; do
  pf="${ptr%%|*}" ph="${ptr#*|}"
  line_is "vault-setup docs: $pf has the heading $ph" "$VSD/$pf" "$ph"
done
file_has "vault-setup: project mode offers the docs setup" "$VSD/SKILL.md" \
  '   - Offer to have `docs-keeper` draft the project'"${q}"'s docs from its code, as'
file_has "vault-setup: the router names the docs file" "$VSD/SKILL.md" '`${CLAUDE_SKILL_DIR}/docs.md`, the docs setup, is no mode'
file_has "vault-setup repo: repo mode offers the docs setup" "$VSD/repo.md" \
  'In repo mode, first offer to have `docs-keeper` draft the repository'"${q}"'s docs from its code, as'
file_has "vault-setup repo: the draft's rows are kept" "$VSD/repo.md" 'A repository with rows from such a draft keeps them'
CT="$here/docs/contract.md"
file_has "contract: a project with no docs gets a draft from docs-keeper" "$CT" \
  '- **A project with no docs gets a draft of them from `docs-keeper`.** When `vault-setup` adds a'
file_has "contract: the draft reads the README, the layout and the code" "$CT" \
  '- `docs-keeper` reads each repository'"${q}"'s README, its layout and its code at the code ref. It'
file_has "contract: the draft writes nothing, and vault-setup holds the approval" "$CT" \
  '- It returns the draft and writes nothing. An agent cannot ask the owner, so `vault-setup` holds'
file_has "contract: docs-keeper writes only on the approval" "$CT" \
  '- Only on the owner'"${q}"'s approval does `vault-setup` start `docs-keeper` again to write the draft as'
file_has "contract: the notes follow the conventions" "$CT" \
  '- Each note it writes follows the conventions: a hub per folder, links with paths, and topic tags'
GD="$here/docs/guide.md"
for ph in '## 2. The draft' '## 4. The write'; do
  file_has "guide: points to $ph in skills/vault-setup/docs.md" "$GD" "\`$ph\` in \`skills/vault-setup/docs.md\`"
  line_is "guide: skills/vault-setup/docs.md has the heading $ph" "$VSO" "$ph"
done
file_has "guide: a project with no docs can have them drafted" "$GD" '- A project with no docs can have them drafted from its code. When `vault-setup` adds a project'
file_has "guide: nothing is written before the approval" "$GD" '- You see the whole draft, and each change you ask for, before anything is written.'
file_has "README: docs-keeper is started by vault-setup too" "$here/README.md" \
  '`vault-setup` when it adds a project or a repo, `vault-doctor fix` on an `old-namespace` row, or you. |'
CG="$here/CHANGELOG.md"
for l in '- `docs-keeper` sets up the docs of a project that has none, in its new' \
  '- `vault-setup` offers it when it adds a project or a repository. The draft writes nothing:' \
  '- Each note it writes follows the conventions: a hub per folder, links with paths, and topic tags'; do
  line_is "changelog: ${l:2:48}" "$CG" "$l"
done

# ---------------------------------------------------------------- define-validation-scope drafts a repo's checks, for the owner to approve
DV="$here/skills/define-validation-scope/SKILL.md"
q="'"
exists "define-validation-scope: a skill of its own" "$DV"
absent "define-validation-scope: a skill, not an agent, as it talks with the owner" "$here/agents/define-validation-scope.md"
line_is "define-validation-scope: the name is the folder's" "$DV" "name: define-validation-scope"
dv_desc="$(sed -n 's/^description: //p' "$DV")"
is "define-validation-scope: has a description under 200 characters" "$((${#dv_desc} > 0 && ${#dv_desc} < 200))" "1"
file_lacks "define-validation-scope: a request may load it, and vault-setup calls it" "$DV" "disable-model-invocation"
line_is "define-validation-scope: it may read the code, edit the section and run ls -d" "$DV" \
  'allowed-tools: Read Grep Glob Edit Bash(second-brain *) Bash(ls -d *)'
file_has "define-validation-scope: carries the conventions pointer" "$DV" \
  'Conventions: before writing notes, run `second-brain conventions` and follow it.'
line_is "define-validation-scope: the context comes first" "$DV" '1. Run `second-brain context` yourself, as your first tool call.'
for h in '## Step 0 - Context' '## 1. The stages the project uses' "## 2. The project${q}s docs" \
  "## 3. The repo${q}s code" '## 4. The draft' '## 5. The approval' '## 6. The write' '## Rules'; do
  line_is "define-validation-scope: has $h" "$DV" "$h"
done
dv_help="$(bash "$SB" help 2>&1)"
for w in $(grep -oE '`second-brain [a-z]+' "$DV" | sed 's/^`second-brain //' | LC_ALL=C sort -u); do
  if printf '%s\n' "$dv_help" | grep -qw -- "$w"; then pass "define-validation-scope: second-brain $w is in help"
  else fail "define-validation-scope: second-brain $w is in help" "help lacks: $w"; fi
done
# It reads the project's docs, and offers docs-keeper's setup of skills/vault-setup/docs.md to a project with none.
file_has "define-validation-scope: the project's docs are its topic notes and the repo's doc files" "$DV" \
  '1. The project'"${q}"'s docs are its topic notes, under the topics root in the vault, and the repo'"${q}"'s own'
file_has "define-validation-scope: none, as docs.md counts the topic folders" "$DV" \
  '2. It has none when the topics root holds no topic folder, as `## 1. Offer it` in'
file_has "define-validation-scope: names the docs setup by its path" "$DV" '`${CLAUDE_PLUGIN_ROOT}/skills/vault-setup/docs.md`'
file_has "define-validation-scope: a project with none is offered docs-keeper's setup first" "$DV" \
  '3. A project with none: offer `docs-keeper`'"${q}"'s setup first, for this repo, as that file says. This'
file_has "define-validation-scope: offers it once a session" "$DV" \
  '   - Declined already in this session, such as at step 7 of vault-setup'"${q}"'s project mode: take it'
file_has "define-validation-scope: on a no it reads the code" "$DV" \
  '   - On a no, or when it writes nothing, read the repo'"${q}"'s code as `## 3. The repo'"${q}"'s code` says, and'
file_has "define-validation-scope: a project with docs drafts from them" "$DV" \
  '4. A project with docs: read the ones on how the repo is set up, tested, built and laid out,'
file_has "define-validation-scope: a command the code does not hold is not confirmed" "$DV" \
  '   - A command the docs name that the code does not hold goes under `Not confirmed:` in the draft,'
line_is "define-validation-scope: the code is its test scripts" "$DV" \
  '- Its test scripts: the test, lint and build entries of `package.json` `scripts`, the targets of a'
line_is "define-validation-scope: its CI workflows" "$DV" \
  '- Its CI workflows, such as `.github/workflows/*.yml` or `.gitlab-ci.yml`: the commands each job'
line_is "define-validation-scope: and its package manifests" "$DV" \
  '- Its package manifests, such as `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml` or'
file_has "define-validation-scope: runs none of the repo's commands" "$DV" 'Run none of'
VSO="$here/skills/vault-setup/docs.md"
for ph in '## 1. Offer it' '## 2. The draft' '## 3. The approval' '## 4. The write'; do
  line_is "define-validation-scope: docs.md has the heading $ph it follows" "$VSO" "$ph"
done
# It drafts each check with its command, its stage and its paths, in the template's shape.
file_has "define-validation-scope: drafts in the template's shape" "$DV" '`${CLAUDE_PLUGIN_ROOT}/templates/validation-repo.md.tmpl`'
exists "define-validation-scope: the template it names exists" "$here/templates/validation-repo.md.tmpl"
for h in '### Set up and start' '### Checks' '### Check as a user would' '### A pass'; do
  file_has "define-validation-scope: drafts $h" "$DV" "- \`$h\`: "
  line_is "define-validation-scope: the template has $h" "$here/templates/validation-repo.md.tmpl" "$h"
done
file_has "define-validation-scope: a check is its command, what it proves, its paths and its when" "$DV" \
  '- `### Checks`: one bullet per check: its command the line'"${q}"'s first code span, then what it'
file_has "define-validation-scope: an example check with paths and a when" "$DV" \
  '`` - `npm run test:api` - the API suite - paths: api/**, `package.json` - when: each story ``.'
file_has "define-validation-scope: each story" "$DV" '  - `when: each story` for one each story'"${q}"'s review runs, quick enough for every change, such'
file_has "define-validation-scope: each merge" "$DV" '  - `when: each merge` for one that runs once a story merges, such as the full suite or the'
file_has "define-validation-scope: release" "$DV" '  - `when: release`, in a project that plans releases, for one that costs money or takes long,'
file_has "define-validation-scope: the paths of a check only some files can break" "$DV" \
  '- The `paths:` of a check that only some files can break, such as the suite of one part: the'
file_has "define-validation-scope: a check any file can break has no paths" "$DV" \
  '  - A check that any file can break, such as the linter of the whole repo or the build, has no'
file_has "define-validation-scope: a user step takes no paths" "$DV" 'A user step takes no `paths:`.'
line_is "define-validation-scope: invents nothing" "$DV" '- Never invent a command, a glob, a stage or a step.'
# It proposes only the stages the project uses.
file_has "define-validation-scope: every project uses each story and each merge" "$DV" \
  '- Every project uses `each story`, run in each story'"${q}"'s review, and `each merge`, run on the'
file_has "define-validation-scope: release only in a project that plans releases" "$DV" \
  '- `release` is only for a project that plans releases: one whose planned-releases note,'
file_has "define-validation-scope: the planned-releases note's path" "$DV" \
  '`<vault>/<project path>/<topics_root>/planned-releases.md`, is there, as `ls -d "<that path>"`'
line_is "define-validation-scope: no release check in a project that plans none" "$DV" \
  '- In a project that plans no releases, draft no `release` check and no `release` user step.'
file_has "define-validation-scope: a release check left out is named" "$DV" \
  '  A check the code keeps for a release, such as an end-to-end suite that costs money, goes under'
# It shows the draft and each change, and writes only on the owner's approval.
file_has "define-validation-scope: shows the draft and stops" "$DV" \
  '1. Show the draft, and end it with the line `What'"${q}"'s wrong or missing?` as plain text. Then stop for'
file_has "define-validation-scope: shows each asked change again" "$DV" \
  '2. A change the owner asks for: make it in the draft, and show each part it changed again, in'
line_is "define-validation-scope: nothing is written before the approval" "$DV" \
  '3. Nothing is written until the owner approves the draft as shown.'
line_is "define-validation-scope: only a plain yes approves it" "$DV" \
  '   - With no change left, ask for that approval. Only a plain yes is one.'
line_is "define-validation-scope: a no writes nothing" "$DV" '4. A no to the whole draft writes nothing. Say that the section stays as it was.'
file_has "define-validation-scope: the write is on the approval" "$DV" \
  '1. On the owner'"${q}"'s approval, take the repo'"${q}"'s state from `second-brain validation <project>`:'
file_has "define-validation-scope: a missing section through validation new" "$DV" \
  '   - `missing` or `no-section`: run `second-brain validation new <project> <repo>`. It writes the'
file_has "define-validation-scope: a section that is there keeps its other lines" "$DV" \
  'Change no other line, and no other repo'"${q}"'s section.'
file_has "define-validation-scope: reads the section back" "$DV" \
  '3. Read it back with `second-brain validation <project> <repo>`. It must print the section as'
# The docs and vault-setup.
RM="$here/README.md"
file_has "README: define-validation-scope proposes the checks of each stage" "$RM" \
  'Proposes which checks run at each stage of a repo'"${q}"'s validation, from your project'"${q}"'s docs or'
file_has "README: each check with its command, stage and paths" "$RM" \
  '- Each check it drafts has its command, its stage, `each story`, `each merge` or `release`, and'
file_has "README: docs first, docs-keeper's setup, then the code" "$RM" \
  '- It reads the project'"${q}"'s docs first. A project with none is offered `docs-keeper`'"${q}"'s setup'
file_has "README: only the stages the project uses" "$RM" \
  '- It proposes only the stages your project uses: no `release` check in a project that plans no'
file_has "README: writes only on the approval" "$RM" \
  '- It shows you the whole draft, and each change you ask for again, and writes the section only'
file_has "README: vault-setup offers it" "$RM" '- `vault-setup` offers it when it adds a repo.'
file_has "README: docs-keeper is started by define-validation-scope too" "$RM" \
  '`define-validation-scope` in a project with no docs, `vault-setup` when it adds a project or a repo,'
CT="$here/docs/contract.md"
file_has "contract: define-validation-scope drafts a repo's section" "$CT" \
  '- **`define-validation-scope` drafts a repo'"${q}"'s validation section.** It is a skill, as it talks'
file_has "contract: it reads the docs, offers the setup, then the code" "$CT" \
  '- It reads the project'"${q}"'s docs first: its topic notes and the repo'"${q}"'s doc surfaces. A project with'
file_has "contract: its code is the test scripts, CI workflows and package manifests" "$CT" \
  'On a no, it reads the repo'"${q}"'s code: its test scripts, CI workflows and package manifests.'
file_has "contract: only the stages the project uses" "$CT" \
  '- It proposes only the stages the project uses. `release` is for a project that plans releases,'
file_has "contract: writes only on the approval, through validation new" "$CT" \
  'owner'"${q}"'s approval does it write the repo'"${q}"'s section, through `second-brain validation new` for a'
file_has "contract: vault-setup offers it in each mode that adds a repo" "$CT" \
  '- `vault-setup` offers it when it adds a repo, in project, repo or adopt mode, and'
file_has "contract: the setup's offer has a second caller" "$CT" \
  '- `define-validation-scope` offers the same setup, through the same steps, to a project with no'
GD="$here/docs/guide.md"
file_has "guide: the request is under What to say" "$GD" \
  '| Define the validation scope of example-api for the Example project. | `define-validation-scope` |'
file_has "guide: define-validation-scope drafts a repo's steps" "$GD" \
  '- `define-validation-scope` drafts a repo'"${q}"'s steps for you: each check'"${q}"'s command, its stage and'
for ph in '## 1. The stages the project uses' '## 6. The write'; do
  file_has "guide: points to $ph in skills/define-validation-scope/SKILL.md" "$GD" "\`$ph\` in \`skills/define-validation-scope/SKILL.md\`"
done
file_has "guide: vault-setup offers it" "$GD" '- `vault-setup` offers it when it adds a repo.'
CG="$here/CHANGELOG.md"
for l in '- The new `define-validation-scope` skill proposes which checks run at each stage of a repo: each' \
  '- It proposes only the stages the project uses: a `release` check only in a project with a' \
  '- `vault-setup` offers it when it adds a repo, in project, repo, subproject or adopt mode.' \
  '- The vault index names the define-validation-scope and achievements skills. The plugin'"${q}"'s index' \
  '  `templates/vault-index.md.tmpl` into your vault'"${q}"'s `CLAUDE.md`, then set `index_version: 9`.'; do
  line_is "changelog: ${l:2:48}" "$CG" "$l"
done
line_is "index template: names define-validation-scope among the plugin's skills" "$here/templates/vault-index.md.tmpl" \
  '  `vault-doctor` checks them, `define-validation-scope` drafts a repo'"${q}"'s validation steps,'
VSD="$here/skills/vault-setup"
line_is "vault-setup: it may call define-validation-scope with the project and the repo" "$VSD/SKILL.md" \
  'allowed-tools: Read Glob Skill(odsb:define-validation-scope *) Bash(second-brain *)'
file_has "vault-setup: project mode offers define-validation-scope for each repo" "$VSD/SKILL.md" \
  '    - First offer `define-validation-scope` for each repo, as step 2 of `## 3. Finish` in'
line_is "vault-setup repo: repo.md has the heading ## 3. Finish" "$VSD/repo.md" '## 3. Finish'
file_has "vault-setup repo: repo mode offers define-validation-scope" "$VSD/repo.md" \
  '2. Write the repository'"${q}"'s validation steps. First offer to have the `define-validation-scope`'
line_is "vault-setup repo: calls it with the Skill tool" "$VSD/repo.md" \
  '   - On a yes, call it with the Skill tool as `odsb:define-validation-scope <project> <repo>`,'
file_has "vault-setup repo: on a no, its own validation steps" "$VSD/repo.md" \
  '   - On a no, or when the session cannot call it, write them as `validation.md`, beside this'
file_has "vault-setup adopt: offers define-validation-scope for each repository" "$VSD/adopt.md" \
  '  - First offer `define-validation-scope` for each one, as step 2 of `## 3. Finish` in `repo.md`'
# Each mode that writes a repo's validation steps by validation.md offers define-validation-scope first.
dv_modes=0
for f in "$VSD"/*.md; do
  [ "${f##*/}" != validation.md ] || continue
  grep -qE 'validation steps as `(\$\{CLAUDE_SKILL_DIR\}/)?validation\.md`' "$f" || continue
  dv_modes=$((dv_modes + 1))
  file_has "vault-setup ${f##*/}: offers define-validation-scope where it writes the validation steps" "$f" \
    'First offer `define-validation-scope` for each'
done
is "vault-setup: project and adopt write the validation steps by validation.md" "$dv_modes" "2"
file_has "vault-setup docs: define-validation-scope offers the setup too" "$VSO" \
  '- The `define-validation-scope` skill, at step 3 of `## 2. The project'"${q}"'s docs` in its `SKILL.md`:'
file_has "docs-keeper: define-validation-scope is a caller of Workflow 7 too" "$here/agents/docs-keeper.md" \
  'The `define-validation-scope` skill is a caller too, through the same steps, for the one'

# ---------------------------------------------------------------- story-tracker looks for the same story first
# Before it writes a new story, start mode shows each story that does the same and the epics it
# could join, and the owner picks.
STC="$here/skills/story-tracker/create.md"
ds_lead='Then, before step 1, look for a story that already does the same, and for the epic it could'
line_is "same story: create.md looks for a story that does the same, and an epic" "$STC" "$ds_lead"
line_is "same story: every new story gets the check, one from refinement too" "$STC" \
  'join. Every new story gets this check, one from refinement too:'
ds_at="$(linex "$STC" "$ds_lead")"
is "same story: the check is in section 3, after the approval and the refinement rule, before step 1" \
  "$((${ds_at:-0} > $(lineno "$STC" 'A story the scrum-master') && ${ds_at:-0} < $(lineno "$STC" '1. `second-brain task new EX-123')))" "1"
is "same story: the check is under ## 3. Create the story" \
  "$(section_of "$STC" '3. Create the story' | grep -cxF -- "$ds_lead")" "1"
line_is "same story: it searches the open and done stories" "$STC" "- Search the project's stories, open and done:"
file_has "same story: with the helper, in the tasks root" "$STC" \
  '`second-brain search <project> "<terms>" --in <tasks_root>`, with `tasks_root` from Step 0.'
line_is "same story: by title, summary and each criterion" "$STC" \
  '  - Search once by the title, once by the Summary and once by each acceptance criterion, in one'
line_is "same story: the searches are chained with ;, so a search with no match stops none" "$STC" \
  '    Bash call, chained with `;` so that a search with no match stops none of the others.'
is "same story: no command of the check is chained with &&" "$(section_of "$STC" '3. Create the story' | grep -c '&&')" "0"
file_has "same story: a search names few terms, as a note must hold each" "$STC" \
  'A note matches only when it holds every term: give each search the 2 or 3 words that name'
file_has "same story: the head of each story found gives its status" "$STC" \
  '`second-brain task head <ID>`, with the folder that holds it'
file_has "same story: a match is by outcome" "$STC" "A story matches when its outcome is the new story's"
file_has "same story: each match is shown with its status" "$STC" 'id, title and status, and the outcome they share.'
file_has "same story: an abandoned story is no match" "$STC" 'Leave out an abandoned one.'
line_is "same story: it lists the open epics the story could join" "$STC" \
  '- List the open epics the story could join, each `planned`, `in-progress` or `in-review` in its'
file_has "same story: the parents of the stories found" "$STC" 'The parent each story the searches found names, on the `epic:` line'
file_has "same story: the epics the planned-releases note lists" "$STC" \
  'Each epic under `## Epics` in `<project path>/<topics_root>/planned-releases.md`'
line_is "same story: a task the searches found is an epic when another task names it" "$STC" \
  '  - Each task the searches found that another task names as its parent:'
file_has "same story: its children's epic lines, with the helper" "$STC" \
  '`second-brain search <project> "\"epic: <ID>\"" --in <tasks_root>`'
file_has "same story: a longer id names another task" "$STC" 'A line with a longer id, such as `epic: <ID>0`, names another task.'
line_is "same story: a refinement story's draft parent is listed" "$STC" \
  '  - For a story from refinement, the parent its approved draft names.'
file_has "same story: it says the project's word" "$STC" '  - Say epic or feature, as Step 0 of `SKILL.md` names it.'
line_is "same story: it proposes one epic, or none, with the reason" "$STC" \
  '- Propose one of them, or none, with the reason: the epic whose outcome the new story serves, or'
file_has "same story: a refinement story's proposal is its approved parent" "$STC" \
  'For a story from refinement, propose the parent its approved draft names'
line_is "same story: the owner picks with AskUserQuestion" "$STC" '- Ask the owner with AskUserQuestion to pick one:'
file_has "same story: pick one, change the story that exists" "$STC" '  - Change the story that exists: show the change to it beside what it says now'
file_has "same story: it names the story that took the new one's place" "$STC" 'say which story took its place, for a refinement to link.'
line_is "same story: a refinement story's place taker moves under the draft's parent" "$STC" \
  '    - A story from refinement whose draft names a parent: the change moves it under that parent,'
file_has "same story: through task set, unless the owner keeps its own parent" "$STC" \
  '`second-brain task set <ID> epic=<parent>`, unless the owner keeps it under its own.'
file_has "same story: it names the parent the story left" "$STC" 'which parent it is under, and the one it left.'
file_has "same story: pick two, file it under an epic" "$STC" \
  '  - File the new one under an epic: write it as the steps below say, with `epic=<ID>` in step 3.'
file_has "same story: pick three, write it on its own" "$STC" \
  '  - Write it on its own: write it as the steps below say, with no `epic`.'
line_is "same story: nothing is written before the pick" "$STC" \
  '- Write nothing, no story, key or note, before the owner picks. No AskUserQuestion, as in a'
file_has "same story: step 3 sets the parent the owner picked" "$STC" \
  'plus `epic=<ID>` when the owner filed it under a parent'
sb help
out_has "same story: the helper's search takes --in, as create.md runs it" 'search <project> "<text>" [--in SUBPATH]'
DSC="$here/docs/contract.md"
line_is "same story: the contract describes the check" "$DSC" \
  '- Then, before it writes a new story, one from refinement too, its start mode shows each open or'
line_is "same story: the contract says the owner picks" "$DSC" \
  '- The owner picks: change the story that exists, file the new one under an epic, or write it on'
ds_ptr="$(linex "$DSC" '  its own. Nothing is written before the owner picks. The check works as')"
is "same story: the contract points to the check's home" "$(sed -n "$((${ds_ptr:-0} + 1))p" "$DSC")" \
  '  `## 3. Create the story` in `skills/story-tracker/create.md` says.'
file_lacks "same story: the contract leaves the search to create.md" "$DSC" 'stories with `second-brain search`, by'
# Defect 2: refinement follows the owner's pick
RFW="$here/skills/scrum-master/refinement.md"
line_is "same story: refinement writes each story with the parent the owner picks" "$RFW" \
  '   as `planned`, with the parent the owner picks.'
line_is "same story: refinement names story-tracker's check" "$RFW" \
  '   - Before it writes, story-tracker shows the owner the stories that do the same and the epics'
file_has "same story: refinement takes the pick as approved" "$RFW" 'That pick is approved: step 5 does not stop for it.'
line_is "same story: refinement, a story that exists in place of a new one" "$RFW" \
  '   - The owner picks a story that exists in its place: story-tracker writes no new one, and names'
file_has "same story: refinement, that story takes the draft's parent" "$RFW" \
  '     that story. Its change sets the draft'"'"'s parent as its `epic`, unless the owner keeps it under'
line_is "same story: refinement, story-tracker names the parent it left, for step 4" "$RFW" \
  '     its own parent. story-tracker names the parent it left, for step 4.'
ds_left='   - A story that left a parent in step 1, for the draft'"'"'s: drop its line from that parent'"'"'s list.'
line_is "same story: refinement drops a story from the list of the parent it left" "$RFW" "$ds_left"
ds_l="$(linex "$RFW" "$ds_left")"
is "same story: refinement drops it in step 4" \
  "$((${ds_l:-0} > $(lineno "$RFW" '4. In each epic'"'"'s list, link each story') && ${ds_l:-0} < $(lineno "$RFW" '5. A step would change the approved text')))" "1"
line_is "same story: the contract drops it from the list of the parent it left" "$DSC" \
  '- A story that leaves its own parent for the draft'"'"'s is dropped from that parent'"'"'s list.'
line_is "same story: refinement, that story stands for the draft's id" "$RFW" \
  '   - From then on that story stands for the draft'"'"'s id: as the parent of the draft'"'"'s stories, in'
file_has "same story: refinement, in step 3 for both ends of each link" "$RFW" \
  'step 3 for the tasks it waits on and for each story that waits on it, and in step 4, once it'
file_has "same story: refinement, in the epic's list once under the draft's parent" "$RFW" \
  'is under the draft'"'"'s parent, in the epic'"'"'s list in place of that id.'
line_is "same story: refinement, a story filed under another parent, or kept under its own" "$RFW" \
  '   - The owner files it under another parent, or none, or keeps the story that exists under its'
file_has "same story: refinement, out of the list of the draft's parent" "$RFW" \
  'own: in step 4, list it under that parent alone, and drop it from the list of the parent the'
line_is "same story: the contract says how refinement follows the pick" "$DSC" \
  '- A story that exists, picked in story-tracker'"'"'s check in place of a new one, takes the draft'"'"'s'
line_is "same story: the contract, it takes the draft's parent as its epic" "$DSC" \
  '  parent as its `epic`, unless the owner keeps it under its own. From then on it stands for the'
line_is "same story: the contract, in the epic's list once under the draft's parent" "$DSC" \
  '  draft'"'"'s id: as a parent, in each `task dep` and, under the draft'"'"'s parent, in the epic'"'"'s list.'
ds_rf="$(linex "$DSC" '- A story filed under another parent, or none, or kept under its own, is listed under that parent')"
is "same story: the contract points to refinement's write" "$(sed -n "$((${ds_rf:-0} + 1))p" "$DSC")" \
  '  alone, as `## 4. Write` in `skills/scrum-master/refinement.md` says.'
line_is "same story: refinement.md has the heading the contract names" "$RFW" '## 4. Write'
file_has "same story: the guide describes the check" "$here/docs/guide.md" \
  '- Before story-tracker writes a new story, yours or one from refinement, it shows each story that'
file_has "same story: the guide points to create.md" "$here/docs/guide.md" \
  'it on its own, as `## 3. Create the story` in `skills/story-tracker/create.md` says.'
CG="$here/CHANGELOG.md"
file_has "same story: the changelog line" "$CG" \
  '- Before story-tracker writes a new story, yours or one from refinement, it searches the project'"'"'s'
file_has "same story: the changelog says refinement follows the pick" "$CG" \
  '- In refinement, a story you pick in place of a new one takes its parent, its links and its line'

# ---------------------------------------------------------------- a story names the one repo it changes
STC="$here/skills/story-tracker/create.md"
line_is "story repo: create.md frames the repo a new story changes" "$STC" \
  '- **Repo** - the one repo the story changes, when `second-brain repo <project>` lists more than'
line_is "story repo: create.md asks which one" "$STC" \
  '  - Ask which one, as `## Story rules` in `SKILL.md` says, with each listed repo as an option.'
line_is "story repo: create.md asks nothing with one repo" "$STC" \
  '  - With one repo listed, or none, ask nothing and write no repo: a story with none takes the'
line_is "story repo: a repo other than the branch check's gets that check again" "$STC" \
  '  - In start mode, the repo settled is not the `repo:` line the branch check printed: run that'
line_is "story repo: with --path, the repo's own path" "$STC" \
  '    check again with `--path "<path>"`, the path `second-brain repo <project> <name>` prints.'
line_is "story repo: that run gives the ref, the branch and the Branch line" "$STC" \
  '    That run gives section 2'"'"'s ref, step 3'"'"'s `branch=` and step 4'"'"'s `**Branch:**` line, and every'
line_is "story repo: and each branch command of the file reads that repo" "$STC" \
  '    `second-brain branch` command of this file takes the same `--path`.'
line_is "story repo: task new takes the repo" "$STC" \
  '   - Add `--repo <name>` with the repo section 1 settled. With one repo listed, or none, no flag.'
line_is "story repo: an unknown repo is asked about" "$STC" \
  '   - Exit 1 with `--repo`: the name is no repo of the project. Show'
is "story repo: the repo is framed in section 1, before the create step that passes it" \
  "$(($(lineno "$STC" '- **Repo** - the one repo') < $(lineno "$STC" '## 2. Verify against the code') && $(lineno "$STC" '## 3. Create the story') < $(lineno "$STC" '   - Add `--repo <name>`')))" "1"
file_has "story repo: the build's repo is the branch check's" "$here/skills/build/story.md" \
  '   - `<repo>` is the `repo:` line `second-brain branch <project> <ID>` prints, with no `--path`:'
RC="$here/docs/contract.md"
line_is "story repo: the contract's task frontmatter has the key" "$RC" \
  'repo: example-api             # optional; the one repo the story changes'
file_has "story repo: the contract says what it names" "$RC" \
  '- `repo` names the one repo the story changes, as `repo <project>` lists it. Its branch check,'
file_has "story repo: the contract's branch row reads it" "$RC" \
  'else the task'"'"'s `repo`, else the profile'"'"'s first.'
file_has "story repo: the contract's task new row takes --repo" "$RC" \
  '| `task new <ID> [--project P] [--title T] [--topics a,b] [--envs] [--repo R]` |'
file_has "story repo: the contract's task set row checks it" "$RC" \
  '`repo` must name a repo that `repo <project>` lists, matched exact first, then without letter case'
file_has "story repo: the contract's task head row prints it" "$RC" \
  'branch, repo (only when set), epic, topics,'
file_has "story repo: the contract's board shows it" "$RC" \
  '- It shows each task'"'"'s `repo` in a `Repo` column, after `branch`, in the `Active`,'
RG="$here/docs/guide.md"
file_has "story repo: the guide describes the key" "$RG" \
  '- A story names the one repo it changes, `repo: <name>`, when the project lists more than one.'
file_has "story repo: the guide points to create.md" "$RG" \
  '`## 1. Lock down the framing` in `skills/story-tracker/create.md` says.'
line_is "story repo: create.md has the heading the guide names" "$STC" '## 1. Lock down the framing'
CG="$here/CHANGELOG.md"
for c in '- A story names the one repo it changes, `repo: <name>`, one of the repos' \
  '- `second-brain branch <project> <ID>` reads the story'"'"'s `repo`, before the profile'"'"'s first. So a' \
  '- story-tracker asks which repo a new story changes when the project lists more than one, and' \
  '- A new board shows each task'"'"'s repo in a `Repo` column, after its branch, in the `Active`,'; do
  file_has "story repo: the changelog: ${c:2:44}" "$CG" "$c"
done

# ---------------------------------------------------------------- subprojects retire, and doctor --fix folds them
RC="$here/docs/contract.md"
for t in '| `subproject <project>' '`scaffold subproject' '[--subproject S]' 'subproject: example-infra' \
  '| project | `subprojects` |' '| project | `task-subproject` |' '### Subprojects' 'subproject.md.tmpl' 'sb_sub_'; do
  file_lacks "retired: the contract has no $t" "$RC" "$t"
done
line_is "retired: the board's views" "$RC" '- Views, by exact name: `Active`, `Current sprint`, `By topic`, `Needs a status`, `All`.'
file_has "retired: the doctor's check of what is left" "$RC" '| project | `retired-subprojects` | a note is left in `claude/subprojects/`'
line_is "retired: the contract says how --fix folds them" "$RC" '### The retired subprojects'
file_has "retired: the doctor row points there" "$RC" \
  'Then it folds each note in `claude/subprojects/` and each task'"'"'s `subproject` key into the project, as `### The retired subprojects` says.'
file_has "retired: a task key goes to the task's repo" "$RC" \
  '  `retired-subprojects` check names each, and `doctor --fix` folds it into the task'"'"'s `repo`.'
file_has "retired: a note's tasks take its one repo" "$RC" '  note with one repo, it takes that repo as the profile spells it,'
file_has "retired: a setting of its own is named, not folded" "$RC" \
  '  `<name>: its <key> <value> is not the profile'"'"'s <value>: not folded, so <note> stays`, with `-`'
line_is "retired: a note's own text outside ## Rules keeps it" "$RC" \
  '- The note'"'"'s own text outside `## Rules` is not folded either, as no other note takes it: each'
file_has "retired: each other section is named" "$RC" '  other section, `<name>: its ## <section> is not folded, so <note> stays`, and any other line'
file_has "retired: the doctor skill says how to settle it" "$here/skills/vault-doctor/checks.md" \
  'a section or a line of the note outside `## Rules`, which the owner moves where it belongs'
file_has "retired: and the changelog says so" "$here/CHANGELOG.md" \
  '  `repo` while the note lists several repos, and a note with text of yours outside `## Rules`,'
file_has "retired: its rules go to claude/README.md" "$RC" '    `## Rules` in `claude/README.md`, under `### <name>` and a line `For work in <repos>:`,'
file_has "retired: its docs folder stays a topic folder" "$RC" '  - Its docs folder stays, a topic folder like any other. Its hub loses the line that began'
line_is "retired: a project's parts are topic folders" "$RC" \
  "- A project's parts, such as its apps or its initiatives, are topic folders it names itself, such"
# The skills, agents, templates, README and guide name no subproject. The doctor's skill alone names
# the check that finds what versions before 0.14.0 left.
named="$(cd "$here" && grep -rli 'subproject' skills agents templates README.md docs/guide.md 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
is "retired: only the doctor's skill names a subproject, for its retired-subprojects check" "$named" \
  "skills/vault-doctor/SKILL.md skills/vault-doctor/checks.md "
is "retired: and each of its lines that does names that check, the folder it finds or the key it drops" \
  "$(grep -hi 'subproject' "$here/skills/vault-doctor/SKILL.md" "$here/skills/vault-doctor/checks.md" | grep -vc 'retired-subprojects\|claude/subprojects/\|subproject=' || true)" "0"
for f in subproject.md.tmpl subproject-docs.md.tmpl; do absent "retired: no template $f" "$here/templates/$f"; done
absent "retired: no subproject library" "$here/scripts/lib/subproject.sh"
RG="$here/docs/guide.md"
file_has "retired: the guide's example topic folders" "$RG" \
  "- A project's parts are topic folders it names itself, such as \`docs/apps/\`, with a folder per"
file_has "retired: and initiatives" "$RG" '  app, or `docs/initiatives/`, with a folder per initiative. A story about one carries its tag,'
line_is "retired: the guide says from which version the conventions note has no spec type" "$RG" \
  '- From version 11 on, the vault'"'"'s conventions note has no `spec` note type and no `delivery`'
file_lacks "retired: and names no version as the current one" "$RG" 'conventions note is at version'
file_has "retired: the README's several repos" "$here/README.md" \
  '- **Several repos.** A project lists its repos, under one ticket key and one board, and each story'
CG="$here/CHANGELOG.md"
for c in '- Subprojects are retired. A project'"'"'s parts, such as its apps or its initiatives, are topic' \
  '- The `subproject` and `scaffold subproject` commands are gone, and so are `task new --subproject`,' \
  '- No command reads a note in `claude/subprojects/` or a task'"'"'s `subproject` key. The doctor'"'"'s new' \
  '- `second-brain doctor --fix` folds each note into its project. It adds the note'"'"'s repos and' \
  '- A setting of a note that is not the profile'"'"'s, such as a `base_branch`, is not folded: `--fix`' \
  '- The conventions note is at version 12: it names a task'"'"'s `repo` key and no subproject. The' \
  '- The plugin'"'"'s index template is now at `index_version: 10`: it names no subproject note, and ties'; do
  line_is "retired: the changelog: ${c:2:44}" "$CG" "$c"
done

# ---------------------------------------------------------------- result
result
