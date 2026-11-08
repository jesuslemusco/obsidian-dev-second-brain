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

### import

- Means: `~/.claude/CLAUDE.md` holds no `@` import of the vault's `CLAUDE.md`.
- Why: the index is then not in context, so a session knows no project until a skill is run by name.
- Fix: after a yes, add the line `@~/.claude/second-brain-vault/CLAUDE.md` to `~/.claude/CLAUDE.md`.

### global-rules

- Means: a line of `~/.claude/CLAUDE.md` names an index project by its name as a whole word or by its path (`<project>:<line number>`), or is an `@` import that names one (`<project>:@<line number>`). Not read: the index's import, the rows of a `## Projects` table, and the files `CLAUDE.md` imports.
- Why: that file loads in every session, so a rule for one project loads in all the others, and the project's own rules lack it.
- Fix: after a yes, move the line under `## Rules` in the project's `claude/README.md`, or in `claude/subprojects/<name>.md` for a rule about one subproject. An import: remove the line, as the index already has Claude read the project's rules. A line true for every project stays: say so.

### links

- Means: a vault skill or agent is `missing`, `wrong-target`, `dangling`, `name-mismatch` or `duplicate` in `second-brain link --check`.
- Why: Claude Code registers only what is linked into `~/.claude/skills` and `~/.claude/agents`, so that one cannot be invoked by name.
- Fix: `second-brain link --apply`. It leaves `name-mismatch` and `duplicate`: rename one first. It leaves `wrong-target` with target `-`, a real file or folder holding the name: the user decides.

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

- Means: `tasks.base` is missing from the tasks root (fail); or, while a sprint is in progress, its `Current sprint` view filters on another sprint id (`tasks.base:<that id>`), has a filter in a form the helper does not read (`tasks.base:filter`), or is not there (`tasks.base:no-view`); or the project has a subproject and the board has no `By subproject` view (`tasks.base:no-subproject-view`); or the project has `task_layout: archive` and the board's own `filters` block does not take the archive folder (`tasks.base:no-archive-filter`).
- Why: Obsidian draws the board from that file, so with none the tasks hub shows no table. With another id, Obsidian shows another sprint than `second-brain board`, which reads the task READMEs. Without `By subproject`, no view groups one subproject's tasks. Without the archive filter, Obsidian shows no archived task, though `second-brain board` lists them.
- Fix: no file: `second-brain scaffold project <name> --path <path>` again, which writes the board and overwrites nothing. Every other fix here comes after a yes. Another id, or `filter`: write the view's filter line in `tasks.base` as `sprint == "<id>"`, in that order and with double quotes, with the sprint in progress that the row's fix names; `sprint open` rewrites only that form. Never add a second view by that name. No view: add the `Current sprint` view and the `sprint` and `carried_from` columns from `templates/tasks.base.tmpl`, with that id in the filter. `no-subproject-view`: copy the `By subproject` view and the `note.subproject` property from `templates/tasks.base.tmpl` into `tasks.base`. `no-archive-filter`: replace the `filters` block at the top of `tasks.base` with the one in `templates/tasks.base.tmpl`, with `{{TASKS_PATH}}` the tasks root's vault path, `{{TASK_DEPTH}}` the number in the board's old `file.folder.split("/").length` line, and `{{ARCHIVE_DEPTH}}` that number plus 2.

### hubs

- Means: a hub of the project is missing or empty: `README.md`, `claude/README.md`, or the `README.md` of the tasks root, of the topics root unless it is `.`, or of the sprints root when the project uses sprints.
- Why: the index has Claude read the first two before anything else, and the up-links of the tasks, the topics and the sprint notes lead to the others.
- Fix: `second-brain scaffold project <name> --path <path>` again, with the index row's name and path. It writes each missing hub from its template and overwrites nothing, so an empty hub stays: ask, then delete it first. A hub written again lacks the lines the old one had gained, such as the sprint links of the sprints hub.

### placeholders

- Means: a line of the project's `README.md`, `claude/README.md`, `claude/profile.md` or a note in `claude/subprojects/` still holds a placeholder of its template, such as `<A rule Claude must follow in this project, one per bullet.>` (`<path under the project>:<line>`). The owner's own angle brackets never count. Not read: frontmatter, fenced code and task READMEs.
- Why: every session reads the hub and `claude/README.md` before it works on the project, so an unwritten rule gives it nothing to follow, and a profile line left as template text answers no question a skill asks.
- Fix: ask the user, then write the rule or the fact the line asks for in its place, or delete the line when there is none. Never invent one. Keep the headings: the `profile` check needs the seven sections.

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

- Means: a task folder holds no `README.md`: a folder directly under the tasks root other than `archive`, or one directly under `archive/<YYYY>/`.
- Why: the board lists only that README, so the folder's work is on no board and no command finds it by id.
- Fix: a task: `second-brain task new <ID> --project <project> --title "<title>"` writes the README into the folder. Not a task: tell the user.

### task-location

- Means: a note under the project has `type: task` in its frontmatter and is not `<tasks root>/<ID>/README.md` or `<tasks root>/archive/<YYYY>/<ID>/README.md`. Each offender is the note's path under the project.
- Why: the board and the task commands read only those paths, so this task is on no board and no task command finds it by id.
- Fix: `second-brain move "<its vault path>" "<project path>/<tasks root>/<ID>/README.md"`, with `--dry-run` first. Then tie it to its topic: `second-brain task tag <ID> add <tag>`. Exit 6: that task has a README already, so ask which note is the task. Not a task: ask, then change its `type`.

### task-layout

- Means: the tasks do not follow the profile's `task_layout`. With `flat`, the default, an `archive` folder sits under the tasks root (`archive:flat`). With `archive`: an open task is inside the archive (`<ID>:open`); a done or abandoned task is still outside it `archive_after_days` days or more, 14 when the key is absent, after its newest status note or its sprint's end (`<ID>:to-archive`; a task with neither a status note nor a sprint is never named, as nothing dates it); or `archive_after_days` is not a whole number (`archive_after_days:not-a-number`).
- Why: the archive keeps the live tasks folder short, and an open task inside it is lost among the finished ones.
- Fix: `to-archive`: `second-brain doctor --fix` archives each one through `second-brain task archive <ID>`; it never moves an open task. A done task that nothing dates: `second-brain task archive <ID>`, after the user says so. A task whose folder in the archive exists already stays where it is, with the reason on stderr: show that folder to the user; after a yes, move it away with `second-brain move`, or delete it when it is empty, then run `--fix` again. `open`: ask whether the task is done; if not, `second-brain move "<its folder>" "<project path>/<tasks root>/<ID>"`. `flat`: ask whether the project should archive; on a yes set `task_layout: archive` in the profile, otherwise move each task in the archive back the same way. `not-a-number`: write the number of days.

### topic-tags

- Means: a topic tag on a task matches no folder under the project's topics root.
- Why: a topic tag is a folder path, so this one leads to no docs and the task is missed when that topic is listed.
- Fix: `second-brain task tag <ID> remove <tag>`, then `add <tag>`. A folder spelled differently: `- <tag> -> <folder>` in the profile's `## Topics`.

### code-doc-map

- Means: a repository in the profile's `repos` has no row in the Code to doc map of its `## Docs` section.
- Why: docs-keeper reads that table for the docs to update after a change in that repository, so its docs get missed.
- Fix: add its rows under `### Code to doc map` in the profile, as `| <repo> | <change> | <docs> |`, or run `/odsb:vault-setup repo <project>`.

### repos

- Means: a repository of the project, in the profile or a subproject note, has a recorded location, from `repos_root` or `repo_paths`, whose folder is missing.
- Why: skills run git in that folder for branch checks and doc audits, so they check no code, or stop to ask where it is.
- Fix: correct `repos_root` or the `repo_paths` entry in the profile, then confirm with `second-brain repo <project>`.

### subprojects

- Means: a note in `claude/subprojects/` is off: its `type` is not `subproject` (`<name>:type`), it lists no repos (`<name>:no-repos`), it has no docs folder `<topics root>/<name>/` (`<name>:no-docs`), a repo of it has no row in the profile's Code to doc map (`<name>/<repo>:no-map-row`), a repo's folder is missing (`<name>/<repo>:missing`) or no location is recorded for it (`<name>/<repo>:no-location`), or two subprojects list one repo (`<repo>:twice`). Only a project with a subproject gets this row.
- Why: a working directory resolves to a subproject through its repos, the branch check reads its settings from the note, and docs-keeper finds its docs through the map row and the docs folder. A repo in two subprojects resolves to neither.
- Fix: a type or repos: edit the note's frontmatter, `type: subproject` and `repos: [<repo>]`. No docs: `second-brain scaffold subproject <project> <name>` writes the docs hub and overwrites nothing. A map row: ask which docs follow the repo, then add `| <repo> | <change> | <topics root>/<name>/... |` under `### Code to doc map` in the profile. A location: `repos_root` in the profile, or `"<repo>=<path>"` in the note's `repo_paths`. Twice: ask which subproject keeps the repo, then remove it from the other note.

### task-subproject

- Means: a task's `subproject` names no note in `claude/subprojects/`, compared without letter case (`<ID>:<value>`). Only a project with a subproject gets this row.
- Why: the `By subproject` view and `second-brain board <project> --subproject <name>` file the task under a name that leads nowhere, and the skills find no branches or docs for it, as they read them from the note.
- Fix: ask which subproject the task belongs to, then `second-brain task set <ID> subproject=<name>`, which checks the name. A task in no subproject: `second-brain task set <ID> subproject=`.

### delivery

- Means: a `delivery` that is not `direct` or `spec`, or a `spec_home` or `validation_home` that is not `vault` or `repo`, compared without letter case: in the profile (`profile:<key>`), a subproject note (`<name>:<key>`) or a task (`<ID>:delivery`).
- Why: a value that is not allowed means the default, so a story meant to be built from a spec is built straight from its README, or its spec and checks are looked for in the wrong place.
- Fix: ask which value was meant and write it. A task's `delivery`: `second-brain task set <ID> delivery=<direct or spec>`, or `delivery=` to take the subproject's or the profile's. A key in the profile or a subproject note: edit it there.

### validation

- Means: a repo of the project has no `validation.md` (`<repo>:missing`), no `## <repo>` section in it (`<repo>:no-section`), a section with nothing under its heading (`<repo>:empty`), or a section that still holds the template's `<...>` text, or a placeholder an earlier template had (`<repo>:placeholders`). A repo whose `validation.md` is in the repo and whose location is not recorded: `<repo>:no-location`. A project with no repo and no `claude/validation.md`: `claude/validation.md:missing`.
- Why: the agents that build and review a change run the steps in its repo's section, so with none a change is called done on the builder's word.
- Fix: `no-location`: record where the repo is, in `repos_root` or `repo_paths`. Otherwise run `second-brain validation new <project> <repo>`, which writes the file or adds the section and never changes one that is there. Then ask how the repo is set up and started, which checks must pass, how a change is checked as a user would and what a pass is. Look first in the repo's README, scripts and CI config; write only what the user confirms. Never invent a step.

### spec-trace

- Means: an open story whose `delivery`, its own or inherited, is `spec` has a criterion, a `- [ ]`, `- [x]` or `- [X]` line under its README's `## Acceptance criteria`, that no `- Serves:` line of its `requirements.md` names (`<ID>:AC<n>`, the n-th criterion); or a `## R<n>` requirement has no `- Serves:` line, names no criterion, or names an item that is not an `AC<n>` the story has (`<ID>:R<n>`). Not read: a done or abandoned story, one with no `requirements.md`, and one whose spec is in a repo with no recorded location or no folder.
- Why: the `- Serves:` lines show the owner that the spec covers the story. A criterion no requirement serves is never built or reviewed; a requirement that serves none is work the story did not ask for.
- Fix: add the criterion's `AC<n>` to the `- Serves:` line of the requirement that meets it, or write a requirement for it, and give every requirement a `- Serves:` line that names only criteria the story has. Ask the owner which requirement meets a criterion; `--fix` changes nothing here.

### sprints

- Means: two sprints are in progress, one is in progress past its end date, or a task's `sprint` names a sprint with no note.
- Why: the `Current sprint` view filters on one sprint id, so the tasks of any other sprint show on no sprint list.
- Fix: close the extra or overdue sprint with `/odsb:sprint close <project>`. A stray task: `second-brain task set <ID> sprint=<id>`, or `sprint=`. Tasks carried at a close point at the next sprint: open it with `/odsb:sprint open <project>`, never re-point them. With `uses_sprints: false` in the profile, the one finding is a sprint note still in progress: set the key to `true`, close the sprint the same way, then set it back to `false`.

### unresolved-links

- Means: a note under the project holds a link that resolves to no file. Each offender is the note's path under the project and the line.
- Why: the link reaches no note; a bare alias link such as `[[EX-123]]` never resolves.
- Fix: `second-brain unresolved <project>` lists each link. Write it as a path link: `[[<project path>/tasks/EX-123/README|EX-123]]`.

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
