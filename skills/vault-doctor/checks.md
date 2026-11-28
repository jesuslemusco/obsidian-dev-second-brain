# Doctor checks

One entry per check, named and ordered as `second-brain doctor` prints its rows. Each entry is its
heading, a blank line, then the `Means`, `Why` and `Fix` lines, one line each, however long. When
to read an entry and when to run its fix: `## check (default)` and `## fix` in
`skills/vault-doctor/SKILL.md`.

### pointer

- Means: `~/.claude/second-brain-vault` is missing, or does not lead to a folder that holds `.obsidian/`.
- Why: every helper command finds the vault through it, so each exits 2 and no skill runs.
- Fix: `/odsb:vault-setup init`, or by hand `second-brain pointer set "<vault folder>"`.

### index

- Means: `CLAUDE.md` at the vault root is missing or has no `## Projects` table; a row's path is not a folder in the vault (`<Project>:no-folder`), as a path that is `.` or holds a `..` part or a backslash never is, and that row's project gets no rows; a name, key or path is on two rows (`<value>:twice`); or the file is older than the plugin's template (warn, `CLAUDE.md:<its version or none>`).
- Why: a project resolves by name, key or working directory only when one row matches and its folder is there. The text above the table loads in every session, so an old one may name commands the helper lacks or miss a rule every session needs.
- Fix: no file: `second-brain scaffold vault`. No table: `second-brain scaffold project <name> --path <path>` adds it, with the first project's row. A row: ask, then correct its path, change the name or key another row has, or remove the row of a project that is gone. Older: ask first, then replace the text above `## Projects` with that of `templates/vault-index.md.tmpl`, keep the user's added lines and the table, and set `index_version` to the template's.

### conventions

- Means: `obsidian-conventions.md` at the vault root is missing (fail), or its `conventions_version` is lower than the plugin's template (warn).
- Why: every skill and agent follows it for notes, tags and links, and an old one may name commands the helper no longer has.
- Fix: missing: `second-brain scaffold vault`, which overwrites nothing. Older: ask first, as the user may have edited it; on a yes, delete it and run `second-brain scaffold vault`, otherwise bring it in line with `templates/obsidian-conventions.md.tmpl` by hand.

### pull-request

- Means: the vault's `claude/pull-request.md`, the pull request description format, is missing (warn), or its `pull_request_version` is lower than the plugin's template or missing (warn, `claude/pull-request.md:<its version or none>`).
- Why: the index has every session write pull request descriptions in that format, so with no note each takes its own shape, and with an old one the old format.
- Fix: missing: `second-brain scaffold vault`, which overwrites nothing. Older and, as the row's fix says, never edited: `second-brain doctor --fix` replaces it with the template. Older and edited: ask first, then bring it in line with `templates/pull-request.md.tmpl` by hand, keep the user's added rules, and set `pull_request_version` to the template's.

### writing-style

- Means: the vault's `claude/writing-style.md`, the style Claude writes notes in, is missing (warn).
- Why: the index has every session write notes in that style, so with no note each takes its own.
- Fix: `second-brain scaffold vault`, which creates it and overwrites nothing.

### import

- Means: `~/.claude/CLAUDE.md` holds no `@` import of the vault's `CLAUDE.md`.
- Why: the index is then not in context, so a session knows no project until a skill is run by name.
- Fix: after a yes, add the line `@~/.claude/second-brain-vault/CLAUDE.md` to `~/.claude/CLAUDE.md`.

### global-rules

- Means: a line of `~/.claude/CLAUDE.md` names an index project by its name as a whole word or by its path (`<project>:<line number>`), or is an `@` import that names one (`<project>:@<line number>`). Not read: the index's import, the rows of a `## Projects` table, and the files `CLAUDE.md` imports.
- Why: that file loads in every session, so a rule for one project loads in all the others, and the project's own rules lack it.
- Fix: after a yes, move the line under `## Rules` in the project's `claude/README.md`. An import: remove the line, as the index already has Claude read the project's rules. A line true for every project stays: say so.

### links

- Means: a vault skill or agent is `missing`, `wrong-target`, `dangling`, `name-mismatch` or `duplicate` in `second-brain link --check`.
- Why: Claude Code registers only what is linked into `~/.claude/skills` and `~/.claude/agents`, so that one cannot be invoked by name.
- Fix: `second-brain link --apply`. It leaves `name-mismatch` and `duplicate`: rename one first. It leaves `wrong-target` with target `-`, a real file or folder holding the name: the user decides.

### foreign

- Means: a skill or agent sits in `~/.claude/skills` or `~/.claude/agents` and no vault `claude/` folder provides it: a real folder (`skills/<name>:folder`), a real file (`agents/<name>.md:file`), or a link and where it leads (`skills/<name>:link to <target>`). Not read: a folder with no `SKILL.md`, an `agents/README.md`, a file that is not `.md`, and a link into the plugin, which `double-registration` names.
- Why: it lives on this host alone, so it is not versioned with the vault, no `claude/README.md` lists it, and the vault's checks of skills and agents never read it.
- Fix: one at a time, ask whether it goes to the vault's `claude/`, to a project's `claude/`, or stays, then move it with `second-brain link move <skill or agent> <name> [--project <name>]`, as `## fix` in `skills/vault-doctor/SKILL.md` says. Nothing moves without the answer. One that stays warns again on the next check.

### double-registration

- Means: a link in `~/.claude/skills` or `~/.claude/agents` points inside the plugin, which registers its own pieces.
- Why: that skill or agent is then listed twice and its description loaded twice.
- Fix: remove that link, not its target: `unlink ~/.claude/skills/<name>` or `unlink ~/.claude/agents/<name>.md`.

### always-loaded-size

- Means: the vault's `CLAUDE.md` is over 60 lines, or `~/.claude/CLAUDE.md` is over 40.
- Why: both load in every session, so each extra line costs context in every conversation.
- Fix: move detail into the project's `README.md` or `claude/README.md`. The index keeps one row per project.

### descriptions

- Means: a skill or agent in the vault has no `description` (`<name>:none`), or one over 200 characters (`<name>:<length>`).
- Why: Claude Code picks a skill or agent by its description, so one with none is never picked. Every description loads in every session, so a long one costs context each time.
- Fix: write the `description` in its frontmatter as one sentence: what it does and when to use it. A long one: cut it to that.

### skill-size

- Means: a `SKILL.md` in the vault is over 150 lines.
- Why: the whole file loads on every run of the skill, with the parts for modes not in use.
- Fix: move the detail of one mode into a file beside `SKILL.md`, and have the skill read it only in that mode.

### old-namespace

- Means: a line still names a plugin skill or agent by its old name, `obsidian-dev-second-brain:<name>`: in a note of the vault, its own skills and agents included (`<vault path>:<line>`), or in `~/.claude/CLAUDE.md` (`~/.claude/CLAUDE.md:<line>`); or a string in a `settings.json` or `settings.local.json` holds `obsidian-dev-second-brain:`: in `~/.claude` (`~/.claude/<file>:<string>`), in `.claude/` at the vault root (`.claude/<file>:<string>`), or in `.claude/` of a repo a profile lists (`<repo>/.claude/<file>:<string>`). History is skipped as `agents/docs-keeper.md` `## Workflow 6 - A renamed command` step 5 lists it. A cut name, such as `obsidian-dev-second-brain:s`, is not read.
- Why: since 0.5.0 the plugin's skills run as `/odsb:<skill>` and its agents as `odsb:<agent>`, so an old name leads nowhere, and a permission rule with it allows or denies nothing.
- Fix: vault lines: after a yes, launch the `docs-keeper` agent on its `Workflow 6 - A renamed command`, from `obsidian-dev-second-brain:` to `odsb:`. A `~/.claude/CLAUDE.md` line: after a yes, write `odsb:` in place of the old name. A settings string: show it to the user to change in that file; never edit a settings file. Over five offenders: use the Grep tool for `obsidian-dev-second-brain:` on `~/.claude/CLAUDE.md`, `~/.claude/settings.json` and `~/.claude/settings.local.json`, and on the same two settings files in `.claude/` of each repo `second-brain repo <project>` lists; Read the two in `.claude/` at the vault root. The doctor names the next vault lines once the first are fixed.

### profile

- Means: the project's `claude/profile.md` is missing, lacks a frontmatter key or one of its seven sections, or has a `tasks_root`, `topics_root` or `sprints_root` with a `..` part or a backslash (`<key>:leaves-project`). A leading slash is no fault: every command drops it.
- Why: skills read the project's folders, cadence and repos from it, so they stop or look in a default folder that is not there. A root that leaves the project sends reads and writes outside it, so the doctor checks under that root's default and opens nothing through the value.
- Fix: no file: `/odsb:vault-setup adopt <path>`. A key or section: add it, shaped as `templates/profile.md.tmpl`. A root: ask where the folder is, then write it as a path inside the project with forward slashes, such as `tasks`.

### board

- Means: `tasks.base` is missing from the tasks root (fail); or, while a sprint is in progress, its `Current sprint` view filters on another sprint id (`tasks.base:<that id>`), has a filter in a form the helper does not read (`tasks.base:filter`), or is not there (`tasks.base:no-view`); or the project has `task_layout: archive` and the board's own `filters` block does not take the archive folder (`tasks.base:no-archive-filter`); or the project has `task_layout: status` and the board's own `filters` block does not take each of the five status folders (`tasks.base:no-status-filter`), each as a quoted path ending in `/<status>`; or the project has `task_layout: sprint`, with sprints on, and the board's own `filters` block has no line `file.folder.split("/")[<digits>] == aliases[0]`, the branch that takes a task in a group folder (`tasks.base:no-sprint-filter`). Or the project has `task_layout: status` or `sprint` and a child task, one whose `epic` names another task, and the board's own `filters` block has fewer than two such lines, as the branch that takes a task one level deeper adds the second (`tasks.base:no-child-filter`).
- Why: Obsidian draws the board from that file, so with none the tasks hub shows no table. With another id, Obsidian shows another sprint than `second-brain board`, which reads the task READMEs. Without the archive filter, Obsidian shows no archived task, though `second-brain board` lists them. Without the status filter, Obsidian shows no task in a status folder, though `second-brain board` lists them. Without the group folder branch, Obsidian shows no task in `backlog/` or a sprint's folder, though `second-brain board` lists them. Without the child branch, Obsidian shows no task one level deeper, such as a child inside its parent's folder, though `second-brain board` lists them.
- Fix: no file: `second-brain scaffold project <name> --path <path>` again, which writes the board and overwrites nothing. Every other fix here comes after a yes. Another id, or `filter`: write the view's filter line in `tasks.base` as `sprint == "<id>"`, in that order and with double quotes, with the sprint in progress that the row's fix names; `sprint open` rewrites only that form. Never add a second view by that name. No view: add the `Current sprint` view and the `sprint` and `carried_from` columns from `templates/tasks.base.tmpl`, with that id in the filter. `no-archive-filter`: replace the `filters` block at the top of `tasks.base` with the one in `templates/tasks.base.tmpl`, with `{{TASKS_PATH}}` the tasks root's vault path, `{{TASK_DEPTH}}` the number in the board's old `file.folder.split("/").length` line, and `{{ARCHIVE_DEPTH}}` that number plus 2. `no-status-filter`: replace the `filters` block as for `no-archive-filter`, with `{{STATUS_DEPTH}}` the `{{TASK_DEPTH}}` number plus 1; one replacement fixes both. `no-sprint-filter`: the same replacement, with the same numbers: its last branch takes a task in `backlog/` or a sprint's folder, and it fixes the other two filters too. `no-child-filter`: the same replacement, with `{{CHILD_DEPTH}}` the `{{TASK_DEPTH}}` number plus 2; its last branch takes a task one level deeper.

### hubs

- Means: a hub of the project is missing or empty: `README.md`, `claude/README.md`, or the `README.md` of the tasks root, of the topics root unless it is `.`, or of the sprints root when the project uses sprints.
- Why: the index has Claude read the first two before anything else, and the up-links of the tasks, the topics and the sprint notes lead to the others.
- Fix: `second-brain scaffold project <name> --path <path>` again, with the index row's name and path. It writes each missing hub from its template and overwrites nothing, so an empty hub stays: ask, then delete it first. A hub written again lacks the lines the old one had gained, such as the sprint links of the sprints hub.

### placeholders

- Means: a line of the project's `README.md`, `claude/README.md` or `claude/profile.md` still holds a placeholder of its template, such as `<A rule Claude must follow in this project, one per bullet.>` (`<path under the project>:<line>`). The owner's own angle brackets never count. Not read: frontmatter, fenced code and task READMEs.
- Why: every session reads the hub and `claude/README.md` before it works on the project, so an unwritten rule gives it nothing to follow, and a profile line left as template text answers no question a skill asks.
- Fix: ask the user, then write the rule or the fact the line asks for in its place, or delete the line when there is none. Never invent one. Keep the headings: the `profile` check needs the seven sections.

### task-template

- Means: the project's own task README template, `claude/templates/task-readme.md.tmpl` in the project, lacks a frontmatter key the helper writes (`aliases`, `title`, `status`, `next`, `branch`, `epic`, `type`) or a section the helper or story-tracker writes under (`## Status notes`, `## Discovery log`). Each offender is the key or the heading. A heading in fenced code does not count. A project with no such template is ok.
- Why: `second-brain task new` fills that template in place of the plugin's, so each new story starts without the key or the section: a story with no `aliases` fails `task-frontmatter`, the board and `task head` show another key as empty, and `task note` and story-tracker add the section where the project did not plan it.
- Fix: ask the user, then add each to the project's template, shaped as the plugin's `templates/task-readme.md.tmpl`. A story already made from it: add `aliases` with `second-brain task alias <ID> add <ID>`, another key with `second-brain task set <ID> <key>=<value>`, and a section's heading by hand.

### task-frontmatter

- Means: a task README's first alias is not its folder name, or it lacks `type: task` or the `type/task` tag.
- Why: the board shows the first alias as the task's name and the helper resolves ids through aliases, so the task shows under a wrong name or is not found.
- Fix: `second-brain task alias <ID> add <ID>`, then `second-brain task set <ID> type=task`, which also writes the tag. Another alias is first: reorder `aliases:` by hand.

### needs-a-status

- Means: a task's `status` is missing, or is not `planned`, `in-progress`, `in-review`, `done` or `abandoned`.
- Why: the `Active` view and the sprint close go by status, so the task drops out of the overview and blocks the close.
- Fix: ask the user for the real status, never guess it, then `second-brain task set <ID> status=<status>`.

### status-tag

- Means: a task's `status/` tag disagrees with `status`. `status/done` goes with `done` and `abandoned`, `status/active` with the rest.
- Why: the tag pane and tag searches then show a finished task as active, or an active one as finished.
- Fix: `second-brain doctor --fix`. It makes the tag follow `status` and changes nothing else in the task.

### yaml-traps

- Means: a task's frontmatter has an unquoted alias holding a colon and a space, an unquoted lone dash, or an unquoted sprint id.
- Why: YAML reads them as a key, an empty value and a date, so the alias is lost and the task misses the board's sprint filter.
- Fix: put the value in double quotes: `- "Runbook: rotate the API keys"`, `epic: "-"`, `sprint: "2026-01-14"`.

### alias-unique

- Means: one alias sits on two notes among the task READMEs and the hubs.
- Why: an id or a hub name then leads to two notes, so a lookup is ambiguous and a write can land on the wrong one.
- Fix: ask which note keeps the alias, then edit `aliases:` on the other. One ticket in two folders: ask which README is the task.

### no-readme

- Means: a task folder holds no `README.md`: a folder directly under the tasks root other than `archive` and the five status folders (`planned`, `in-progress`, `in-review`, `done`, `abandoned`), `backlog` and a group folder; one directly under a status folder, `backlog` or a group folder; or one directly under `archive/<YYYY>/`. A group folder is, in a sprint project, each folder directly under the tasks root with no README, such as a sprint's folder, and in another layout one that holds a task, which `task-layout` names. A status folder itself never needs a README, in every layout. Neither does `backlog` or a group folder. A folder with no README directly in a status folder, `backlog` or a group folder that holds a task, such as `done/<parent>/` that holds a child task, holds tasks one level deeper and needs none; each folder in it is read as one in a group folder is.
- Why: the board lists only that README, so the folder's work is on no board and no command finds it by id.
- Fix: a task: `second-brain task new <ID> --project <project> --title "<title>"` writes the README into the folder. A folder under a status folder: `task new` writes into `<tasks root>/<ID>/`, or `<tasks root>/planned/<ID>/` in a status project, or `<tasks root>/backlog/<ID>/` in a sprint project, so first move the folder there with `second-brain move`, unless it is there already, then run `task new`; in a status project, `second-brain task set <ID> status=<status>` then moves it to the folder of its status. A folder under `backlog/` or another group folder: the same; in a sprint project, `second-brain task set <ID> sprint=<id>`, with the sprint the user names, then moves it to the folder of that sprint. Not a task: tell the user.

### task-location

- Means: a note under the project has `type: task` in its frontmatter and is not `<tasks root>/<ID>/README.md`, `<tasks root>/<status>/<ID>/README.md` in one of the five status folders, `<tasks root>/<folder>/<ID>/README.md` in `backlog` or another group folder, or `<tasks root>/archive/<YYYY>/<ID>/README.md`. Each offender is the note's path under the project. A child task sits one level deeper, in `<tasks root>/<folder>/<parent>/<ID>/README.md`, and is in its place there too; a README inside a task whose `epic` does not name that task is not.
- Why: the board and the task commands read only those paths, so this task is on no board and no task command finds it by id.
- Fix: `second-brain move "<its vault path>" "<project path>/<tasks root>/<ID>/README.md"`, with `--dry-run` first. In a status project, move it to `<project path>/<tasks root>/<status>/<ID>/README.md`, with the task's status. In a sprint project, move it to `<project path>/<tasks root>/backlog/<ID>/README.md`; a task with a sprint is then named by `task-layout`, and `second-brain doctor --fix` moves it to the folder of its sprint. Then tie it to its topic: `second-brain task tag <ID> add <tag>`. Exit 6: that task has a README already, so ask which note is the task. Not a task: ask, then change its `type`. A task note inside another task's folder whose `epic` does not name that task: move it out to `<project path>/<tasks root>/<folder>/<ID>/README.md` with `second-brain move`, then `second-brain task set <ID> epic=<parent>` puts it under the parent it names.

### task-layout

- Means: the tasks do not follow the profile's `task_layout`. With `flat`, the default, an `archive` folder sits under the tasks root (`archive:flat`). With `archive`: an open task is inside the archive (`<ID>:open`); a done or abandoned task is still outside it `archive_after_days` days or more, 14 when the key is absent, after its newest status note or its sprint's end (`<ID>:to-archive`; a task with neither a status note nor a sprint is never named, as nothing dates it); or `archive_after_days` is not a whole number (`archive_after_days:not-a-number`). With `flat` or `archive`, a status folder holds a task (`<status>:flat` or `<status>:archive`, such as `done:flat`). With `status`: a task with a status of the five sits outside the folder of that status (`<ID>:<status>`, with the task's status), or a task sits in the archive (`archive:status`); a task with no status of the five is left to `needs-a-status`. In these three, a group folder that holds a task and is not the layout's own, `backlog` or a sprint's folder, is named (`<folder>:<layout>`, as `backlog:flat` or `2026-10-14:status`); in a status project each task in it is `<ID>:<status>` too. A `task_layout: sprint` with `uses_sprints: false` reads as `flat`, and is named too (`task_layout:no-sprints`). With `sprint`: a task sits outside the folder of its sprint, or outside `backlog/` with no sprint, wherever it is, in the archive or a status folder too (`<ID>:<folder>`, with the folder it belongs in, such as `EX-1:backlog`); or `sprint_folder` gives the sprint of a task no folder name, or, with no task in a sprint, gives none to a sprint ending today (`sprint_folder:invalid`). A task whose sprint gives no folder name is not named. With `status` or `sprint`, a child task, one whose `epic` names another task, belongs inside a folder named for its parent in that folder (`<ID>:<status>/<parent>` or `<ID>:<folder>/<parent>`), and a task whose `epic` names no single task of the project is `<ID>:unknown-<word>`, the word being the profile's `parent_label`, `epic` or `feature`. In every layout, a `parent_label` that is neither `feature` nor `epic` is `parent_label:invalid`.
- Why: the archive keeps the live tasks folder short, and an open task inside it is lost among the finished ones. With `status`, the folder shows a task's status, so a task outside the folder of its status is not where a reader looks for it. In another layout, nothing moves a task in a status folder when its status changes, so the folder comes to show a status the task no longer has, and nothing moves a task in `backlog/` or a sprint's folder when its sprint changes. With `sprint`, the folder shows a task's sprint, so a task outside it is not where a reader looks for it, and a pattern that names no folder leaves the task nowhere to go. `task_layout: sprint` with sprints off reads as `flat`, so no task moves at all. A child outside its parent's folder is not where a reader looks for it, and an `epic` that names no single task points at no parent story.
- Fix: `to-archive`: `second-brain doctor --fix` archives each one through `second-brain task archive <ID>`; it never moves an open task. A done task that nothing dates: `second-brain task archive <ID>`, after the user says so. A task whose folder in the archive exists already stays where it is, with the reason on stderr: show that folder to the user; after a yes, move it away with `second-brain move`, or delete it when it is empty, then run `--fix` again. `open`: ask whether the task is done; if not, `second-brain move "<its folder>" "<project path>/<tasks root>/<ID>"`. `flat`: ask whether the project should archive; on a yes set `task_layout: archive` in the profile, otherwise move each task in the archive back the same way. `not-a-number`: write the number of days. `<ID>:<status>` and `archive:status`: `second-brain doctor --fix` moves each task to the folder of its status, as `second-brain task set` does, then removes the archive's empty folders and each empty group folder other than the five status folders, such as `backlog/` or a sprint's folder; an empty status folder stays, and a folder that holds any other file, such as an archive README, stays. It moves task folders and rewrites links, so run `second-brain snapshot` before it and `second-brain compare` after it. A task whose new folder exists already stays where it is, with the reason on stderr: handle that folder as for an archive. A task with no status of the five stays where it is: `needs-a-status` names it. `<status>:flat` or `<status>:archive`: ask whether the project should keep each task in the folder of its status; on a yes set `task_layout: status` in the profile and run `second-brain doctor --fix`, otherwise move each task in that folder back to `<project path>/<tasks root>/<ID>` with `second-brain move`. `<ID>:<folder>`: `second-brain doctor --fix` moves each task to the folder of its sprint, or to `backlog/` with none, as `second-brain task set` does, then removes each empty group folder, a status folder too, whether or not a move emptied it, and the archive's empty folders. Run `second-brain snapshot` before it and `second-brain compare` after it, and handle a task whose new folder exists already as for an archive. A new `sprint_folder` renames the sprint folders the same way, through one `--fix`. `sprint_folder:invalid`: ask the user for a pattern with `<end>`, `<start>` or `<n>` that gives a folder name, and write it in `sprint_folder`, or remove the key for the end date; then run `second-brain doctor` again. `task_layout:no-sprints`: ask whether the project runs sprints; on a yes set `uses_sprints: true` in the profile, otherwise set another `task_layout`. `<folder>:flat` or `<folder>:archive`, for `backlog` or a sprint's folder: ask whether the project should keep each task in the folder of its sprint; on a yes set `task_layout: sprint` in the profile, with `uses_sprints: true` when sprints are off, and run `second-brain doctor --fix`, otherwise move each task in that folder back to `<project path>/<tasks root>/<ID>` with `second-brain move`; `--fix` alone moves nothing for it. `<folder>:status`: `--fix` moves each task in it, as the row names it `<ID>:<status>` too, then removes the folder once it is empty, so `no-readme` does not name it. `<ID>:<status>/<parent>` and `<ID>:<folder>/<parent>`: `second-brain doctor --fix` moves the child into that folder, as `second-brain task set` does, and removes the folder named for a parent that a move leaves empty. `<ID>:unknown-<word>`: `--fix` leaves the task where it is; ask the user which story is its parent, then run `second-brain task set <ID> epic=<parent>`, or `epic=` for none. `parent_label:invalid`: ask the user whether the project calls its parent stories features or epics, then write `feature` or `epic` in the profile, or remove the key for `epic`.

### topic-tags

- Means: a topic tag on a task matches no folder under the project's topics root.
- Why: a topic tag is a folder path, so this one leads to no docs and the task is missed when that topic is listed.
- Fix: `second-brain task tag <ID> remove <tag>`, then `add <tag>`. A folder spelled differently: `- <tag> -> <folder>` in the profile's `## Topics`.

### code-doc-map

- Means: a repository in the profile's `repos` has no row in the Code to doc map of its `## Docs` section.
- Why: docs-keeper reads that table for the docs to update after a change in that repository, so its docs get missed.
- Fix: add its rows under `### Code to doc map` in the profile, as `| <repo> | <change> | <docs> |`, or run `/odsb:vault-setup repo <project>`.

### repos

- Means: a repository of the project, in the profile, has a recorded location, from `repos_root` or `repo_paths`, whose folder is missing.
- Why: skills run git in that folder for branch checks and doc audits, so they check no code, or stop to ask where it is.
- Fix: correct `repos_root` or the `repo_paths` entry in the profile, then confirm with `second-brain repo <project>`.

### retired-subprojects

- Means: a note is left in `claude/subprojects/` (`claude/subprojects/<name>.md`), or a task has a `subproject` key (`<ID>:<value>`). Versions before 0.14.0 wrote them, and subprojects are retired. Only a project with one of them gets this row.
- Why: no command reads them, so a note's repos, rules and branch settings reach no session: `second-brain repo` lists the profile's repos, and the branch check and the build read the story's `repo` and the profile.
- Fix: a bulk change, after a yes: `second-brain doctor <project> --fix`. It adds each note's repos and `repo_paths` entries to the profile, sets `repo` on each of its tasks when it has one repo, moves its `## Rules` under `### <name>` at the end of `## Rules` in `claude/README.md`, drops its docs hub's line about it and removes it. It names on stderr what it cannot fold, and the note stays: a setting that is not the profile's, which the owner settles in the profile or the note; a section or a line of the note outside `## Rules`, which the owner moves where it belongs, such as a topic note, then deletes from the note; a task of a note with several repos, `second-brain task set <ID> repo=<repo> subproject=` with the repo the owner names; a key that names no note, `second-brain task set <ID> subproject=`. Run `--fix` again after.

### settings

- Means: a `validation_home` that is not `vault` or `repo`, compared without letter case, in the profile (`profile:validation_home`). Or a profile `lead_check_minutes` that is not empty, 10, 12, 15, 20, 30 or 60 (`lead_check_minutes:invalid`). Or a profile `build_pairs` that is not empty, 1, 2, 3, 4 or 5 (`build_pairs:invalid`). A `delivery` or `spec_home` key left from the retired spec flow is not read.
- Why: a `validation_home` that is not allowed means `vault`, so a repo's checks are looked for in the wrong place. A `lead_check_minutes` that is not allowed means 20, so the lead of a build checks on its orders at a pace the owner did not set. A `build_pairs` that is not allowed means 1, so a build runs one pair at a time where the owner may have meant more.
- Fix: ask which value was meant and write it in the profile, or remove the key.

### validation

- Means: a repo of the project has no `validation.md` (`<repo>:missing`), no `## <repo>` section in it (`<repo>:no-section`), a section with nothing under its heading (`<repo>:empty`), or a section that still holds the template's `<...>` text, or a placeholder an earlier template had (`<repo>:placeholders`). A repo whose `validation.md` is in the repo and whose location is not recorded: `<repo>:no-location`. A project with no repo and no `claude/validation.md`: `claude/validation.md:missing`. A check or user step whose `when:` is an old name, `each task` or `each build`: `<repo>:<name>:each-task` or `<repo>:<name>:each-build`, a check named by its command, or by its text when it has none, and a user step by its text.
- Why: the agents that build and review a change run the steps in its repo's section, so with none a change is called done on the builder's word. An old `when:` still runs, as its new name, but the file no longer says which stage runs it.
- Fix: `no-location`: record where the repo is, in `repos_root` or `repo_paths`. Otherwise run `second-brain validation new <project> <repo>`, which writes the file or adds the section and never changes one that is there. Then ask how the repo is set up and started, which checks must pass, how a change is checked as a user would and what a pass is. Look first in the repo's README, scripts and CI config; write only what the user confirms. Never invent a step. An old `when:`: write `each story` for `each task` and `each merge` for `each build`, as `### Validation` in `docs/contract.md` says.

### sprints

- Means: two sprints are in progress, one is in progress past its end date, or a task's `sprint` names a sprint with no note.
- Why: the `Current sprint` view filters on one sprint id, so the tasks of any other sprint show on no sprint list.
- Fix: close the extra or overdue sprint with `/odsb:scrum-master sprint-planning <project>`. A stray task: `second-brain task set <ID> sprint=<id>`, or `sprint=`. Tasks carried at a close point at the next sprint: open it with `/odsb:scrum-master sprint-planning <project>`, never re-point them. With `uses_sprints: false` in the profile, the one finding is a sprint note still in progress: set the key to `true`, close the sprint the same way, then set it back to `false`.

### unresolved-links

- Means: a note under the project holds a link that resolves to no file. Each offender is the note's path under the project and the line.
- Why: the link reaches no note; a bare alias link such as `[[EX-123]]` never resolves.
- Fix: `second-brain unresolved <project>` lists each link. Write it as a path link. A task's path is the one `second-brain find <ID> --project <project>` prints, written without `.md`: `[[<the path find prints, no .md>|EX-123]]`.

### bare-links

- Means: a task README links a file name that many notes share, such as `[[README]]`, with no path.
- Why: the link leads to one of the notes by that name, maybe the wrong one, and is never listed as unresolved.
- Fix: write the full vault path and the alias: `[[<project path>/docs/billing/invoices/README|Invoices Hub]]`.

### line-endings

- Means: a task README holds both LF and CRLF line endings.
- Why: a value that ends in a stray carriage return can fail to match in a search or a script, and every diff of the file is noisy.
- Fix: `second-brain snapshot` first, then one ending for the whole file. To LF: `perl -pi -e 's/\r$//' "<file>"`.

### depends-on

- Means: a task's `depends_on` links to no note, or to a path outside the vault (`<ID>:missing`), or the project's tasks wait on each other in a ring (`<ID>:cycle`, once for each task in it, and for a task that waits on itself). A link matches a task without letter case. `awk:error` (fail): the check could not run.
- Why: the board shows such a dependency as `missing`, and in a ring no task can start first.
- Fix: ask which task it waits on, then `second-brain task dep <ID> remove <ID>` and `second-brain task dep <ID> add <ID>`. A link the helper cannot match: edit the line in the note. A ring: ask which dependency is wrong and remove it.
