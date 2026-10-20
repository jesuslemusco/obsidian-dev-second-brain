# Doctor checks

One entry per check, named as `second-brain doctor` prints it, in the order of its table: eleven for
the vault, then twenty for each project, and `subprojects` and `task-subproject` as well for a
project that has a subproject. Every entry is a heading, a blank line and three lines,
`Means`, `Why` and `Fix`, each on one line however long. Read an entry only when its check is not
`ok`, and run a fix only after the user agrees to it.

### pointer

- Means: `~/.claude/second-brain-vault` is missing, or does not lead to a folder that holds `.obsidian/`.
- Why: every helper command finds the vault through it, so each one exits 2 and no skill can run.
- Fix: `/obsidian-dev-second-brain:vault-setup init`, or by hand `second-brain pointer set "<vault folder>"`.

### index

- Means: `CLAUDE.md` at the vault root is missing or has no `## Projects` table; a row's path is not a folder in the vault (`<Project>:no-folder`), which a path that is `.` or holds a `..` part or a backslash never is, and such a row gets no project rows; a name, a key or a path is on two rows (`<value>:twice`); or the file is older than the plugin's template (warn, `CLAUDE.md:<its version or none>`).
- Why: that table is the only list of projects, so a project resolves by name, by ticket key or by working directory only when one row matches and its folder is there. The text above the table is in every session, so an old one may name commands the helper no longer has, or lack a rule every session needs, such as the one for finding and reading notes.
- Fix: no file: `second-brain scaffold vault`. No table: `second-brain scaffold project` adds it, with the first project's row. A row: ask, then correct its path, change the name or the key another row has, or remove the row of a project that is gone. Older: ask first; then replace the text above `## Projects` with the text of `templates/vault-index.md.tmpl`, keep the lines the user added and the table, and set `index_version` to the template's.

### conventions

- Means: `obsidian-conventions.md` is missing from the vault root (fail), or it is older than the plugin's template (warn): its `conventions_version` is lower, so it may name commands the helper no longer has.
- Why: every skill and agent points to it for the rules on notes, tags and links, so they would write without them.
- Fix: missing: `second-brain scaffold vault` creates the note and overwrites nothing. Older: ask first, because the user may have edited the note; on a yes, delete it and run `second-brain scaffold vault`, otherwise bring it in line with the template by hand.

### pull-request

- Means: `claude/pull-request.md`, the note that holds the pull request description format, is missing from the vault (warn), or it is older than the plugin's template (warn, `claude/pull-request.md:<its version or none>`): its `pull_request_version` is lower or missing.
- Why: the index tells every session to write a pull request description in that format, so without the note each one takes a shape of its own, and with an old note it takes the old one.
- Fix: missing: `second-brain scaffold vault` creates the note and overwrites nothing. Older and never edited, as the row's fix says: `second-brain doctor --fix` replaces it with the template. Older and edited: ask first; then bring it in line with `templates/pull-request.md.tmpl` by hand, keep the rules the user added, and set `pull_request_version` to the template's.

### import

- Means: `~/.claude/CLAUDE.md` holds no `@` import of the vault's `CLAUDE.md`.
- Why: the index is then not in context, so a session does not know the projects until a skill is run by name.
- Fix: after a yes from the user, add the line `@~/.claude/second-brain-vault/CLAUDE.md` to `~/.claude/CLAUDE.md`.

### global-rules

- Means: a line of `~/.claude/CLAUDE.md` names a project of the index, by its name as a whole word or by its path (`<project>:<line number>`), or is an `@` import that names one (`<project>:@<line number>`). The import of the index and the rows of a `## Projects` table are not read, and neither are the files `CLAUDE.md` imports.
- Why: that file is loaded in every session, so a rule about one project loads in all the others, and the project's own rules never get it.
- Fix: after a yes from the user, move the line under `## Rules` in the project's `claude/README.md`, or in its subproject's note `claude/subprojects/<name>.md` when the rule is about one subproject. An import: remove the line, because the index already tells Claude to read the project's rules. A line that holds for every project stays: say so and leave it.

### links

- Means: a vault skill or agent is `missing`, `wrong-target`, `dangling`, `name-mismatch` or `duplicate` in `second-brain link --check`.
- Why: Claude Code registers only what is linked into `~/.claude/skills` and `~/.claude/agents`, so that piece cannot be invoked by name.
- Fix: `second-brain link --apply`. It leaves `name-mismatch` and `duplicate` (rename one first), and `wrong-target` with target `-`, a real file or folder holding the name: the user decides.

### double-registration

- Means: a link in `~/.claude/skills` or `~/.claude/agents` points inside the plugin, which registers its own pieces.
- Why: the same skill or agent is registered twice, so it is listed twice and its description is loaded twice.
- Fix: remove that link, not its target: `unlink ~/.claude/skills/<name>` or `unlink ~/.claude/agents/<name>.md`.

### always-loaded-size

- Means: the vault's `CLAUDE.md` is over 60 lines, or `~/.claude/CLAUDE.md` is over 40.
- Why: both files are loaded into every session, so each extra line is paid for in every conversation.
- Fix: move detail into the project's `README.md` or `claude/README.md`. The index keeps one row per project.

### descriptions

- Means: a skill or agent in the vault has no `description` (`<name>:none`), or one over 200 characters (`<name>:<length>`).
- Why: Claude Code decides from the description when to use a skill or an agent, so one without is never picked. Every registered description is loaded into every session, so a long one costs context each time.
- Fix: write the `description` in its frontmatter as one sentence: what it does and when to use it. A long one: cut it to that.

### skill-size

- Means: a `SKILL.md` in the vault is over 150 lines.
- Why: the whole file is loaded on every run of the skill, including the parts for modes that are not in use.
- Fix: move the detail of one mode into a file beside `SKILL.md`, and have the skill read it only in that mode.

### profile

- Means: the project's `claude/profile.md` is missing, lacks a frontmatter key or one of its seven sections, or has a root that leaves the project (`<key>:leaves-project`): `tasks_root`, `topics_root` or `sprints_root` with a `..` part or a backslash. A slash in front is no fault: every command drops it.
- Why: skills read the project's folders, cadence and repos from it, so they stop or look in a default folder that is not there. A root that leaves the project sends them to read and write outside it; the doctor checks under that root's default and opens nothing through the value.
- Fix: no file: `/obsidian-dev-second-brain:vault-setup adopt <path>`. A key or section: add it, shaped as `templates/profile.md.tmpl` under the plugin root. A root: ask where the folder is, then write it as a path inside the project with forward slashes, such as `tasks`.

### board

- Means: `tasks.base` is missing from the tasks root (fail); or, while a sprint is in progress, its `Current sprint` view filters on another sprint id (`tasks.base:<that id>`), its filter is in a form the helper does not read (`tasks.base:filter`), or the board has no such view (`tasks.base:no-view`); or the project has a subproject and the board has no `By subproject` view (`tasks.base:no-subproject-view`), which a board made before that view was added lacks.
- Why: Obsidian shows the task board from that file, so with no file the tasks hub that embeds it shows no table. `second-brain board` still answers: it reads the task READMEs and goes by the sprint in progress, so with another id in the view Obsidian shows another sprint than the helper reports. Without `By subproject`, Obsidian has no view that shows the tasks of one subproject together.
- Fix: no file: `second-brain scaffold project <name> --path <path>` again; it writes the board and overwrites nothing. Another id, or `filter`: after a yes, write the filter line of the view in `tasks.base` as `sprint == "<id>"`, in that order and with double quotes, with the sprint in progress that the row's fix names; `sprint open` rewrites that form alone. Never add a second view by that name. No view: after a yes, add the `Current sprint` view and the `sprint` and `carried_from` columns from `templates/tasks.base.tmpl`, with that id in the filter. `no-subproject-view`: after a yes, copy the `By subproject` view and the `note.subproject` property from `templates/tasks.base.tmpl` into `tasks.base`.

### hubs

- Means: a hub of the project is missing or empty: `README.md`, `claude/README.md`, or the `README.md` of the tasks root, of the topics root unless it is `.`, or of the sprints root when the project uses sprints.
- Why: the index tells Claude to read the first two before anything else, and the up-links of the tasks, the topics and the sprint notes lead to the others. `second-brain scaffold project` creates all of them.
- Fix: `second-brain scaffold project <name> --path <path>` again, with the name and the path of the index row. It writes each missing hub from its template and overwrites nothing, so it keeps an empty file: ask, then delete that one first. A hub that comes back is a new one, without the lines the old one had gained, such as the sprint links of the sprints hub.

### placeholders

- Means: a line of the project's `README.md`, `claude/README.md`, `claude/profile.md` or a note in `claude/subprojects/` still holds text in angle brackets from the template it was written from, such as `<A rule Claude must follow in this project, one per bullet.>` (`<path under the project>:<line>`). Only the template's own placeholders count, so the owner's angle brackets never do; frontmatter, fenced code and task READMEs are not read.
- Why: every session reads the hub and `claude/README.md` before it works on the project, so a rule never written gives it nothing to follow, and a profile line left as template text answers no question a skill asks.
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
- Why: the tag pane and tag searches go by the tag, so they show a finished task as active, or an active one as finished.
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

- Means: a task folder holds no `README.md`: a folder directly under the tasks root other than `archive`, or one directly under a year of the archive, `archive/<YYYY>/`.
- Why: the board lists only that README, so the folder's work is on no board and no command finds it by id.
- Fix: a task: `second-brain task new <ID> --project <project> --title "<title>"` writes the README into the folder. Not a task: tell the user.

### task-location

- Means: a note under the project has `type: task` in its frontmatter and is not `<tasks root>/<ID>/README.md` or `<tasks root>/archive/<YYYY>/<ID>/README.md`: it is filed under a topic, loose in the tasks root, deeper inside a task folder, or in the archive with no year folder. Each offender is the note's path under the project.
- Why: the board and the task commands read only the README directly inside a folder of the tasks root, so this task is on no board and no task command finds it by id.
- Fix: `second-brain move "<its vault path>" "<project path>/<tasks root>/<ID>/README.md"`, with `--dry-run` first; it rewrites the links to the note. Then tie it to its topic: `second-brain task tag <ID> add <tag>`. Exit 6: that task has a README already, so ask which note is the task. Not a task: ask, then change its `type`.

### task-layout

- Means: the tasks do not follow the profile's `task_layout`. With `flat`, the default, an `archive` folder sits under the tasks root (`archive:flat`). With `archive`, an open task is inside the archive (`<ID>:open`), a done or abandoned task is still outside it `archive_after_days` days or more after its newest status note or its sprint's end, 14 days when the key is absent (`<ID>:to-archive`), or `archive_after_days` is not a whole number (`archive_after_days:not-a-number`).
- Why: the archive keeps the live tasks folder short, so a done task left out of it makes the folder grow again, and an open task inside it is lost among the finished ones.
- Fix: `to-archive`: `second-brain doctor --fix` archives each one through `second-brain task archive <ID>` and prints a `fixed:` line per task; it never moves an open task. `open`: ask whether the task is done; if not, `second-brain move "<its folder>" "<project path>/<tasks root>/<ID>"`. `flat`: ask whether the project should archive; on a yes set `task_layout: archive` in the profile, otherwise move each task in the archive back the same way. `not-a-number`: write the number of days.

### topic-tags

- Means: a topic tag on a task matches no folder under the project's topics root.
- Why: a topic tag is a folder path, so this one leads to no docs and the task is missed when that topic is listed.
- Fix: `second-brain task tag <ID> remove <tag>`, then `add <tag>`. A folder spelled differently: `- <tag> -> <folder>` in the profile's `## Topics`.

### code-doc-map

- Means: a repository in the profile's `repos` has no row in the Code to doc map of its `## Docs` section.
- Why: the docs-keeper agent uses that table to know which docs to update after a change in that repository, so its docs get missed.
- Fix: add its rows under `### Code to doc map` in the profile, as `| <repo> | <change> | <docs> |`, or run `/obsidian-dev-second-brain:vault-setup repo <project>`.

### repos

- Means: a repository of the project, listed in the profile or in a subproject note, has a recorded location, from `repos_root` or `repo_paths`, whose folder is missing.
- Why: skills run git in that folder for branch checks and doc audits, so they would check no code, or stop to ask where it is.
- Fix: correct `repos_root` or the `repo_paths` entry in the profile, then confirm with `second-brain repo <project>`.

### subprojects

- Means: a note in `claude/subprojects/` is off: its `type` is not `subproject` (`<name>:type`), it lists no repos (`<name>:no-repos`), it has no docs folder `<topics root>/<name>/` (`<name>:no-docs`), a repo of it has no row in the profile's Code to doc map (`<name>/<repo>:no-map-row`), a repo's folder is missing (`<name>/<repo>:missing`) or no location is recorded for it (`<name>/<repo>:no-location`), or two subprojects list one repo (`<repo>:twice`). Only a project with a subproject gets this row.
- Why: a working directory resolves to a subproject through its repos, the branch check reads its settings from the note, and docs-keeper finds its docs through the map row and the docs folder. A repo in two subprojects resolves to neither.
- Fix: a type or repos: edit the note's frontmatter, `type: subproject` and `repos: [<repo>]`. No docs: `second-brain scaffold subproject <project> <name>` writes the docs hub and overwrites nothing. A map row: add `| <repo> | <change> | <topics root>/<name>/... |` under `### Code to doc map` in the profile, after asking which docs follow it. A location: `repos_root` in the profile, or `"<repo>=<path>"` in the note's `repo_paths`. Twice: ask which subproject keeps the repo, then remove it from the other note.

### task-subproject

- Means: a task's `subproject` names no note in `claude/subprojects/`, compared without letter case (`<ID>:<value>`): the note was renamed or removed, or the value was written by hand. Only a project with a subproject gets this row.
- Why: the board's `By subproject` view and `second-brain board <project> --subproject <name>` file the task under a name that leads nowhere, and the skills read a subproject's branches and docs from its note, so for this task they find none.
- Fix: ask which subproject the task belongs to, then `second-brain task set <ID> subproject=<name>`, which checks the name. A task in no subproject: `second-brain task set <ID> subproject=`.

### sprints

- Means: two sprints are in progress, one is in progress past its end date, or a task's `sprint` names a sprint with no note.
- Why: the `Current sprint` view filters on one sprint id, so the tasks of any other sprint show on no sprint list.
- Fix: close the extra or overdue sprint through the sprint skill. A stray task: `second-brain task set <ID> sprint=<id>`, or `sprint=`. Tasks carried at a close point at the next sprint: open it through the sprint skill, never re-point them. With `uses_sprints: false` in the profile the one finding is a sprint note still in progress: set the key to `true`, close the sprint through the sprint skill, then set it to `false` again.

### unresolved-links

- Means: a note under the project holds a link that resolves to no file. Each offender is the note's path under the project and the line.
- Why: a bare alias link such as `[[EX-123]]` does not resolve, so the note is not reachable from it.
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

- Means: a task's `depends_on` holds a link to no note, or to a path outside the vault (`<ID>:missing`), or tasks of the project wait on each other in a ring (`<ID>:cycle`, once for each task in it, and for a task that waits on itself). A link matches a task without letter case. `awk:error` (fail): the check could not run.
- Why: the board shows such a dependency as `missing`, and in a ring no task can start first, so the work it records is blocked for good.
- Fix: ask which task it waits on, then `second-brain task dep <ID> remove <ID>` and `second-brain task dep <ID> add <ID>`. A link the helper cannot match: edit the line in the note. A ring: ask which dependency is wrong and remove it.
