# Changelog

## 0.3.0 - unreleased

- The README has an Update section: refresh the marketplace, update the plugin, restart Claude Code,
  then run the doctor's `check` and `fix`. It says what to do when the update does not take, and
  how to turn on auto-update for the `second-brain` marketplace.
- The guide has a Releases section: `version` changes in one commit on `main`, after the release
  pull request is merged, and that commit is tagged `v<version>`. An early copy of 0.2.0 never
  moved to the final 0.2.0, because both say `0.2.0`; 0.3.0 does move.
- A new doctor check, `placeholders`, warns about each line of a project's hub, `claude/README.md`,
  profile or subproject note that still holds the `<...>` text of its template, such as
  `<A rule Claude must follow in this project, one per bullet.>`. Only the template's own text
  counts, and task READMEs are not read. `vault-setup` asks for the project's paragraph and rules
  after `scaffold project`.
- The pull request format opens with a `Goal` section, one or two lines on why the pull request
  exists. Every heading is bold, and every bullet starts with a bold label, as in
  `- **doctor:** warns on an old index`; a heading with nothing to say gets `- **None.**`. The
  description is written from the branch, with `git log <target>..<source>` and
  `git diff <target>...<source>`, both branches named, never from memory of the work.
- The pull request note carries a version, `pull_request_version: 2`, in frontmatter. The doctor's
  `pull-request` check warns about a note older than the plugin's template. `doctor --fix`
  replaces an old note that was never edited with the template. An edited one is left alone, and
  its row says to bring it in line with `templates/pull-request.md.tmpl` by hand: add the goal,
  bold the headings and the labels, take the rules, keep your own, and set
  `pull_request_version: 2`.
- The board shows a task's `subproject` and has a `By subproject` view, which groups the active
  tasks by subproject. `scaffold project` writes it into a new board. The doctor's `board` check
  warns when a project with a subproject has a board without it (`tasks.base:no-subproject-view`).
- `second-brain board <project> [view] --subproject <name>` lists only the tasks of that
  subproject, and `board <project> "By subproject"` lists the active tasks by subproject.
- Inside a subproject's repo, the story-tracker status overview lists that subproject's stories.
- The doctor's new `task-subproject` check warns about a task whose `subproject` names no
  subproject of the project (`<ID>:<value>`). Only a project with a subproject gets the row.
- A profile key, `task_layout`, keeps the tasks folder short: `flat`, the default, or `archive`.
  With `archive`, `second-brain task archive <ID>` moves a done or abandoned task once, through
  `move`, to `tasks/archive/<YYYY>/<ID>/`, writes `archived: "<date>"` and rewrites the links to
  it. When anything is at that path already, even an empty folder, it moves nothing and exits 6.
  Every command still finds the task by id, at either depth, in both layouts.
- The board file that `scaffold project` writes lists archived tasks too. A board written before
  lists only the live ones in Obsidian until its filters block is copied from
  `templates/tasks.base.tmpl`. In a project with `task_layout: archive`, the doctor's `board` check
  warns about such a board (`tasks.base:no-archive-filter`).
- `task new` refuses an id that is archived, and the id `archive`, the archive's folder.
- A doctor check, `task-layout`, keeps a project in its layout: an `archive` folder in a `flat`
  project, an open task in the archive, and a done task left out of it, all warn. A done task is
  left out once `archive_after_days`, 14 by default, have passed since its newest status note or
  its sprint's end; one with neither does not warn, and `task archive` moves it by hand.
  `doctor --fix` archives those tasks through `task archive`, one `fixed:` line each, and never
  moves an open task.
- `no-readme` and `task-location` accept a task at `tasks/archive/<YYYY>/<ID>/README.md`.
- The vault index has a rule for finding and reading notes, under
  `## Rules for notes that most often go wrong`: `second-brain find`, `search`, `task head`, then
  `outline` and a ranged read, a whole note last, and never grep, cat or sed on vault files. Every
  session has it without running `second-brain conventions`.
- The plugin's index template is now at `index_version: 3`, so the doctor's `index` check warns
  about a vault index without the rule. Add the rule from `templates/vault-index.md.tmpl` under
  `## Rules for notes that most often go wrong`, keep your own lines and the table, and set
  `index_version: 3`. The `vault-doctor` skill does this after asking.
- A new PreToolUse hook warns Claude when a Grep call, a Read of a whole task note, or a shell
  grep, cat or sed reaches into the vault, and names the helper commands to use. It only adds
  context: it never blocks a call and never approves one. Edits pass as before.
- The SessionStart hook prints the session's context in a repo of a project: the project, the
  subproject, the sprint in progress, the branch and the ticket it names, and that ticket's story
  with its status and next step, or `story: none - run story-tracker start`. It ends with the
  rule for finding and reading notes. It reads the repo's files and runs no git command, and
  outside every project it prints nothing, as before.
- story-tracker writes a new story's `subproject` from the `subproject:` line of
  `second-brain context`, and asks which subproject, or none, when the repo is in none of a
  project that has some. A story set to `done` or `abandoned` in an `archive` project gets one
  question: archive it now with `task archive`? The sprint close asks the same once for the
  sprint's done and abandoned tasks. Neither moves a task without a yes.
- `vault-setup project` and `adopt` ask for `task_layout`, and `archive_after_days` with
  `archive`, and write them into the profile. `vault-setup subproject` says how a task names its
  subproject and offers to set it on the tasks that exist.
- docs-keeper and scrum-master take a task's path from `find` or `task head`, so they reach an
  archived task too. The story-tracker overview of what waits on docs uses `task docs` for the
  same reason.
- The vault index and the conventions say where a task lives in each layout and that a task names
  its subproject in `subproject`. Copy the task line under `## Rules for notes that most often go
  wrong` from `templates/vault-index.md.tmpl` into your vault's `CLAUDE.md`.
- The vault-doctor `fix` mode says that `doctor --fix` also archives the tasks `task-layout` names
  in an `archive` project, and replaces an old pull request note that was never edited. Before an
  archive it takes a snapshot, and `compare` after it proves that only those tasks moved.
- Claude can now run the doctor's check on its own: a request such as "Check my vault for
  problems." loads `vault-doctor`, which ran only by name before. Its check writes nothing, and its
  fix repairs only what is safe and asks before anything else. `vault-setup` still runs only by
  name, and offers the doctor for the detail of a check.
- The `story-tracker` description names where a ticket stands and a standup, so "Where does EX-2
  stand?" and "Standup for the Example project" load it.
- The end-to-end check asks five more requests in plain words: where a ticket stands, a standup,
  an update to a ticket, a new sprint and a vault check. A request that does not load its skill
  fails the job, which may now take 30 minutes. The guide lists every request it proves under
  `What to say`.

## 0.2.0 - unreleased

The helper works on the vault's files alone, and the plugin runs on Windows.

- The helper never calls Obsidian. Obsidian is where the vault is read: its command line interface
  is no longer needed, and the app does not have to be running.
- New commands replace what went through Obsidian's index: `outline`, `backlinks`, `unresolved`,
  `move` and `rename`. `move` and `rename` rewrite the links to a moved note in the vault's notes
  and take `--dry-run`. They refuse, before a file is touched, a move that would lose or break a
  link: a name a link cannot spell, a note that cannot be read in full or written, a destination
  that exists.
- Removed: `second-brain ob`, `second-brain probe`, the `--files` flag and the `source:` line of
  `board`, the `obsidian` and `search` lines of `context`, the doctor checks `obsidian-cli` and
  `index-fresh`, and exit code 3.
- `search` finds the notes that hold every term of the text; a part in double quotes is a phrase.
  A note gives at most three lines, the ones that hold the most terms, so the forty rows show
  more notes.
- Windows is supported in Git Bash, the shell Claude Code uses there. The links are directory
  junctions, which need no special rights: one per skill folder, and one per `claude/agents`
  folder. Absolute paths are printed as `C:/...` and read in any form Windows writes them. A path
  inside the vault uses forward slashes on every system, and one with a backslash is refused.
- `second-brain pointer set <folder>` creates the vault pointer on every system. `vault-setup` uses
  it in place of a hand-made symlink.
- The SessionStart hook is written in shell form, so it runs on Windows.
- The conventions note is at version 3: it describes the helper commands in place of the Obsidian
  command line interface, and names `depends_on`.
- The vault's `CLAUDE.md` carries a version, `index_version`, in frontmatter. The doctor's `index`
  check warns about an index older than the plugin's template. It now fails on a row whose path
  is not a folder in the vault, and on a name, a key or a path that two rows share.
- The index says first what holds in every session: a new personal skill or agent is created in
  the vault, at `~/.claude/second-brain-vault/`, not straight in `~/.claude/skills` or
  `~/.claude/agents`, and is registered with `second-brain link --apply`. Its closing line, to
  ignore the file for a task outside the projects, is gone: it cancelled that rule. The rules
  for notes say that they are for notes.
- The index also tells every session to answer in short, plain English and lead with the answer,
  unless the user or their own instructions say otherwise.
- Pull request descriptions have one format: the headings `What was changed?`, `What was added?`,
  `Dependencies:` and `Risks:`, in that order, with a few one-line bullets in plain English under
  each. It lives in a new vault note, `claude/pull-request.md`, which `scaffold vault` creates and
  you can edit. One line in the index points every session to it. A project's own
  `<project>/claude/pull-request.md` wins. The doctor's new `pull-request` check warns when the
  vault note is missing.
- The doctor checks more. `hubs` warns about a project's hub that is missing or empty.
  `task-location` warns about a note with `type: task` that is not the README of its own folder
  under the tasks root. `board` warns, while a sprint is in progress, about a `Current sprint`
  view that filters on another sprint, has a filter the helper cannot read, or is not there.
  `descriptions` warns about a skill or an agent of the vault with no description.
- The doctor opens nothing outside the vault. An index row whose path is `.` or holds a `..`
  part or a backslash fails `index` and gets no project rows, and `doctor --fix` writes nothing
  under it. A `tasks_root`, `topics_root` or `sprints_root` that leaves the project fails
  `profile`, and the project is checked under that root's default.
- The tests run on Linux, macOS and Windows. An end-to-end check runs Claude Code itself against a
  scratch vault on a Linux and a Windows runner.
- CI uses `actions/checkout@v7`, which runs on Node.js 24, in place of `@v4`, which runs on
  Node.js 20.
- A task can list the tasks it waits on in `depends_on`, as quoted path links.
  `second-brain task dep <ID> add|remove <ID>` edits the list, and `task set` refuses it.
  `board` has a ninth column, `depends_on`, with each task and its status. The board template
  has a `Depends on` column, the `story-tracker` status overview flags a task in progress that
  waits on one not done, and a new doctor check, `depends-on`, warns about a link to no note and
  about tasks that wait on each other in a ring.
- A project can hold subprojects, one note each at `<project>/claude/subprojects/<name>.md`: its
  repos, its own branches and environments, which fall back to the profile's, and its rules. Its
  docs live in `docs/<name>/`. `second-brain scaffold subproject` creates one, and
  `vault-setup subproject <project>` walks through it. `second-brain subproject <project> [name]`
  lists them or prints one's settings; `context` adds a `subproject:` line in a subproject's
  repo; a task carries the `subproject` key (`task new --subproject`, `task set subproject=`).
  The doctor's new `subprojects` check looks at each one. A project with none works as before.
- A rule the user asks Claude to save goes where it applies. The index says that a rule about one
  project goes under `## Rules` in its `claude/README.md`, or in its subproject's note, and only a
  rule for every project goes in `~/.claude/CLAUDE.md`. It also says to read the subproject's note
  with the project's rules. The doctor's new `global-rules` check warns about a line of
  `~/.claude/CLAUDE.md` that names a project of the index.
- `story-tracker` has a `draft` mode. It writes a ticket's summary, description and acceptance
  criteria from the ticket template, with or without an id, and writes no file until the id
  arrives. Its description names ticket text, so a request to write a ticket loads it.
- The vault index says ticket text is never written freehand and names `story-tracker`. The
  `sprint` skill sends a request to write a ticket there.
- Marking a ticket done starts the `docs-keeper` agent. `story-tracker` starts it when a story is
  set `done` in a project with no environments, or when its last environment is set `done`.
  `docs-keeper` has a new Workflow 5 for it: it makes and ticks the edits under
  `## Docs to update`, or, with no such section, checks the ticket's change against the
  "Code to doc map". A gap it does not fix goes to the debt file, and the ticket gets a status
  note naming what was updated.
- New command `second-brain task docs <ID>[,<ID>...]` prints each task with unticked lines under
  `## Docs to update`, its path and those lines.
- The sprint close lists the done tasks whose `## Docs to update` lines are still unticked, with
  `task docs`. It recommends `docs-keeper` for them and does not start it. The `scrum-master`
  agent cannot start `docs-keeper` either, so it reports it as an action for the caller.

Upgrading a vault that was set up with 0.1.0:

- The pointer and the links keep working as they are.
- `scaffold vault` never overwrites, so the vault keeps its version 1 conventions note, which
  still names the removed commands. The doctor warns about it. Delete `obsidian-conventions.md`
  and run `second-brain scaffold vault` to get the new one, or edit it by hand.
- The vault's `CLAUDE.md` has no `index_version`, so the doctor warns about it. Bring the text
  above `## Projects` in line with `templates/vault-index.md.tmpl`: it opens with
  `## In every session`, which says where new skills and agents go, it no longer says to ignore
  the file, and its rule about moving notes names `second-brain move` and `second-brain rename`.
  Keep your own lines and the table, and put the template's frontmatter, with its
  `index_version`, at the top. The `vault-doctor` skill does this after asking.
- The vault has no `claude/pull-request.md`, so the doctor warns about it. Run
  `second-brain scaffold vault`: it creates the note and overwrites nothing. Then add the index
  line about pull requests from `templates/vault-index.md.tmpl` under `## In every session`.
- The plugin's index template is now at `index_version: 2`, and its conventions note at
  `conventions_version: 3`. The doctor's `index` and `conventions` checks warn about a vault whose
  copy is older, and say so. Bring the index's text above `## Projects` in line with
  `templates/vault-index.md.tmpl`: it adds the answer-style line, the rule about where a saved rule
  goes, the line about pull requests, the subproject note to read with a project's rules, the
  ticket text line under `## Rules for notes that most often go wrong`, and on the plugin lines
  that `story-tracker` writes ticket text and that `docs-keeper` runs for a ticket marked done.
  Keep your own lines and the table, and set `index_version: 2`. Delete
  `obsidian-conventions.md` and run `second-brain scaffold vault` for the new conventions note.
- A snapshot taken with 0.1.0 does not compare with one taken now.
- A `tasks.base` written before has no `Depends on` column. Add `note.depends_on` and the
  `depends_on` column from `templates/tasks.base.tmpl` by hand to show it in Obsidian.

## 0.1.0 - unreleased

First version.

- Skills: `story-tracker`, `sprint`, `vault-setup`, `vault-doctor`.
- Agents: `scrum-master`, `docs-keeper`.
- Helper: `second-brain` (lookups, board, task and sprint writes, scaffolding, link, doctor).
- Templates for a vault, a project, a task, a sprint and the task board.
- A project profile records where its code repositories are stored (`repos_root`, `repo_paths`);
  `second-brain repo <project> [name]` returns the path, and the doctor warns when a folder is missing.
- Docs follow production: `docs-keeper` edits a doc only after the change is confirmed deployed, and
  records the planned edits until then. Every repository has rows in the profile's code-to-doc map;
  `vault-setup repo <project>` adds a repository with its rows, and the doctor warns when one has none.
- The helper works where `awk` is gawk in a UTF-8 locale, as on the Ubuntu CI runner: every awk
  program that loads the shared functions now runs in the C locale.
- Sprints are optional per project: `uses_sprints: false` in the profile, written by
  `second-brain scaffold project --no-sprints`, turns them off. The project gets no sprints hub and
  no `Current sprint` view, the `sprint` commands refuse it, and the doctor skips its sprint checks.
