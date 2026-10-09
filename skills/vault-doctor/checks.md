# Doctor checks

One entry per check, named as `second-brain doctor` prints it, in the order of its table: ten for
the vault, then sixteen for each project. Every entry is a heading and three lines. Read an
entry only when its check is not `ok`, and run a fix only after the user agrees to it.

### pointer

- Means: `~/.claude/second-brain-vault` is missing, or does not lead to a folder that holds `.obsidian/`.
- Why: every helper command finds the vault through it, so each one exits 2 and no skill can run.
- Fix: `/obsidian-dev-second-brain:vault-setup init`, or by hand `ln -s "<vault folder>" ~/.claude/second-brain-vault`.

### index

- Means: `CLAUDE.md` at the vault root is missing, or has no `## Projects` table.
- Why: that table is the only list of projects, so none resolves by name, by ticket key or by working directory.
- Fix: no file: `second-brain scaffold vault`. No table: `second-brain scaffold project` adds it, with the first project's row.

### conventions

- Means: `obsidian-conventions.md` is missing from the vault root.
- Why: every skill and agent points to it for the rules on notes, tags and links, so they would write without them.
- Fix: `second-brain scaffold vault`. It creates the note and overwrites nothing.

### import

- Means: `~/.claude/CLAUDE.md` holds no `@` import of the vault's `CLAUDE.md`.
- Why: the index is then not in context, so a session does not know the projects until a skill is run by name.
- Fix: after a yes from the user, add the line `@~/.claude/second-brain-vault/CLAUDE.md` to `~/.claude/CLAUDE.md`.

### links

- Means: a vault skill or agent is `missing`, `wrong-target`, `dangling`, `name-mismatch` or `duplicate` in `second-brain link --check`.
- Why: Claude Code registers only what is linked into `~/.claude/skills` and `~/.claude/agents`, so that piece cannot be invoked by name.
- Fix: `second-brain link --apply`. It leaves `name-mismatch` and `duplicate` (rename one first), and `wrong-target` with target `-`, a real file or folder holding the name: the user decides.

### double-registration

- Means: a link in `~/.claude/skills` or `~/.claude/agents` points inside the plugin, which registers its own pieces.
- Why: the same skill or agent is registered twice, so it is listed twice and its description is loaded twice.
- Fix: remove that link, not its target: `unlink ~/.claude/skills/<name>` or `unlink ~/.claude/agents/<name>.md`.

### obsidian-cli

- Means: the Obsidian command line was not found, or Obsidian is not running.
- Why: the board, alias lookups, link checks and moves use Obsidian's index, so some checks are `skip` and no note can be moved.
- Fix: open Obsidian and turn on its command line interface (Settings, General). Confirm with `second-brain context`.

### always-loaded-size

- Means: the vault's `CLAUDE.md` is over 60 lines, or `~/.claude/CLAUDE.md` is over 40.
- Why: both files are loaded into every session, so each extra line is paid for in every conversation.
- Fix: move detail into the project's `README.md` or `claude/README.md`. The index keeps one row per project.

### descriptions

- Means: a skill or agent in the vault has a `description` over 200 characters.
- Why: every registered description is loaded into every session, so a long one costs context each time.
- Fix: cut the `description` in its frontmatter to one sentence: what it does and when to use it.

### skill-size

- Means: a `SKILL.md` in the vault is over 150 lines.
- Why: the whole file is loaded on every run of the skill, including the parts for modes that are not in use.
- Fix: move the detail of one mode into a file beside `SKILL.md`, and have the skill read it only in that mode.

### profile

- Means: the project's `claude/profile.md` is missing, or lacks a frontmatter key or one of its seven sections.
- Why: skills read the project's folders, cadence and repos from it, so they stop or look in a default folder that is not there.
- Fix: no file: `/obsidian-dev-second-brain:vault-setup adopt <path>`. A key or section: add it, shaped as `templates/profile.md.tmpl` under the plugin root.

### board

- Means: `tasks.base` is missing from the tasks root, or Obsidian cannot answer for one of its views.
- Why: status overviews and the sprint list are read from those views, so they come back empty or wrong.
- Fix: no file: `second-brain scaffold project <name> --path <path>` again. A view: repair it in `tasks.base`; `templates/tasks.base.tmpl` under the plugin root lists all five.

### index-fresh

- Means: the number of task READMEs on disk differs from the rows of the board's `All` view.
- Why: Obsidian's index lags behind the files, so a board answer can miss a task or show a stale one.
- Fix: `second-brain ob reload`, wait a few seconds, check again. Still off: report both counts to the user.

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
- Fix: `second-brain doctor --fix`. It makes the tag follow `status` and changes nothing else.

### yaml-traps

- Means: a task's frontmatter has an unquoted alias holding a colon and a space, an unquoted lone dash, or an unquoted sprint id.
- Why: YAML reads them as a key, an empty value and a date, so the alias is lost and the task misses the board's sprint filter.
- Fix: put the value in double quotes: `- "Runbook: rotate the API keys"`, `epic: "-"`, `sprint: "2026-01-14"`.

### alias-unique

- Means: one alias sits on two notes among the task READMEs and the hubs.
- Why: an id or a hub name then leads to two notes, so a lookup is ambiguous and a write can land on the wrong one.
- Fix: ask which note keeps the alias, then edit `aliases:` on the other. One ticket in two folders: ask which README is the task.

### no-readme

- Means: a folder directly under the tasks root holds no `README.md`.
- Why: the board lists only that README, so the folder's work is on no board and no command finds it by id.
- Fix: a task: `second-brain task new <ID> --project <project> --title "<title>"` writes the README into the folder. Not a task: tell the user.

### topic-tags

- Means: a topic tag on a task matches no folder under the project's topics root.
- Why: a topic tag is a folder path, so this one leads to no docs and the task is missed when that topic is listed.
- Fix: `second-brain task tag <ID> remove <tag>`, then `add <tag>`. A folder spelled differently: `- <tag> -> <folder>` in the profile's `## Topics`.

### code-doc-map

- Means: a repository in the profile's `repos` has no row in the Code to doc map of its `## Docs` section.
- Why: the docs-keeper agent uses that table to know which docs to update after a change in that repository, so its docs get missed.
- Fix: add its rows under `### Code to doc map` in the profile, as `| <repo> | <change> | <docs> |`, or run `/obsidian-dev-second-brain:vault-setup repo <project>`.

### repos

- Means: a repository listed in the profile has a recorded location, from `repos_root` or `repo_paths`, whose folder is missing.
- Why: skills run git in that folder for branch checks and doc audits, so they would check no code, or stop to ask where it is.
- Fix: correct `repos_root` or the `repo_paths` entry in the profile, then confirm with `second-brain repo <project>`.

### sprints

- Means: two sprints are in progress, one is in progress past its end date, or a task's `sprint` names a sprint with no note.
- Why: the `Current sprint` view filters on one sprint id, so the tasks of any other sprint show on no sprint list.
- Fix: close the extra or overdue sprint through the sprint skill. A stray task: `second-brain task set <ID> sprint=<id>`, or `sprint=`. Tasks carried at a close point at the next sprint: open it through the sprint skill, never re-point them.

### unresolved-links

- Means: Obsidian lists links, from notes under the project, that lead to no note.
- Why: a bare alias link such as `[[EX-123]]` does not resolve in Obsidian, so the note is not reachable from it.
- Fix: `second-brain ob unresolved verbose` lists them. Write each as a path link: `[[<project path>/tasks/EX-123/README|EX-123]]`.

### bare-links

- Means: a task README links a file name that many notes share, such as `[[README]]`, with no path.
- Why: Obsidian opens one of the notes by that name, maybe the wrong one, and never lists the link as unresolved.
- Fix: write the full vault path and the alias: `[[<project path>/docs/billing/invoices/README|Invoices Hub]]`.

### line-endings

- Means: a task README holds both LF and CRLF line endings.
- Why: a value that ends in a stray carriage return can fail to match in a search or a script, and every diff of the file is noisy.
- Fix: `second-brain snapshot` first, then one ending for the whole file. To LF: `perl -pi -e 's/\r$//' "<file>"`.
