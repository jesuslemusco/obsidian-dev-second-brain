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

# ---------------------------------------------------------------- skills follow the subproject and layout standards
ST="$here/skills/story-tracker/SKILL.md"
STC="$here/skills/story-tracker/create.md"
CL="$here/skills/scrum-master/sprint-planning.md"
file_has "story-tracker create: task new takes the subproject from context" "$STC" 'Add `--subproject <name>` with the name on the `subproject:` line of `second-brain context`'
file_has "story-tracker create: asks when the repo is in no subproject" "$STC" 'ask which one the story is in, or none'
file_has "story-tracker create: a name that is no subproject is asked about" "$STC" 'Exit 1 with `--subproject`: the name is no'
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
line_is "vault-setup subproject: a section on its tasks" "$here/skills/vault-setup/subproject.md" "## 3. Its tasks"
file_has "vault-setup subproject: a task names its subproject" "$here/skills/vault-setup/subproject.md" 'frontmatter, `subproject: <name>`, spelled as the note is named'
file_has "vault-setup subproject: sets it through task set" "$here/skills/vault-setup/subproject.md" '`second-brain task set <ID> subproject=<name>`'
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
file_has "index: a task names its subproject" "$vault/CLAUDE.md" 'to its subproject with the `subproject` property.'
file_has "conventions: the short version names subproject on a task" "$vault/obsidian-conventions.md" '`branch` and `epic`, and `subproject` when it belongs to one.'
file_has "conventions: subproject is spelled as its note" "$vault/obsidian-conventions.md" '`subproject` is the name of the task'"'"'s subproject, spelled as its note'
VD="$here/skills/vault-doctor/SKILL.md"
file_has "vault-doctor fix: --fix repairs three checks" "$VD" 'repairs three checks only'
file_lacks "vault-doctor fix: no longer says two" "$VD" 'repairs two checks only'
file_has "vault-doctor fix: names the checks --fix repairs" "$VD" '`status-tag`, `pull-request` and'
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
is "conventions: the retired spec type and delivery key raise conventions_version to 11" "$cv_version" "11"
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
is "index template: the scrum-master skill raises index_version to 8" "$vi_version" "8"
line_is "contract: the index example is at the template's version" "$here/docs/contract.md" "index_version: $vi_version"
line_is "docs-keeper: a task's place names the status folders" "$DK" \
  '- A task is `<tasks_root>/<ID>/README.md`, `<tasks_root>/<status>/<ID>/README.md` with'
line_is "docs-keeper: in a status project, or archived" "$DK" \
  '  `task_layout: status`, or `<tasks_root>/archive/<YYYY>/<ID>/README.md` once archived.'
CG="$here/CHANGELOG.md"
file_has "changelog: the index template is at version 6" "$CG" 'The plugin'"'"'s index template is now at `index_version: 6`'
is "changelog: the newest section is 0.12.0, unreleased" "$(grep -m1 '^## ' "$CG")" "## 0.12.0 - unreleased"
st_line="$(lineno "$CG" '- A project can keep each task in the folder of its status:')"
st_top="$(lineno "$CG" '## 0.10.0 - ')"
st_end="$(lineno "$CG" '## 0.9.0 - ')"
is "changelog: the status layout is under 0.10.0" \
  "$((${st_line:-0} > ${st_top:-0} && ${st_line:-0} < ${st_end:-0}))" "1"
vi_line="$(lineno "$CG" '- The vault index and docs-keeper name `tasks/<status>/` as a task'"'"'s place')"
is "changelog: the index's status line is under 0.10.0" \
  "$((${vi_line:-0} > ${st_top:-0} && ${vi_line:-0} < ${st_end:-0}))" "1"
sr_line="$(lineno "$CG" '- The search rule warns on a whole Read of a task note in a status folder too.')"
is "changelog: the search rule's status line is under 0.10.0" \
  "$((${sr_line:-0} > ${st_top:-0} && ${sr_line:-0} < ${st_end:-0}))" "1"
cv_line="$(lineno "$CG" '- The conventions note is at version 8: it names the status layout.')"
is "changelog: the conventions note at version 8 is under 0.10.0" \
  "$((${cv_line:-0} > ${st_top:-0} && ${cv_line:-0} < ${st_end:-0}))" "1"
cv_text="$(awk -v n="${cv_line:-0}" 'n && NR == n { t = $0; next } n && NR > n && !d && /^  / { t = t " " substr($0, 3); next } NR > n { d = 1 } END { print t }' "$CG")"
case "$cv_text" in
  *'The doctor'"'"'s `conventions` check warns about an older note.'*) pass "changelog: the version 8 line says the doctor warns on an older note" ;;
  *) fail "changelog: the version 8 line says the doctor warns on an older note" "in: $cv_text" ;;
esac
# under_011 <desc> <line>: the line is in the 0.11.0 section, above 0.10.0.
sp_top="$(lineno "$CG" '## 0.11.0 - ')"
under_011() {
  local n
  n="$(lineno "$CG" "$2")"
  is "$1" "$((${sp_top:-0} > 0 && ${n:-0} > ${sp_top:-0} && ${n:-0} < ${st_top:-0}))" "1"
}
under_011 "changelog: the sprint layout is under 0.11.0" '- A project can keep each task in the folder of its sprint:'
under_011 "changelog: sprint_folder is under 0.11.0" '- `sprint_folder` in the profile names a sprint'"'"'s folder'
under_011 "changelog: the conventions note at version 9 is under 0.11.0" \
  '- The conventions note is at version 9: it names the sprint layout. The doctor'"'"'s `conventions`'
under_011 "changelog: the index's sprint line is under 0.11.0" \
  '- The vault index names the sprint folders as a task'"'"'s place in a sprint project.'
file_has "changelog: the index template is at version 7" "$CG" 'index template is now at `index_version: 7`'
file_has "changelog: set index_version 7 once the task line is copied" "$CG" 'then set `index_version: 7`.'
under_011 "changelog: a pattern with no folder name is under 0.11.0" \
  '  `docs/contract.md` says. A pattern that gives a sprint no folder name makes each command that'
under_011 "changelog: task new and task set in a sprint project are under 0.11.0" \
  '- In a sprint project, `second-brain task new` writes a task into `backlog/`. `task set` with a'
under_011 "changelog: task set's exit 6 is under 0.11.0" \
  'destination or the sprint'"'"'s folder is a task. A status change moves nothing.'
under_011 "changelog: sprint open and sprint close moves are under 0.11.0" \
  '- `sprint open` moves each task it re-points to the new sprint'"'"'s folder. `sprint close` moves each'
under_011 "changelog: done and abandoned tasks stay, under 0.11.0" \
  'done and abandoned tasks stay in the closed sprint'"'"'s folder.'
under_011 "changelog: the lookup in backlog/ and the group folders is under 0.11.0" \
  '- Commands find a task in `backlog/` and in every group folder, in every layout: a folder directly'
under_011 "changelog: task new and task alias refuse backlog, under 0.11.0" \
  '`task new` and `task alias` exit 5 for `backlog`, in any letter case, as they do for `archive`.'
under_011 "changelog: the board's group folder branch is under 0.11.0" \
  '- A new board'"'"'s filters take a task in a group folder. An existing board is not rewritten: in a'
under_011 "changelog: tasks.base:no-sprint-filter is under 0.11.0" \
  '  sprint project, the doctor'"'"'s `board` check warns on one without that branch,'
under_011 "changelog: no-readme and task-location are under 0.11.0" \
  '- The doctor'"'"'s `no-readme` check reads each folder under `backlog/` and a group folder, and'
under_011 "changelog: task-layout's sprint rows are under 0.11.0" \
  '  folder of its sprint or `backlog/` (`<ID>:<folder>`), a `sprint_folder` that gives no folder'
under_011 "changelog: sprint_folder:invalid and task_layout:no-sprints are under 0.11.0" \
  '  name (`sprint_folder:invalid`), `task_layout: sprint` with sprints off (`task_layout:no-sprints`),'
under_011 "changelog: <folder>:<layout> is under 0.11.0" \
  '  and a group folder that holds a task in another layout (`<folder>:<layout>`, as `backlog:flat`).'
under_011 "changelog: doctor --fix in a sprint project is under 0.11.0" \
  '- In a sprint project, `doctor --fix` moves each task to the folder of its sprint, or to'
under_011 "changelog: turning the layout on with doctor --fix once is under 0.11.0" \
  '  `sprint_folder`, set the key, then run `doctor --fix` once.'
under_011 "changelog: the search rule's sprint line is under 0.11.0" \
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
under_011 "changelog: story-tracker asks nothing in a sprint project, under 0.11.0" \
  'Nothing is archived, and story-tracker asks'
under_011 "changelog: the sprint skill and scrum-master, under 0.11.0" \
  'sprint skill and scrum-master say what a sprint project'"'"'s close moves'
under_011 "changelog: docs-keeper names the sprint folders, under 0.11.0" \
  '- docs-keeper names `tasks/backlog/` and the sprint folders as a task'"'"'s place in a sprint'
under_011 "changelog: vault-setup offers the sprint layout, under 0.11.0" \
  '`vault-setup project` and `adopt` offer `task_layout: sprint`'
under_011 "changelog: vault-doctor fix counts a sprint project's moves, under 0.11.0" \
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
under_011 "changelog: the sprint skill's open and plan moves, under 0.11.0" \
  'The sprint skill says the same of `sprint open` and of setting a task'"'"'s sprint in plan.'
under_011 "changelog: doctor --fix removes each empty group folder, under 0.11.0" \
  '  `backlog/` with none, then removes each empty group folder, a status folder too, whether or not'
file_lacks "changelog: doctor --fix: not only the folders a move emptied" "$CG" 'group folder it leaves empty'
file_has "guide: doctor --fix removes each empty group folder" "$GS" \
  'It also removes each empty group folder, a'
line_is "guide: whether or not a move emptied it" "$GS" '  status folder too, whether or not a move emptied it.'
file_lacks "guide: doctor --fix: not only the folders a move emptied" "$GS" 'removes the folders it leaves empty'
under_011 "changelog: a status project's --fix removes each empty group folder, under 0.11.0" \
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
done
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
file_has "implementer: runs its test and the each-task checks before it commits" "$IM" \
  "Before you commit, run your test and the repo's \`each task\` checks, which are quick and run on"
file_has "implementer: the each-task checks through validation run in the worktree" "$IM" \
  '`second-brain validation run "<project>" <repo> --when each-task --path "<worktree>"`. Each row'
file_has "implementer: runs each test and check in the foreground" "$IM" \
  '- Run each test and check in the foreground, with the Bash tool'"'"'s longest timeout:'
line_is "implementer: runs no release check, no user step and no build-wide check" "$IM" \
  '- Run no other check: no `release` check, no user step, and no `each build` check but the one'
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
  "The implementer runs its test and the \`each task\` checks before it commits. You run the checks"
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
file_has "README: the build is test-first" "$RM" '- One `implementer` builds each story test-first and checks its own change. Then a fresh'
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
file_has "README: --fix changes three checks without asking" "$here/skills/vault-doctor/SKILL.md" \
  '`second-brain doctor --fix` repairs three checks only'

# ---------------------------------------------------------------- guide: each rule it points to has a home
GD="$here/docs/guide.md"
line_is "guide: keeps the What to say heading that its links name" "$GD" "## What to say"
for ptr in 'docs/contract.md|## 1. Words and paths' 'docs/contract.md|## 2. The index' \
  'docs/contract.md|## 3. The project' 'docs/contract.md|### Profile frontmatter' \
  'docs/contract.md|### Subprojects' 'docs/contract.md|### Validation' 'docs/contract.md|## 4. A task' \
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
  '- A `delivery` or `spec_home` key in a profile, a subproject note or a task is read by nothing,'
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
file_has "contract: one story and one agent at a time" "$CT" \
  '- **One story at a time.** One story and one agent at a time, never in parallel.'
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
file_has "reviewer: grades each check it runs" "$RV" '   `each build`, and grade each.'
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
qf_line="$(lineno "$here/CHANGELOG.md" '- `reviewer` grades code quality on a failing story too')"
qf_top="$(lineno "$here/CHANGELOG.md" '## 0.12.0 - ')"
qf_end="$(lineno "$here/CHANGELOG.md" '## 0.11.0 - ')"
is "changelog: quality on a failing story is under 0.12.0" \
  "$((${qf_line:-0} > ${qf_top:-0} && ${qf_line:-0} < ${qf_end:-0}))" "1"

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
df_line="$(lineno "$CG" '- `reviewer` sorts each finding as a defect or a follow-up')"
df_top="$(lineno "$CG" '## 0.12.0 - ')"
df_end="$(lineno "$CG" '## 0.11.0 - ')"
is "changelog: the follow-ups are under 0.12.0" \
  "$((${df_line:-0} > ${df_top:-0} && ${df_line:-0} < ${df_end:-0}))" "1"

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
  'a profile `lead_check_minutes` that is not empty, 10, 12, 15, 20, 30 or 60 (`lead_check_minutes:invalid`) (warn).'
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
lc_min="$(awk '/^## 0\.11\.0 - / { on = 1; next } /^## / { on = 0 } on && /[0-9]+ minutes/' "$CG")$(grep -nE '[0-9]+ minutes' "$GD")"
is "the lead's check: the changelog's 0.11.0 lines and the guide name no minutes" "$lc_min" ""
file_lacks "the lead's check: nor in the guide" "$GD" 'The check every'
file_lacks "the lead's check: nor in the contract" "$CT" 'The check every'
cg_top="$(lineno "$CG" '## 0.11.0 - ')"
cg_end="$(lineno "$CG" '## 0.10.0 - ')"
for l in '- A spec build agent that goes idle with no report, such as one that says its checks still run,' \
  '- An idle notice that repeats a reply the skill took already, as a named agent'"${q}"'s last reply comes' \
  '- The skill keeps your open orders of a build in `<project>/claude/lead-agent-task-memory.md`,' \
  '- While an order is open, the skill checks on the agents, the branch and the running checks' \
  '- A profile key, `lead_check_minutes`, sets the pace of that check in one place, as'; do
  n="$(linex "$CG" "$l")"
  is "changelog: under 0.11.0: ${l:2:48}" "$((${n:-0} > ${cg_top:-0} && ${n:-0} < ${cg_end:-0}))" "1"
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
tp_done="$(printf '%s\n' "$tpl" | grep -nP '^\t- Done when: ' | cut -d: -f1)"
tp_now="$(printf '%s\n' "$tpl" | grep -nP '^\t- Now: ' | cut -d: -f1)"
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
dw_line="$(lineno "$CG" '- Each order in `lead-agent-task-memory.md` has a `Done when:` line')"
dw_top="$(lineno "$CG" '## 0.12.0 - ')"
dw_end="$(lineno "$CG" '## 0.11.0 - ')"
is "changelog: the done-when lines are under 0.12.0" "$((${dw_line:-0} > ${dw_top:-0} && ${dw_line:-0} < ${dw_end:-0}))" "1"

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
is "build skill: its text runs git -C, which prompts" "$(grep -c '`git -C "<path>" worktree add' "$BY")" "2"
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
line_is "build skill: one story at a time" "$BS" '- One story at a time, and one agent at a time.'
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
line_is "story build: the implementer's name" "$BY" '  - The build and fix rounds 1 to 3: `name: "<ID>-implementer"`.'
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
line_is "story build: rounds 1 to 3 go to the same implementer" "$BY" \
  '   - `fails` 1 to 3: the same `implementer`. Send the fix message to `<ID>-implementer`, and wait'
line_is "story build: a fresh one gets the fix line too" "$BY" \
  '     `implementer` in its place, with the build'"${q}"'s prompt and the fix message'"${q}"'s first line, its'
line_is "story build: round 4 on the stronger model" "$BY" \
  '   - `fails` 4: launch a fresh `implementer` on the stronger model, named from round 4 on, with'
file_has "story build: the merge waits for the owner's go" "$BY" \
  '4. The merge: say that `<branch>` passed its review and waits for the owner'"${q}"'s go to merge, as the'
line_is "story build: and merges nothing" "$BY" \
  '   project'"${q}"'s git flow says. Merge nothing here: a merge is an outside effect, item 3 of'
bm6="$(lineno "$BY" '4. The merge: say that')"
bm7="$(lineno "$BY" '5. Remove the worktree.')"
is "story build: the worktree goes after the merge step" "$(( ${bm6:-0} > 0 && ${bm6:-0} < ${bm7:-0} ))" "1"
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
file_has "implementer: runs the each-task checks in the worktree" "$IM" \
  '`second-brain validation run "<project>" <repo> --when each-task --path "<worktree>"`.'
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
file_has "reviewer: story mode runs the each-build checks" "$RV" '   the checks with `--when each-build`, and each user step whose `when:` is `each task` or'
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
file_has "contract: a passed story waits for the owner's go" "$CT" '- A passed story waits for the owner'"${q}"'s go to merge, as the project'"${q}"'s git flow says: the skill'
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
bk_line="$(lineno "$CG" '- A new `build` skill builds approved stories')"
bk_top="$(lineno "$CG" '## 0.12.0 - ')"
bk_end="$(lineno "$CG" '## 0.11.0 - ')"
is "changelog: the build skill is under 0.12.0" "$(( ${bk_line:-0} > ${bk_top:-0} && ${bk_line:-0} < ${bk_end:-0} ))" "1"

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
file_has "contract: the worktree goes as soon as the story passed" "$CT" \
  '  merges nothing. It removes the worktree as soon as the story passed, with `git worktree remove`,'
file_has "guide: the worktree goes once the story passed" "$GD" '- Once a story passed, its worktree is removed, after Claude shows you any ignored file in it,'
# A session cut off before the removal ends it next time.
file_has "build skill: an in-review story with its worktree left ends the build" "$BS" \
  '- An `in-review` story with a `Build: finished` note whose worktree is still there, on its branch'
file_has "build skill: reads story.md, then removes the leftover worktree" "$BS" \
  '  `story.md` names them: its session ended before the worktree went. Read `story.md`, then'
line_is "build skill: by item 5 alone, and back to Step 1" "$BS" \
  '  remove the worktree as item 5 of `## 6. When the story passed` says, and go on with Step 1.'
file_lacks "build skill: never jumps out of Step 1 to the next story" "$BS" 'items 5 to 7 of'
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
under_011 "changelog: the child folders are under 0.11.0" \
  '- In a status or sprint project, a child task, one whose `epic` names another task, sits inside a'
under_011 "changelog: epic= moves a child is under 0.11.0" \
  '- `task set <ID> epic=<parent>` moves a child into that folder, and `epic=` moves it out. A status'
under_011 "changelog: parent_label is under 0.11.0" \
  '- `parent_label` in the profile names a project'"'"'s parent stories `feature`, or `epic` with no key.'
under_011 "changelog: the board's child branch is under 0.11.0" \
  '- A new board'"'"'s filters take a task one level deeper. An existing board is not rewritten: in a'
under_011 "changelog: the conventions note at version 10 is under 0.11.0" \
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
under_011 "changelog: the folder named for a task is under 0.11.0" \
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
is "scrum-master: SKILL.md and the four workflow files" "$(ls "$SMD" | tr '\n' ' ')" \
  "SKILL.md organize-board.md refinement.md release-planning.md sprint-planning.md "
file_has "scrum-master: SKILL.md gives the path of story-tracker's create.md" "$SMS" '`${CLAUDE_PLUGIN_ROOT}/skills/story-tracker/create.md`'
file_has "scrum-master: a ticket goes to the story-tracker skill" "$SMS" 'skill, with the Skill tool as `odsb:story-tracker`.'
file_lacks "scrum-master: no daily status" "$SMS" 'daily status'
is "story-tracker: SKILL.md and its three files" "$(ls "$STD" | tr '\n' ' ')" "SKILL.md create.md env-split.md status.md "
file_has "story-tracker: the start row takes refinement's stories" "$STS" \
  'or the scrum-master'"'"'s refinement hands over a story the owner approved |'
line_is "story-tracker: it may edit notes and run ls -d" "$STS" \
  'allowed-tools: Read Grep Glob Edit Bash(second-brain *) Bash(ls -d *)'
line_is "scrum-master: it may edit and write notes, call story-tracker with an id and run ls -d" "$SMS" \
  'allowed-tools: Read Grep Glob Edit Write Skill(odsb:story-tracker *) Bash(second-brain *) Bash(ls -d *)'
# The commands the two skills' text runs, other than the helper: ls -d has a pattern, git -C has
# none and prompts, as a -c setting before its subcommand can run a program. Read line by line, so
# no glob in a command expands.
seen_ls=0
seen_git=0
while IFS= read -r c; do
  case "$c" in
    'ls -d '*) seen_ls=1 ;;
    'git -C '*) seen_git=1 ;;
  esac
done <<CMDS
$(cat "$STD"/*.md "$SMD"/*.md | grep -oE '`(git -C|ls -d) [^`]*`' | tr -d '`')
CMDS
is "allowed-tools: the skills' text runs ls -d" "$seen_ls" "1"
is "allowed-tools: the skills' text runs git -C" "$seen_git" "1"
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
line_is "vault-setup: asks nothing for achievements_skill" "$here/skills/vault-setup/SKILL.md" \
  '   - Ask nothing for `achievements_skill`. When the profile lacks it, write'
line_is "vault-setup: writes it empty" "$here/skills/vault-setup/SKILL.md" \
  '     `achievements_skill: ""`: no skill reads it until the plugin'"'"'s achievements skill, which is'
file_lacks "vault-setup: no interview row for achievements_skill" "$here/skills/vault-setup/SKILL.md" '| `achievements_skill` |'
line_is "refinement: asks for the approval without showing the draft again" "$here/skills/scrum-master/refinement.md" \
  '  `create.md` says, without showing the draft again.'
file_has "contract: a story that refinement got approved gets the note too" "$here/docs/contract.md" \
  '- Every story whose text the owner approved, in start mode or in refinement, gets the status note'
line_is "profile template: achievements_skill waits for the achievements skill" "$here/templates/profile.md.tmpl" \
  '- `achievements_skill:` waits for the plugin'"'"'s achievements skill, which is planned. No skill'
file_lacks "profile template: no story is handed to it" "$here/templates/profile.md.tmpl" 'hand it to'
file_has "contract: only an achievements skill tracks achievements" "$here/docs/contract.md" \
  '  reads it until then. Only that skill tracks achievements.'
file_has "contract: a close with no sprint stops" "$here/docs/contract.md" \
  '- A request to close the sprint goes to its close. With no sprint in progress, it says so and'
file_lacks "README: no achievement is logged" "$here/README.md" 'achievement'
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
line_is "index template: still at version 8, unreleased" "$here/templates/vault-index.md.tmpl" 'index_version: 8'
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
cg12_top="$(lineno "$CG" '## 0.12.0 - unreleased')"
cg12_end="$(lineno "$CG" '## 0.11.0 - ')"
# under_012 <desc> <line>: the line is in the 0.12.0 section, above 0.11.0.
under_012() {
  local n
  n="$(lineno "$CG" "$2")"
  is "$1" "$((${cg12_top:-0} > 0 && ${n:-0} > ${cg12_top:-0} && ${n:-0} < ${cg12_end:-0}))" "1"
}
under_012 "changelog: the scrum-master skill is under 0.12.0" \
  '- The `scrum-master` skill replaces the `sprint` skill and the `scrum-master` agent. It has four'
under_012 "changelog: /odsb:sprint moved to sprint-planning, under 0.12.0" '- `/odsb:sprint` is now `/odsb:scrum-master sprint-planning`'
under_012 "changelog: refinement is under 0.12.0" '- `refinement` drafts or refines an epic and its stories'
under_012 "changelog: release-planning is under 0.12.0" '- `release-planning` sets a release'"'"'s goals, epics and stories with you'
under_012 "changelog: organize-board is under 0.12.0" '- `organize-board` is the agent'"'"'s hygiene pass'
under_012 "changelog: no daily status, under 0.12.0" '- The daily status is gone.'
under_012 "changelog: story-tracker's approval, under 0.12.0" '- story-tracker'"'"'s start mode shows a new story'"'"'s text'
under_012 "changelog: no achievements logged, under 0.12.0" '- story-tracker and the sprint close no longer log achievements'
under_012 "changelog: a close with no sprint stops, under 0.12.0" '- A sprint close asked for with no sprint in progress says so and stops.'
under_012 "changelog: the skills' tools, under 0.12.0" '- The scrum-master skill may edit and write notes and call story-tracker with no prompt, and'
under_012 "changelog: index_version 8 is under 0.12.0" 'template is now at `index_version: 8`'
under_012 "changelog: set index_version 8, under 0.12.0" 'then set `index_version: 8`.'

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
sp_new="$(awk '/^## / { on = ($0 ~ / - unreleased$/); next } on' "$here/CHANGELOG.md" | grep -nE -- "$sp_re")"
is "spec flow: nor does the changelog outside its released sections" "$sp_new" ""
sp_old="$(awk '/^## / { on = ($0 !~ / - unreleased$/); next } on' "$here/CHANGELOG.md" | grep -cE -- "$sp_re")"
is "spec flow: the released sections keep their history" "$((sp_old > 0))" "1"
dl_hits="$(cd "$here" && grep -rnw -- 'delivery' skills agents hooks templates bin scripts/lib 2>/dev/null |
  grep -v 'is not read' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#')"
is "spec flow: no skill, agent, template or helper reads a delivery key, and the one that names it says so" "$dl_hits" ""
CG="$here/CHANGELOG.md"
sp_top="$(lineno "$CG" '## 0.12.0 - ')"
sp_end="$(lineno "$CG" '## 0.11.0 - ')"
for l in '- The spec flow is retired, so there is one flow to learn: the `build` skill builds every approved' \
  '- A vault with specs moves on as it is. A story'"'"'s `spec/` folder and `build.json` stay in its task' \
  '- To build a story you started from a spec, bring what its spec settled into the README'"'"'s' \
  '- The doctor'"'"'s `delivery` check is now `settings`: it names a `validation_home` or a'; do
  n="$(linex "$CG" "$l")"
  is "changelog: under 0.12.0: ${l:2:48}" "$((${n:-0} > ${sp_top:-0} && ${n:-0} < ${sp_end:-0}))" "1"
done
file_has "contract: an old spec folder and build.json stay as plain files of the task" "$here/docs/contract.md" \
  '  retired spec flow wrote, before 0.12.0, stay there as plain files of the task.'
file_has "contract: the delivery and spec_home keys are no keys" "$here/docs/contract.md" \
  '- `delivery` and `spec_home` are no keys of the profile, a subproject'"'"'s note or a task. Versions'

# ---------------------------------------------------------------- result
result
