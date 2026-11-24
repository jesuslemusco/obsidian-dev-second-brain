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
file_has "sprint: its rules send a request to write a ticket to story-tracker" "$here/skills/sprint/SKILL.md" "goes to the story-tracker skill in \`draft\` mode"
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
file_has "sprint close: reports done tasks with unticked docs through the helper" "$here/skills/sprint/close.md" '`second-brain task docs <done ids> --project <project>`'
file_lacks "sprint close: no Grep" "$here/skills/sprint/close.md" 'Grep'
file_has "scrum-master: carries docs-keeper as an action for the caller" "$here/agents/scrum-master.md" 'start `docs-keeper` Workflow 5 for <ID>, <README path>'
file_has "sprint close: does not start docs-keeper" "$here/skills/sprint/close.md" 'Do not start it here: the close only reports.'
file_has "scrum-master: still does not spawn docs-keeper" "$here/agents/scrum-master.md" 'Do not spawn it.'
file_has "index: names a ticket marked done for docs-keeper" "$vault/CLAUDE.md" '`docs-keeper` for docs that follow the code and for a ticket marked done.'

# ---------------------------------------------------------------- skills follow the subproject and layout standards
ST="$here/skills/story-tracker/SKILL.md"
STC="$here/skills/story-tracker/create.md"
CL="$here/skills/sprint/close.md"
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
is "sprint close: the archive question comes after the achievements and before the report" \
  "$(($(lineno "$CL" '8. Run `second-brain profile') < $(lineno "$CL" '9. `task_layout: archive`') && $(lineno "$CL" '9. `task_layout: archive`') < $(lineno "$CL" '10. Report the summary')))" "1"
file_has "sprint: its rules allow task archive after a yes at close" "$here/skills/sprint/SKILL.md" 'a yes at close, `second-brain task archive`'
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
file_has "scrum-master: a story's path comes from task head" "$here/agents/scrum-master.md" 'path from the `path:` line of `second-brain task head <ID> --project <project>`'
file_has "scrum-master: the close's archive answer is the user's" "$here/agents/scrum-master.md" 'archive the sprint'"'"'s done tasks; that answer is the user'"'"'s too.'
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
SM="$here/agents/scrum-master.md"
line_is "scrum-master: a status project's close moves the abandoned tasks" "$SM" \
  '- With `task_layout: status`, the close moves each task it abandons into `abandoned/` and asks'
line_is "scrum-master: a taken folder is the user's, and a closed sprint is not closed again" "$SM" \
  '  nothing. A taken `abandoned/<ID>` folder is the user'"'"'s to clear, and a sprint that closed is'
line_is "scrum-master: never closed twice" "$SM" \
  '  never closed again.'
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
is "conventions: the child folders raise conventions_version to 10" "$cv_version" "10"
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
is "index template: the sprint folders raise index_version to 7" "$vi_version" "7"
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
  'tell. Then it writes `<project>/tasks/EX-123/README.md`, or `<project>/tasks/planned/EX-123/README.md`'
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
SM="$here/agents/scrum-master.md"
line_is "scrum-master: a sprint project's close moves the carried and backlog tasks" "$SM" \
  '- With `task_layout: sprint`, the close moves each carried task to the next sprint'"'"'s folder and'
file_has "scrum-master: done and abandoned tasks stay" "$SM" 'Done and abandoned tasks stay in the'
file_has "scrum-master: a taken destination or a bad pattern is the user's" "$SM" \
  'A taken destination, or a `sprint_folder` that gives the next sprint no'
CL="$here/skills/sprint/close.md"
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
cl_sp5="$(lineno "$CL" '   - Exit 5 that names the `sprint_folder` pattern')"
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
SP="$here/skills/sprint/SKILL.md"
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
line_is "sprint plan: task set moves the folder in a sprint project" "$SP" \
  '   - With `task_layout: sprint`, each call also moves the task'"'"'s folder, to the sprint'"'"'s folder or'
line_is "sprint plan: exit 6 there, as in open" "$SP" \
  '   - Exit 6 there, as in open: the destination is taken, or the sprint'"'"'s folder is a task, and'
line_is "sprint plan: a failed move keeps the sprint written" "$SP" \
  '   - A move that fails exits as `second-brain move` does, with the sprint written:'
sp_o6="$(lineno "$SP" '6. Run `second-brain sprint open')"
sp_oe6="$(lineno "$SP" '   - Exit 6 with `the destination exists: <path>`')"
sp_o7="$(lineno "$SP" '7. Report the note it created')"
sp_omv="$(lineno "$SP" '   - With `task_layout: sprint`, each re-pointed task')"
sp_o8="$(lineno "$SP" '8. A goal given or changed later')"
sp_p5="$(lineno "$SP" '5. Set each answer:')"
sp_pmv="$(lineno "$SP" '   - With `task_layout: sprint`, each call also moves')"
sp_p6="$(lineno "$SP" '6. A task that does not exist yet')"
is "sprint open: the exits are under step 6 and the moves under step 7" \
  "$((${sp_o6:-0} < ${sp_oe6:-0} && ${sp_oe6:-0} < ${sp_o7:-0} && ${sp_o7:-0} < ${sp_omv:-0} && ${sp_omv:-0} < ${sp_o8:-0}))" "1"
is "sprint plan: the moves are under step 5" "$((${sp_p5:-0} < ${sp_pmv:-0} && ${sp_pmv:-0} < ${sp_p6:-0}))" "1"
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

# ---------------------------------------------------------------- the spec skill and its agents
SK="$here/skills/spec/SKILL.md"
sk_desc="$(sed -n 's/^description: //p' "$SK")"
is "spec skill: the description is under 200 characters" "$((${#sk_desc} < 200))" "1"
case "$sk_desc" in *"spec-driven"*) pass "spec skill: the description names spec-driven" ;; *) fail "spec skill: the description names spec-driven" "in: $sk_desc" ;; esac
file_has "spec skill: carries the conventions pointer" "$SK" 'Conventions: before writing notes, run `second-brain conventions`'
file_has "spec skill: its first tool call is the context" "$SK" 'Your first tool call is `second-brain context`'
file_has "spec skill: an inherited spec becomes the story's own delivery" "$SK" \
  '5. `delivery: spec`: run `second-brain task set <ID> delivery=spec`. A value that came from the'
file_has "spec skill: so story-tracker never weighs it" "$SK" \
  'subproject or the profile becomes the story'"'"'s own, so story-tracker never weighs it.'
file_lacks "README: no longer says the profile decides a spec" "$here/README.md" \
  'or set `delivery: spec` in'
for ph in requirements design tasks; do
  file_has "spec skill: the $ph approval note" "$SK" "Spec: $ph approved by the owner."
done
file_has "spec skill: asks the owner with AskUserQuestion" "$SK" "Ask with AskUserQuestion whether to approve the phase"
file_has "spec skill: never builds before the tasks are approved" "$SK" "Never start the build before the tasks approval note is written."
for a in implementer reviewer spec-checker; do
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
SC="$here/agents/spec-checker.md"
line_is "spec-checker: reads, and has no tool that writes" "$SC" "tools: Read, Glob, Grep"
line_is "spec-checker: runs on opus" "$SC" "model: opus"
for g in 'a requirement or design heading a task names that the files lack.' 'a requirement no task meets.' \
  'a task that needs a later one.'; do
  line_is "spec-checker: a tasks.md gap, $g" "$SC" "- In \`tasks.md\`: $g"
done
file_has "spec-checker: its prompt is the spec files' paths alone" "$SC" \
  'Your prompt is the paths of'
file_has "spec-checker: reads nothing but those files" "$SC" \
  '- Read nothing else: not the story, not the code, not another file in the folder.'
file_has "spec-checker: a vague task check is a gap" "$SC" \
  'a task with no `- Check: <command or step> - expected: <what it prints or shows>`'
file_has "spec-checker: reports one line per gap" "$SC" \
  '- One line per gap: `- <file> > <heading> - <what an agent could not build> - <a question>`.'
file_has "spec-checker: says when there is no gap" "$SC" 'No gap: reply `No gaps.` and nothing else.'
file_has "spec-checker: proposes no fix" "$SC" '- Propose no fix: the caller closes each gap with the owner.'
line_is "spec-checker: writes nothing" "$SC" "- Write nothing, anywhere."
PH="$here/skills/spec/phases.md"
file_has "spec phases: one question per AskUserQuestion call" "$PH" \
  '- Ask one question at a time: one question per AskUserQuestion call. Wait for its answer.'
file_has "spec phases: the draft in chunks of 200 to 300 words" "$PH" \
  '- Show the draft in chunks of about 200 to 300 words'
file_has "spec phases: each chunk asks what is wrong or missing, as plain text" "$PH" \
  "- End each chunk with the line \`What's wrong or missing?\` as plain text, not an AskUserQuestion"
line_is "spec phases: then stops for the owner's answer" "$PH" "  call. Then stop for the owner's answer."
line_is "spec phases: the check runs once the last chunk's fixes are written" "$PH" \
  'For design and tasks, once the owner has answered the last chunk and its fixes are written:'
line_is "spec phases: approval only after the last chunk" "$PH" "- Ask for the approval only after the last chunk."
file_has "spec phases: each task check names its expected result" "$PH" \
  '`- Check: <command or step> - expected: <what it prints or shows>`.'
file_has "spec phases: a vague check is rewritten with the owner" "$PH" \
  '- A check with no command or step, or no expected result, is vague: rewrite it with the owner.'
line_is "spec phases: the spec check has a section" "$PH" "## The spec check"
file_has "spec phases: launches spec-checker" "$PH" '1. Launch `odsb:spec-checker` with the Agent tool.'
line_is "spec phases: the design check reads requirements and design" "$PH" \
  '   - Design: `requirements.md` and `design.md`.'
line_is "spec phases: the tasks check reads all three files" "$PH" \
  '   - Tasks: `requirements.md`, `design.md` and `tasks.md`.'
file_has "spec phases: shows the owner the gaps" "$PH" '3. Show the owner the gaps, numbered, as it wrote them.'
file_has "spec phases: closes each gap with the owner" "$PH" \
  '4. Close each gap with the owner, and write the answer in the phase file.'
line_is "spec phases: a gap the owner rejects is left" "$PH" '   - The owner says a gap is not one: leave it.'
line_is "spec phases: a gap in an approved phase reopens it" "$PH" \
  '   - A gap in an approved phase: write `Spec: <phase> reopened.` as a status note, then go back to'
line_is "spec phases: and goes back to that phase" "$PH" '     that phase.'
line_is "spec skill: a change at approval is shown, then asked again" "$SK" \
  '   - A change: make it, show the changed chunk, then ask again.'
file_has "spec skill: asks as the chat rules say" "$SK" 'Ask as `## The chat` in `phases.md` says.'
file_has "spec skill: shows the phase in chunks" "$SK" \
  '4. Show the owner the path, then the phase in chunks, as `## The chat` in `phases.md` says.'
file_has "spec skill: spec-checker reads design and tasks before approval" "$SK" \
  '5. Design and tasks: have `spec-checker` read the spec, and close its gaps with the owner, as'
line_is "spec tasks template: the check names its expected result, and who runs it" "$here/templates/spec-tasks.md.tmpl" \
  '  - Check: <The command or step the implementer and the reviewer run.> - expected: <What it prints or shows.>'
line_is "contract: spec-checker and its tools" "$here/docs/contract.md" \
  '| `spec-checker` | Read, Glob, Grep | reads the spec files it is given and lists what it could not build from them; writes nothing |'
line_is "contract: a task check names its expected result" "$here/docs/contract.md" \
  '  `- Check: <command or step> - expected: <what it prints or shows>`.'
file_has "README: lists spec-checker" "$here/README.md" \
  '| `spec-checker` | Reads a spec alone, as a fresh build agent would, and lists what it could not build from it. Writes no file. |'
file_has "changelog: names spec-checker" "$here/CHANGELOG.md" \
  'the new `spec-checker` agent reads the spec'
file_has "validation template: each user step names its tool" "$here/templates/validation-repo.md.tmpl" \
  "- <One line per step that uses the change as a user does: its tool, then what to look for, then when it runs.>"
file_has "validation template: a tool is a skill, a command, an API call or a query" "$here/templates/validation-repo.md.tmpl" \
  "a skill by name, such as a browser-testing skill, a command, an API call or a query."
file_has "reviewer: runs each user step with the tool its line names" "$here/agents/reviewer.md" "that runs it. Run the step with that tool."
file_has "reviewer: a skill runs through the Skill tool" "$here/agents/reviewer.md" "- A skill: call it with the Skill tool"
file_has "reviewer: a step whose tool it cannot run is BLOCKED and names the tool" "$here/agents/reviewer.md" "found, is BLOCKED. Name the tool."
file_has "reviewer: screenshots go in a temp folder outside the repo" "$here/agents/reviewer.md" "make one temp folder outside the repo with \`mktemp -d\`"
file_has "reviewer: names the screenshots folder" "$here/agents/reviewer.md" '- With browser steps, add `"screenshots": "<folder>"`: the temp folder that holds them.'
file_has "reviewer: keeps step 0's status output" "$here/agents/reviewer.md" "Keep the \`status --porcelain\` output: the user steps are checked against it."
file_has "reviewer: removes only an untracked path step 0 did not list" "$here/agents/reviewer.md" "Remove only an untracked (\`??\`) path that step 0's output did not list, and name it."
file_has "reviewer: a tracked file a step changed is a finding, never deleted" "$here/agents/reviewer.md" "A tracked file a step changed is a finding. Never delete it."
file_has "reviewer: never resets the owner's work" "$here/agents/reviewer.md" "Never run \`git checkout\`, \`restore\`, \`reset\`, \`clean\` or \`stash\`."
file_has "reviewer: a line with no tool runs with Bash only when Bash can do it" "$here/agents/reviewer.md" "run it with Bash when Bash can do what it says."
file_has "reviewer: a browser line with no tool is BLOCKED" "$here/agents/reviewer.md" "A line that needs a browser and names no tool is BLOCKED. Name the step and ask for its tool."
file_has "vault-setup: drafts each user step's tool from the repo" "$here/skills/vault-setup/validation.md" "Draft the tool from the repo"
BM="$here/skills/spec/build.md"
file_has "spec build: the packet is the implementer's whole context" "$BM" "The packet is the implementer's whole context."
file_has "spec build: only a reviewer's pass ticks a task" "$BM" 'Only a reviewer'"'"'s PASS, read from its JSON block, ticks a task.'
line_is "spec build: the baseline comes first" "$BM" "## 4. The baseline"
is "spec build: the baseline before the builds" "$(($(lineno "$BM" '## 4. The baseline') < $(lineno "$BM" '## 5. Each task in turn')))" "1"
file_lacks "spec build: no longer two retries" "$BM" "At most two retries"
file_has "reviewer: a step not run is never a pass" "$here/agents/reviewer.md" "A step that could not be run is never a PASS."
file_has "implementer: never the vault or tasks.md" "$here/agents/implementer.md" 'Never the vault, the spec files or `tasks.md`'
file_has "spec phases: every task's packet must build, unprinted" "$here/skills/spec/phases.md" 'Run `second-brain spec packet <ID> T<n> >/dev/null` for every task.'
file_has "spec phases: never prints a packet" "$here/skills/spec/phases.md" '- Never print a packet here: the agents fetch their own.'
file_has "spec phases: a task names what it provides" "$here/skills/spec/phases.md" 'adds `- Provides: <signatures>` lines'
file_has "spec phases: a task names the tasks it uses" "$here/skills/spec/phases.md" 'adds one line, `- Uses: T1, T2`. Its packet then holds those'
file_has "spec skill: writes each phase in this session" "$here/skills/spec/SKILL.md" "write the phase yourself, in this session"
file_has "spec skill: reads only what the session lacks" "$here/skills/spec/SKILL.md" "Read only what this session does not have yet"
file_has "spec skill: asks what the story and the code do not settle" "$here/skills/spec/SKILL.md" "what the story and the code do not settle, before you"
file_has "spec phases: never the whole repo" "$here/skills/spec/phases.md" "and what they call. Not the whole"
if [ -e "$here/agents/spec-writer.md" ]; then fail "spec-writer: the agent is gone"; else pass "spec-writer: the agent is gone"; fi
ST="$here/skills/story-tracker/SKILL.md"
file_has "story-tracker: weighs a story when work starts" "$ST" \
  'Weigh how a story is built when work starts on it: in start mode once the story exists, or on a'
file_has "story-tracker: its own delivery is the key in its frontmatter" "$ST" \
  "A story has its own \`delivery\` when its README's frontmatter sets the key to \`direct\` or"
file_has "story-tracker: the spec command does not tell where delivery comes from" "$ST" \
  '`second-brain spec <ID>` cannot tell: its `delivery` line may come from the subproject or the'
file_lacks "story-tracker: no longer reads the delivery that holds" "$ST" 'Read its `delivery` line'
file_has "story-tracker: a story with its own delivery is never weighed again" "$ST" \
  'A story with its own `delivery` is never weighed again.'
file_has "story-tracker: its own spec offers the spec skill" "$ST" \
  '`spec`: say the story is built from a spec and offer `/odsb:spec <ID>`.'
file_has "story-tracker: a delivery the owner names is written, not weighed" "$ST" \
  'The owner says how to build it, such as "spec-driven": write it with'
file_has "story-tracker: an approved spec note makes a story spec" "$ST" \
  '- A story with a `Spec: <phase> approved by the owner.` status note is `spec`: its spec was'
file_has "story-tracker: that story's spec key is written" "$ST" \
  '  - Write `second-brain task set <ID> delivery=spec`, then go on as for a story with its own'
file_has "story-tracker create: start mode reaches the weighing" "$STC" \
  '6. Weigh how the story is built, as `## Spec-driven stories` in `SKILL.md` says.'
file_has "story-tracker: a spec helps a big, unclear or unattended story" "$ST" \
  'Spec-driven: the story is big, unclear, or meant to run without the owner.'
file_has "story-tracker: gives the signs of a spec" "$ST" \
  'Signs: many files or repos, open questions in the criteria, a long unattended build.'
file_has "story-tracker: a simple story is set direct with no question" "$ST" \
  'Weighed direct: run `second-brain task set <ID> delivery=direct` and ask nothing. Say so in one'
line_is "story-tracker: it says so in one line, with the reason" "$ST" '  line, with the reason.'
file_has "story-tracker: a spec story is described in three lines" "$ST" \
  'describe the story in at most three lines: what it changes, what it'
file_has "story-tracker: the description names what it touches and the criteria" "$ST" \
  'touches and how many criteria it has. Then say why a spec helps.'
file_has "story-tracker: the owner is asked" "$ST" \
  'Ask the owner with AskUserQuestion: `spec` or `direct`.'
file_has "story-tracker: the answer is written" "$ST" \
  'Write the answer with `second-brain task set <ID> delivery=<answer>`.'
line_is "story-tracker: an answered spec offers the spec skill" "$ST" \
  '  - `spec`: offer `/odsb:spec <ID>`.'
line_is "story-tracker: direct goes on" "$ST" '  - `direct`: go on here.'
file_has "conventions: a task's delivery is set when work starts" \
  "$here/templates/obsidian-conventions.md.tmpl" \
  '  - `delivery` - `spec` or `direct`, how the story is built, set when work starts on it.'
file_lacks "guide: the profile's delivery is no default" "$here/docs/guide.md" \
  "A project's default, and where"
file_has "contract: an inherited delivery is what spec falls back to" "$here/docs/contract.md" \
  '- A value a story inherits from its subproject or the profile is what `spec <ID>` and the `spec`'
file_has "contract: story-tracker weighs a story with no delivery of its own" \
  "$here/docs/contract.md" \
  '- When work starts on a story with no `delivery` of its own, `story-tracker` weighs it and'
file_has "contract: points to the weighing in story-tracker" "$here/docs/contract.md" \
  'the story'"'"'s own, as `## Spec-driven stories` in `skills/story-tracker/SKILL.md` says.'
st_desc="$(sed -n 's/^description: //p' "$ST")"
st_check="story-tracker: the description leaves spec requests to the spec skill"
case "$st_desc" in
  *[Ss][Pp][Ee][Cc]*) fail "$st_check" "in: $st_desc" ;;
  *) pass "$st_check" ;;
esac
file_has "guide: the spec request is under What to say" "$here/docs/guide.md" '| Implement EX-2 spec-driven, starting with its requirements. | `spec` |'
file_has "e2e: asks the same spec request" "$here/scripts/e2e-claude.sh" '"Implement EX-2 spec-driven, starting with its requirements."'

# ---------------------------------------------------------------- the build runs in the owner's session
lead="spec""-lead"
absent "$lead: the agent is gone" "$here/agents/$lead.md"
named="$(cd "$here" && find . -type f -not -path './.git' -not -path './.git/*' -not -path './.scratch/*' -not -path './tmp/*' \
  -not -path './.omc/*' -not -path './.claude/*' -not -name CHANGELOG.md -exec grep -lF -- "$lead" {} + 2>/dev/null)"
is "$lead: no file but CHANGELOG.md names it" "$named" ""
file_has "changelog: says $lead is gone" "$here/CHANGELOG.md" "The \`$lead\` agent is gone."
is "spec skill: SKILL.md stays a short router" "$(($(lines "$(cat "$SK")") <= 90))" "1"
file_has "spec skill: reads build.md only when a build starts" "$SK" \
  '`${CLAUDE_SKILL_DIR}/build.md` once, when a build starts or resumes, and follow it.'
file_lacks "spec skill: holds no build step" "$SK" 'spec status <ID> <task>'
file_lacks "spec skill: launches no build agent" "$SK" 'odsb:implementer'
exists "spec build: the build has its own file" "$BM"
file_has "spec build: launches one agent at a time with the Agent tool" "$BM" \
  '- Launch one agent at a time with the Agent tool, and wait for its result. Its result is its'
file_has "spec build: takes each report from the result, relays nothing" "$BM" \
  'report: never relay a report by hand, and never read an agent'"'"'s transcript.'
file_has "spec build: names the implementer's model" "$BM" '- `odsb:implementer`: `model: "opus"`.'
line_is "spec build: the stronger model from fix round 4 on" "$BM" \
  '  - `odsb:implementer` from fix round 4 on: `model: "fable"`, the stronger model.'
line_is "spec build: names the reviewer's model" "$BM" '  - `odsb:reviewer` in task, baseline or user mode: `model: "opus"`.'
line_is "spec build: the branch review on the most capable model" "$BM" \
  '  - `odsb:reviewer` in branch mode: `model: "fable"`, the most capable model.'
line_is "spec build: names the implementer for the build" "$BM" \
  '  - The build and fix rounds 1 to 3: `name: "<ID>-<task>-implementer"`.'
line_is "spec build: and from fix round 4 on" "$BM" '  - From fix round 4 on: `name: "<ID>-<task>-implementer-2"`.'
file_has "spec build: never prints a packet" "$BM" 'Never run `spec packet` here, and never put a packet, a diff or'
for l in '  - `Story: <ID>, project <project>.`' '  - `Task: <task>.`' '  - `Session: <session id>.`' \
  '  - Last, the commit line: `Commit it as "<ID> <task>: <title>".`' \
  '  - `Fix: the review of <task> failed. Fetch your packet again: its ## Issues lists the findings.`'; do
  line_is "spec build: the implementer's prompt line ${l#  - }" "$BM" "$l"
done
file_has "spec build: the fix message goes with SendMessage, by name" "$BM" \
  '- The fix message, sent with SendMessage to an `implementer` by its name, one line each:'
file_has "spec build: the branch review starts from the build's start" "$BM" \
  'the hash of the newest `Build: started on <branch> at <short hash>.` note.'
file_lacks "spec build: no pass that builds every task first" "$BM" '## 5. Build every task'
file_lacks "spec build: and no pass that reviews them after" "$BM" '## 6. Review every task'
# The order: each task is built, then reviewed, then fixed, before the next; then the build-wide
# run, the user check and the branch review.
for h in '### Where the task stands' '### Build it' '### Review it' '### The fix loop' '## 6. When every task passed'; do
  line_is "spec build: has $h" "$BM" "$h"
done
o1="$(linex "$BM" '### Build it')"
o2="$(lineno "$BM" '2. Launch `implementer` on the task, named for the build.')"
o3="$(linex "$BM" '### Review it')"
o4="$(lineno "$BM" '2. Launch a fresh `reviewer` in task mode on the task.')"
o5="$(linex "$BM" '### The fix loop')"
o6="$(linex "$BM" '## 6. When every task passed')"
o7="$(lineno "$BM" '`second-brain validation run "<project>" <repo> --when each-build`.')"
o8="$(lineno "$BM" '2. Launch `reviewer` in user mode on the finished branch.')"
o9="$(lineno "$BM" '3. Launch `reviewer` in branch mode: one review of the whole branch ends the build.')"
o10="$(lineno "$BM" '7. Read `finish.md`, next to this file, and follow it.')"
is "spec build: build, review, fix, then the build-wide run, the user check and the branch review, in order" \
  "$((${o1:-0} > 0 && o1 < o2 && o2 < o3 && o3 < o4 && o4 < o5 && o5 < o6 && o6 < o7 && o7 < o8 && o8 < o9 && o9 < o10))" "1"
file_has "spec build: each task is reviewed before the next starts" "$BM" \
  'review it right after, before the next task starts. A task that fails holds up the tasks after it'
line_is "spec build: the build-wide run has no agent" "$BM" '1. Run the build-wide checks once, with no agent:'
file_has "spec build: a failing check is logged on its task" "$BM" \
  '"<command> fails in the build-wide run, exit <code>: <its lines>" --fix "<the fix you propose>"`.'
file_has "spec build: and that task takes the fix loop" "$BM" \
  '- Then `second-brain spec status <ID> <task> failed` for each such task, and go back to'
line_is "spec build: building before the implementer" "$BM" '1. `second-brain spec status <ID> <task> building`.'
line_is "spec build: in-review before the reviewer" "$BM" '1. `second-brain spec status <ID> <task> in-review`.'
file_has "spec build: building before each fix round too" "$BM" \
  '2. Otherwise, `second-brain spec status <ID> <task> building`, then the round:'
file_has "spec build: the fix rounds come from build.json, every session's" "$BM" \
  'The task'"'"'s `fails` in `spec status <ID>` is its failed reviews in `build.json`, from every session.'
line_is "spec build: rounds 1 to 3 go to the same implementer" "$BM" \
  '   - `fails` 1 to 3: the same `implementer`. Send the fix message to'
file_has "spec build: a fresh one when it cannot be reached" "$BM" \
  '- SendMessage is not there, or no agent has that name, as in a new session: launch a fresh'
line_is "spec build: round 4 goes to a fresh one on the stronger model" "$BM" \
  '   - `fails` 4: launch a fresh `implementer` on the stronger model, named from round 4 on, with'
line_is "spec build: round 5 goes back to it" "$BM" \
  '   - `fails` 5: send the fix message to `<ID>-<task>-implementer-2`, or launch a fresh one as for'
line_is "spec build: a sixth failed review stops the build" "$BM" \
  '1. `fails` 6 or more, right after a FAIL: the cap is reached. First the stop note,'
is "spec build: the cap is checked before a round sets building" \
  "$(($(lineno "$BM" '1. `fails` 6 or more, right after a FAIL') < $(lineno "$BM" '2. Otherwise, `second-brain spec status <ID> <task> building`')))" "1"
file_has "spec build: every resumed failed task looks for a ruling" "$BM" \
  '4. Review `failed`: look for its ruling as item 3 says, since a stop may have left one.'
file_has "spec build: below the cap it resumes in the fix loop, with the ruling" "$BM" \
  '- `fails` 5 or less: `### The fix loop`, with its ruling lines, as `### Rulings in each prompt`'
file_has "spec build: a task stopped at the cap waits for a newer ruling on resume" "$BM" \
  '- `fails` 6 or more, the build stopped at the cap: the answer sends one more round, as for'
file_has "spec build: the cap stops as the stop section says" "$BM" \
  '`second-brain task note <ID> "Build: stopped at <task>: <why>."`, then stop, as'
file_has "spec build: and that section writes no second stop note" "$BM" \
  ', unless a block or the cap'
file_has "spec build: a cut-off fix goes back to the fix loop" "$BM" \
  '- No hash, or one `spec status` lists already: `### The fix loop` when the task'"'"'s `fails` is 1'
file_has "spec build: a blocked task gets the ruling" "$BM" \
  '3. Build or review `blocked`: its ruling is the owner'"'"'s ruling on it, the status note'
file_has "spec build: a cut-off build takes only a commit build.json lacks" "$BM" \
  '- The full hash starts with no listed hash: that run committed. Run'
file_has "spec build: a ruling counts only when newer than the stop" "$BM" \
  'newest `Build: stopped at <task>: <why>.` note. Status notes are newest first, so it is above.'
file_has "spec build: a cut-off build's commit is found by its full hash" "$BM" \
  'hash: the first line of `git -C "<path>" log --format="%H %s" --grep="^<ID> <task>: "` whose'
file_has "spec build: a cut-off build never takes the tick commit for its own" "$BM" \
  'subject is not `<ID> <task>: passed review`. That one is the tick of a `spec_home: repo` spec.'
file_lacks "spec build: no longer takes the newest commit of the task whatever it is" "$BM" 'log -1 --format=%H --grep='
file_has "contract: the tick commit is never a task's own" "$here/docs/contract.md" \
  '- The tick commit of a `spec_home: repo` spec, `<ID> <task>: passed review`, is never a task'"'"'s own'
file_has "spec build: and a listed hash matches by prefix" "$BM" \
  '- A hash `spec status` lists under the task is that commit when the full hash starts with it.'
file_has "contract: a blocked task waits for a ruling newer than its stop" "$here/docs/contract.md" \
  '- A `blocked` task is launched again with the owner'"'"'s ruling on it, when that ruling is newer than'
file_has "contract: so does a task stopped at the cap" "$here/docs/contract.md" \
  '- A task stopped past the fix loop'"'"'s cap gets one more round in the same way: only with a ruling'
file_has "spec build: sets the result the implementer reports" "$BM" \
  '5. Otherwise: `second-brain spec status <ID> <task> built --commit <short hash>`, with the hash'
line_is "spec build: sets a failed review" "$BM" '4. FAIL: `second-brain spec status <ID> <task> failed`.'
line_is "spec build: then the fix loop" "$BM" '7. PASS: go on to the next task. FAIL: `### The fix loop`.'
is "spec build: shows the status once per task, after its review" \
  "$(grep -c '^[0-9]\. Show the owner `second-brain spec status <ID>`\.$' "$BM")" "1"
is "spec build: and that is in the review step" \
  "$(awk '/^### Review it/ { on = 1 } /^### The fix loop/ { on = 0 } on && /^6\. Show the owner `second-brain spec status <ID>`\.$/' "$BM")" \
  '6. Show the owner `second-brain spec status <ID>`.'
is "spec build: shown once the verdict's state is set" \
  "$(($(lineno "$BM" '4. FAIL: `second-brain spec status <ID> <task> failed`.') < $(lineno "$BM" '6. Show the owner `second-brain spec status <ID>`.') && \
  $(lineno "$BM" '   - Then `second-brain spec status <ID> <task> passed`.') < $(lineno "$BM" '6. Show the owner `second-brain spec status <ID>`.')))" "1"
file_has "spec build: shows the status when a session starts or resumes" "$BM" \
  '1. Show the owner `second-brain spec status <ID>` as it prints.'
file_has "spec build: shows the status when the build stops" "$BM" \
  '1. Show the owner `second-brain spec status <ID>`, the task that stopped the build, and why'
file_has "spec build: shows the status when it finishes" "$BM" \
  '6. Show the owner `second-brain spec status <ID>` and the final validation result.'
for nt in 'Build: started on <branch> at <short hash>.' 'Build: stopped at <task>: <why>.' \
  'Build: finished; every task passed review, the branch is at <short hash>.' \
  'Build: the owner ruled on <task>: <the ruling, as written>.'; do
  file_has "spec build: the status note $nt" "$BM" "\"$nt\""
done
file_has "spec build: a task's progress is in build.json alone" "$BM" "A task's progress is in \`build.json\` alone."
file_has "spec build: reads finish.md when every task passed" "$BM" 'Read `finish.md`, next to this file, and follow it.'
file_has "spec build: keeps track of the build" "$BM" "You keep track of the build"
file_has "spec build: a release check runs only when the owner asks" "$BM" '- Run a `release` check only when the owner asks:'
file_has "spec build: the build-wide run runs in the background" "$BM" \
  '- Run it with the Bash tool'"'"'s `run_in_background: true`, and wait for its notice. A run can'
file_has "contract: the skill runs validation run in the background" "$here/docs/contract.md" \
  '- The skill runs `validation run` with the Bash tool'"'"'s `run_in_background` and waits for its'
file_has "spec build: a timed-out call moves to the background" "$BM" \
  '     outlast a Bash call'"'"'s timeout, which moves the call to the background anyway, and its notice'
file_has "contract: a timed-out call moves to the background" "$here/docs/contract.md" \
  '  notice. A run can outlast a Bash call'"'"'s timeout, which moves the call to the background anyway.'
for f in "$BM" "$here/docs/contract.md"; do
  file_lacks "$(basename "$f"): no helper that a timeout kills" "$f" 'a helper that a timeout kills'
done
file_has "contract: implementer and reviewer run each check in the foreground" "$here/docs/contract.md" \
  '- `implementer` and `reviewer` run each check in the foreground, with the Bash tool'"'"'s longest'
file_has "contract: a background agent's call moves after 3 minutes" "$here/docs/contract.md" \
  '- In a background agent, such as each one the skill launches, a call moves to the background'
file_has "contract: the exit line goes on a line of its own" "$here/docs/contract.md" \
  '- Each check'"'"'s command is followed by `echo "exit: $?"` on a line of its own. A check that'
file_lacks "contract: the exit line is never added to the command's own line" "$here/docs/contract.md" \
  '; echo "exit: $?"'
file_has "contract: a message may move a check to the background" "$here/docs/contract.md" \
  '  outlasts its call moves to the background and still runs. A message that reaches the agent'
file_has "contract: the agent waits in calls under 3 minutes" "$here/docs/contract.md" \
  '- The agent waits for it in the foreground, in calls under 3 minutes, until its output file holds'
file_has "contract: no agent replies while a check it started runs" "$here/docs/contract.md" \
  '- No agent replies while a check it started still runs: once it replies, the notice may never'
file_has "contract: fix rounds 1 to 3 still resume the same implementer" "$here/docs/contract.md" \
  '- Fix rounds 1 to 3 go back to the same `implementer`, with the findings in its packet. Rounds 4'
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
  line_is "$ag: a background agent's call moves after 3 minutes" "$AF" \
    '- In a background agent, a call moves to the background after 3 minutes, whatever its timeout.'
  file_has "$ag: puts the exit line on a line of its own" "$AF" \
    '- Put `echo "exit: $?"` on a line of its own after each check'"'"'s command, so that its output'
  file_lacks "$ag: never adds the exit line to the command's own line" "$AF" '; echo "exit: $?"'
  file_has "$ag: a check moved to the background still runs" "$AF" \
    '- A check that outlasts its call moves to the background and still runs. A message that reaches'
  file_has "$ag: a message may move it there too" "$AF" '  you while it runs may move it there too.'
  file_lacks "$ag: no claim that a message always moves it" "$AF" 'moves it there too'
  file_has "$ag: waits for it in the foreground" "$AF" \
    '`for i in $(seq 17); do grep -q '"'"'^exit: '"'"' "<file>" && break; sleep 10; done`. It returns'
  # The wait must return before a background agent's call moves, at 180 seconds.
  wl="$(grep -m1 -F 'grep -q '"'"'^exit: '"'"'' "$AF")"
  wn="$(printf '%s\n' "$wl" | sed -n 's/.*\$(seq \([0-9][0-9]*\)).*/\1/p')"
  ws="$(printf '%s\n' "$wl" | sed -n 's/.*sleep \([0-9][0-9]*\);.*/\1/p')"
  is "$ag: the wait loop's count times its sleep stays under 180 seconds" \
    "$(( ${wn:-999} * ${ws:-999} < 180 ))" "1"
  file_has "$ag: a check with no exit line is no pass" "$AF" \
    '- A check with no `exit:` line has not finished, whatever its output shows: it is no pass. One'
  file_has "$ag: never replies while a check it started runs" "$AF" \
    '- Never reply while a check you started still runs. Once you reply, its notice may never reach'
done
file_has "reviewer: a server a step needs is no check" "$here/agents/reviewer.md" \
  '- A server a step needs is no check: start it as `### Set up and start` says.'
IM="$here/agents/implementer.md"
file_has "implementer: fetches its own packet" "$IM" '1. Run `second-brain spec packet <ID> <task> --project "<project>"`.'
line_is "implementer: replies with its commit first" "$IM" '1. `Commit: <short hash>`.'
line_is "implementer: then one line on what it built" "$IM" '2. One line on what you built. It also names anything the task asks that you could not do, and'
line_is "implementer: then its test" "$IM" \
  '3. `Test: <the test you wrote> - failed first, then passed`, or `Test: none - <why>` for a task'
line_is "implementer: then each check's result" "$IM" \
  '4. One line per check you ran: `Check: <the command or step> - <pass, fail or skipped>`.'
file_has "implementer: a stop names the checks it ran" "$IM" \
  '- You stop without a commit: the first line is `BLOCKED: <why>`, then the `Check:` lines of the'
file_has "implementer: fixes the packet's issues on a fix" "$IM" "On a fix, the packet's \`fails:\` is above 0 and its \`## Issues\` lists the findings of the last"
file_has "implementer: calls what earlier tasks provide" "$IM" "The packet's \`## Uses\` names what earlier tasks provide."
file_lacks "implementer: no longer runs no check" "$IM" "Run no check"
file_lacks "implementer: and its description no longer says so" "$IM" "runs no check"
file_has "implementer: writes a test that fails for the requirement first" "$IM" \
  '1. Write a test that fails for the task'"'"'s requirement first, where the task'"'"'s `Check` and the'
file_has "implementer: sees it fail before the change" "$IM" '- Run it and see it fail, for the reason the requirement gives.'
line_is "implementer: then makes it pass" "$IM" '2. Then make the change, until the test passes.'
line_is "implementer: runs its own test narrowly, never every suite" "$IM" \
  '   that holds it. Never every suite.'
line_is "implementer: a task with nothing to test says why" "$IM" \
  '4. A task with nothing to test, such as a doc change, gets no test. Your reply says why.'
line_is "implementer: has a check step" "$IM" "## 2. Check"
file_has "implementer: runs every check the packet names" "$IM" \
  "Before you commit, run every check under the packet's \`## Checks\`."
file_has "implementer: the each-task checks through validation run" "$IM" \
  '`second-brain validation run "<project>" <repo> --when each-task`, with the packet'"'"'s `repo`.'
file_has "implementer: runs each test and check in the foreground" "$IM" \
  '- Run each test and check in the foreground, with the Bash tool'"'"'s longest timeout:'
line_is "implementer: the exit line is not compared with expected" "$IM" \
  '  - The `exit:` line you add after the command is not part of what it prints.'
line_is "implementer: runs no release check, no user step and no build-wide check" "$IM" \
  '- Run no other check: no `release` check, no user step, and no `each build` check but the one'
line_is "implementer: but the suite that holds its own test" "$IM" \
  '  suite that holds your own test. The `spec` skill runs the build'"'"'s checks once every task has'
line_is "implementer: a step it has no tool for is not its to take" "$IM" \
  '  - A step that needs a tool you do not have, such as a browser or a skill, is not yours to take.'
line_is "implementer: it reports it skipped and leaves it to the review" "$IM" \
  '    Report it as `Check: <the step> - skipped - needs <the tool>`, and leave it to the review.'
line_is "implementer: only a command it cannot pass or run blocks" "$IM" \
  '- A command you cannot make pass, or cannot run, such as one that is not found: commit nothing,'
line_is "implementer: commits only when every check passed or was skipped" "$IM" \
  '- Commit only when every check under `## Checks` passed or was skipped. A row `validation run`'
file_has "implementer: never changes a test so that it passes" "$IM" \
  'Never change a test or a check'
is "implementer: checks before it commits" \
  "$(($(linex "$IM" '## 1. Build test-first') < $(linex "$IM" '## 2. Check') && $(linex "$IM" '## 2. Check') < $(linex "$IM" '## 3. Commit')))" "1"
RV="$here/agents/reviewer.md"
file_has "reviewer: fetches its own packet" "$RV" '1. Run `second-brain spec packet <story> <task> --project "<project>"`.'
file_has "reviewer: reads the diff from the file the helper writes" "$RV" "2. Read the change from the file the packet's \`diff:\` line names, and nothing else of the code."
file_has "reviewer: logs each issue with a proposed fix" "$RV" 'second-brain spec issue <story> <task>'
file_has "reviewer: replies with its verdict and the number of issues" "$RV" '- `issues`: the number of defects, those you logged and those in the reply. A follow-up is not'
file_lacks "reviewer: no longer says the implementer runs no check" "$RV" "the implementer runs none"
file_has "reviewer: runs the task's checks again" "$RV" "The implementer runs the task's checks before it commits. You run them again, and never take its"
CT="$here/docs/contract.md"
line_is "contract: the skill takes each report from the agent's result" "$CT" \
  '- The skill takes each report from the agent'"'"'s result. Nothing is relayed by hand.'
file_has "contract: the agents run spec packet themselves" "$CT" \
  '`spec packet <ID> <task>` themselves. The skill never prints a packet into the owner'"'"'s session.'
file_has "contract: build progress is build.json in the vault" "$CT" \
  "- A spec story's build progress is \`build.json\` in its task folder in the vault, whatever its"
file_has "guide: the build runs in your session" "$here/docs/guide.md" \
  '- The build runs in your session. The `spec` skill launches `implementer` and `reviewer` one at a'
file_has "guide: progress is in build.json, never in the README" "$here/docs/guide.md" 'issues and times are in `build.json`, never in the'
file_has "changelog: names build.md" "$here/CHANGELOG.md" '`skills/spec/build.md`'
file_has "changelog: names build.json" "$here/CHANGELOG.md" 'build progress is in `build.json`'
file_has "spec tasks template: each task is reviewed right after it is built" "$here/templates/spec-tasks.md.tmpl" "Each task is built, then reviewed right after, before the next one"
file_has "spec phases: written for the build build.md runs" "$here/skills/spec/phases.md" "Write every phase for the build \`build.md\` runs."
file_has "spec phases: a whole-branch check is the final validation's" "$here/skills/spec/phases.md" "belongs to the final validation, not to one task's review."

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
file_has "README: points to the guide's Spec-driven delivery" "$RM" \
  '`## Spec-driven delivery` in `docs/guide.md`'
line_is "README: docs/guide.md has the heading ## Spec-driven delivery" "$here/docs/guide.md" \
  "## Spec-driven delivery"
line_is "README: has ## Story templates" "$RM" "## Story templates"
file_has "README: a project's own templates go in its claude/templates folder" "$RM" '`<project>/claude/templates/` in your vault'
file_has "README: points to the contract's rules for a project's own templates" "$RM" \
  "\`### A project's own templates\` in"
line_is "README: docs/contract.md has the heading ### A project's own templates" "$here/docs/contract.md" \
  "### A project's own templates"
file_has "README: names the doctor's task-template check" "$RM" "The doctor's \`task-template\` check warns"
for pf in skills/spec/build.md skills/vault-doctor/checks.md templates/pull-request.md.tmpl \
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
for h in "### Start a ticket" "### Ask where things stand" "### Build a story from a spec" "### Check the vault"; do
  line_is "README: the example $h" "$RM" "$h"
done
file_has "README: the build is test-first" "$RM" '`implementer` builds each one test-first when it has'
file_has "README: the review ends with a JSON verdict" "$RM" 'It grades each check and ends with a JSON'
file_has "README: the fix rounds are capped" "$RM" '- A failed task goes back for a fix, in a capped number of rounds.'
file_has "README: the stop list holds once the build has started" "$RM" '- Once the build has started, Claude asks you only for a short list'
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
  'skills/story-tracker/SKILL.md|## Spec-driven stories' \
  'skills/spec/SKILL.md|## Step 2 - One phase at a time' 'skills/spec/build.md|## 2. Ready to build' \
  'skills/spec/phases.md|## The chat' 'skills/spec/phases.md|## The spec check'; do
  pf="${ptr%%|*}" ph="${ptr#*|}"
  file_has "guide: points to $ph in $pf" "$GD" "\`$ph\` in \`$pf\`"
  line_is "guide: $pf has the heading $ph" "$here/$pf" "$ph"
done
for pf in skills/sprint/close.md skills/spec/SKILL.md skills/spec/build.md .github/workflows/test.yml \
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
file_has "guide: no build starts without the repo's steps" "$here/skills/spec/build.md" \
  '`second-brain validation <project> <repo>` must print the repo'"'"'s steps'

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
file_has "spec build: cuts a missing branch as the branch check says" "$here/skills/spec/build.md" \
  'No branch yet: ask, then cut it as the branch check says, named by `branch_pattern`.'
line_is "contract: base_branch is where a new story's branch is cut from" "$here/docs/contract.md" \
  "- \`base_branch\` is the branch a new story's branch is cut from, as"

# ---------------------------------------------------------------- a passed spec build is finished
FN="$here/skills/spec/finish.md"
exists "spec finish: the step has its own file" "$FN"
file_has "spec build: reads finish.md only when the build finished" "$here/skills/spec/build.md" \
  'Read `finish.md`, next to this file, and follow it.'
file_has "spec finish: read only when every task passed" "$FN" \
  'Read this file only when the build finished with every task passed, as `build.md` says.'
file_has "spec finish: the story's branch stays its own" "$FN" \
  "- The story's \`branch\` stays \`<branch>\` whatever the owner picks: review fixes go on it."
file_lacks "spec finish: never sets the story's branch" "$FN" 'task set <ID> branch='
file_has "spec finish: asks the owner with AskUserQuestion" "$FN" \
  '- Ask with AskUserQuestion, with three options:'
file_has "spec finish: offers a merge into the target" "$FN" '  - Merge `<branch>` into `<target>`.'
file_has "spec finish: offers a pull request into the target" "$FN" \
  '  - Open a pull request from `<branch>` into `<target>`.'
file_has "spec finish: offers to keep the branch" "$FN" '  - Keep `<branch>` as it is.'
file_has "spec finish: another target is asked again" "$FN" \
  '- The owner names another target in the free-text answer: ask again, with the three options for'
file_has "spec finish: any other answer keeps the branch" "$FN" \
  '- Do only what the owner picks. Any other answer is `## 5. Keep`.'
line_is "spec finish: has the Keep heading it points to" "$FN" '## 5. Keep'
file_has "spec finish: the target is the open release branch" "$FN" \
  '- The target is the open release branch, `release/<version>`.'
line_is "spec finish: lists the release branch names" "$FN" \
  "  git -C \"<path>\" for-each-ref --format='%(refname:lstrip=-2)' \\"
line_is "spec finish: local and remote, highest first, once each" "$FN" \
  "    'refs/heads/release/*' 'refs/remotes/*/release/*' | sort -rVu"
file_lacks "spec finish: no sort by the full ref name" "$FN" 'branch -a --list'
file_has "spec finish: the highest tag is the last release shipped" "$FN" \
  '- The highest `v<version>` tag is the last release that shipped.'
file_has "spec finish: the tags are listed highest first" "$FN" \
  "git -C \"<path>\" tag --list 'v*' --sort=-v:refname"
file_has "spec finish: only a release above that tag is open" "$FN" \
  '- Only a release branch higher than that tag is open.'
file_has "spec finish: with no tag every release is open" "$FN" \
  '- With no `v<version>` tag, every release branch is open.'
file_has "spec finish: the target is the highest open one" "$FN" \
  '- The target is the highest open release branch.'
file_has "spec finish: no open release asks the owner" "$FN" \
  '- No release branch is open: ask the owner to name the target, or a version to cut.'
file_has "spec finish: base_branch only with no release branch" "$FN" \
  '- No release branch at all: the target is `base_branch`.'
file_lacks "spec finish: no repo path the project's repo lacks" "$FN" '`docs/guide.md`'
file_has "spec finish: does only what the owner picks" "$FN" '- Do only what the owner picks.'
file_has "spec finish: finds the worktree that holds the target" "$FN" \
  'git -C "<path>" worktree list --porcelain'
file_has "spec finish: merges in that worktree" "$FN" \
  'git -C "<where>" merge --no-ff <branch> -m "Merge <branch> into <target>"'
file_has "spec finish: a merge pushes nothing" "$FN" 'The merge is local. It pushes nothing.'
file_has "spec finish: a merge sets next" "$FN" \
  'second-brain task set <ID> next="Owner reviews the merge into <target>"'
file_has "spec finish: a merge records a status note" "$FN" \
  '"Finish: merged <branch> into <target> at <short hash>."'
file_has "spec finish: names the push and the pull request before they run" "$FN" \
  '1. Before either runs, name both: the push of `<branch>` to `origin`, and the pull request into'
file_has "spec finish: a pull request sets next" "$FN" \
  'second-brain task set <ID> next="Owner reviews the pull request"'
file_has "spec finish: a pull request records a status note" "$FN" \
  '"Finish: opened a pull request into <target>: <url>."'
file_has "spec finish: the description follows the pull request format" "$FN" \
  '4. Write the description in the pull request format the index points to.'
file_lacks "spec finish: no template path the project's repo lacks" "$FN" 'pull-request.md.tmpl'
file_has "spec finish: a failed pick writes a note" "$FN" \
  '"Finish: <pick> into <target> failed: <reason>; <what ran>."'
line_is "spec finish: has the failure heading it points to" "$FN" '## 7. A pick that fails'
file_has "spec finish: deleting the branch needs discard typed" "$FN" \
  '- Delete the branch only when the owner types `discard`. A pick or a yes is not enough.'
file_has "spec finish: discard detaches before it deletes" "$FN" \
  '- `git -C "<path>" switch --detach`, then `git -C "<path>" branch -D <branch>`.'
file_has "spec finish: discard sets next" "$FN" \
  'second-brain task set <ID> next="<branch> was discarded; the owner decides what follows"'
file_has "spec finish: discard keeps the hash in the note" "$FN" \
  '"Finish: the owner typed discard; <branch> was at <short hash>."'
file_has "spec finish: never forces a push" "$FN" '- Never force a push or rewrite history.'
file_has "guide: points to the finishing step" "$GD" 'as `skills/spec/finish.md` says.'
file_lacks "guide: does not restate the finishing step" "$GD" 'only when you type `discard`'
file_has "changelog: names the finishing step" "$here/CHANGELOG.md" '`skills/spec/finish.md`'
line_is "contract: a merge or a pull request runs only on the pick" "$here/docs/contract.md" \
  "- A merge or a pull request runs only on the owner's pick."
line_is "contract: each push or pull request is named before it runs" "$here/docs/contract.md" \
  '- Each push or pull request is named before it runs.'
file_has "contract: deleting the branch needs discard typed" "$here/docs/contract.md" \
  "- The story's branch is deleted only when the owner types \`discard\`."

# ---------------------------------------------------------------- the baseline skip and bundles
PH="$here/skills/spec/phases.md"
file_has "spec build: a resumed build skips the baseline, whatever the start" "$BM" '1. Skip it when the build resumes, whatever the start.'
file_has "spec build: the base branch is the subproject's" "$BM" \
  '2. The base branch is the `base_branch` that `second-brain subproject <project> <subproject>`'
file_has "spec build: or the profile's" "$BM" '`second-brain profile <project> --keys` prints.'
file_has "spec build: origin/<base> when the repo has it" "$BM" \
  '`git -C "<path>" rev-parse --verify --quiet "refs/remotes/origin/<base_branch>"` prints a'
file_has "spec build: else the base branch itself" "$BM" 'hash, else `<base_branch>`.'
line_is "spec build: the start is tested with git's own test" "$BM" \
  '3. Run `git -C "<path>" merge-base --is-ancestor <start> <base>`.'
file_has "spec build: a start on the base skips the baseline, with its note" "$BM" \
  '`second-brain task note <ID> "Build: baseline skipped: the branch starts at <start> on <base>."`,'
file_has "spec build: any other start runs it" "$BM" '- Any other exit, such as on a branch cut from `release/<version>` or with commits the base'
is "spec build: the start is tested before the baseline launch" \
  "$(($(lineno "$BM" 'merge-base --is-ancestor <start> <base>') < $(lineno "$BM" '4. Launch `reviewer` in baseline mode on the branch as it is.')))" "1"
line_is "spec build: the start is noted before a spec is committed" "$BM" '   - Then note `<short hash>`: it is `<start>`.'
is "spec build: and that note comes before the spec commit" \
  "$(($(lineno "$BM" 'Then note `<short hash>`: it is `<start>`.') < $(lineno "$BM" 'commit -m "<ID>: spec"')))" "1"
file_has "spec build: the final validation runs either way" "$BM" 'The build-wide checks in `## 6. When every task passed` run either way.'
line_is "spec build: has ### A bundle" "$BM" '### A bundle'
is "spec build: the bundle steps come after the fix loop, before the build-wide run" \
  "$(($(linex "$BM" '### The fix loop') < $(linex "$BM" '### A bundle') && $(linex "$BM" '### A bundle') < $(linex "$BM" '## 6. When every task passed')))" "1"
file_has "spec build: a bundle comes from the last column of spec tasks" "$BM" \
  'A task whose `spec tasks` row names a bundle, in its last column, goes with the other tasks of'
file_has "spec build: one task or bundle at a time, never in parallel" "$BM" 'One task or bundle at a time, never in parallel.'
file_has "spec build: a bundle's tasks go to one fresh implementer run" "$BM" \
  '2. Launch one fresh `implementer` on them, with the bundle'"'"'s prompt and name.'
line_is "spec build: one commit line per task" "$BM" \
  '  - Last, one commit line per task, in order: `Commit <task> as "<ID> <task>: <title>".`'
for l in '  - `Bundle: <n>.`' '  - `Tasks: <task>, <task>.`: the tasks of the bundle it builds, in order.' \
  '  - The ruling lines of those tasks, each led by its task:' '    `Owner on <task>: <the ruling, as written>.` or' \
  '    `Ruling on <task>: <the question> - <the decision and why>.`'; do
  line_is "spec build: the bundle prompt line ${l#  - }" "$BM" "$l"
done
file_has "spec build: names the bundle's implementer" "$BM" '`name: "<ID>-bundle-<n>-implementer"`'
file_has "spec build: each task of a bundle is set building first" "$BM" \
  '1. `second-brain spec status <ID> <task> building` for each of them, in order.'
file_has "spec build: each committed task is set built" "$BM" '`second-brain spec status <ID> <task> built --commit <hash>`, with the hash it names.'
file_has "spec build: a task with no report or no commit line is looked for by its commit" "$BM" \
  '- No report, or one with no `Commit:` and no `BLOCKED:` line: look for its commit first, as'
file_has "spec build: a block, or no commit found, stops the run there" "$BM" \
  '- A report with `BLOCKED:`, or no commit found: that task stopped the run. Take no task'
file_has "spec build: a fix found built is reviewed, not fixed again" "$BM" \
  'Review too each task whose review is `failed` and whose `fix` in `spec status` is'
file_has "reviewer: follows a ruling on one task of a bundle" "$RV" \
  '- An `Owner on <task>:` line is the owner'"'"'s ruling on that task alone: follow it there.'
file_has "contract: a bundle task with no report is looked for by its commit" "$CT" \
  '- A task the run gives no report on, or no commit line, is looked for by its commit first, in the'
file_has "contract: a task of a bundle uses none of it" "$CT" '- A task of a bundle uses no other task of its bundle on its `- Uses:` line.'
file_has "contract: spec tasks refuses such a Uses line" "$CT" 'or when a task'"'"'s `- Uses:` line names a task of its own bundle'
file_has "spec phases: spec tasks checks the bundle rules" "$PH" 'bundle. `spec tasks` checks both.'
file_has "changelog: a resumed task never takes the tick commit" "$here/CHANGELOG.md" \
  '- A resumed task cut off while `building` no longer takes the tick commit of a `spec_home: repo`'
file_has "spec build: the tasks after a stop go back to todo" "$BM" \
  'first `second-brain spec status <ID> <task> todo` for each task'
file_has "spec build: and the stop is taken as for a task alone" "$BM" 'after it. Then take its stop as item 4 of `### Build it` says: a ruling, or a stop of the'
file_has "spec build: then one fresh reviewer reads the bundle" "$BM" \
  '2. Launch one fresh `reviewer` in task mode on them, with the bundle'"'"'s prompt.'
file_has "spec build: each task of a bundle is set in-review first" "$BM" \
  '1. `second-brain spec status <ID> <task> in-review` for each of them, in order.'
file_has "spec build: one verdict per task" "$BM" '3. Read each task'"'"'s verdict from its entry in the block, as `### Reading a verdict` says.'
file_has "spec build: a failed task of a bundle takes the fix loop alone" "$BM" \
  '4. Fix each task left whose review is not `passed`, one at a time, in order.'
file_has "spec build: a fix is always on one task" "$BM" '- A fix is always on one task, with the prompt and message above, even for a task of a bundle.'
file_has "spec build: fix rounds 1 to 3 reach the bundle's implementer" "$BM" \
  'or to `<ID>-bundle-<n>-implementer` for a task of bundle `<n>`,'
file_has "spec build: a resumed bundle finds each cut-off commit first" "$BM" \
  '1. Where they stand: a build `building` looks for its commit, and sets `built` when it finds one,'
file_has "spec build: the next task or bundle waits for the bundle" "$BM" '5. Every task of the bundle has passed: go on to the next task or bundle.'
file_has "spec build: a split bundle stops the build" "$BM" 'None, or exit 1 as for a split bundle: say so'
file_has "spec phases: names the Bundle line" "$PH" \
  '- Small, alike tasks may form a bundle: each adds one line, `- Bundle: <n>`, the same whole number'
file_has "spec phases: a bundle's tasks stand together and use none of each other" "$PH" \
  "- A bundle's tasks stand next to each other in the list, and none uses another task of its"
file_has "spec phases: each keeps its own check and commit" "$PH" '- Each task of a bundle keeps its own requirements, `- Check:` and commit.'
file_has "spec phases: the owner approves the bundles with the tasks" "$PH" \
  '- Show the bundles with the task list. The owner approves them with the tasks.'
file_has "spec phases: spec tasks must succeed and name each bundle" "$PH" \
  '- Run `second-brain spec tasks <ID>`. It must succeed, and its last column names each task'"'"'s'
file_has "spec tasks template: says how a bundle builds" "$here/templates/spec-tasks.md.tmpl" \
  'Tasks next to each other with the same `- Bundle: <n>` line are one bundle: built in one'
file_has "implementer: builds a bundle one task at a time" "$IM" \
  'per task. Build them one at a time, in that order, each as a task alone:'
file_has "implementer: fetches each packet as it starts the task" "$IM" '1. Fetch its packet only when you start it, and check where you are, as `## 0. Get your packet`'
file_has "implementer: each task test-first, with its checks and its own commit" "$IM" \
  '2. Build it test-first, run its packet'"'"'s `## Checks` and commit it with its own commit line, as'
file_has "implementer: one report per task" "$IM" 'Each opens with a line `Task: <task>`, then the lines'
file_has "implementer: a task it cannot commit stops the bundle" "$IM" '- A task you cannot commit stops the bundle.'
file_has "reviewer: reviews each task of a bundle against its own packet" "$RV" 'one commit per task. Review each task against its own packet:'
file_has "reviewer: runs the each-task checks once for a bundle" "$RV" '   once for the bundle, as step 4 says.'
file_has "reviewer: logs each finding on its own task" "$RV" 'and log each finding on its own task, as'
file_has "reviewer: one verdict per task of a bundle" "$RV" '3. A bundle: one block, with one entry per task of its `Tasks:` line, in order. Each entry is the'
for a in implementer reviewer; do
  d="$(sed -n 's/^description: //p' "$here/agents/$a.md")"
  ok=""
  case "$d" in *bundle*) [ "${#d}" -lt 200 ] && ok="ok" ;; esac
  is "$a: the description names a bundle, under 200 characters" "$ok" "ok"
done
file_has "contract: a task item may name its bundle" "$CT" '- A task item may add `- Bundle: <n>`, a whole number. The tasks with the same number are one'
file_has "contract: spec tasks prints the bundle" "$CT" 'title (`-` when none), bundle (`-` when none).'
file_has "contract: spec tasks --json has the bundle key" "$CT" '`--json` prints the rows with the keys `id`, `state`, `title` and `bundle`'
file_has "contract: the baseline is skipped on a start on the base branch" "$CT" \
  '- The branch starts on the base branch when `git merge-base --is-ancestor HEAD <base>` exits 0.'
file_has "contract: names the skip note" "$CT" '`Build: baseline skipped: the branch starts at <short hash> on <base>.`'
file_has "contract: a resumed build skips it, and the final validation always runs" "$CT" \
  '- A resumed build skips the baseline, whatever the start. The final validation always runs.'
file_has "contract: a bundle goes to one implementer run" "$CT" "- A bundle's tasks go to one fresh \`implementer\` run. It builds them in order, one commit per"
file_has "contract: then one reviewer gives a verdict per task" "$CT" \
  'requirements, logs each finding on its task, and gives one verdict per task.'
file_has "contract: the cap counts per task" "$CT" 'Its own `fails` picks each round, so the cap counts per task.'
file_has "contract: never in parallel" "$CT" '- One task or bundle at a time, never in parallel.'
file_has "guide: says when the baseline is skipped" "$GD" 'It is skipped when the branch starts on the base'
file_has "guide: says how a bundle builds" "$GD" '- Small, alike tasks may form a bundle, which you approve with the task list.'
file_has "guide: spec tasks names each bundle" "$GD" '- `second-brain spec tasks EX-2` prints each task'"'"'s bundle in its last column.'
file_has "changelog: the baseline skip" "$here/CHANGELOG.md" '- A new build skips the baseline when the story'"'"'s branch starts on the base branch'
file_has "changelog: bundles" "$here/CHANGELOG.md" '- A bundle'"'"'s tasks go to one `implementer` run, one commit per'
file_has "changelog: spec tasks names the bundle" "$here/CHANGELOG.md" '- `second-brain spec tasks` prints each task'"'"'s bundle in a fourth column'

# ---------------------------------------------------------------- the build asks only for a stop list, and rules on the rest
BM="$here/skills/spec/build.md"
FN="$here/skills/spec/finish.md"
CT="$here/docs/contract.md"
GD="$here/docs/guide.md"
IM="$here/agents/implementer.md"
RV="$here/agents/reviewer.md"
q="'"
line_is "spec build: has the stop list" "$BM" '## 8. When to ask the owner'
file_has "spec build: the stop list holds once the build has started" "$BM" \
  'Once the build has started, stop and ask the owner with AskUserQuestion only for these. Each one'
for l in "1. A destructive action, such as discarding the owner${q}s changes or deleting a branch." \
  '2. A security-sensitive action, such as one that needs a secret, a credential or a permission.' \
  '3. An outside effect, such as a push, a merge or a publish.' \
  '4. A spec too broken to follow: going on would change, add or drop a requirement, a design' \
  '5. A task blocked, or past its last fix round. A `BLOCKED` from the user check or the branch' \
  '6. A failed baseline.'; do
  line_is "spec build: the stop list names ${l%%,*}" "$BM" "$l"
done
is "spec build: the stop list has six items and no more" \
  "$(awk '/^## 8\. When to ask the owner/ { on = 1; next } /^### / { on = 0 } on && /^[0-9]+\. /' "$BM" | grep -c '')" "6"
is "spec build: asks with AskUserQuestion only in the list and at a stop" "$(grep -c 'AskUserQuestion' "$BM")" "2"
line_is "spec build: a stop asks the owner" "$BM" '3. Ask the owner with AskUserQuestion what to do.'
line_is "spec build: only a listed stop comes to the stop section" "$BM" \
  'Only a stop that `## 8. When to ask the owner` lists comes here.'
file_has "spec build: decides any other question itself" "$BM" \
  '- Any other question you decide yourself, as `### A ruling` says. Never ask the owner it.'
file_has "spec build: the steps before the build starts ask as they say" "$BM" \
  '- The steps before the `Build: started` or `Build: resumed` note ask as they say: the owner has'
file_has "spec build: the finish asks only for outside effects and destructive actions" "$BM" \
  'just run the skill. So does `finish.md`: each of its questions is an outside effect or a'
line_is "spec build: has the ruling step" "$BM" '### A ruling'
file_has "spec build: an ambiguous requirement is a ruling" "$BM" \
  "A question comes in an agent's reply, such as an \`implementer\`'s \`BLOCKED:\` on a requirement it"
file_has "spec build: two agents that disagree are a ruling" "$BM" \
  'reads two ways, or from two agents that disagree, such as two reviews of a task that ask for'
line_is "spec build: records each ruling as a status note" "$BM" \
  '   `second-brain task note <ID> "Ruling: <task>: <the question> - <the decision and why>"`.'
file_has "spec build: a ruling decides by the spec first" "$BM" \
  '1. Decide by the approved spec first, then the story, then the code on the branch. Pick what keeps'
line_is "spec build: a ruling never changes, adds or drops a requirement or a check" "$BM" \
  '   - A ruling never changes, adds or drops a requirement, a design decision, a task or a check.'
file_has "contract: so says the contract" "$CT" \
  '- A ruling never changes, adds or drops a requirement, a design decision, a task or a check. It'
line_is "spec build: a spec too broken to follow names a check too" "$BM" '   decision, a task or a check.'
file_has "spec build: one ruling note per task it touches" "$BM" \
  'A question on several tasks gets one note per'
file_has "spec build: a ruling never lifts a stop" "$BM" '- A ruling of yours never lifts a stop.'
file_has "spec build: a BLOCKED on a question gets a ruling, not a stop" "$BM" \
  '- A `BLOCKED:` on a question a ruling settles, such as a requirement it reads two ways: rule on'
file_has "spec build: and goes on from the task's state, a bundle's task too" "$BM" \
  '`### Where the task stands` says, or item 1 of `### A bundle` for a task of a bundle. Its'
line_is "spec build: only a missing or unparsed block is asked once more" "$BM" \
  '5. No block, or one that does not parse: ask the reviewer once more with SendMessage,'
line_is "spec build: a bad block goes to one fresh reviewer at once" "$BM" \
  '6. A block that parses and is not good, or no good block after item 5: launch one fresh'
line_is "spec build: and only then is BLOCKED" "$BM" '7. No good block from the fresh `reviewer` either: take it as BLOCKED.'
is "spec build: asked once more, then a fresh reviewer, then BLOCKED, in order" \
  "$(($(lineno "$BM" '5. No block, or one that does not parse') < $(lineno "$BM" '6. A block that parses and is not good') && \
  $(lineno "$BM" '6. A block that parses and is not good') < $(lineno "$BM" '7. No good block from the fresh')))" "1"
file_has "spec build: a bundle task with no verdict gets one fresh reviewer first" "$BM" \
  '   block, with the bundle'"'"'s prompt for those tasks.'
file_lacks "spec build: no stop that the list does not name" "$BM" 'Still none: stop.'
file_has "spec build: a failing check no task holds goes to the last task, with a ruling" "$BM" \
  '- No task you can tell: the last task in order, with a ruling, as `### A ruling` says.'
file_lacks "spec build: a failing check no longer stops the build" "$BM" 'No task you can tell: stop'
file_has "spec build: a user check FAIL takes the fix loop" "$BM" \
  '   - FAIL: it logged each defect it could tie to a task. Log each defect its reply lists on the'
file_has "spec build: each task with a new issue is set failed" "$BM" \
  '   - Else `second-brain spec status <ID> <task> failed` for each task whose issue count grew since'
file_has "spec build: a user or branch FAIL that adds no issue is no verdict" "$BM" \
  '   - Now no task'"'"'s issue count is above the one item 1 of `### Reading a verdict` noted: the FAIL'
line_is "spec build: and goes to the fresh reviewer, then BLOCKED" "$BM" '     is no verdict. Go on as items 6 and 7 there say.'
is "spec build: the reply's findings are logged before the counts are checked" \
  "$(($(lineno "$BM" 'Log each defect its reply lists on the') < $(lineno "$BM" '   - Now no task'"'"'s issue count is above')))" "1"
file_has "spec build: each task's issue count is noted before the user and branch reviews" "$BM" \
  '1. Before a review'"'"'s first launch, but the baseline'"'"'s, note the issue count of each task it'
line_is "spec build: the ask and the fresh reviewer are judged against those counts" "$BM" \
  '   - Item 5'"'"'s ask and item 6'"'"'s fresh `reviewer` take no new count: they are judged against these.'
file_has "spec build: the user and branch reviews review every task" "$BM" '   and the branch review review every task.'
cn_note="$(lineno "$BM" 'Item 1 there notes each task'"'"'s issue count')"
cn_fail="$(lineno "$BM" '   - FAIL: it logged each defect it could tie to a task.')"
is "spec build: the count is noted before the review's result is taken" \
  "$((${cn_note:-0} < ${cn_fail:-0}))" "1"
file_lacks "spec build: no new issue told by its day" "$BM" 'with a new issue in'
file_has "spec build: a new session reads the rulings from the story's note" "$BM" \
  '- A new session finds them there: `second-brain outline <note>`, with `<note>` the `path:` that'
file_lacks "spec build: never outlines the repo path" "$BM" 'second-brain outline <path>'
file_has "spec build: an unanswered stop on a failed task asks the owner first" "$BM" \
  "   - Its newest \`Build: stopped at <task>: <why>.\` note has no newer owner's ruling and no newer"
is "spec build: before its fix is reviewed or fixed" \
  "$(($(lineno "$BM" 'note has no newer owner'"'"'s ruling and no newer') < $(lineno "$BM" '- A `fix` in `spec status` that is not `-`: its fix was built')))" "1"
file_has "spec build: a reopen newer than the stop answers a blocked task's stop" "$BM" \
  '   - A `Spec: <phase> reopened.` note newer than that stop note answers the stop too: the owner'
file_has "spec build: and a failed task's" "$BM" 'reopen note: the build stopped there, and the owner has not answered.'
file_has "contract: a reopen newer than the stop answers it" "$CT" \
  '- A `Spec: <phase> reopened.` note newer than a task'"'"'s stop note answers that stop too, for a'
file_lacks "spec build: the cap asks the owner once, in the first bullet" "$BM" 'None: ask the owner'
file_lacks "spec build: a fix ruling is always logged" "$BM" 'unless the task has a new issue'
file_has "spec skill: outlines the story's note, from task head" "$SK" \
  'Read the story'"'"'s status notes: `second-brain outline <note>`, with `<note>` the `path:` that'
file_lacks "spec skill: never an undefined path" "$SK" 'second-brain outline <path>'
file_has "contract: an unanswered stop on a resumed failed task asks first" "$CT" \
  "- A resumed \`failed\` task whose newest stop note has no newer owner's ruling stopped the build"
file_has "spec build: a ruling to fix a task logs what it asks" "$BM" \
  '`second-brain spec issue <ID> <task> "The owner ruled: <the ruling, as written>" --fix "<the fix it asks>"`.'
is "spec build: before it sets the task failed" \
  "$(($(lineno "$BM" '"The owner ruled: <the ruling, as written>"') < $(lineno "$BM" '     Then `second-brain spec status <ID> <task> failed`, and back to')))" "1"
file_has "spec build: a reversed ruling on a passed task is fixed as such" "$BM" \
  'A task that passed already takes it as a ruling to fix the task, as the bullet above says.'
file_has "spec build: a reopen bounds the rulings" "$BM" \
  '- They are newer too than the newest `Spec: <phase> reopened.` note. The changed phase holds what'
file_has "spec build: a reopen retires the rulings before it" "$BM" '     - The reopen retires every ruling before it'
file_has "contract: a reopen bounds the rulings" "$CT" \
  '- They are newer too than the build'"'"'s newest `Spec: <phase> reopened.` note. A reopen retires the'
file_lacks "spec build: no prompt takes the ruling as its one Owner line" "$BM" 'as its `Owner:` line'
file_lacks "spec build: nor as the one Owner line of the next prompt" "$BM" 'as the `Owner:` line'
file_has "spec build: the branch review FAIL too" "$BM" '   FAIL: as item 2 says.'
file_lacks "spec build: a FAIL of the user check no longer stops the build" "$BM" 'FAIL or BLOCKED: stop'
line_is "spec build: has the rulings of this build" "$BM" '### The rulings of this build'
file_has "spec build: the rulings of a build come after its newest start note" "$BM" \
  '- They are the status notes newer than the newest'
file_has "spec build: the skill's rulings and the owner's" "$BM" \
  '`Build: started on <branch> at <short hash>.` note: each of your `Ruling: <task>:` notes and'
file_has "spec build: an earlier build's rulings are left out" "$BM" 'A note below it is from an earlier build of the'
line_is "spec build: has the rulings in each prompt" "$BM" '### Rulings in each prompt'
file_has "spec build: every ruling of the build goes into each later prompt" "$BM" \
  '- Every ruling of this build on a task goes, as written and oldest first, into each later prompt'
line_is "spec build: the owner's ruling line" "$BM" '    `Owner: <the ruling, as written>.`'
line_is "spec build: the skill's ruling line" "$BM" '    `Ruling: <the question> - <the decision and why>.`'
line_is "spec build: the implementer's prompt holds the ruling lines" "$BM" \
  "  - The task's ruling lines, one per ruling of this build on it, as \`### Rulings in each prompt\`"
line_is "spec build: so does the fix message" "$BM" "  - The task's ruling lines."
file_has "spec build: so does the reviewer's prompt" "$BM" "  task's ruling lines."
file_has "spec build: so does the bundle reviewer's" "$BM" 'the session line and their ruling lines, each led by'
file_has "spec build: the user and branch reviews get every task's" "$BM" \
  '`Repo: <repo> at <path>.` and `Branch: <branch>.`, then the ruling lines of every task, each led'
file_lacks "spec build: no prompt takes only one owner ruling" "$BM" 'when there is one: `Owner:'
file_has "spec build: the owner's ruling wins" "$BM" '- The agents follow both. Where they differ, the `Owner:` line wins.'
line_is "spec build: has the list of rulings" "$BM" '### The list of rulings'
file_has "spec build: lists every ruling when the build finishes or stops" "$BM" \
  'When the build finishes or stops, show the owner every ruling of this build, as written, oldest'
file_has "spec build: names the phase each ruling touched" "$BM" \
  '- Name for each the phase it touched: the requirements, the design or the tasks.'
is "spec build: lists them at the finish and at a stop" \
  "$(grep -c '^   - Then list the rulings of the build, as `### The list of rulings` says\.$' "$BM")" "2"
is "spec build: the finish lists them before finish.md" \
  "$(($(lineno "$BM" '6. Show the owner `second-brain spec status <ID>` and the final validation result.') < $(lineno "$BM" '   - Then list the rulings of the build') && \
  $(lineno "$BM" '   - Then list the rulings of the build') < $(lineno "$BM" '7. Read `finish.md`, next to this file')))" "1"
file_has "spec build: the owner can reopen the phase a ruling touched" "$BM" \
  '- The owner can reopen the phase a ruling touched, or reverse a ruling with one of their own. At a'
file_has "spec build: a reversed ruling is the owner's ruling on its task" "$BM" \
  '- The owner reverses a ruling of yours: their ruling on its task, as above. It wins over yours.'
file_has "spec build: a stop can reopen the phase a ruling touched" "$BM" \
  '- The spec needs a change, such as in the phase a ruling touched: write'
file_has "spec finish: the owner can reverse a ruling or reopen its phase" "$FN" \
  '- Say too that the owner can reverse a ruling of the build, or reopen the phase one touched, in'
file_has "spec finish: and the story goes back in progress first" "$FN" \
  '`second-brain task set <ID> status=in-progress next="The spec skill builds the approved tasks"`.'
is "spec finish: that answer comes before any other is a keep" \
  "$(($(lineno "$FN" '- Say too that the owner can reverse a ruling') < $(lineno "$FN" '- Do only what the owner picks.')))" "1"
file_has "implementer: follows a ruling line" "$IM" \
  "- A \`Ruling:\` line is the \`spec\` skill's ruling on a question the spec left open: follow it too."
file_has "implementer: and one on a task of its bundle" "$IM" \
  "- A \`Ruling on <task>:\` line is the skill's ruling on that task alone: follow it there."
file_has "implementer: puts a BLOCKED as one question" "$IM" 'stop with `BLOCKED:` and say what, as one question the'
file_has "reviewer: follows a ruling line" "$RV" \
  "- A \`Ruling:\` line is the \`spec\` skill's ruling on a question the spec left open: follow it too."
file_has "reviewer: and one on a task of its bundle" "$RV" \
  "- A \`Ruling on <task>:\` line is the skill's ruling on that task alone: follow it there."
for f in "$IM" "$RV"; do
  file_has "${f##*/}: the owner's line wins over a ruling" "$f" '  Where it and an `Owner:` line differ, the `Owner:` line wins.'
done
file_has "reviewer: what a ruling decided is no finding" "$RV" '- What an `Owner:` or `Ruling:` line decided is never a finding.'
file_has "reviewer: the user and branch modes get the build's rulings" "$RV" \
  '- The caller gives too an `Owner on <task>:` or `Ruling on <task>:` line for each ruling of the'
file_has "contract: the stop list" "$CT" \
  '- **The stop list.** Once the build has started, the skill stops and asks the owner with'
file_has "contract: names its six reasons" "$CT" \
  'such as a push, a merge or a publish, a spec too broken to follow, a task blocked or past its'
file_has "contract: any other question is a ruling" "$CT" \
  '`second-brain task note <ID> "Ruling: <task>: <the question> - <the decision and why>"`, before'
file_has "contract: the rulings of a build" "$CT" '- **The rulings of a build** are the status notes newer than its newest'
file_has "contract: every ruling goes into the task's prompts" "$CT" \
  '- Every ruling of the build on a task goes, as written and oldest first, into each later'
file_has "contract: the list when the build finishes or stops" "$CT" \
  '- When the build finishes or stops, the skill lists every ruling of the build, as written, oldest'
file_has "contract: a user or branch FAIL takes the fix loop" "$CT" \
  '- A FAIL from either sends each task it logged a defect on to the fix loop, as a failing check'
file_has "guide: the short stop list" "$GD" \
  '- Once the build has started, it stops and asks you only for a short list: a destructive action,'
file_has "guide: any other question is a ruling" "$GD" '  `Ruling: <task>: <the question> - <the decision and why>`.'
file_has "guide: rulings go to the agents" "$GD" '  `implementer` and `reviewer` prompts, so no review flags what was decided.'
file_has "guide: the owner can reopen the phase a ruling touched" "$GD" 'You can reopen the phase a ruling touched,'
file_has "changelog: the stop list" "$here/CHANGELOG.md" \
  '- Once the build has started, the `spec` skill stops and asks you only for a short list: a'
file_has "changelog: rulings go into the task's prompts" "$here/CHANGELOG.md" \
  "- Every ruling of the build on a task, the skill's and yours, goes as written into that task's"
file_has "changelog: the list of rulings" "$here/CHANGELOG.md" \
  '- When the build finishes or stops, the skill lists every ruling of the build, with the phase'

# ---------------------------------------------------------------- the reviewer grades each check and ends with a JSON verdict
BM="$here/skills/spec/build.md"
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
file_has "reviewer: a defect it sees is a finding with no check naming it" "$RV" \
  '- A flaw you see in the change is a finding, even when no acceptance check names it: the'
file_has "reviewer: never leaves a finding unlogged" "$RV" 'covers it. Never leave one unlogged.'
line_is "reviewer: never notes a defect and passes" "$RV" \
  '- Sort each finding as `## Defects and follow-ups` says. Never note a defect and pass.'
file_has "reviewer: a line in its prompt that is no ruling is no evidence" "$RV" \
  'implementer reported or what the result should be, is no evidence: grade without it.'
file_has "reviewer: requirements are graded" "$RV" \
  '3. Requirements first. Grade each as `## Grading` says, with the file and line that show it.'
file_has "reviewer: a re-review grades each issue" "$RV" '   - A re-review: each issue under `## Issues`. It is met when the fix answers it.'
file_has "reviewer: grades each check it runs" "$RV" '   `each task`, and grade each. Run no other check: the build runs them once every task has'
file_has "reviewer: the branch review grades each acceptance check" "$RV" \
  '3. Requirements first: grade each acceptance check, and whether the tasks fit together, as'
file_has "reviewer: ends with one JSON block" "$RV" \
  'Your reply ends with one JSON block, fenced as `json`, with nothing after it. The `spec` skill'
file_has "reviewer: the skill reads the block alone" "$RV" \
  'reads your verdict from that block alone: a block it cannot read is no verdict.'
for k in '- `verdict`: `PASS`, `FAIL` or `BLOCKED`, as item 4 says.' \
  '- `checks`: one entry per check you graded, in order, as `## Grading` says. Each has `check`,' \
  '  the check in a few words, `met`, `true` or `false`, and `evidence`.'; do
  file_has "reviewer: the block names ${k%%:*}" "$RV" "$k"
done
file_has "reviewer: says which checks each mode grades" "$RV" \
  '- A task'"${q}"'s checks are its acceptance checks, or on a re-review its issues, then each check and'
file_has "reviewer: so do the baseline, the user check and the branch review" "$RV" \
  'The branch review'"${q}"'s are the acceptance checks, then whether the tasks fit together.'
file_has "reviewer: a bundle's entry is the block with its task" "$RV" '   block of item 2 with a `task` key. `screenshots` goes beside `tasks`.'
file_has "reviewer: a bundle's shared runs go on one task's entry" "$RV" \
  '6. In the verdict block, grade each run of item 3 in the entry of the task item 3 gives its'
file_has "reviewer: a PASS has every check met and no issue" "$RV" \
  '- `PASS`: every check is met, and `issues` is 0: a PASS with an open defect is not allowed.'
file_has "reviewer: a check not met fails the task" "$RV" \
  '- `FAIL`: a check is not met, or there is another defect, so `issues` is 1 or more. The'
line_is "reviewer: evidence is one phrase" "$RV" \
  '   - `evidence` is one phrase: a file and line, or a command and the line it printed. Never paste'
line_is "reviewer: never pastes output" "$RV" '     output.'
file_has "reviewer: the example bullets are the grading, not the reply" "$RV" \
  'Two task reviews, cut short. Grade as they do. Their bullets are the grading you do, not your'
line_is "reviewer: in task mode the reply is the block alone" "$RV" 'reply: in task mode the reply is the block alone.'
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
is "reviewer: the worked FAIL logs its findings" "$(example_of 'A FAIL' | grep -c 'spec issue')" "1"
is "reviewer: the worked FAIL takes the commit message as a claim" "$(example_of 'A FAIL' | grep -c 'a claim, not evidence')" "1"
is "reviewer: the worked PASS meets a check through an Owner line" "$(example_of 'A PASS' | grep -c 'the `Owner:` line chose it: met')" "1"
is "reviewer: the worked examples name no ticket key but the example one" \
  "$(awk '/^## Worked examples$/ { on = 1; next } /^## / { on = 0 } on' "$RV" | grep -E '[A-Z][A-Z0-9]+-[0-9]+' | grep -cvE 'EX-[0-9]+')" "0"
line_is "spec build: has the verdict reading" "$BM" '### Reading a verdict'
file_has "spec build: takes the verdict from the block alone" "$BM" \
  'verdict from that block alone, never from the words before it.'
file_has "spec build: reads the reply's last json block" "$BM" \
  "2. The block is the reply${q}s last fenced block tagged \`json\`. It parses when it is one JSON object"
file_has "spec build: a bundle's task is judged on its own entry" "$BM" \
  '   - In a bundle, each task of its `Tasks:` line is judged on its own entry. A task with no entry'
line_is "spec build: a verdict is one of three" "$BM" \
  '   - `verdict` is `PASS`, `FAIL` or `BLOCKED`, and `issues` is a whole number.'
line_is "spec build: each check has a met of true or false" "$BM" \
  '   - `checks` is a list. Each entry has a `check` text and a `met` of `true` or `false`.'
line_is "spec build: a PASS needs every check met, no issue, and no issue logged on its task" "$BM" \
  '   - A `PASS` has every `met` `true` and `issues` 0. Its task'"${q}"'s count did not grow; in user and'
line_is "spec build: a user or branch PASS needs no issue logged on any task, and task and branch one check" "$BM" \
  '     branch mode, no task'"${q}"'s count grew. In task and branch mode it has one check or more.'
line_is "spec build: a FAIL needs an issue, and in task mode one logged" "$BM" \
  '   - A `FAIL` has `issues` 1 or more. In task mode, its task'"${q}"'s count grew. In user and branch'
line_is "spec build: no good block is never a PASS" "$BM" '4. No good block is no verdict, and never a PASS.'
line_is "spec build: the message asks for the block and nothing else" "$BM" \
  '   `Your reply has no JSON verdict block that parses. Reply with the block alone.`'
is "spec build: the baseline, a task, a bundle and the user check read it there" \
  "$(grep -c 'as `### Reading a verdict` says' "$BM")" "4"
line_is "spec build: the branch review reads it as the user check does" "$BM" '   - Read its verdict as item 2 does.'
file_lacks "spec build: no VERDICT line is read" "$BM" 'VERDICT:'
file_has "spec build: never coaches the reviewer" "$BM" \
  '`### Reading a verdict` gives. Never add a view of your own on the result, such as the'
file_has "spec build: not even the implementer's report" "$BM" \
  "  implementer${q}s report, its \`Test:\` or \`Check:\` lines, or the verdict you expect."
file_has "contract: the reviewer grades each check with its evidence" "$CT" \
  '- `reviewer` grades each acceptance check, or on a re-review each finding the fix answers, and'
file_has "contract: the implementer's words are a claim" "$CT" \
  "- The implementer${q}s words, in its report, a commit message or a comment, are a claim to check,"
file_has "contract: a PASS with an open defect is not allowed" "$CT" \
  'defect, and any defect fails the task: a PASS with an open defect is not allowed.'
file_has "contract: names the worked examples" "$CT" '- `agents/reviewer.md` holds two short worked examples: a FAIL with its findings, and a PASS with'
file_has "contract: the JSON block" "$CT" \
  '`{"verdict": "FAIL", "issues": 1, "checks": [{"check": "...", "met": false, "evidence": "..."}]}`.'
file_has "contract: a bundle's block" "$CT" 'ends with one block, `{"tasks": [...]}`: one entry per task, in order, each that block with a'
file_has "contract: the skill reads the block in place of a VERDICT line" "$CT" \
  '- The skill reads each verdict from the block, in place of a `VERDICT:` line. A PASS needs every'
line_is "contract: a bad block is never a PASS" "$CT" '- No block, or one that breaks these rules, is no verdict: never a PASS.'
file_has "contract: a branch review grades one check or more" "$CT" '`met` true and `issues` 0, and in task and branch mode one check or more. A FAIL needs `issues`'
file_has "contract: the block is checked against the issues logged" "$CT" \
  '- Before a review'"${q}"'s first launch, but the baseline'"${q}"'s, the skill notes the issue count of each'
file_has "contract: the counts come from spec status" "$CT" 'task it reviews, from `spec status --json`. The fresh `reviewer` is judged against the same'
file_lacks "contract: the counts are not written to build.json" "$CT" 'issue count of each task it reviews in'
file_has "contract: a PASS is judged on its own task's count" "$CT" \
  '- A PASS is no verdict when its task'"${q}"'s count grew, or in user and branch mode any task'"${q}"'s. So is a'
file_has "contract: a user or branch FAIL that adds no issue is no verdict" "$CT" \
  '- A user or branch FAIL is no verdict when no count grew once the skill has logged the findings'
file_has "contract: only a missing or unparsed block is asked again" "$CT" \
  '- The skill asks the same reviewer once more only when the block is missing or does not parse.'
file_has "contract: the skill gives the reviewer no view of its own" "$CT" \
  'never gives it a view of its own on the result, and never the implementer'"${q}"'s report.'
file_has "guide: the reviewer ends with a JSON verdict" "$GD" \
  '- `reviewer` grades each check as met or not, with its evidence, and ends its reply with a JSON'
file_has "changelog: the reviewer grades each check" "$here/CHANGELOG.md" \
  '- `reviewer` grades each acceptance check, and each check and user step it runs, as met or not,'
file_has "changelog: the JSON verdict" "$here/CHANGELOG.md" \
  '- `reviewer` ends its reply with a JSON block, `{"verdict": ..., "issues": <n>, "checks": [...]}`,'
file_has "changelog: a bad block is never a PASS" "$here/CHANGELOG.md" \
  '- No block, or one that breaks its rules, is no verdict and never a PASS. So is a PASS with a'
file_has "changelog: only a missing block is asked again" "$here/CHANGELOG.md" \
  'asks once more only when the block is missing or does not parse. Otherwise it launches one'
file_has "changelog: the worked examples" "$here/CHANGELOG.md" \
  '- `agents/reviewer.md` holds two worked examples, a FAIL with its findings and a PASS with its'

# ---------------------------------------------------------------- the reviewer grades code quality on a failing task too
CT="$here/docs/contract.md"
RV="$here/agents/reviewer.md"
q="'"
file_lacks "reviewer: a FAIL no longer skips the code quality pass" "$RV" 'skip step 6'
file_lacks "reviewer: a bundle task with a finding still gets the quality pass" "$RV" 'for each task with no finding yet'
line_is "reviewer: a FAIL still runs step 6" "$RV" \
  '   is FAIL. Still run step 6, so that one fix round answers every defect.'
file_lacks "reviewer: the FAIL rule is said once, in step 5" "$RV" 'on a FAIL too'
file_has "reviewer: a re-review grades the fix's commits alone" "$RV" \
  '6. Then code quality, in the diff alone. On a re-review the diff is the fix'"${q}"'s commits: grade'
line_is "reviewer: the quality pass sorts each finding" "$RV" \
  '   those alone. Each of these is a finding, sorted as `## Defects and follow-ups` says:'
q5_line="$(lineno "$RV" 'Still run step 6')"
q6_line="$(lineno "$RV" '6. Then code quality, in the diff alone.')"
q8_line="$(lineno "$RV" '8. Log each defect in the story')"
is "reviewer: step 5's FAIL comes before the quality pass" \
  "$((${q5_line:-0} < ${q6_line:-0} && ${q6_line:-0} < ${q8_line:-0}))" "1"
line_is "reviewer: branch mode uses the list in step 6" "$RV" \
  '4. Then code quality across the change, by the list in step 6 of `## Task mode`.'
line_is "reviewer: a bundle grades each task's quality" "$RV" \
  '4. Step 6, code quality, in its own diff, for each task, one with a finding too.'
is "reviewer: the worked FAIL still runs step 6" "$(example_of 'A FAIL' | grep -c 'step 6 still runs')" "1"
line_is "contract: code quality is graded on a FAIL too" "$CT" \
  '- It grades code quality on a FAIL too, and in a bundle on each task, so that one fix round'
line_is "contract: one fix round answers every defect" "$CT" '  answers every defect.'
line_is "contract: a re-review grades the fix's quality alone" "$CT" \
  "  It grades the code quality of the fix${q}s commits alone."
file_has "changelog: quality on a failing task" "$here/CHANGELOG.md" \
  '- `reviewer` grades code quality on a failing task too, so that one fix round answers every'
file_has "changelog: a re-review grades the fix's quality" "$here/CHANGELOG.md" \
  "  defect. A re-review still grades the quality of the fix${q}s commits alone."
qf_line="$(lineno "$here/CHANGELOG.md" '- `reviewer` grades code quality on a failing task too')"
qf_top="$(lineno "$here/CHANGELOG.md" '## 0.12.0 - ')"
qf_end="$(lineno "$here/CHANGELOG.md" '## 0.11.0 - ')"
is "changelog: quality on a failing task is under 0.12.0" \
  "$((${qf_line:-0} > ${qf_top:-0} && ${qf_line:-0} < ${qf_end:-0}))" "1"

# ---------------------------------------------------------------- a review sorts each finding as a defect or a follow-up
BM="$here/skills/spec/build.md"
CG="$here/CHANGELOG.md"
CT="$here/docs/contract.md"
FN="$here/skills/spec/finish.md"
GD="$here/docs/guide.md"
RV="$here/agents/reviewer.md"
q="'"
line_is "reviewer: has the defects and follow-ups section" "$RV" '## Defects and follow-ups'
df_gr="$(linex "$RV" '## Grading')"
df_hd="$(linex "$RV" '## Defects and follow-ups')"
df_bm="$(linex "$RV" '## Baseline mode')"
is "reviewer: the section comes after grading, before the modes" \
  "$((${df_gr:-0} < ${df_hd:-0} && ${df_hd:-0} < ${df_bm:-0}))" "1"
DF="$(section_of "$RV" 'Defects and follow-ups')"
in_df() { case "$DF" in *"$2"*) pass "$1" ;; *) fail "$1" "missing: $2" ;; esac; }
in_df "reviewer: only a defect fails the task" 'Sort each finding as a defect or a follow-up. Only a defect fails the task.'
in_df "reviewer: a follow-up is one of three kinds" '- A follow-up is one of three kinds:'
is "reviewer: the three follow-up kinds, in order" \
  "$(printf '%s\n' "$DF" | awk '/^- A follow-up is one of three kinds:$/ { on = 1; next } /^- / { on = 0 } on')" \
  "$(printf '%s\n' '  - A name that misleads.' '  - Code repeated where it could be shared.' '  - Code against the conventions the diff shows around it.')"
in_df "reviewer: any other finding is a defect" '- Any other finding is a defect.'
in_df "reviewer: the defect list wins over the kinds" '- Each of these is a defect too, whatever its kind:'
for k in '  - An acceptance check not met, or an issue not answered.' \
  '  - A check or a step that fails, or could not be run.' \
  '  - What a user would hit, such as a wrong behaviour, or an error or edge case left unhandled.' \
  '  - A doc the change makes wrong.' \
  '  - What a requirement, a design decision or a rule written in the repo names, such as a rule'; do
  in_df "reviewer: a defect whatever its kind:${k#  -}" "$k"
done
in_df "reviewer: a finding it cannot place is a defect" '- A finding you cannot place for sure is a defect.'
in_df "reviewer: a defect goes in with spec issue" '- Log a defect with `spec issue`, as step 8 of `## Task mode` says. Only defects count in'
in_df "reviewer: a follow-up is a status note, never an issue" '- Log a follow-up as a status note on the story, never with `spec issue`:'
in_df "reviewer: the follow-up note's text" \
  '`second-brain task note <story> "Follow-up: <task>: <what could be better, at file:line> - <the change you propose>" --session <id>`.'
in_df "reviewer: a follow-up no task covers names build" 'One that no task covers names `build`.'
in_df "reviewer: a follow-up fails nothing" '  - A follow-up fails nothing and goes to no fix round. The build lists it for the owner at its'
line_is "reviewer: step 8 logs each defect" "$RV" '8. Log each defect in the story, with how to fix it, before you reply:'
line_is "reviewer: and each follow-up" "$RV" '   - Log each follow-up too, before you reply, as `## Defects and follow-ups` says.'
file_lacks "reviewer: no finding goes in with spec issue alone" "$RV" 'Log a finding that has a task with `spec issue`'
line_is "reviewer: a defect no task covers goes in the reply" "$RV" '- A defect no task covers goes in the reply, as baseline mode'"${q}"'s do.'
file_has "reviewer: a task review's findings are issues and notes" "$RV" 'Your findings are in the story, through `spec issue` and `task note`.'
line_is "reviewer: a follow-up is not counted in issues" "$RV" '     one.'
file_has "reviewer: a follow-up never stops a PASS" "$RV" 'A step that could not be run is never a PASS. A follow-up never stops one.'
line_is "reviewer: may write a follow-up note" "$RV" '- `second-brain spec issue` and a follow-up'"${q}"'s `task note` are your only writes to the vault.'
is "reviewer: the worked FAIL credits its repeat to step 6" \
  "$(example_of 'A FAIL' | grep -c '  lines 85 and 86: code repeated where it could be shared.')" "1"
is "reviewer: the worked FAIL sorts the repeat as a follow-up" \
  "$(example_of 'A FAIL' | grep -c 'No requirement or rule names the repeat, so it is a follow-up.')" "1"
is "reviewer: the worked FAIL logs the repeat with task note" "$(example_of 'A FAIL' | grep -c '^  `task note`, to cut it.$')" "1"
file_lacks "reviewer: the worked FAIL no longer finds nothing more" "$RV" 'It finds nothing more.'
case "$(json_of 'A FAIL')" in *'"verdict": "FAIL", "issues": 1,'*) pass "reviewer: the worked FAIL counts no follow-up" ;;
  *) fail "reviewer: the worked FAIL counts no follow-up" "in: $(json_of 'A FAIL')" ;; esac
is "reviewer: the worked PASS logs a follow-up with task note" "$(example_of 'A PASS' | grep -c 'so it is a follow-up. It goes in with `task note`,')" "1"
case "$(json_of 'A PASS')" in *'"verdict": "PASS", "issues": 0,'*) pass "reviewer: the worked PASS still passes with its follow-up" ;;
  *) fail "reviewer: the worked PASS still passes with its follow-up" "in: $(json_of 'A PASS')" ;; esac
line_is "contract: the two kinds" "$CT" \
  '- **Defects and follow-ups.** `reviewer` sorts each finding as a defect, which fails the task, or'
file_has "contract: the follow-up kinds" "$CT" \
  '- A follow-up is a name that misleads, code repeated where it could be shared, or code against'
line_is "contract: any other finding is a defect" "$CT" '  the conventions the diff shows around it. Any other finding is a defect.'
file_has "contract: the defects whatever their kind" "$CT" \
  '  what a requirement, a design decision or a rule written in the repo names.'
line_is "contract: a finding not placed for sure is a defect" "$CT" '- A finding `reviewer` cannot place for sure is a defect.'
line_is "contract: only defects count and go to the fix loop" "$CT" \
  '- `reviewer` logs a defect with `spec issue`. Only defects count in `issues` and go to the fix'
file_has "contract: a follow-up is a status note" "$CT" \
  '`task note <ID> "Follow-up: <task>: <what, at file:line> - <the change it proposes>"`. One that'
line_is "contract: a follow-up fails nothing" "$CT" '- A follow-up changes no issue count, fails no task and goes to no fix round.'
file_has "contract: the build lists the follow-ups" "$CT" \
  '- When the build finishes, the skill lists each follow-up of the build, oldest first: the'
file_has "contract: a follow-up is a story-level note" "$CT" '  follow-up a review logs. A task'"${q}"'s progress is in `build.json` alone.'
line_is "contract: issues counts defects" "$CT" \
  '- `verdict` is `PASS`, `FAIL` or `BLOCKED`, `issues` the number of defects, and `checks` one'
file_lacks "contract: no finding fails a task by itself" "$CT" 'any finding fails the task'
file_has "spec build: points to the line between the kinds" "$BM" \
  'A review sorts each finding as a defect or a follow-up, as `## Defects and follow-ups` in'
file_has "spec build: only a defect fails a task" "$BM" \
  '`agents/reviewer.md` says. Only a defect counts in `issues`, fails a task and goes to the fix'
line_is "spec build: a follow-up changes no count" "$BM" 'loop. A follow-up is a `Follow-up:` status note: it changes no issue count.'
df_rv="$(linex "$BM" '### Reading a verdict')"
df_ks="$(lineno "$BM" 'A review sorts each finding as a defect')"
df_b4="$(linex "$BM" '## 4. The baseline')"
is "spec build: the kinds are named in the verdict reading" \
  "$((${df_rv:-0} < ${df_ks:-0} && ${df_ks:-0} < ${df_b4:-0}))" "1"
line_is "spec build: has the list of follow-ups" "$BM" '### The list of follow-ups'
line_is "spec build: the finish lists the follow-ups" "$BM" '   - Then list the follow-ups of the build, as `### The list of follow-ups` says.'
df_ru="$(lineno "$BM" '   - Then list the rulings of the build')"
df_fu="$(lineno "$BM" '   - Then list the follow-ups of the build')"
df_fn="$(lineno "$BM" '7. Read `finish.md`, next to this file')"
is "spec build: the follow-ups come after the rulings, before finish.md" \
  "$((${df_ru:-0} < ${df_fu:-0} && ${df_fu:-0} < ${df_fn:-0}))" "1"
line_is "spec build: lists each follow-up oldest first" "$BM" \
  'When the build finishes, show the owner each follow-up of this build, as written, oldest first.'
line_is "spec build: the follow-ups are the newer notes" "$BM" \
  '- They are the `Follow-up: <task>:` status notes newer than the newest'
line_is "spec build: the same follow-up is listed once" "$BM" '- List the same text once, even when two reviews logged it.'
line_is "spec build: says when there are none" "$BM" '- None: say the build has no follow-ups.'
file_has "spec build: a follow-up fixed is a ruling to fix its task" "$BM" \
  '`## 2. Ask the owner` in `finish.md` says. It is a ruling to fix its task, as item 3 of'
line_is "spec build: one on build goes on the last task" "$BM" '  `## 7. When the build stops` says. One on `build` goes on the last task in order.'
file_has "spec build: the README gets each follow-up" "$BM" '  follow-up a review logs.'
file_has "spec finish: the owner can have a follow-up fixed" "$FN" \
  '  follow-up fixed, as `### The list of follow-ups` there says.'
df_ff="$(lineno "$FN" 'follow-up fixed, as `### The list of follow-ups`')"
df_od="$(lineno "$FN" '  - The owner does: first')"
is "spec finish: that comes before the owner does" "$((${df_ff:-0} < ${df_od:-0}))" "1"
file_has "guide: a review sorts defects and follow-ups" "$GD" \
  '- A review sorts each finding as a defect, which fails the task, or a follow-up, which does not.'
file_has "guide: points to the line" "$GD" '  `## Defects and follow-ups` in `agents/reviewer.md` draws the line.'
line_is "guide: the build's end lists them" "$GD" '- The build'"${q}"'s end lists the follow-ups, and you can have one fixed then.'
file_has "guide: a PASS with an open defect never counts" "$GD" 'a PASS with an open defect never counts, as'
file_has "changelog: a review sorts defects and follow-ups" "$CG" \
  '- `reviewer` sorts each finding as a defect or a follow-up, as `## Defects and follow-ups` in'
file_has "changelog: what stays a defect" "$CG" \
  'against the conventions around it is a follow-up. It stays a defect when a check fails on it, a'
file_has "changelog: only a defect fails a task" "$CG" \
  '- Only a defect fails a task, counts in the verdict'"${q}"'s `issues` and goes to the fix loop. A'
file_has "changelog: the build's end lists the follow-ups" "$CG" \
  'follow-up is a `Follow-up: <task>:` status note on the story, and the build'"${q}"'s end lists each one'
df_line="$(lineno "$CG" '- `reviewer` sorts each finding as a defect or a follow-up')"
df_top="$(lineno "$CG" '## 0.12.0 - ')"
df_end="$(lineno "$CG" '## 0.11.0 - ')"
is "changelog: the follow-ups are under 0.12.0" \
  "$((${df_line:-0} > ${df_top:-0} && ${df_line:-0} < ${df_end:-0}))" "1"

# ---------------------------------------------------------------- the build catches an agent with no report, and checks on the owner's orders
BM="$here/skills/spec/build.md"
CT="$here/docs/contract.md"
CG="$here/CHANGELOG.md"
q="'"
for h in '### An agent with no report' "### The owner${q}s open orders" "### The lead${q}s check"; do
  line_is "spec build: has $h" "$BM" "$h"
  is "spec build: $h is in the launch section, before the verdict reading" \
    "$(($(linex "$BM" '## 3. Launching an agent') < $(linex "$BM" "$h") && $(linex "$BM" "$h") < $(linex "$BM" '### Reading a verdict')))" "1"
done
line_is "spec build: a repeated reply is no new event" "$BM" \
  '- A named agent can send its last reply twice: as its message, then again in its idle notice. A'
line_is "spec build: it changes no state and gets no reply" "$BM" \
  '  notice that repeats a reply you took already is no new event: it changes no state, and gets no'
line_is "spec build: an implementer's report is a commit or a block" "$BM" \
  "- An \`implementer\`${q}s: a \`Commit:\` line, or a first line \`BLOCKED:\`. A bundle${q}s run gives one per"
line_is "spec build: a reviewer's report is its JSON block" "$BM" \
  "- A \`reviewer\`${q}s: the JSON block of \`### Reading a verdict\`."
line_is "spec build: an idle agent with no report is checked before its reply is final" "$BM" \
  'Before you take the reply of an agent idle with no report as final:'
line_is "spec build: it checks the branch with git log and git status" "$BM" \
  '   - `git -C "<path>" log --oneline <start>..HEAD` and `git -C "<path>" status --porcelain`: what'
line_is "spec build: and whether a check the agent started still runs" "$BM" \
  '   - Whether a check it started still runs, such as its tests or a `validation run`: look for its'
line_is "spec build: a process counts only under the repo's path" "$BM" \
  '     process with `ps`. Count only a process whose working directory or command line is under'
line_is "spec build: since another build may run its tests in another worktree" "$BM" \
  "     \`<path>\`: another build${q}s tests may run in another worktree."
line_is "spec build: work that still runs is waited for" "$BM" \
  '2. Its check still runs: the work is real. Wait for its next reply.'
line_is "spec build: nothing running gets one message" "$BM" \
  '3. Nothing of it runs: send that agent one message with SendMessage, by its name, or by its id'
line_is "spec build: the message asks it to finish its step and report" "$BM" \
  '   `Nothing you started is still running. Finish your step, then reply with your report.`'
line_is "spec build: the message goes once" "$BM" '   - Send it once per launch or fix message, never twice.'
line_is "spec build: then its next reply is final" "$BM" \
  '4. Its next reply is final, with a report or not, unless its check still runs, as item 2 says.'
is "spec build: the message comes before the reply is final" \
  "$(($(lineno "$BM" '3. Nothing of it runs: send that agent one message') < $(lineno "$BM" '4. Its next reply is final, with a report or not')))" "1"
bi_ptr='   - It is idle with no report: first take it as `### An agent with no report` says. Then read'
is "spec build: Build it item 3 sends an idle implementer there first" \
  "$(awk '/^### Build it$/ { on = 1 } /^### Review it$/ { on = 0 } on' "$BM" | grep -cxF -- "$bi_ptr")" "1"
is "spec build: between items 3 and 4 of Build it" \
  "$(($(lineno "$BM" '3. Its reply has no `Commit:` line, and does not start with `BLOCKED:`') < $(linex "$BM" "$bi_ptr") && \
  $(linex "$BM" "$bi_ptr") < $(lineno "$BM" '4. Its reply starts with `BLOCKED:`, or no commit was found')))" "1"
rv_ptr='   - A `reviewer` idle with no block at all: first take it as `### An agent with no report`'
line_is "spec build: the verdict reading sends an idle reviewer there first" "$BM" "$rv_ptr"
is "spec build: before it asks for the block alone" \
  "$(($(lineno "$BM" '5. No block, or one that does not parse') < $(linex "$BM" "$rv_ptr") && \
  $(linex "$BM" "$rv_ptr") < $(lineno "$BM" '6. A block that parses and is not good')))" "1"
line_is "spec build: a bundle's run goes there too" "$BM" \
  '      - It is idle with no report: first take it as `### An agent with no report` says.'
line_is "spec build: the reviewer may get that message" "$BM" '  `### An agent with no report` gives, or the one that'
line_is "spec build: the orders note's path" "$BM" "\`<project path>/claude/lead-agent-task-memory.md\`. It tells the lead${q}s check, and a new session,"
line_is "spec build: an order is the owner's ask, in their words" "$BM" \
  '- An order is what the owner asked you to do, in their words: the request that ran the skill, and'
line_is "spec build: the note holds each open order with its date and the owner's words" "$BM" \
  "- Under \`## Open orders\`, the note holds each open order: its date, its story, the owner${q}s words"
line_is "spec build: and what works on it now" "$BM" \
  '  as written, and a `Now:` line on what works on it, such as you, an agent by its name, or a'
line_is "spec build: then the orders done and a last-check line per story" "$BM" \
  '- Under `## Done`, each order done, with what finished it. Last, one `Last check:` line per'
line_is "spec build: another build of the project may share the note" "$BM" \
  '- Another build of the project may keep its orders in the same note. Your own are the orders of'
line_is "spec build: once the note is there, it is only edited" "$BM" \
  '   - Once the note is there, change it only with the Edit tool, never a whole rewrite, so that you'
line_is "spec build: so no session overwrites another's orders" "$BM" \
  "     never overwrite another session${q}s orders."
line_is "spec build: the hub links to the note" "$BM" \
  "     \`- Lead memory: [[<project path>/claude/lead-agent-task-memory|<project> Lead Memory]] - the owner${q}s open orders.\`"
line_is "spec build: no order of the story open stops its check" "$BM" \
  "4. No order of \`<ID>\` open: stop the lead${q}s check, as its item 6 says."
line_is "spec build: another story's open order keeps the note" "$BM" \
  '   - An order of another story still open: leave the note and its hub line.'
line_is "spec build: no order of any story open removes the hub's line, then the note" "$BM" \
  "   - No order of any story open: remove the hub${q}s line, then the note:"
line_is "spec build: removing its own note is no destructive action" "$BM" \
  '     it is no destructive action of `## 8`.'
file_has "spec build: it is the lead's own note" "$BM" '`rm "<vault>/<project path>/claude/lead-agent-task-memory.md"`. It is your own note: removing'
for l in '## Open orders' '## Done' '> Up: [[<project path>/claude/README|<project> Claude Hub]]' \
  "- <YYYY-MM-DD> <ID>: \"<the owner${q}s words, as written>\"" \
  'Last check: <ID> at <YYYY-MM-DD HH:MM> - <what it found>.'; do
  is "spec build: the note's shape has $l" \
    "$(awk '/^```markdown$/ { on = 1; next } /^```$/ { on = 0 } on' "$BM" | grep -cxF -- "$l")" "1"
done
line_is "spec build: the start writes the order and starts the check" "$BM" \
  "7. Write the order that ran the build in the orders note, as \`### The owner${q}s open orders\` says."
is "spec build: right after the build's started or resumed note" \
  "$(($(lineno "$BM" 'Build: resumed on <branch> at <short hash>.') < $(lineno "$BM" '7. Write the order that ran the build in the orders note') && \
  $(lineno "$BM" '7. Write the order that ran the build in the orders note') < $(linex "$BM" '## 3. Launching an agent')))" "1"
line_is "spec build: the check runs at the profile's pace while an order of the story is open" "$BM" \
  'While an order of `<ID>` is open, check on it at the pace the profile sets. An agent can go idle'
line_is "spec build: the pace is lead_check_minutes from the profile's keys" "$BM" \
  '   - Its pace is the `lead_check_minutes` line of `second-brain profile "<project>" --keys`: 10,'
line_is "spec build: the values the pace takes, and 20 otherwise" "$BM" \
  '     12, 15, 20, 30 or 60 minutes. No line, `-` or any other value: 20.'
line_is "spec build: the cron line starts at minute 7 and steps by the pace" "$BM" \
  '   - Its cron line runs at minute 7, then once more each time that many minutes pass, up to'
line_is "spec build: off the hour and the half hour, with the default's example" "$BM" \
  '     minute 59, so no check falls on :00 or :30. With 20: `7,27,47 * * * *`.'
line_is "spec build: CronList first keeps a job with the same prompt and cron line" "$BM" \
  '   - In Claude Code, run `CronList` first. A job that already has the prompt below and that cron'
line_is "spec build: one with another cron line is deleted" "$BM" \
  '     line is the check: keep it, and start none. One with the prompt and another line: delete it'
line_is "spec build: CronCreate takes that cron line" "$BM" \
  '   - Else create it with `CronCreate`: that cron line, `recurring: true`, and the prompt'
file_lacks "spec build: no job on the hour or the half hour" "$BM" '*/10 * * * *'
line_is "spec build: the prompt names build.md of the spec skill" "$BM" \
  "     \`Check on the open orders of <ID>, as the lead${q}s check in build.md of the spec skill says.\`"
line_is "spec build: in this session alone" "$BM" \
  '   - It is session-only: never pass `durable: true`. Keep its job id, from `CronCreate` or'
line_is "spec build: a missing note is written again, not a stop" "$BM" \
  '   - The note is missing while an order of `<ID>` is open: write it again with your open orders,'
file_has "spec build: and the check goes on" "$BM" 'says, and go on. Never stop the check for it.'
line_is "spec build: the check goes on only when the owner has not interrupted or said to hold" "$BM" \
  '   - No one works toward it, and the owner has not since interrupted you or told you to hold: go'
line_is "spec build: otherwise it waits for the owner" "$BM" \
  '     on with its next step now. Otherwise wait for the owner, and say so.'
file_lacks "spec build: no longer goes on whatever the owner said" "$BM" '   - No one works toward it: go on with its next step now.'
line_is "spec build: with no scheduling tool it checks on each notice" "$BM" \
  '   - No scheduling tool: check on each notice that comes to you instead, from an agent or from a'
line_is "spec build: the check asks of each order who works toward it" "$BM" \
  '2. Read the orders note. Of each open order of `<ID>`, ask: is it done, and are you or an agent'
line_is "spec build: the check edits its story's last-check line" "$BM" \
  '4. Write the `Last check:` line of `<ID>` with the Edit tool: the time, and what the check found.'
line_is "spec build: the check takes no outside action" "$BM" \
  '5. The check never pushes, merges or takes another outside action.'
line_is "spec build: CronDelete stops it once no order of the story is open" "$BM" \
  '6. Stop it once no order of `<ID>` is open. In Claude Code, run `CronDelete` with the job id.'
file_has "spec build: the finish closes the build's orders" "$BM" \
  "   - Once \`finish.md\` is done, so are the build${q}s orders: take them to \`## Done\`, as"
is "spec build: after finish.md" \
  "$(($(lineno "$BM" '7. Read `finish.md`, next to this file') < $(lineno "$BM" '   - Once `finish.md` is done, so are the build')))" "1"
line_is "spec build: an answer at a stop that sends the build on is an order" "$BM" \
  '   - An answer that sends the build on is an order: add it to the orders note, as'
file_has "spec build: the owner stopping closes the build's orders" "$BM" \
  "     from it. Take the build${q}s orders to \`## Done\`, as \`### The owner${q}s open orders\` says."
line_is "contract: the orders note is an optional file of the project" "$CT" \
  "  claude/lead-agent-task-memory.md  optional; the owner${q}s open orders, which the lead of a spec build writes (section 9)"
file_has "contract: an agent with no report" "$CT" '- **An agent with no report.** An agent can go idle before its report, such as on a reply that'
file_has "contract: one message, then the next reply is final" "$CT" \
  '- A check that still runs is waited for. With none, the skill sends the agent one message to'
file_has "contract: a repeated reply is no new event" "$CT" \
  '- A notice that repeats a reply the skill took already, such as a named agent'"${q}"'s last reply sent'
file_has "contract: the owner's open orders" "$CT" \
  "- **The owner${q}s open orders.** The skill keeps the owner${q}s open orders of a build in"
file_has "contract: the lead's check" "$CT" \
  "- **The lead${q}s check.** While an order of its story is open, the skill checks on the agents, the"
file_has "contract: at the pace of the profile's lead_check_minutes" "$CT" '  `lead_check_minutes` says (section 3). Of each order it asks whether it or an agent works toward'
line_is "contract: the profile example has lead_check_minutes" "$CT" 'lead_check_minutes: 20'
file_has "contract: lead_check_minutes is described with the profile keys" "$CT" \
  '- `lead_check_minutes` is how many minutes the lead of a spec build waits between two checks on'
file_has "contract: it takes the values that space the checks through the hour" "$CT" \
  '  20, 30 or 60, the values that space the checks evenly through the hour. A missing or empty key,'
file_has "contract: the template leaves it out" "$CT" \
  '- `templates/profile.md.tmpl` leaves the key out. The doctor'"${q}"'s `delivery` check warns on a value'
file_has "contract: the delivery row names lead_check_minutes:invalid" "$CT" \
  'a profile `lead_check_minutes` that is not empty, 10, 12, 15, 20, 30 or 60 (`lead_check_minutes:invalid`) (warn) |'
file_lacks "profile template: leaves lead_check_minutes out" "$here/templates/profile.md.tmpl" 'lead_check_minutes'
file_has "vault-doctor checks: the delivery check names lead_check_minutes:invalid" "$here/skills/vault-doctor/checks.md" \
  'Or a profile `lead_check_minutes` that is not empty, 10, 12, 15, 20, 30 or 60 (`lead_check_minutes:invalid`).'

file_has "contract: builds of one project only edit the shared note" "$CT" \
  '  note, so once it is there the skill changes it only with edits, never a whole rewrite.'
file_has "contract: the check stops with its story, the note with every story" "$CT" \
  '- Once no order of its story is open, the skill stops its check. Once no order of any story is'
file_has "contract: the check holds when the owner interrupts or says to hold" "$CT" \
  '- The check goes on with an order no one works toward only when the owner has not since'
file_has "contract: a process counts only under the repo's path" "$CT" \
  '- A process counts as the agent'"${q}"'s check only when its working directory or command line is under'
line_is "contract: the building and in-review line names the skill" "$CT" \
  '- The skill sets a task `building` before each `implementer` launch or fix message, and'
file_lacks "contract: no bare It after the check's bullets" "$CT" '- It sets a task `building`'
file_has "contract: the check takes no outside action" "$CT" '- The check never pushes, merges or takes another outside action.'
line_is "spec build: the check's own prompt is no order" "$BM" "  check${q}s own prompt is no order."
line_is "spec build: the owner stops the build or drops an order at any time" "$BM" \
  '   - The owner stops the build or drops an order, at a stop or not: it is done, stopped by the'
file_lacks "spec build: no longer closes an order only at a stop" "$BM" 'The owner stops the build at a stop'
line_is "spec build: a wait for the owner is said once" "$BM" '   - Waiting for the owner: say it once, not at each check.'
is "spec build: and that is in the check" \
  "$(awk '/^### The lead'"${q}"'s check$/ { on = 1 } /^### Reading a verdict$/ { on = 0 } on' "$BM" | grep -cxF -- '   - Waiting for the owner: say it once, not at each check.')" "1"
file_has "contract: an order closes when the owner stops the build or drops it" "$CT" \
  '- An order closes when it is done, or when the owner stops the build or drops the order, at a stop'
file_has "contract: the check's prompt is no order" "$CT" "  or not. The check${q}s own prompt is no order."
file_has "contract: the check says a wait once" "$CT" 'Otherwise it waits for the owner and says so once,'
GD="$here/docs/guide.md"
line_is "guide: a build writes the orders note" "$GD" \
  "- A build writes your open orders to \`claude/lead-agent-task-memory.md\` in the project${q}s folder of"
line_is "guide: and a hub line, both removed once no order is open" "$GD" \
  "  your vault, with a line in the project${q}s \`claude/README.md\`, and removes both once no order is"
line_is "guide: and runs a check at the profile's pace" "$GD" \
  '  open. While one is open, it runs a check in your session, as often as `lead_check_minutes` in'
line_is "guide: pointing to the two build.md headings" "$GD" \
  "  the project${q}s profile says, as \`### The owner${q}s open orders\` and \`### The lead${q}s check\` in"
for h in "### The owner${q}s open orders" "### The lead${q}s check"; do
  is "guide: the build.md heading $h is under Spec-driven delivery" \
    "$(awk '/^## Spec-driven delivery$/ { on = 1; next } /^## / { on = 0 } on' "$GD" | grep -cF -- "\`$h\`")" "1"
done
file_has "changelog: the owner can stop the build or drop an order" "$CG" \
  'You can stop the build or drop an order at any time: it is then closed.'
lc_files="$(cd "$here" && find skills agents docs templates hooks README.md CHANGELOG.md -type f | sort)"
# The Bash tool's timeout of 10 minutes for a check names no pace: its three phrases are left out.
lc_ten="$(cd "$here" && printf '%s\n' "$lc_files" | tr '\n' '\0' | xargs -0 grep -nE '10 minutes|every 10\b|10-minute' 2>/dev/null \
  | grep -vE 'timeout(: 600000`)?(,| of) 10 minutes')"
is "the lead's check: no file names 10 minutes for it" "$lc_ten" ""
lc_cron="$(cd "$here" && printf '%s\n' "$lc_files" | tr '\n' '\0' | xargs -0 grep -nF '* * * *' 2>/dev/null)"
is "the lead's check: the one cron line is build.md's example for the default" "$lc_cron" \
  'skills/spec/build.md:'"$(linex "$BM" '     minute 59, so no check falls on :00 or :30. With 20: `7,27,47 * * * *`.')"':     minute 59, so no check falls on :00 or :30. With 20: `7,27,47 * * * *`.'
lc_min="$(awk '/^## 0\.11\.0 - / { on = 1; next } /^## / { on = 0 } on && /[0-9]+ minutes/' "$CG")$(grep -nE '[0-9]+ minutes' "$GD")"
is "the lead's check: the changelog's 0.11.0 lines and the guide name no minutes" "$lc_min" ""
line_is "the lead's check: the start links to the renamed heading" "$BM" \
  "   Then start the lead${q}s check, as \`### The lead${q}s check\` says."
file_lacks "the lead's check: no link to the old heading in build.md" "$BM" 'The check every'
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
SPK="$here/skills/sprint/SKILL.md"
file_has "sprint: calls a parent story by the project's word" "$SPK" \
  '- A task whose `epic` names another task is a child of that parent story. Call a parent story by'
file_has "sprint: a move keeps a child under its parent" "$SPK" \
  'parent, in the folder it moves to, and a parent'"'"'s move takes its own files alone.'
file_has "sprint close: a child goes under its parent" "$here/skills/sprint/close.md" \
  '   - In both, a child goes into a folder named for its parent in the folder it moves to, and a'
file_has "scrum-master: calls a parent story by the project's word" "$here/agents/scrum-master.md" \
  'parent moves its own files alone. Call a parent story by the project'"'"'s word, `feature` or'
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
BM="$here/skills/spec/build.md"
line_is "spec build: the orders note's nested item is indented with a tab" "$BM" \
  "$(printf '\t')- Now: <what works on it: you, an agent by its name, or a check that runs>."
line_is "spec build: the template says to indent with a tab" "$BM" \
  'The note, with each `<...>` filled. A nested item is indented with a tab, as the vault'"'"'s writing'
is "spec build: no nested item of the orders note is indented with spaces" \
  "$(awk '/^# <project> lead memory$/ { on = 1 } on && /^\`\`\`$/ { on = 0 } on && /^ +- /' "$BM" | wc -l | tr -d ' ')" "0"

# ---------------------------------------------------------------- result
result
