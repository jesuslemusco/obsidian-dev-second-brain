# Contract

The interfaces every part of this plugin agrees on. Change this file first, then the code.

## 1. Words and paths

| Word | Meaning |
|---|---|
| vault | The Obsidian vault root, the folder that holds `.obsidian/`. |
| link directory | `~/.claude`. It holds the pointer and the links to the vault's own skills and agents. |
| pointer | `second-brain-vault` in the link directory: a link to the vault, made by `second-brain pointer set`. |
| index | `<vault>/CLAUDE.md`, the only list of projects. Claude always loads it through an import in `~/.claude/CLAUDE.md`. |
| conventions | `<vault>/obsidian-conventions.md`. Its first section is `The short version`. |
| pull request format | `<vault>/claude/pull-request.md`: the headings and style of every pull request description Claude writes. A project's own `<project>/claude/pull-request.md` wins over it. The index points to it in one line. Its frontmatter holds `pull_request_version`, the version of `templates/pull-request.md.tmpl` it follows. |
| writing style | `<vault>/claude/writing-style.md`: how Claude writes notes. A project's own `<project>/claude/writing-style.md` wins over it. The index points to it in one line. |
| project | A folder inside the vault, listed in the index by its vault-relative path. |
| profile | `<vault>/<project path>/claude/profile.md`, the project's one settings note. |
| subproject | A part of a project with its own repos, branches and docs folder. It shares the project's ticket keys, tasks and board. |
| child task | A task whose `epic` names another task of its project, its parent. A project calls its parent stories features or epics, as `parent_label` says. |
| helper | `bin/second-brain`, on the Bash PATH while the plugin is enabled. |
| vault path | A path relative to the vault root, with forward slashes on every system. |

## 2. The index

`<vault>/CLAUDE.md` holds a `## Projects` section with exactly this table:

```markdown
## Projects

| Project | Path | Keys | Use when |
|---|---|---|---|
| Example | clients/acme/projects/example | EX, EXOPS | Anything about the Example service. |
```

- `Project` is the display name, unique, matched without letter case.
- `Path` is vault-relative, with no slash in front or behind.
- Each `Path` is a folder in the vault, and no two rows share one. Paths are compared without
  letter case, with `//` and `/./` folded.
- `Keys` are ticket key prefixes, comma separated, and may be empty. A key belongs to one row,
  compared in upper case.
- An item with no letter or digit, such as `-`, is no key.
- A project's folder may sit inside another project's folder. Each row is its own project.
- A check that goes by the path alone, such as `unresolved-links`, lists the inner project's notes
  under both projects.
- A path names no project folder when, with `//` and `/./` folded, it is `.` or holds a `..` part
  or a backslash. What the doctor does with one is under `### link, doctor, snapshot`.

The file opens with frontmatter that holds `index_version`, a whole number:

```markdown
---
index_version: 8
---
```

- `index_version` is the version of `templates/vault-index.md.tmpl` that the text above
  `## Projects` follows. The template's number goes up when that text changes.
- The doctor counts a version too long to compare as newer, for `index_version`,
  `conventions_version` and `pull_request_version`.
- No command updates an index. By hand: bring the text above `## Projects` in line with the
  template, keep the table, and set `index_version` to the template's number.
- The first line under `## In every session` is the answer style: short, plain English, the
  answer first, unless the user or their own instructions say otherwise.
- The text says where a rule the user asks Claude to save goes. A rule about one project goes
  under `## Rules` in `<Path>/claude/README.md`, or in its subproject's note. Only a rule for every
  project goes in `~/.claude/CLAUDE.md`. When Claude cannot tell which, it asks.
- When `second-brain context` prints a `subproject` line, the text says to read that subproject's
  note with the project's `claude/README.md`.
- `## Rules for notes that most often go wrong` holds the rule for finding and reading notes:
  `second-brain find`, `search` (also for related notes before a decision), `task head`, then
  `outline` and a ranged read, and a whole note last. Never grep, cat or sed on vault files.
- A test pins the text of the answer style and of the rule for finding and reading notes.

## 3. The project

```
<project>/
  README.md
  claude/README.md
  claude/profile.md
  claude/pull-request.md        optional; the project's own pull request format, which wins
  claude/templates/             optional; the project's own story templates, which win (section 8)
  claude/writing-style.md       optional; the project's own writing style, which wins
  claude/lead-agent-task-memory.md  optional; the owner's open orders, which the lead of a build writes (section 9)
  claude/subprojects/<name>.md  one per subproject; none by default
  claude/validation.md          how to run and check each repo, with validation_home: vault
  tasks/README.md
  tasks/tasks.base
  tasks/<TICKET-ID>/README.md
  tasks/archive/<YYYY>/<TICKET-ID>/README.md   a done or abandoned task, with task_layout: archive
  tasks/<status>/<TICKET-ID>/README.md         a task, with task_layout: status
  tasks/backlog/<TICKET-ID>/README.md          a task in no sprint, with task_layout: sprint
  tasks/<sprint folder>/<TICKET-ID>/README.md  a task in a sprint, with task_layout: sprint
  tasks/<status>/<parent>/<TICKET-ID>/README.md   a child task, with task_layout: status
  tasks/backlog/<parent>/<TICKET-ID>/README.md    a child task in no sprint, with task_layout: sprint
  tasks/<sprint folder>/<parent>/<TICKET-ID>/README.md   a child task in a sprint
  <topics_root>/...            default docs/
  <topics_root>/<name>/README.md   the docs folder of a subproject
  <topics_root>/planned-releases.md   optional; the releases ahead, which release-planning writes
  <sprints_root>/README.md     default sprints/; only when the project uses sprints
  <sprints_root>/<YYYY-MM-DD>.md
```

### Profile frontmatter

```yaml
---
aliases:
  - "<Project> Profile"
type: profile
project: "<Project>"
ticket_keys: [EX, EXOPS]
tracker: "Jira"
persona: "Example engineer"
tasks_root: tasks
task_layout: flat
archive_after_days: 14
topics_root: docs
uses_sprints: true
sprints_root: sprints
sprint_length_days: 14
sprint_anchor_end: "2026-01-14"
base_branch: main
production_branch: ""
branch_pattern: "feature/<ID>-<slug>"
environments: []
repos: [example-api, example-web]
repos_root: "~/code/acme"
repo_paths: []
validation_home: vault
lead_check_minutes: 20
achievements_skill: ""
tags:
  - type/profile
---
```

- `base_branch` is the branch a new story's branch is cut from, as
  `## Branch check (start, update, recall)` in `skills/story-tracker/SKILL.md` says.
- `production_branch` is the branch production runs. Empty means `base_branch`.
- `persona` is the role a story's description opens with (`*As a* <persona>,`).
- `parent_label` is the word for the project's parent stories: `feature`, in any letter case, or
  `epic`. A missing or empty key is `epic`. So is any other value, which the doctor's
  `task-layout` check names. `scaffold project --parent-label` writes the key.
- The word changes labels only: the skills, the board's column and the helper's output. A task's
  frontmatter key stays `epic`.
- `topics_root: "."` puts the topic folders at the project root.
- `tasks_root`, `topics_root` and `sprints_root` are folders inside the project, written with
  forward slashes.
- Every command drops a slash in front of or behind a root: `/tasks` is `tasks`.
- A root that holds a `..` part or a backslash leaves the project. What the doctor does with one
  is under `### link, doctor, snapshot`.
- `task_layout` is `flat`, `archive`, `status` or `sprint`, in any letter case. A missing key or
  another value is `flat`, and so is `sprint` with `uses_sprints: false`.
- `flat`: every task stays in `<tasks_root>/<ID>/`.
- `archive`: a done or abandoned task moves to the archive through `task archive`, as its row
  under `## 7. The helper` says.
- `status`: each task sits in the folder of its status, `<tasks_root>/<status>/<ID>/`, and moves
  when its status changes, as `## 4. A task` says. Nothing is archived.
- To turn `status` on for a project that has tasks, set the key, then run `doctor --fix` once: it
  moves each task to the folder of its status, as its row under `## 7. The helper` says.
- `sprint`: each task sits in the folder of its sprint, `<tasks_root>/<sprint folder>/<ID>/`, or
  in `<tasks_root>/backlog/<ID>/` with no sprint, and moves when its sprint changes, as
  `## 4. A task` says. Nothing is archived.
- `sprint_folder` is the pattern that names a sprint's folder in the sprint layout. A missing or
  empty key is `"<end>"`, so the folder of sprint `2026-10-14` is `2026-10-14`.
- In the pattern, `<end>` is the sprint id, `<start>` its first day and `<n>` its number.
  `"sprint-<n>"` gives `sprint-3` to the third sprint.
- `<start>` is the `start` key of the sprint's note, or with no note the id less
  `sprint_length_days` plus one day, as `sprint open` counts it.
- `<n>` is one more than the count of the project's sprint notes with an earlier id. A sprint
  with no note shares its number with the next sprint that has one.
- With a pattern that has none of the three, or gives a sprint no folder name, each command that
  would move a task there exits 5 naming the pattern, and nothing is written.
- A folder name is letters, digits, dots, hyphens and underscores, neither a dot nor a hyphen
  first, and not `archive`, `backlog` or a status, in any letter case.
- To turn `sprint` on for a project that has tasks, or after a change to `sprint_folder`, set
  the key, then run `doctor --fix` once: it moves each task to the folder of its sprint, or to
  `backlog/`, as its row under `## 7. The helper` says.
- Commands find a task directly under the tasks root, in a status folder, in `backlog` or another
  group folder, or in the archive, in every layout, as `## 4. A task` says.
- In `status` and `sprint`, a child task sits inside a folder named for its parent, one folder
  deeper, as `## 4. A task` says. In `flat` and `archive` a child stays at `<tasks_root>/<ID>/`.
- `archive_after_days` is a whole number of days, 14 when the key is absent.
- With `archive`, a done or abandoned task outside the archive is due once that many days have
  passed since its newest date: the date of its newest status note, or its sprint id when that is
  later.
- A task with neither date is never due. `task archive <ID>` archives it by hand.
- `uses_sprints: false`, in any letter case, turns sprints off. Any other value, or no key, uses
  sprints.
- With `false` the project has no sprints hub, its board has no `Current sprint` view and no
  sprint columns, and the three sprint keys are ignored. How each command treats such a project
  is in its row under `## 7. The helper`.
  - To turn sprints on later, set the key to `true` and run `scaffold project` again. It creates
    the hub. It names on stderr what to add by hand in files that exist: the map line in the
    project README, and the board's `Current sprint` view and sprint columns.
  - To turn them off on a project that ran sprints, close the sprint in progress first. One left
    in progress can no longer be closed.
- `environments` lists environment names in promotion order, or is empty.
- `repos` are the folder names of the code repositories, used to match the working directory. The
  first is the default repo for branch checks.
- `repos_root` is the folder those repositories usually sit in on this machine, absolute or
  starting with `~`.
- `repo_paths` lists the exceptions, one `name=path` string per repo stored elsewhere.
- Both may be empty. A repo's location is then unknown, and the skills ask for it.
- `achievements_skill` is kept for the plugin's achievements skill, which is planned. No skill
  reads it until then. Only that skill tracks achievements.
- `validation_home` is where `validation.md` lives. `vault`: `claude/validation.md` in the
  project. `repo`: `validation.md` at the root of each repo. A subproject's note may set it for its
  repos.
- `validation_home` takes any letter case. A missing or empty value in a subproject's note takes
  the profile's. At the profile it means the default, `vault`.
- The first value found decides. One that is not allowed means `vault`.
- `delivery` and `spec_home` are no keys of the profile, a subproject's note or a task. Versions
  before 0.12.0 read them for the retired spec flow. A note that still has one keeps it: no
  command reads it, and the doctor does not name it.
- `lead_check_minutes` is how many minutes the lead of a build waits between two checks on its
  open orders, as `## The lead's check` in `skills/build/lead.md` says. It is 10, 12, 15, 20, 30
  or 60, the values that space the checks evenly through the hour. A missing or empty key, or any
  other value, is 20.
- `templates/profile.md.tmpl` leaves the key out. The doctor's `settings` check warns on a value
  it does not take.

### Profile sections

Fixed level-2 headings: `## Stories`, `## Topics`, `## Repos`, `## Environments`, `## Sprints`,
`## Docs`, `## Live systems`.

`## Docs` holds these level-3 headings: `### Repo doc surfaces`, `### Vault doc surfaces`,
`### Code to doc map`, `### Facts in several places`, `### Not drift`, `### Terminology`,
`### Reference implementation`, `### Neighbours`, `### Debt file`.

`### Code to doc map` is a table with the columns `Repo`, `Change in the code`, `Docs to update`.

- Every repository in `repos` has at least one row.
- So does every repository of a subproject, with the subproject's docs folder in its
  `Docs to update` cell.
- The change that adds a repository to a project adds its rows.

### Subprojects

One note per subproject: `<project>/claude/subprojects/<name>.md`.

- The name is the file name without `.md`. It is a folder name: no slash, none of
  `| [ ] " # ^ : * ? < >` and the backslash, no blank at either end, not starting with `.` or `-`.

```yaml
---
aliases:
  - "<Project> <name> Subproject"
type: subproject
project: "<Project>"
repos: [example-infra]
base_branch: ""
production_branch: ""
branch_pattern: ""
environments: []
repo_paths: []
validation_home: ""
tags:
  - type/subproject
---
```

- `repos` lists the subproject's repositories. The first is the default for branch checks.
- A repository belongs to one subproject. It need not be in the profile's `repos`.
- The project's repositories are the profile's, then each subproject's that the profile does not
  list.
- `base_branch`, `production_branch`, `branch_pattern`, `environments`, `repo_paths` and
  `validation_home` mean what they mean in the profile. One that is absent or empty (`""`, `[]`)
  takes the profile's value.
- An empty effective `production_branch` still means the effective `base_branch`.
- `repos_root` is the profile's.
- A subproject's `repo_paths` entry wins over the profile's entry for the same repo.
- The body has a `## Rules` section: the rules Claude follows in that subproject.
- Its docs folder is `<topics_root>/<name>/`, or `<name>/` at the project root when the topics
  root is `.`. It is a topic folder like any other, with a `README.md` hub.
- A working directory resolves to a subproject as it resolves to a project. The deepest recorded
  folder of a project repository that holds it decides. With none, the deepest folder on the way
  up whose name is a repo of the project decides, the profile's repos included.
- A directory in a repository of the profile alone is in no subproject, and neither is a folder of
  the vault.

### Validation

`validation.md` says how to run and check a repo's code. Agents read a repo's part with
`second-brain validation <project> <repo>` before they build or review a change.

- A repo's home is the `validation_home` of the subproject that lists it, else the profile's.
- `vault`: one note, `<project>/claude/validation.md`, written from `validation.md.tmpl`, with one
  `## <repo>` section per repo.
- `scaffold project` writes that note, with a section for each repo it knows, when the profile's
  home is `vault`. The project's Claude hub then links to it.
- `repo`: `validation.md` at the root of the repo, with a `# <repo> validation` title and one
  `## <repo>` section. Nothing in the vault points to it.
- A section is written from `validation-repo.md.tmpl` and keeps its four level-3 headings:
  `### Set up and start`, `### Checks`, `### Check as a user would` and `### A pass`.
- Each step under `### Check as a user would` is one line that starts with the tool that runs it:
  a skill by its name, a command, an API call or a query.
- Under `### Checks` a bullet's first inline code span is its command:
  `` - `npm test` - the unit tests - when: each story ``.
- Each bullet under `### Checks` and `### Check as a user would` ends with when it runs, its
  stage: `when: each story`, `when: each merge` or `when: release`.
- `each story` runs in each story's review. `each merge` runs on the branch a story merges into,
  once the merge is made and before it is pushed. `release` is for a project that plans releases:
  it runs only before a release or when the owner asks, such as an end-to-end suite.
- No stage needs sprints or a release branch: a story merges wherever the project's git flow says.
- A run of a stage takes the stages before it too: `each merge` runs the `each story` checks as
  well, and `release` all three.
- `each task` and `each build`, the names before 0.13.0, read as `each story` and `each merge`.
  The doctor's `validation` check names each bullet that still holds one.
- A bullet with no `when:` is `each merge`.
- The `when:` is the last one in the bullet outside code spans. Its value is read without letter
  case, with a hyphen as a blank and a final period dropped.
- Any other value is unknown and counts as `each merge`, so a typo never drops a check.
  `validation run` names it as a warning in every run.
- A check may name the paths it covers, as `paths: <glob>, ...`. A story's review runs it only
  when the story's change touches one of them:
  `` - `npm run e2e:api` - the API suite - paths: api/**, `package.json` - when: each story ``.
- The `paths:` is the last one in the bullet outside code spans, as for `when:`. Its globs run to
  a `when:` that follows it, or to the end of the bullet, and the `when:` runs to a `paths:` that
  follows it: the two may come in either order.
- The globs are split at commas, each one trimmed, a final ` -` and a final period dropped. A glob
  may be a code span of its own, so that a `*` is not read as emphasis.
- A glob is matched against each path from the folder the checks run from, the repo's root, as git
  matches a `:(glob)` pathspec: `*` and `?` stay within a folder, and `**` crosses folders.
- With `--changed <base>`, `validation run` runs a check that has globs only when the diff from
  `<base>` to the folder touches a path one of them matches. A file changed, added, deleted or
  moved since `<base>` counts, committed or not, and so does a new file that git does not ignore.
  A moved file counts at both of its paths.
- A check with no `paths:`, or with an empty one, runs every time, and so does every check in a run
  with no `--changed`. A check that git cannot match runs too, so that an error never drops it.
- A user step takes no `paths:`. Who runs each stage's checks and user steps is under
  **Who runs which check.** in `## 9. Skills and agents`.
- A bullet is its first line and the indented lines under it, up to a blank line, a nested item
  or the next bullet. A nested item is part of no check.
- A section is written when something is under its heading. One with nothing is `empty`.
- A story built in a git worktree of its own is checked there: `validation` and `validation run`
  take `--path <worktree>`, so the checks run on the branch under review, not on the repo's
  recorded folder.

### Planned releases

`<project>/<topics_root>/planned-releases.md` says which release each epic and story goes to. The
`release-planning` workflow of the scrum-master skill writes it (section 9).

```markdown
---
aliases:
  - "Example Planned Releases"
type: note
tags:
  - type/note
---

> Up: [[clients/acme/projects/example/docs/README|Example Docs Hub]]

# Example Planned Releases

The releases ahead, and the epics and stories planned for each. A story's status and next step
live in its task note; this note says only which release it goes to.

## Epics

- EPIC: [[clients/acme/projects/example/tasks/EX-1/README|EX-1]] - Export the invoices. 0.2.0.

## 0.1.0 - released 2026-01-14

Release goals:
- The board shows each task's branch.

- STORY: [[clients/acme/projects/example/tasks/EX-5/README|EX-5]] - Show each task's branch.

## 0.2.0 - next

Release goals:
- Close epic EX-1: the invoices export as CSV.

- EPIC: [[clients/acme/projects/example/tasks/EX-1/README|EX-1]] - Export the invoices.
	- STORY: [[clients/acme/projects/example/tasks/EX-2/README|EX-2]] - Export as CSV.
	- STORY: [[clients/acme/projects/example/tasks/EX-3/README|EX-3]] - Keep the tax column. After EX-2.
- STORY: [[clients/acme/projects/example/tasks/EX-4/README|EX-4]] - Sort the board by status.
```

- `## Epics` lists each epic once: a path link, a one-line summary and the releases it spans.
- Then one `## <version>` section per release, oldest first.
- The release in work is `## <version> - next`. Only one release is `next`.
- A release once out is `## <version> - released <YYYY-MM-DD>`. One still ahead has no suffix.
- A release section holds `Release goals:` and its bullets, a blank line, then one `- STORY:` or
  `- EPIC:` line per item, each a path link and a one-line summary.
- An epic's stories are nested under its line, indented with one tab.
- A line may end with what it waits on, such as `After EX-2.`
- A last `## Not yet in a release` section may hold the items kept for later.
- A link carries the path `second-brain find <ID>` prints, as `### Links between notes` says.
- A story's status and next step stay in its task note. The note holds no status.

## 4. A task

Path: `<project>/<tasks_root>/<ID>/README.md`. `<ID>` is the ticket id, or a kebab-case slug when
there is no ticket yet.

- An archived task is `<project>/<tasks_root>/archive/<YYYY>/<ID>/README.md` (see `task_layout`
  in the profile).
- With `task_layout: status`, a task is `<project>/<tasks_root>/<status>/<ID>/README.md`, in the
  folder of its status: `planned`, `in-progress`, `in-review`, `done` or `abandoned`.
- There, a status change moves the task's folder with `move`, so every link to it follows:
  `task set` moves it, and `sprint close` moves each task it abandons, as their rows under
  `## 7. The helper` say. A status edited by hand moves nothing until `doctor --fix`.
- With `task_layout: sprint`, a task in a sprint is
  `<project>/<tasks_root>/<sprint folder>/<ID>/README.md`, in the folder that `sprint_folder`
  names for its sprint, and a task in no sprint is `<project>/<tasks_root>/backlog/<ID>/README.md`.
- There, a sprint change moves the task's folder with `move`: `task set` moves it, `sprint open`
  moves each task it re-points, and `sprint close` moves each task it carries or sends to the
  backlog, as their rows under `## 7. The helper` say.
- A done or abandoned task stays in the folder of its sprint, and a status change moves nothing.
  A sprint edited by hand moves nothing until `doctor --fix`.
- The folder `archive` directly under the tasks root holds the archive, and the five status
  folders beside it hold the tasks of a status project. Commands look in all six in every layout.
  None of the six is a task, and none of their names, in any letter case, is a task id or an
  alias.
- `backlog` and the sprint folders beside them hold the tasks of a sprint project. Each folder
  directly under the tasks root with no `README.md` of its own is a group folder, such as a
  sprint's folder; one with a `README.md` is a task. The five status folders and `backlog` are
  group folders whatever they hold.
- Commands look in `backlog` and in every group folder, in every layout.
- `backlog` is no task either, and its name, in any letter case, is no task id and no alias.

A child task:

- A task is a child when its `epic` names another task of its project, its parent: by its folder
  name or an alias, without letter case. An empty `epic`, `-` or the task's own id names none.
- With `task_layout: status` or `sprint`, a child sits inside a folder named for its parent, in
  the folder its own status or sprint gives: `<project>/<tasks_root>/<status>/<parent>/<ID>/README.md`,
  `<project>/<tasks_root>/backlog/<parent>/<ID>/README.md` or
  `<project>/<tasks_root>/<sprint folder>/<parent>/<ID>/README.md`. `<parent>` is the parent's
  folder name.
- The parent's note is `README.md` in its own folder, where its own status, or its sprint or
  `backlog`, puts it, as every task's is. A child that joins a sprint moves to
  `<sprint folder>/<parent>/<ID>/` while its parent's note stays in `backlog/<parent>/`.
- A README one folder inside a task folder in a group folder is a child task when its `epic` names
  that task. Any other README inside a task is still no task.
- A folder directly in a group folder with no `README.md` of its own holds tasks, one level
  deeper, when it is named for a task found elsewhere, by its folder name or an alias, without
  letter case: such as `done/<parent>/`, which holds a done child while its parent's note is in
  `in-progress/<parent>/`. Each folder in it with a `README.md` is then a task.
- A task found elsewhere is one directly under the tasks root, in a group folder or in the
  archive, a child inside its parent's folder, or one such a folder holds.
- A folder with no `README.md` that is named for no task holds none: a README in it is no task,
  and the folder is a task folder with no README, as the doctor's `no-readme` check says.
- Commands look for a task one level deeper in every layout. In `flat` and `archive` a child stays
  at `<tasks_root>/<ID>/`, and nothing moves it into a parent's folder.
- In a status or sprint project, a move keeps a child under its parent. A change of its status or
  sprint moves it to `<new folder>/<parent>/<ID>/`, and makes `<new folder>/<parent>/` when it is
  missing. Setting `epic` moves it in, and clearing it moves it out to `<folder>/<ID>/`.
- A move of a parent takes its own note and files alone: every entry of its folder but its
  children's folders, which stay where they are. Its destination may be a folder named for it that
  holds one of its children already: its entries go in beside them, each to a place that is free.
- An entry whose name starts with a dot moves too. `move` takes no such name, so it moves as it
  is, and no link into it is rewritten.
- A parent that is done or abandoned leaves its open children where they are, and every command
  still finds them.
- In a status or sprint project, a move of a task out of a folder that holds tasks one level
  deeper, one with no `README.md`, removes that folder when it leaves it empty.
- An `epic` that names no single task of the project, none or several, names no parent: a move
  puts the task at `<folder>/<ID>/`. The doctor's `task-layout` check names it, and `doctor --fix`
  leaves it where it is.

```yaml
---
aliases:
  - <ID>                      # always first, always the folder name
title: "<short title>"
status: planned               # planned | in-progress | in-review | done | abandoned
next: "<one phrase: the next action>"
branch: "none yet"
epic: "-"
subproject: example-infra     # omit the key when the task is in no subproject
sprint: "2026-10-14"          # omit the key when the task is in the backlog
carried_from: []              # sprint ids this task was carried over from
depends_on:                   # optional; the tasks this one waits on, as quoted path links
  - "[[<vault path of its README, no .md>|<other ID>]]"
type: task
tags:
  - <topic/tag>               # zero or more; the folder path under the topics root, lowercased
  - type/task
  - status/active             # status/done for done and abandoned, status/active otherwise
---
```

- The helper never writes `jira_id`. Notes that have it keep it; readers ignore it.
- An archived task carries `archived: "YYYY-MM-DD"`, quoted: the day `task archive` moved it. A
  task that moves out of the archive into a status folder loses the key, as does one that moves
  into `backlog` or a sprint's folder.
- The tasks that wait on a task are never stored: Obsidian shows them as backlinks.
- A task folder may hold more than its `README.md`. The `spec/` folder and `build.json` that the
  retired spec flow wrote, before 0.12.0, stay there as plain files of the task.
- No command reads them, a move takes them with the task, and no doctor check is about them. A
  task folder with a `spec/` folder is still one task.
- Environment sets add an `envs:` mapping (`<env>: { id: <ID>, status: <status> }`) and list every
  id in `aliases`.
- Strings are double-quoted when they contain `: ` or `#`, start with `-` or `[`, or look like a
  date or number. Sprint ids are always quoted.
- Body sections of a new task, in order: `# <ID> - <title>`, `**Summary:**`, `**Branch:**`,
  `## Description`, `## Findings` (optional), `## Acceptance criteria`,
  `## Approach / Key decisions`, `## Code verification (read-only)`, `## Changes`,
  `## Verification`, `## Status notes`, `## Discovery log`.
- A task may also carry `## Docs to update`: one checkbox line per doc edit waiting for the change
  to reach production.
- A status note line is `**YYYY-MM-DD (session `<id>`) - <text>**`, newest first.

## 5. A sprint

Path: `<project>/<sprints_root>/<YYYY-MM-DD>.md`. The id is the end date.

```yaml
---
aliases:
  - "<Project> Sprint 2026-10-14"
type: sprint
sprint: "2026-10-14"
start: 2026-10-01
end: 2026-10-14
status: in-progress           # planned | in-progress | done
goal: ""
committed: 0
completed: 0
carried_over: 0
tags:
  - type/sprint
  - status/active
---
```

Body: an up-link to the sprints hub, then `## Goal`, `## Notes`, `## Close`.

## 6. The board

`<project>/<tasks_root>/tasks.base`, an Obsidian Bases file.

- Views, by exact name: `Active`, `Current sprint`, `By topic`, `By subproject`,
  `Needs a status`, `All`.
- It lists only the README directly inside each task folder, live or archived: a folder-depth
  filter takes `<tasks_root>/<ID>/`, `<tasks_root>/<status>/<ID>/` in each of the five status
  folders, and `<tasks_root>/archive/<YYYY>/<ID>/`.
- Every new board holds that status filter, in every layout. An existing board is never
  rewritten: in a status project, the doctor's `board` check names one without it.
- A last branch takes a task in a group folder, `<tasks_root>/<folder>/<ID>/`, such as `backlog/`
  or a sprint's folder: a README two folders below the tasks root whose folder's name is its first
  alias, as a task's is. The board cannot see whether a folder has a README.
- Every new board holds that branch too, in every layout. An existing board is never rewritten:
  in a sprint project, the doctor's `board` check names one without it.
- A branch after it takes a task one level deeper, such as a child task in
  `<tasks_root>/<folder>/<parent>/<ID>/`: a README three folders below the tasks root whose
  folder's name is its first alias.
- Every new board holds it too, in every layout. An existing board is never rewritten: in a status
  or sprint project that has a child task, the doctor's `board` check names one without it.
- The board names its `epic` column by `parent_label`: `Feature` or `Epic`.
- It shows `file.asLink(aliases[0])` as the task name.
- The `Current sprint` view filters on one literal sprint id, which `sprint open` rewrites.
- `By subproject` shows the active tasks grouped by `subproject`, with a `Subproject` column.
- For a project that does not use sprints, see `uses_sprints` under `### Profile frontmatter`.
- `board <project> "Current sprint"` goes by the sprint in progress, not by the literal. The
  doctor's `board` check warns when the two differ.

## 7. The helper

`second-brain <command> [args]`. Bash 3.2 and awk only. It runs on macOS, on Linux, and on Windows
in Git Bash. Output is plain text for Claude: short, stable, no colour.

Exit codes: `0` ok, `1` not found, `2` setup missing (no pointer or not a vault), `4` ambiguous,
`5` bad usage, `6` already exists. `3` is retired: it meant the Obsidian CLI was unavailable.

Rules that hold for every command:

- An empty cell or value prints `-`. Callers read `-` as empty.
- Every command works on the vault's files and never calls Obsidian. None needs Obsidian
  installed or running.
- Wherever a command takes `<ID>`, the folder id or any alias of the task is accepted. Task
  commands resolve it from the task READMEs on disk.
- A lookup that finds nothing exits 1 (`find`, `topic`, `search`). A listing that finds nothing
  exits 0 with no rows (`board`, `projects`, `backlinks`, `unresolved`).
- Writes change only the lines they must and keep the file's line endings.
- `task note`, `task head`, `task new --envs`, `sprint open`, `sprint close` and
  `scaffold subproject` take no line in fenced code for the heading they write under or read.
- Wherever a command takes `<path>`, it is a vault path. A path that leaves the vault, enters a
  dot folder, holds a backslash or is absolute exits 5.
- An absolute path is printed with forward slashes; on Windows in the drive form, `C:/...`.
- An absolute path that is read (an argument, an environment override, `repos_root`, a
  `repo_paths` entry) may be in that form, written with backslashes, or in Git Bash's own form,
  `/c/...`.
- Environment overrides: `SECOND_BRAIN_VAULT` (vault root), `SECOND_BRAIN_CLAUDE_HOME` (link
  directory), `SECOND_BRAIN_TODAY` (today's date, for tests), `SECOND_BRAIN_NOW` (the time in the
  name `snapshot` gives, for tests).
- `--json` prints the same fields as the text, as one JSON value and nothing else on stdout.
- With `--json`, exit codes and stderr do not change.
- Only a form whose row below names `--json` takes it.
- In JSON a row is an object, its keys the field names. Rows are an array of objects, `[]` when
  there is none.
- A list field is an array of strings, `[]` for `-`.
- A count is a number.
- Any other field is a string, `-` when empty, as in the text.
- A string escapes `"`, `\` and every control character.

| Command | Output | Notes |
|---|---|---|
| `help` | the command list | |
| `version` | the plugin version | read from `.claude-plugin/plugin.json` |
| `conventions [section]` | one level-2 section of the vault's conventions note | default section `The short version`; the name is matched without letter case; exit 1 when the note or the section is missing |
| `root` | the absolute physical path of the vault | exit 2 when the pointer is missing or not a vault |
| `context [--cwd DIR]` | at most 5 `key: value` lines: `vault`, `project`, `project_path`, `subproject`, `sprint` | always exits 0; an unknown value prints `none`. `sprint` is `off` for a project that does not use sprints. The `subproject` line is there only when one subproject's repository holds the directory |
| `projects` | one TSV row per project: name, path, keys | from the index table |
| `project --name N` / `--key K` / `--cwd DIR` | one TSV row: name, path, keys | `K` is a key prefix or a full id (`EX` or `EX-123`). With no flag it uses the working directory. Exit 1 none, exit 4 several (prints them) |
| `repo <project> [name]` | with no name, one TSV row per repo: name, path, state (`ok`, `missing`, or `unknown` with path `-` when no location is recorded). The profile's repos come first, in order, then each subproject's repos the profile does not list, by subproject name. With a name, the path alone | paths are absolute, with `~` expanded. With a name, exit 1 when the name is not in `repos`, when no location is recorded, or when the folder is missing; the message says which |
| `subproject <project>` | one TSV row per subproject, by name: name, repos (comma separated, or `-`), docs folder as a vault path | exit 0 with no rows for a project with none; exit 1 when the profile is missing |
| `subproject <project> <name>` / `--cwd DIR` | the effective settings as `key: value` lines: `subproject`, `note`, `docs`, `repos`, `base_branch`, `production_branch`, `branch_pattern`, `environments`, `validation_home`, `repo_paths` | the name is matched exact first, then without letter case. `base_branch` to `environments` are as `### Subprojects` says; lists are joined with `, `. `validation_home` includes the default (section 3). `repo_paths` is `<repo>=<path>` for each of its repos with a location, found as `repo` finds it, or `-`. `--cwd` takes the subproject whose repository holds the directory. Exit 1 none, exit 4 several (prints their names) |
| `profile <project> --keys` | the profile frontmatter as `key: value` lines | exit 1 when the profile is missing, with a hint to run vault-setup adopt |
| `profile <project> <section>` | the body of that level-2 section | the name is matched without letter case; exit 1 when absent |
| `board <project> [view] [--subproject S]` | one row per task: `id | title | status | sprint | topics | branch | next | envs | depends_on`. The `By subproject` view adds a tenth cell, `subproject` (`-` for none). `Current sprint` has no rows when no sprint is in progress or the project does not use sprints | default view `Active`: status planned, in-progress or in-review. `By subproject` lists the active tasks by subproject, those with none last. `--subproject` keeps the tasks whose `subproject` is that subproject, in any letter case; the name is matched as by `subproject <project> <name>`, exit 1 when none matches. Rows come from the frontmatter of the task READMEs, by the view's own rule; the board file is not read. `envs` is `-` or `dev:EX-1:done,qa:EX-2:planned`, each name as the note spells it. `depends_on` is `-` or `EX-1:done,EX-2:planned`: the folder of each linked task README and that task's status. The folder is spelled as on disk for a task of the project, whatever the link's letter case. The status is `-` when it has none, or `missing` when the link leads to no note in the vault. `title` falls back to the note's first heading when the property is absent |
| `find <ID-or-alias> [--project P]` | vault path(s) | tries the task path, directly under the tasks root, in a status folder, in `backlog` or another group folder, or archived, or one level deeper in a group folder, as a child task is (section 4), then the aliases in frontmatter: task READMEs first, then every note of the project; exit 1 none |
| `task head <ID> [--project P] [--json]` | at most 15 lines: id, path, title, status, next, sprint, branch, epic, subproject (only when set), topics, envs, summary line, newest status note | `--json` prints one object whose keys are the lines' keys, `subproject` only when set. `topics` and `envs` are arrays, each env as `<env>:<id>:<status>`. The `epic` line takes its key from the profile's `parent_label`: `feature: <value>` where it is `feature`, in the text and in `--json` |
| `task docs <ID>[,<ID>...] [--project P]` | for each task with unticked `- [ ]` lines under `## Docs to update`: a line `<id> <vault path>`, then those lines as written; nothing for a task with none | ids may be comma-separated or given as several arguments; exit 1 when an id names no task |
| `task set <ID> key=value... [--project P]` | the changed keys, or `no change` | scalar keys only. Setting `status` also sets the `status/` tag, and setting `type` the `type/` tag. `key=` removes the key. Exit 5 for a status outside the five, for `jira_id`, for a list key (`depends_on` goes through `task dep`), and for a sprint id on a project that does not use sprints (`sprint=` still removes one). `subproject` must name a subproject of the task's project, matched as by `subproject <project> <name>`, and is written as its note is named; exit 1 when none matches. In a status project, a `status` other than the task's own, the last `status=` pair winning, moves the task's folder with `move` to `<tasks_root>/<status>/<ID>/` once the keys are written: the README's new vault path and the move's `links: <path> \| <count>` lines come after the changed keys. Exit 6, writing nothing, when anything is at that destination, an empty folder or a link too. The same status moves nothing, even from another folder, and a task whose folder is the destination already is not moved. A move that fails exits as `move` does, with the keys written. In a sprint project, a `sprint` other than the task's own, the last `sprint=` pair winning, moves the task's folder the same way, to the folder of that sprint, `<tasks_root>/<sprint folder>/<ID>/`, or to `<tasks_root>/backlog/<ID>/` for `sprint=`; there a status change moves nothing. Exit 6, writing nothing, when anything is at that destination, or when the sprint's folder is a task, with a `README.md` of its own (`the sprint folder is a task: <path>`). Exit 5, writing nothing, when `sprint_folder` gives the sprint no folder name. The same sprint moves nothing, even from another folder, and a task whose folder is the destination already is not moved. In a status or sprint project, an `epic` other than the task's own, the last `epic=` pair winning, moves the task's folder the same way, into its parent's folder in the folder of its status or sprint, `<tasks_root>/<folder>/<parent>/<ID>/`, and `epic=` or `epic=-` moves it out to `<tasks_root>/<folder>/<ID>/`. A move for a status or a sprint keeps a child under its parent, `<tasks_root>/<new folder>/<parent>/<ID>/`. An `epic` that names no single task of the project names no parent, with `note: <label> <value> names no single task of <project>` on stderr, `<label>` being the profile's `parent_label`. A task that holds children moves its own entries alone (section 4), and its destination may be a folder named for it that holds one of them; an entry already there gives exit 6, writing nothing. A move that leaves a folder that holds tasks empty removes it, and prints `removed: <path>` after the `links:` lines |
| `task tag <ID> add\|remove <tag> [--project P]` | the resulting topic tags | edits the `tags:` list; exit 5 for a `type/` or `status/` tag |
| `task alias <ID> add <alias> [--project P]` | the resulting aliases | appends to `aliases:`, quoted when needed; the first alias never changes. Exit 6 when the alias already names another task, exit 5 for an alias that names the folder `archive` or a status folder, in any letter case (section 4): `archive`, in any letter case, keeps the message `archive is the folder of the archived tasks, not a task alias`, and a status folder's name says `<alias> is the folder of the <status> tasks, not a task alias`, with `<alias>` as typed and `<status>` lowercased. Exit 5 too for `backlog`, in any letter case: `backlog is the folder of the backlog tasks, not a task alias`. Renaming a slug-named task to its ticket id is done by hand |
| `task dep <ID> add\|remove <ID> [--project P]` | the resulting `depends_on` links, or `-` when none is left | the second id is the task the first waits on, found by id or alias like the first; `--project` applies to both. `add` appends `"[[<vault path of its README, no .md>\|<its folder id>]]"` and puts the key after `carried_from`; a task already linked is not added twice. `remove` drops the item whose link leads to that README, whatever its display text, and leaves `depends_on: []` when none is left. Exit 1 for an unknown task, exit 5 for the task itself. No cycle check: the doctor's `depends-on` check reports one |
| `task new <ID> [--project P] [--title T] [--topics a,b] [--envs] [--subproject S]` | the new README's vault path | `--project` may be left out when the id's key names one project. In a status project the README is `<tasks_root>/planned/<ID>/README.md`, and in a sprint project `<tasks_root>/backlog/<ID>/README.md`, as a new task is in no sprint; every message names that path. Exit 6 when the task already has a README; when the id is a task in another folder, in every layout: at `<tasks_root>/<ID>/`, `<tasks_root>/<status>/<ID>/` or archived, or in `backlog/` or a sprint's folder (`the task is archived: <path>` for an archived one, else `the task exists: <path>`); or when the id is another task's alias; or when the folder has no README and holds a task, `<folder>/<ID>/README.md`, as a group folder such as a sprint's does (`the folder holds tasks: <path>`), since a README there would make it a task and take the tasks in it off the board. A folder with no README that holds no task gets one. Exit 5 for an id that names the folder `archive` or a status folder, in any letter case (section 4): `archive`, in any letter case, keeps the message `archive is the folder of the archived tasks, not a task id`, and a status folder's name says `<ID> is the folder of the <status> tasks, not a task id`, with `<ID>` as typed and `<status>` lowercased, as in `In-Review is the folder of the in-review tasks, not a task id`. Exit 5 too for `backlog`, in any letter case: `backlog is the folder of the backlog tasks, not a task id`. Also exit 5 for `--envs` when the profile lists no environments, and when the README filled from a project's own template has no frontmatter (section 8). A topic with no folder is still written, with a `note:` on stderr. `--subproject` writes the `subproject` key as `task set` does, exit 1 when it names none. With `--envs` the subproject's own environments come first. It fills the project's own `task-readme.md.tmpl` when there is one (section 8) |
| `task note <ID> "<text>" [--project P] [--session S]` | the line it added | prepends a dated line under `## Status notes` |
| `task archive <ID> [--project P]` | the README's new vault path, then the move's `links: <path> \| <count>` lines | moves a done or abandoned task's folder with `move` to `<tasks_root>/archive/<YYYY>/<ID>/`, the year being today's, then writes `archived: "<today>"`. Exit 5 when the project's `task_layout` is not `archive`, or when the task's status is not `done` or `abandoned`. Exit 6, moving nothing, when it is archived already or when anything is at the destination, an empty folder or a link too. Exit 1 for an unknown task. A move that fails exits as `move` does |
| `validation <project> [--json]` | one TSV row per repo, in the order `repo` lists them: name, home (`vault` or `repo`), path, state (`ok`, `missing`, `no-section`, `empty`, or `unknown` when a `repo` home has no recorded location) | path is a vault path for `vault`, absolute for `repo`, `-` when unknown. `missing`: the file is not there. `no-section`: it has no `## <repo>` section. `empty`: nothing is under its heading. A project with no repo prints nothing. Exit 1 when the profile is missing. `--json` prints the rows with the keys `name`, `home`, `path` and `state` |
| `validation <project> <repo> [--path <dir>] [--json]` | `path: <path>`, then the body of the repo's `## <repo>` section, as `profile <project> <section>` prints a section | the repo is matched exact first, then without letter case. Exit 1 when it is not a repo of the project, has no recorded location with a `repo` home, or when the file or its section is missing. `--path` names a folder that stands in for the repo's recorded one, such as a git worktree of it: a `repo` home's file is `<dir>/validation.md`, and the recorded location is not needed. A `vault` home's file is the same with it or without it. Exit 1 when `<dir>` is not a folder. `--json` prints one object: `path`, and `body`, the body as one string. `body` is `""` when the section is empty |
| `validation run <project> <repo> [--when each-story\|each-merge\|release] [--changed <base>] [--timeout <seconds>] [--path <dir>] [--json]` | one TSV row per check it runs or skips, in order: command, result (`pass`, `fail` or `skipped`), exit code, seconds, log. Under a `fail` or `skipped` row, its lines, each indented by two blanks | runs the command of each bullet under `### Checks` in the repo's section whose `when:` the run takes (section 3): `each-story` takes `each story`, `each-merge` takes `each story` and `each merge`, and `release` takes all three. `--when` is `each-merge` by default. `each-task` and `each-build`, the old names, read as `each-story` and `each-merge`. With `--changed <base>`, a check whose `paths:` the diff from `<base>` does not touch is `skipped`, with the line `no change to its paths since <base>`, as section 3 says. `<base>` is any commit git names in the folder the checks run from, such as a hash or a branch. The repo and its section are found as `validation <project> <repo>` finds them, with its `--path` too. Each command runs through bash, one at a time, from the repo's root, or from `<dir>` with `--path`, with stdin from `/dev/null` and its output and errors in its log, a temp file outside the repo and the vault. It is stopped after `--timeout` seconds, 1800 by default: it and the processes it started get TERM, then KILL 5 seconds later, and its exit code is 124. On Windows, `taskkill` also stops the Windows processes under it. What a command leaves running when it exits gets TERM, then KILL 5 seconds later, before the next command starts. On Windows this reaches only the shell's own processes. `seconds` is whole seconds. A `fail` row's lines are `stopped after <n> seconds` for a timeout, then the first 10 lines of its output that hold `fail` or `error` in any letter case, or its last 10 lines when none does, blank lines left out and each cut at 200 bytes. A bullet with no code span is `skipped`, with the line `no command`. A bullet with an unknown `when:` runs as `each merge`, and every run names it on stderr as `note: unknown when: <value>, read as each merge: <the bullet's text>`. A row skipped for `no command` has the bullet's text, on one line, for its command, and one skipped for its paths has its command. A skipped row's exit code, seconds and log are `-`. A section with no `### Checks` prints no row, with `note: no ### Checks in <path>` on stderr. Exit 0 when no row fails, 1 when one does. Exit 1 with no row as `validation <project> <repo>` does, and when the repo's folder is missing, or `<dir>` with `--path`. Exit 1 with no row too when `<base>` is no commit in that folder, or the folder is in no git repo: `--changed: no commit <base> in <folder>`. Exit 5 for another `--when`, a `--timeout` that is not a whole number above 0, a `--path` with no value, or a `--changed` with none or with one that starts with `-`. `--json` prints the rows with the keys `command`, `result`, `exit`, `seconds`, `log` and `lines`; `exit` and `seconds` are numbers, `null` on a skipped row, and `lines` is a list |
| `validation new <project> <repo>` | the path of the file it wrote or added the section to | from `validation-repo.md.tmpl`, writes a missing file with the repo's section, or adds the section to a file without it, after one blank line and in the file's line endings. A section that is there is never changed: `exists: <path>` on stderr, exit 0. Exit 1 as `validation <project> <repo>` does for the repo |
| `topic <project> <tag>` | paths of task READMEs carrying the tag or a sub-tag | |
| `search <project> "<text>" [--in SUBPATH]` | `path:line: text` matches, at most 40 | the text is split into terms at blanks; a part in double quotes is one term, a phrase. A note matches when it holds every term, in any letter case. A note gives at most three lines: for one term, the first lines that hold it; for several, the lines that hold the most terms among those holding at least two, or, when it has none, the first line that holds each term. When more than 40 lines are left, every note's best line is kept before any note's second. Lines holding more of the terms come first, then by path and line. Exit 1 when no note matches, exit 5 when the text holds no term |
| `outline <path>` | one row per heading: `<line>: <hashes> <heading>`, as in `12: ## Status notes` | a heading is a line that opens with one to six `#` and a space; those in frontmatter or a fenced code block are skipped. Exit 1 when the note is missing |
| `backlinks <path>` | `path:line: <link as written>`, one row per link that resolves to the note | covers every note of the vault; exit 1 when the note is missing. A note that cannot be read is named on stderr as `note: <path> could not be read` |
| `unresolved [project]` | `path:line: <link as written>`, one row per link that resolves to no file | the whole vault, or the notes under one project. A note that cannot be read is named on stderr as `backlinks` names it |
| `move <from> <to> [--dry-run]` | `moved: <from> -> <to>`, then one line `links: <path> \| <count>` per note it rewrote, with the note's path after the move | moves a note, any other file, or a folder with everything under it, and rewrites the links (see Links between notes). `<to>` is the new vault path, taken as written: no extension is added. When it names an existing folder or ends with `/`, the item goes inside it under its own name. Missing folders are created. Exit 1 when `<from>` is missing, exit 6 when the destination exists. Exit 5 when `<from>` is the vault root, or is or holds what the helper finds at a fixed path (the index, the conventions note, an index project's folder or its profile), and when a name in `<to>` cannot be written in a link. `--dry-run` prints the same lines after a first line `dry run`, writes nothing, and exits as the move would. `--` ends the options, for a name that starts with a hyphen |
| `rename <path> <name> [--dry-run]` | the same lines as `move` | a new name in the same folder; `--` ends the options here too. The extension never changes: `<name>` may end with the file's own extension, in any letter case, or leave it out, and anything else is part of the name, so `api.v2` gives `api.v2.md`. Exit 5 when `<name>` holds a slash |
| `sprint current <project>` | TSV: id, start, end, days_left, goal | exit 1 when no sprint is in progress. This and every other `sprint` command exits 5 with `<project> does not use sprints` when the profile says `uses_sprints: false` |
| `sprint next <project>` | TSV: id, start, end | what `sprint open` would create with no `--end`; writes nothing; exit 1 when the profile has no `sprint_anchor_end` |
| `sprint open <project> [--end YYYY-MM-DD] [--goal G]` | the new sprint note's path, then one line per task it re-pointed | exit 6 while another sprint is in progress. With no `--end` it takes the first cadence end on or after today that has no note. It writes `sprint_anchor_end` only when the profile has none. It rewrites the board's sprint literal. It moves every open task (status not done or abandoned) whose `sprint` id has no sprint note onto the sprint being opened, printing `re-pointed: <ID> from <old> to <new>`. In a sprint project each task it re-points then moves to the new sprint's folder with `move`, after the note and the keys are written. Before any write, exit 6 naming the destination when anything is there, or when that folder is a task (`the sprint folder is a task: <path>`), and exit 5 when `sprint_folder` gives the sprint no folder name. A task already in that folder is re-pointed and not moved. A child moves into its parent's folder there, `<tasks_root>/<sprint folder>/<parent>/<ID>/`, and a task that holds children moves its own entries alone (section 4). A move that leaves a folder that holds tasks empty removes it, and prints `removed: <path>` after its `links:` lines. After the re-pointed lines come each moved task's new README path and its `links:` lines. A move that fails is named on stderr, the other tasks still move, and the command exits with the first failing code |
| `sprint set <project> key=value...` | the changed keys | sets `goal` or `committed` on the sprint in progress; exit 1 when there is none, exit 5 for any other key |
| `sprint close <project> [--carry ID,ID] [--backlog ID,ID] [--abandon ID,ID]` | a summary: `sprint:`, `done:`, `carried:`, `backlog:`, `abandoned:`, `next:` | every open task of the sprint must be named in exactly one list, else exit 5 listing the problem. On tasks it writes `carried_from`, `sprint`, `status` and the tag. On the sprint note it writes the `## Close` lists, `completed`, `carried_over`, `status: done` and the tag. It writes no status notes; the caller adds the reason with `task note`. `next:` is the id carried tasks now point at. In a status project it moves each task named in `--abandon` to `<tasks_root>/<status>/<ID>/` for its new status, `abandoned`, with `move`, after the sprint note is written, so the note's links follow. In a sprint project it moves each task named in `--carry` to the next sprint's folder, `<tasks_root>/<sprint folder>/<ID>/`, and each named in `--backlog` to `<tasks_root>/backlog/<ID>/`, the same way; a done or abandoned task, and one named in `--abandon`, stays in the closed sprint's folder. Before any write, exit 6 naming the destination when anything is there. In a sprint project, a carried task also gives exit 6 when the next sprint's folder is a task, and exit 5 when `sprint_folder` gives that sprint no folder name. A task whose folder is `abandoned/<ID>/` already is set abandoned and not moved, and a task already in the folder its list sends it to is not moved either. A child moves into its parent's folder in the folder its list sends it to, such as `<tasks_root>/backlog/<parent>/<ID>/`, and a task that holds children moves its own entries alone (section 4). A move that leaves a folder that holds tasks empty removes it, and prints `removed: <path>` after its `links:` lines. After the six summary lines come each moved task's new README path and its `links:` lines. A move that fails is named on stderr, the other tasks still move, and the command exits with the first failing code |
| `scaffold vault [DIR]` | the files it created | never overwrites; creates the index, the conventions note, `claude/README.md`, `claude/pull-request.md` and `claude/writing-style.md`. A file that exists is named on stderr as `exists: <path>` |
| `scaffold project <name> --path P [--keys K1,K2] [--use-when TEXT] [--tasks-root R] [--topics-root R] [--sprints-root R] [--no-sprints] [--parent-label feature\|epic]` | the files it created | never overwrites (`exists: <path>` on stderr); adds the index row; exit 6 when a key in `--keys` already belongs to another project. The three root flags are written into a new profile, and the hubs and board are created under them. `--topics-root .` creates no topics hub. When the profile exists its roots win and the flags are ignored. Exit 5 for a root that leaves the project, repeats another root, or sits inside the tasks root. `--no-sprints` writes `uses_sprints: false` into a new profile, creates no sprints hub and no map line for it, and writes the board without its sprint parts; exit 5 together with `--sprints-root`. An existing profile's `uses_sprints` wins over the flag. `--parent-label` writes `parent_label` into a new profile, in lower case, and takes `feature` or `epic` in any letter case; exit 5 for another value. An existing profile's `parent_label` wins over the flag. The board names its `epic` column by the profile's `parent_label` |
| `scaffold subproject <project> <name> [--repos R1,R2]` | the files it created: the subproject note and the `README.md` of its docs folder | never overwrites (`exists: <path>` on stderr). Adds a link to the new docs hub under `## Topics` in the topics hub, once. A repo named twice in `--repos`, in any letter case, is written once. Exit 5 for a name that is not a folder name, or a repo name that holds a character outside letters, digits, `.`, `_` and `-`. Exit 6 when another subproject has that name in another letter case, or already lists one of the repos. Exit 1 for an unknown project or a missing profile. Writes no Code to doc map row: the user names the docs |
| `pointer` | the absolute path of the folder the pointer leads to | exit 2 when there is no pointer, or when a real file or folder sits in its place. A pointer whose folder is gone still prints where it leads, with a `note:` on stderr |
| `pointer set <DIR> [--replace]` | the folder the pointer now leads to | creates the pointer in the link directory: a symlink on macOS and Linux, a junction on Windows. Exit 5 when `DIR` has no `.obsidian` folder. A pointer that already leads to `DIR` is left alone. One that leads elsewhere, or to a folder that is gone, is kept, and the command exits 6 naming where it leads, unless `--replace` is given. A real file or folder in the pointer's place is never replaced: exit 6 |
| `link [--check \| --apply]` | one row per skill or agent: `name \| kind \| state \| target` | scans `<vault>/claude/` and each index project's `claude/`, but not that of a row whose path holds a `..` part or a backslash; never touches links it did not make. Exit 1 when a row is neither `linked` nor `foreign`. `--apply` reports what it did as `note:` lines on stderr |
| `link --foreign` | one row per foreign skill or agent: `name \| kind \| what \| target` | the foreign skills and agents of `### link, doctor, snapshot`. `what` is `folder`, `file` or `link`; `target` is where a link leads, else `-`. Exit 0, with no rows when there is none |
| `link move <skill\|agent> <name> [--project P]` | `moved: <from> -> <to>`, or `copied:` for a link that leads out of the vault; for a link into the vault, then the `links:` lines of `move`; then `listed: <path>`; then the item's row as `link --check` prints it | takes one foreign skill or agent, as `link --foreign` lists it, into the vault's `claude/`, or into the `claude/` of the project `--project` names, as `### link, doctor, snapshot` says. Exit 1 when no foreign item has that kind and name, for an unknown project, or when the row is not `linked` at the end. Exit 5 for another kind, a name that holds a slash or a backslash, starts with a dot or cannot be written in a link (as `move` says), a project path that leaves the vault, a frontmatter `name` that is missing or not `<name>`, and, for a link into the vault, a symlink on the way that `move` does not look behind. Exit 6 when the destination exists. Nothing is moved before these checks pass |
| `link drop-original <skill\|agent> <name> <path>` | `removed: <path>` | removes the original that `link move` copied in from out of the vault, the path of its `copied:` line, as `### link, doctor, snapshot` says. Exit 1, removing nothing, when no claude folder of the vault links the item, `<path>` is missing, or it differs from the copy. Exit 5 for another kind, a path that is not absolute, a link, the vault, a path inside the vault or one that holds it, a path that holds the link directory, and a path that is not a skill folder with `SKILL.md` or an agent `.md` file |
| `doctor [project] [--json] [--fix]` | one row per check: `result \| check \| scope \| count \| offenders \| fix` | exit 0 when no check fails, 1 when one does, 2 when there is no vault. `--fix` replaces a `pull-request` note that is older than the template and was never edited, `fixed: claude/pull-request.md -> version <n> (vault)`. It makes each `status/` tag follow its status, `fixed: <ID> -> <tag> (<project>)`. Then it fixes the tasks that `task-layout` names, each as `fixed: <ID> -> <new README path> (<project>)`, and prints the table. In an archive project it archives each one named `to-archive` through `task archive`, and never moves an open task. In a status project it moves each task to the folder of its status, as `task set` moves it, then removes each empty group folder other than the five status folders, such as `backlog/` or a sprint's folder, whether or not a move emptied it, each as `fixed: <path> -> removed (<project>)`; an empty status folder stays, and a task with no status of the five stays where it is, with `<ID> has no status of the five: left where it is` on stderr. In a sprint project it moves each task to the folder of its sprint, or to `backlog/` with none, as `task set` moves it, then removes each empty group folder, a status folder too, whether or not a move emptied it, each as `fixed: <path> -> removed (<project>)`; a task whose sprint gives no folder name stays where it is. Then, in a status or a sprint project, it removes each empty `<tasks_root>/archive/<YYYY>/` folder, and then `archive` when it is empty, each as `fixed: <path> -> removed (<project>)`; a folder that holds any other file, such as an archive README, stays. In a status or a sprint project a child moves into its parent's folder there, and a task whose `epic` names no single task of the project stays where it is, with `<ID>: its <label> <value> names no single task of <project>: left where it is` on stderr, `<label>` being the profile's `parent_label`. A folder that holds tasks that a move leaves empty is removed, `fixed: <path> -> removed (<project>)`. It moves nothing in a project whose tasks root leaves it. A task that `task archive` or the move refuses stays where it is, with the reason on stderr |
| `snapshot [name]`, `compare [name]` | where the snapshot is, or the differences | stored under `<vault>/.second-brain/snapshots/`. `snapshot` exits 6 when the name exists. `compare` covers unresolved links, aliases, task ids and statuses, and links; it does not compare tags or doctor rows. It exits 0 with `no differences`, and 1 on a difference or when there is no snapshot |
| `session-check [--cwd DIR]` | with no vault, one line; in a directory of a project of the index, the session block; else nothing | for the SessionStart hook, see session-check below; always exits 0. `--cwd` reads another directory than the working one |

### Links between notes

`backlinks`, `unresolved`, `move`, `rename`, the doctor's `unresolved-links` check and the snapshot
share one reading of a note's links, in `scripts/lib/graph.sh`.

- A link is a wikilink, `[[target]]`, or a markdown link to a file, `[text](target)`.
- A wikilink may carry `#heading` or `#^block` after the target, `|text` after that, and a leading
  `!` for an embed.
- A markdown target may be wrapped in `<>` or percent-encoded. One with a scheme (`https:`,
  `mailto:`) or one that starts with `#` is not a link to a file.
- Text in a fenced code block or an inline code span holds no links. Frontmatter does.
- A link with an empty target, such as `[[#heading]]`, points inside its own note and is skipped.
- A target is tried as written, then with `.md` added. Letter case is ignored (ASCII letters).
- A target resolves to the first of these that exists: the file at that vault path; the file at
  that path taken from the linking note's folder; the file whose vault path ends with the target
  at a folder boundary.
- When several files match that last rule, the one in the linking note's folder wins, then the one
  with the fewest folders in its path, then the first in byte order.
- A target that starts with `./` or `../` is taken from the linking note's folder only. One that
  starts with `/` is a vault path only.
- A target that resolves to no file is unresolved.
- The files of the vault are every file under the vault root outside dot folders (`.obsidian`,
  `.trash`, `.second-brain`). Notes are the `.md` files among them; only notes are read for links.
- A symlink inside the vault is not followed: what lies behind it is not a file of the vault.
- A markdown link sits on one line. One whose text is wrapped over two lines is not read.

What `move` and `rename` do to links:

- Every link keeps leading to the file it led to.
- A link that resolved to a moved file is rewritten to resolve to it at its new place. So is a
  link inside a moved note.
- So is a link anywhere that the moved file would capture at its new place, when it would
  otherwise resolve to another file or to none.
- A link that still resolves to the same file is left as written.
- A rewritten wikilink is the new file name alone when the old target was a file name alone and
  the new name is unique in the vault; otherwise it is the new vault path. It has `.md` only when
  the old target had it. `!`, `#heading` and `|text` are kept.
- A rewritten markdown link keeps its form: a path taken from its note's folder stays one, a vault
  path stays one, and `<>` or percent-encoding is kept.
- In frontmatter, a link inside a single-quoted value is written, and read, with each apostrophe
  of its target doubled.
- Not covered in frontmatter: a quoted value that runs over several lines, a block scalar, a quoted
  value behind a tag or an anchor, an unquoted link whose new name YAML reads as structure, and a
  note whose opening `---` is never closed.
- Files that are not notes are moved and never edited. A `.canvas` or `.base` file that mentions a
  moved file's old vault path is named on stderr as `note: <path> mentions <old path>`.
- The links are worked out before anything is written; the files are moved, then the notes edited.
- A destination is refused with exit 5 when a name the move creates, the new name or a folder that
  does not exist yet, holds one of `# ^ [ ] | \ : * ? " < >`, a backtick or a control character,
  or starts or ends with a blank.
- A source or a destination that lies behind a symlinked folder is refused with exit 5 too.
- Where the file system ignores letter case, `<from>` may be written in another case of ASCII
  letters. A spelling that reaches the file only through a fold the helper does not make, a
  Unicode form or the case of a letter outside ASCII, is refused with exit 1.
- Nothing is moved or written unless every note of the vault can be read in full and every note
  to rewrite can be written. A note that cannot is named on stderr and the command exits 1.
- Every rewritten line is read again before anything is moved: each rewritten link must be found
  and must resolve to its file. One that does not stops the command with exit 1, naming the note
  and the line.
- A note that changed while the command ran is left as it is and named on stderr as still holding
  old links. The other notes are rewritten and the command exits 1.
- The destination is looked at again right before the move and is never overwritten.
- Not covered: a rename that changes only the letter case of a name, on a file system that ignores
  case. It exits 6.

### link, doctor, snapshot

Library files: `scripts/lib/link.sh` (`cmd_link`, `cmd_pointer`, `sb_link_scan`),
`scripts/lib/doctor.sh` (`cmd_doctor`, `cmd_session_check`), `scripts/lib/snapshot.sh`
(`cmd_snapshot`, `cmd_compare`). Their private helpers are named `sb_link_*`, `sb_doc_*` and
`sb_snap_*`.

- On macOS and Linux every link is a symlink: one per skill folder in the link directory's
  `skills/`, one per agent file in its `agents/`.
- On Windows every link is a directory junction: one per skill folder, and one per claude folder
  for its whole `agents` folder.
- The agents junction is named `second-brain-vault` for the vault's own `claude/`, and
  `second-brain-project-<project path with each slash as a hyphen>` for a project's.
- Claude Code reads every agent file in a linked `agents` folder, and any other `.md` file kept
  there.
- `link` prints one row per agent on every system. On Windows each agent row carries the state of
  its folder's junction.
- Two project paths that give the same junction name cannot both be linked: the agents of the
  later one are `duplicate`.
- A junction needs a folder on a local drive, so a vault on a network share cannot be linked.
- A plain `ln -s` is never used on Windows.
- `sb_link_scan` prints one row per item, no header: `name | kind | state | target`. `kind` is
  `skill` or `agent`. `state` is one of `linked`, `missing`, `wrong-target`, `name-mismatch`,
  `duplicate`, `dangling`, `foreign`. `cmd_link --check` prints the same rows.
- A foreign skill is a `foreign` row of kind `skill` whose entry is a folder that holds
  `SKILL.md`, or a link to one. A foreign agent is a `foreign` row of kind `agent` whose entry is
  a `.md` file, or a link to one.
- Not foreign skills or agents: a folder with no `SKILL.md`, a `README.md` in `agents/` in any
  letter case, as no claude folder links one, any other file, and a link that leads inside the
  plugin, which `double-registration` names.
- Nor is a place in the link directory that another row of `sb_link_rows` names, such as the
  place of a vault item that is `name-mismatch` or `duplicate`. The vault provides it, and the
  `links` check names it.
- `link --foreign` lists them, and the doctor's `foreign` check warns on each.
- `link move` puts a skill at `claude/skills/<name>/` and an agent at `claude/agents/<name>.md` of
  the chosen folder.
- A real folder or file is moved there.
- What a link into the vault leads to is moved as `move` moves it, and the links to it are
  rewritten. The link, then dangling, is removed.
- What a link out of the vault leads to is copied there and stays where it was, named in a
  `note:`. The link is removed.
- A destination that appears after the check is never removed or overwritten: exit 6, and the
  item stays where it was. The copy makes its folder or file only where none is, and removes only
  what it made. The move runs `mv -n`, then checks that the item left its place and the
  destination is there, as `move` does.
- A real folder carries an empty mark file, `.sb-move.<random>`, while it moves. When `mv` put it
  inside a folder that took its place, the mark shows it there: it goes back where it was, with
  no row and no link, and the command exits 6. An agent file put inside such a folder goes back
  the same way. The mark is removed in either case, and when the folder cannot move back.
- Any `.sb-move.*` file directly in the folder is a stale mark, and is removed before the move.
- Stopped by INT, TERM or HUP while the mark exists, the command removes it from the folder's
  place, the destination and a folder that took its place, then exits 1.
- `link drop-original` removes that original. The vault-doctor fix runs it only after the owner's
  yes.
- It removes it only when the item's link leads into a claude folder of the vault, and the
  original matches that copy: the same entries by path, each of the same type (folder, file,
  link or other), each file with the same bytes and each link with the same target.
- It never removes a link, the vault, anything inside the vault or a folder that holds it, `/`
  included, or a folder that holds the link directory: each exits 5.
- It reads `<path>` as the system does: its folder is resolved with `cd -P`, links and `..`
  included, and its last part is added as it is. A last part `.` or `..` exits 5.
- That one resolved path is the one every check reads, and the one it removes.
- It exits 5 when the copy in the vault is the original itself, as `-ef` finds it, or when the
  copy is a link or lies behind one inside the vault.
- Then `link move` makes that item's link as `--apply` does, and no other.
- It adds the item's row to the table under `## Skills` or `## Agents` in that folder's
  `README.md`: `| [[<vault path of SKILL.md or the agent file, without .md>\|<name>]] | <description> |`.
- `<description>` is the frontmatter's `description` on one line, with `\|` for each `|`, or `-`.
- A `description` written as a block scalar, `>` or `|` with its text on the lines below, is `-`.
- The row goes after the table's last row. With no table under the heading, a new table ends the
  section. With no heading, the heading and the table end the file.
- A table row whose first cell names the item already is kept, with a `note:`. The cell names it
  by its text, or by a link whose alias is its name or whose path, `.md` or not, is the row's
  path. A missing `README.md` gets a `note:` and no row. `listed:` names the `README.md` only when a row was added.
- A doctor row is `result | check | scope | count | offenders | fix`. `result` is `ok`, `warn` or
  `fail`. `scope` is `vault` or a project name. `offenders` holds at most five, comma separated,
  or `-`.
- A long offender is cut and ends with `...`: at 48 bytes, or at 120 for the paths of `foreign`,
  `hubs`, `task-location` and `old-namespace`. A short tag after its last colon, such as `:no-folder`, is
  kept whole: the cut falls in the value before it.
- A check prints one row. Where it has a fail case and a warn case, a fail wins: the row is the
  fail row, with the fail offenders only.
- `subprojects` and `task-subproject` are the exceptions: a project with no subproject note gets no
  row for them.
- The doctor follows no `..`. An index path or a profile root is judged as it is written.
- For an index path that names no project folder (`## 2. The index`), the doctor prints no
  project rows, and opens and writes nothing under it.
- A project whose root leaves it (`### Profile frontmatter`) is checked under that root's default.
  Nothing is opened through that root, or through a root that starts with `/`.
- The doctor does not check where a project folder that is a link inside the vault leads.
- Doctor check names, exactly as printed:

| Scope | Check | Fails or warns when |
|---|---|---|
| vault | `pointer` | the pointer does not resolve to a vault (fail) |
| vault | `index` | the index is missing, has no Projects table, has a row whose path is not a folder in the vault (`<Project>:no-folder`; a path that names no project folder is never one and is not looked for on disk), or has a name, a key or a path on two rows (`<value>:twice`, compared as `## 2. The index` says) (fail); or its `index_version` is missing or lower than the template's (warn, `CLAUDE.md:<version or none>`) |
| vault | `conventions` | the conventions note is missing (fail), or its `conventions_version` is lower than the template's (warn) |
| vault | `pull-request` | `claude/pull-request.md` is missing from the vault (warn), or its `pull_request_version` is missing or lower than the template's (warn, `claude/pull-request.md:<version or none>`). A note was never edited when, CRs dropped, it holds a text the plugin wrote: the helper knows each by its `cksum`. The fix of an edited one says to bring it in line with the template by hand |
| vault | `writing-style` | `claude/writing-style.md` is missing from the vault (warn) |
| vault | `import` | no import line for the index in the link directory's `CLAUDE.md` (warn) |
| vault | `global-rules` | a line of the link directory's `CLAUDE.md` names an index project: its name as a whole word, as written, or its path in any letter case (`<project>:<line number>`, or `<project>:@<line number>` for an `@` import line, whose fix is to remove it) (warn). A whole word has no letter, digit, `_` or `-` on either side. The import line of the index and the table rows under a `## Projects` heading are not read, nor the files the `CLAUDE.md` imports |
| vault | `links` | a vault-owned skill or agent is missing, wrong-target, dangling, name-mismatch or duplicate (fail) |
| vault | `foreign` | a foreign skill or agent sits in the link directory (warn): a real folder (`skills/<name>:folder`), a real file (`agents/<name>.md:file`), or a link and where it leads (`skills/<name>:link to <target>`) |
| vault | `double-registration` | a link in the link directory points inside the plugin (warn) |
| vault | `always-loaded-size` | the index is over 60 lines or the link directory's `CLAUDE.md` over 40 (warn) |
| vault | `descriptions` | a scanned skill or agent has no description (`<name>:none`), or one over 200 characters (`<name>:<length>`) (warn) |
| vault | `skill-size` | a scanned `SKILL.md` is over 150 lines (warn) |
| vault | `old-namespace` | a line names a skill or agent of the plugin by its old name, `obsidian-dev-second-brain:<name>`: in a note of the vault outside its history (`<vault path>:<line>`), or in the link directory's `CLAUDE.md` (`~/.claude/CLAUDE.md:<line>`); or a string of a settings file holds `obsidian-dev-second-brain:`: in the link directory (`~/.claude/<file>:<string>`), the vault root (`.claude/<file>:<string>`) or a repo (`<repo>/.claude/<file>:<string>`) (warn). See the bullets under this table |
| project | `profile` | the profile is missing, lacks a contract key, lacks one of the seven sections, or has a root that leaves the project (`<key>:leaves-project`) (fail) |
| project | `board` | the board file is missing (fail). While a sprint is in progress: its `Current sprint` view filters on another sprint id (`tasks.base:<that id>`), its filter is not written as `sprint == "<id>"` (`tasks.base:filter`), or it has no such view (`tasks.base:no-view`) (warn); with no sprint in progress, or for a project that does not use sprints, the view is not looked at. For a project with a subproject note, a board with no `By subproject` view (`tasks.base:no-subproject-view`) (warn). For a project with `task_layout: archive`, a board whose own filters do not take `<tasks_root>/archive` (`tasks.base:no-archive-filter`) (warn). For a project with `task_layout: status`, a board whose own filters do not take each of the five status folders, as a quoted path ending in `/<status>` (`tasks.base:no-status-filter`) (warn). For a project with `task_layout: sprint`, a board whose own filters have no line `file.folder.split("/")[<digits>] == aliases[0]`, the branch that takes a task in a group folder (`tasks.base:no-sprint-filter`) (warn); with `uses_sprints: false` the board is not asked for it. For a status or a sprint project that has a child task, a board whose own filters have fewer than two such lines, as the branch that takes a task one level deeper adds the second (`tasks.base:no-child-filter`) (warn) |
| project | `hubs` | a hub is missing or empty (warn): `README.md`, `claude/README.md`, `<tasks_root>/README.md`, `<topics_root>/README.md` unless the topics root is `.`, and `<sprints_root>/README.md` when the project uses sprints. Offenders are paths under the project, and a hub that two roots share is named once |
| project | `placeholders` | a line of `README.md`, `claude/README.md`, `claude/profile.md` or a note in `claude/subprojects/` holds a placeholder of the template it was written from (warn, `<path under the project>:<line>`). A placeholder is text in angle brackets, with no blank after `<`, outside inline code unless it opens the code; only the template's own count, as written there. Frontmatter, fenced code and task READMEs are not read |
| project | `task-template` | the project's own `claude/templates/task-readme.md.tmpl` lacks a frontmatter key or a section that `### A project's own templates` names (warn, the key, or the section's heading as `## <heading>`). A key is read from frontmatter that opens on the first line. A heading is a line that equals it without letter case and trailing blanks, outside fenced code, as `task note` finds it. Frontmatter is not read for one. A project with no such template is ok |
| project | `task-frontmatter` | first alias differs from the folder name, or `type` or its tag is missing (fail) |
| project | `needs-a-status` | status missing or not one of the five (warn; never changed) |
| project | `status-tag` | the `status/` tag disagrees with `status` (warn; `--fix` repairs it) |
| project | `yaml-traps` | an unquoted alias holding a colon and a space, an unquoted lone dash value, an unquoted sprint id (fail) |
| project | `alias-unique` | one alias on two notes among task READMEs and hubs (fail) |
| project | `no-readme` | a task folder without a README (warn), in every layout: a folder directly under the tasks root other than `archive`, the five status folders, `backlog` and a group folder, one directly under a status folder, `backlog` or a group folder, or one directly under `<tasks_root>/archive/<YYYY>/`. A group folder here is, in a sprint project, each folder directly under the tasks root with no README, such as a sprint's folder; in another layout, one that holds a task, which `task-layout` names. A status folder itself never needs a README, and neither does `backlog` or a group folder. A folder with no README directly in a status folder, `backlog` or a group folder that holds a task holds tasks one level deeper (section 4): it needs no README, and each folder directly in it is read as one in a group folder is |
| project | `task-location` | a note under the project has `type: task` in its frontmatter and is not `<tasks_root>/<ID>/README.md`, `<tasks_root>/<status>/<ID>/README.md` in one of the five status folders, `<tasks_root>/<folder>/<ID>/README.md` in `backlog` or another group folder, `<tasks_root>/<folder>/<parent>/<ID>/README.md` one level deeper in one of them, as a child task is (section 4), or `<tasks_root>/archive/<YYYY>/<ID>/README.md` (warn). Offenders are paths under the project. Dot folders are not read, and neither is the folder of another index project that sits inside this one |
| project | `task-layout` | the tasks do not follow `task_layout` (warn). `flat`: an `archive` folder under the tasks root (`archive:flat`), and `task_layout: sprint` with `uses_sprints: false`, which reads as `flat` (`task_layout:no-sprints`): its fix is to set `uses_sprints: true`, or another layout. `archive`: an open task (planned, in progress or in review) in the archive (`<ID>:open`), a done or abandoned task outside it that is due by `archive_after_days` (`<ID>:to-archive`; `--fix` archives it), or an `archive_after_days` that is not a whole number (`archive_after_days:not-a-number`). In both, a status folder that holds a task (`<status>:flat` or `<status>:archive`): its fix is to set `task_layout: status`, or to move each task in it back to `<tasks_root>/<ID>` with `move`. `status`: a task with a status of the five outside the folder of that status (`<ID>:<status>`; `--fix` moves it), and any task in the archive (`archive:status`). A task with no status of the five is left to `needs-a-status`. In these three, a group folder that holds a task and is not the layout's own, `backlog` or a sprint's folder (`<folder>:<layout>`, as `backlog:flat` or `2026-10-14:status`). In `flat` and `archive` its fix is to set `task_layout: sprint`, with `uses_sprints: true` when sprints are off, or to move each task in it back to `<tasks_root>/<ID>` with `move`, and `--fix` moves nothing for it; in `status` each task in it is `<ID>:<status>` too, and `--fix` moves it. `sprint`: a task outside the folder of its sprint, or outside `backlog/` with no sprint, wherever it is, in the archive or a status folder too (`<ID>:<folder>`, the folder it belongs in; `--fix` moves it), and a `sprint_folder` that gives the sprint of a task no folder name, or, with no task in a sprint, gives none to a sprint ending today (`sprint_folder:invalid`). A task whose sprint gives no folder name is not named. In `status` and `sprint`, a child belongs in its parent's folder there, and its offender names that folder, `<ID>:<status>/<parent>` or `<ID>:<folder>/<parent>`; `--fix` moves it. A task that is no child belongs directly in the folder, even when it sits one level deeper. A task whose `epic` names no single task of the project is `<ID>:unknown-<label>`, `<label>` being the profile's `parent_label`, and `--fix` leaves it where it is. In every layout, a `parent_label` that is neither `feature` nor `epic`, in any letter case (`parent_label:invalid`) |
| project | `topic-tags` | a topic tag on a task maps to no folder under the topics root (warn). The profile's `## Topics` section may hold exceptions as lines `- <tag> -> <folder>` |
| project | `code-doc-map` | a repository in `repos` has no row in the profile's Code to doc map (warn) |
| project | `repos` | a repo of the project, a subproject's included, has a recorded location whose folder is missing (warn). Nothing recorded is ok |
| project | `subprojects` | only for a project with a subproject note. A note whose `type` is not `subproject` (`<name>:type`), one with no repos (`<name>:no-repos`), no docs folder (`<name>:no-docs`), a repo with no row in the profile's Code to doc map (`<name>/<repo>:no-map-row`), a repo whose folder is missing (`<name>/<repo>:missing`) or that has no recorded location (`<name>/<repo>:no-location`), or a repo listed by two subprojects, compared without letter case (`<repo>:twice`) (warn) |
| project | `task-subproject` | only for a project with a subproject note. A task whose `subproject` names no note in `claude/subprojects/`, compared without letter case (`<ID>:<value>`) (warn) |
| project | `settings` | a `validation_home` value that is not allowed, compared without letter case, in the profile (`profile:validation_home`) or a subproject note (`<name>:validation_home`), and a profile `lead_check_minutes` that is not empty, 10, 12, 15, 20, 30 or 60 (`lead_check_minutes:invalid`) (warn). A `delivery` or `spec_home` key, which versions before 0.12.0 read, is not read |
| project | `validation` | a repo of the project has no `validation.md` (`<repo>:missing`), no `## <repo>` section in it (`<repo>:no-section`), a section with nothing under its heading (`<repo>:empty`), or a section that still holds a placeholder of `validation-repo.md.tmpl`, or a retired one of an earlier version, listed in `sb_val_placeholders` (`<repo>:placeholders`) (warn). A `repo` home with no recorded location (`<repo>:no-location`). One whose folder is missing is left to the `repos` check. A project with no repo and a `vault` home: a missing `claude/validation.md` (`claude/validation.md:missing`). Each bullet under `### Checks` and `### Check as a user would` whose `when:` is an old name, `each task` or `each build` (section 3), as `<repo>:<name>:each-task` or `<repo>:<name>:each-build`. A check's name is its command, its first code span. A user step's name, and that of a check with no code span, is its text before its `when:` or `paths:`, with a code span in it read as its text. Those come after the other offenders, and the fix names each old name's new one |
| project | `sprints` | two sprints in progress, one in progress past its end, or a task pointing at a sprint with no note (fail). Not an offender: an open task pointing at the id `sprint next` gives while no sprint is in progress, which is where a close leaves carried tasks. For a project that does not use sprints, the one offender is a sprint note still in progress (warn) |
| project | `unresolved-links` | a note under the project holds a link that resolves to no file (warn) |
| project | `bare-links` | a task README links a repeated file name without a path, such as `[[README]]` (warn) |
| project | `line-endings` | a task README with mixed line endings (warn) |
| project | `depends-on` | a `depends_on` link of a task leads to no note or out of the vault (`<ID>:missing`), or tasks of the project depend on each other in a ring (`<ID>:cycle`, every task of a strongly connected group of two or more, and a task that depends on itself) (warn). A link matches a task of the project without letter case. The check fails with `awk:error` when it cannot run |

- `task-location` takes a note's type from frontmatter that opens on the first line and closes.
  The key is `type:` followed by a blank: `type:task` is no property, and frontmatter that never
  closes holds none.
- Not covered: a tasks root spelled in the profile with a letter outside ASCII in another Unicode
  form than the folder has on disk. macOS still finds the tasks through it, and `task-location`
  may then report each of them.
- Not covered: the notes behind a project folder that is a link. `task-location` and
  `unresolved-links` go by the files of the vault, and a link is not followed there.
- `old-namespace` reads every note of the vault, as `### Links between notes` defines them, the
  vault's own skills and agents included.
- A name of the plugin is a folder of its `skills/` or a file of its `agents/`. It counts only
  when no letter, digit, `_` or `-` follows it, so a cut name such as
  `obsidian-dev-second-brain:s` is none.
- A note's history is not read: the body of a heading `Status notes`, `Discovery log` or
  `Changelog`, of level 1 or 2 and in any letter case, up to the next heading of its level or
  higher; and the whole of a note named `CHANGELOG.md`, in any letter case.
- A heading `Build` opens history in a task README alone: a note whose frontmatter has
  `type: task`, read as `task-location` reads it. Elsewhere it is a heading like any other.
- A heading in frontmatter or fenced code opens no history. Frontmatter and fenced code are read.
- `docs-keeper` leaves exactly that history as written, so the warning clears once it has run:
  `Workflow 6 - A renamed command` in `agents/docs-keeper.md`.
- The settings files are `settings.json` and `settings.local.json`, in this order of folders:
  - the link directory, found as it always is: `SECOND_BRAIN_CLAUDE_HOME`, else `~/.claude`;
  - `.claude/` at the vault root;
  - `.claude/` in each repo a profile lists, a subproject's included, whose folder is there, in
    the order of the index and of `repo`.
- A file is read once, under its first label, even when two folders lead to it. No other settings
  file is read.
- A string is JSON text from a `"` to the next `"` that no backslash escapes, on one line. Any
  string that holds `obsidian-dev-second-brain:` counts, a rule with a wildcard such as
  `Skill(obsidian-dev-second-brain:*)` included.
- The link directory's `CLAUDE.md` is read whole, unless it is the index itself.
- Offenders name the link directory `~/.claude`, and a repo by its name in `repos`. The vault
  lines come first, by path and line, then the `CLAUDE.md` lines, then the settings strings, by
  file in the order above.
- The fix hands the vault lines to `docs-keeper`. A `CLAUDE.md` line is rewritten after the
  owner's yes. Nothing edits a settings file: the owner changes its strings.
- A snapshot is a folder `<name>/` holding `unresolved.txt`, `aliases.txt`, `tasks.tsv` (project,
  id, status), `links.txt` and `doctor.txt`, all read from the vault's files.

### session-check

The SessionStart hook runs it.

- With no vault, or a vault with no index, it prints one line:
  `second-brain: no vault is set up - run /odsb:vault-setup init`.
- In a directory that a project of the index holds, found as `context` finds the project, it
  prints one block:

```
second-brain context for this session:
project: Example
subproject: infra
sprint: 2026-10-14
branch: feature/EX-123-board-column
ticket: EX-123
story: projects/example/tasks/EX-123/README.md - in-progress, next: Add the column
rule: find and read notes with `second-brain find`, `search`, `task head` and `outline`, then a ranged read; never grep, cat or sed on vault files.
```

- `subproject` is there as in `context`.
- `sprint` is there only for a project that uses sprints: the sprint in progress, or `none`.
- `branch` is read from the repository's files, never from a git command: `.git/HEAD`, or in a
  linked worktree the `HEAD` of the git folder its `.git` file names. It is `detached` for a
  detached head, and `none` outside a repository.
- `ticket` is the first `<KEY>-<number>` in the branch for one of the project's keys, at the start
  of a word, matched without letter case and printed with the key as the index spells it. It is
  `none` when the branch names none.
- `story` is there only with a ticket: the vault path of its task README, found by its folder and
  then by its aliases, with its `status` and `next`; or `none - run story-tracker start`.
- The block always ends with the `rule` line, the search and read rule of the index.
- Anywhere else it prints nothing.
- Anything that fails while the block is built leaves the block out, and the command still exits
  0.

### Code layout

`bin/second-brain` resolves its own real directory, sources every `scripts/lib/*.sh`, then calls
the function `cmd_<command>` (dashes become underscores) with the remaining arguments.

- An unknown command prints usage and exits 5.
- A library file only defines functions.
- `scripts/lib/graph.sh` holds `cmd_outline`, `cmd_backlinks`, `cmd_unresolved`, `cmd_move` and
  `cmd_rename`. Its private helpers are `sb_graph_*`. `link move` calls `sb_graph_path`,
  `sb_graph_spell`, `sb_graph_link` and `sb_graph_move` for a link into the vault.
- The doctor calls `sb_link_foreign` and `sb_link_in_plugin` of `scripts/lib/link.sh`.
- `scripts/lib/platform.sh` holds what differs between systems. Its private helpers are
  `sb_plat_*`.
- `scripts/lib/subproject.sh` holds `cmd_subproject` and the subproject helpers, `sb_sub_*` and
  `sb_need_sub`. `sb_scaffold_subproject` is in `scaffold.sh`.
- `scripts/lib/validation.sh` holds `cmd_validation` and its helpers, `sb_val_*`. The doctor,
  `scaffold project` and `subproject` call `sb_val_home`, the doctor and `scaffold project`
  `sb_val_rows`, and the doctor `sb_val_placeholders`, and `sb_val_checks` for each old `when:`.
- Inside the helper every absolute path is in the shell's own form: on Windows, Git Bash's
  `/c/...`. `sb_path_in` turns a path that was read into that form, and `sb_path_out` turns one
  into the printed form. On macOS and Linux both leave the path as it is.
- On Windows `platform.sh` defines shell functions named `awk`, `grep` and `sed` that run the
  tools in binary mode, so a CRLF file is read and written byte for byte. They are the one
  exception to the `sb_*` naming rule.
- A library calls those three tools by their plain names, never through `env` or `command`.

Shared functions, defined in `scripts/lib/core.sh`, `platform.sh`, `link.sh`, `graph.sh`,
`projects.sh` and `subproject.sh`:

| Function | Does |
|---|---|
| `sb_die <code> <message>` | prints to stderr, exits |
| `sb_root` | prints the vault root or exits 2 |
| `sb_plugin_root` | prints the repo root |
| `sb_template <name>` | prints the path of a template: the current project's own (section 8) when it has one, else the plugin's |
| `sb_template_shown <name>` | prints how a message names the template `sb_template` finds: the plugin's by its name, a project's own by its vault path, whatever folder the vault is in |
| `sb_fm_get <file> <key>` | prints a scalar frontmatter value, unquoted |
| `sb_fm_list <file> <key>` | prints a list value, one item per line (block or inline form) |
| `sb_fm_set <file> <key> <value>` | sets or removes (empty value) a scalar key, keeping line endings |
| `sb_is_windows` | returns 0 when the helper runs in Git Bash on Windows |
| `sb_path_in <path>` | prints an absolute path that was read, in the shell's own form |
| `sb_path_out <path>` | prints an absolute path in the form the helper shows |
| `sb_link_home` | prints the link directory |
| `sb_mklink <target> <link>` | creates one link: a symlink, or on Windows a junction to a folder; returns 1 when it cannot |
| `sb_rmlink <link>` | removes one link and never what it leads to |
| `sb_graph_unresolved [vault folder]` | prints the `unresolved` rows for the vault or one folder, for other libraries to reuse |
| `sb_projects_tsv` | name, path, keys per line |
| `sb_project_path <name>` | prints the vault-relative path or returns 1 |
| `sb_profile <name>` | prints the profile's absolute path or returns 1 |
| `sb_repo_rows <project>` | prints the `repo` rows (name, path, state) for other libraries to reuse, with paths in the shell's own form |
| `sb_sub_files <project path>` | prints the absolute path of each subproject note, by name |
| `sb_sub_by_cwd <project path> <dir>` | prints the names of the subprojects whose repository holds the directory |
| `sb_today` | prints today's date; honours `SECOND_BRAIN_TODAY` for tests |

- Every helper function is named `sb_*` and every command `cmd_*`.
- A library must not redefine a function another library owns.
- Also shared: `sb_need_root`, `sb_need_project`, `sb_setting`, `sb_fm_edit`, `sb_fm_keys`,
  `sb_fm_cache`, `sb_lc`, `sb_section`, `sb_task_files`, `sb_task_list`, `sb_task_list_keep`,
  `sb_task_list_drop`, `sb_task_readme`, `sb_task_groups`, `sb_task_nested`, `sb_task_scan`,
  `sb_task_parent`, `sb_task_parents`, `sb_task_parent_in`, `sb_alias_hits`, `sb_parent_label`,
  `sb_sprint_current_id`, `sb_sprint_folder`, `sb_uses_sprints`, `sb_need_sprints`, `sb_fill`,
  `sb_body_insert`, `sb_note`, `sb_md_files`, `sb_board_sprint_literal`, `sb_projects_memo`,
  `sb_repo_memo`, `sb_date_days`, `sb_date_civil`.
- Every command that looks for a task goes through `sb_task_files`, which lists a tasks folder's
  task READMEs directly under it, in each of the five status folders and in the archive, and
  `sb_task_readme`, which finds one task folder's README in any of them.
- Both also look in each group folder that `sb_task_groups` lists: the five status folders in
  their order, `backlog`, then each other folder directly under the tasks root with no
  `README.md`, sorted. `sb_sprint_folder` names a sprint's folder from `sprint_folder`.
- In each group folder, both take a task one level deeper too, as section 4 says, from
  `sb_task_nested`. `sb_task_parent` names a task's parent, and `sb_parent_label` the profile's
  word for it.
- A command that moves several tasks lists their tasks folder once for its moves.
  `sb_task_list_keep` keeps the listing, and `sb_task_list` prints it in place of `sb_task_files`
  for that folder, until `sb_task_list_drop`. `sb_task_parents` reads the parent of every task
  that moves in one pass, the one `sb_task_parent` names for each. `sprint open`, `sprint close`
  and the doctor's `--fix` do so; the doctor lists each project's tasks folder once more for its
  rows, after the moves.
- `sb_need_project` and the doctor's project setup call `sb_fm_cache`, which reads the scalar
  keys of one note's frontmatter once, the project's profile, so that `sb_fm_get` and
  `sb_setting` answer for that note with no process. `sb_fm_list`, `sb_section`, `sb_repo_paths`
  and the doctor's profile checks still read the file. An edit through `sb_fm_edit`,
  `sb_body_insert` or `sb_body_append` drops the cache. `sb_lc` lowers the letter case of a
  keyword with no process.

## 8. Templates

`templates/*.tmpl`, filled by `sb_fill`.

- Placeholders are `{{UPPER_SNAKE}}`.
- A line that holds only an empty placeholder is dropped.
- A filled file must contain no `{{`.

| Template | Becomes | Placeholders |
|---|---|---|
| `vault-index.md.tmpl` | `<vault>/CLAUDE.md` | none |
| `obsidian-conventions.md.tmpl` | `<vault>/obsidian-conventions.md` | none |
| `vault-claude-hub.md.tmpl` | `<vault>/claude/README.md` | none |
| `pull-request.md.tmpl` | `<vault>/claude/pull-request.md` | none |
| `writing-style.md.tmpl` | `<vault>/claude/writing-style.md` | none |
| `project-readme.md.tmpl` | `<project>/README.md` | `PROJECT`, `PROJECT_PATH`, `TASKS_HUB_LINE`, `TOPICS_HUB_LINE`, `SPRINTS_HUB_LINE` |
| `project-claude-hub.md.tmpl` | `<project>/claude/README.md` | `PROJECT`, `PROJECT_PATH`, `VALIDATION_LINE` (empty when the profile's `validation_home` is `repo`) |
| `profile.md.tmpl` | `<project>/claude/profile.md` | `PROJECT`, `PROJECT_PATH`, `TICKET_KEYS`, `TASKS_ROOT`, `TOPICS_ROOT`, `SPRINTS_ROOT` |
| `hub.md.tmpl` | `tasks/README.md`, `docs/README.md`, `sprints/README.md` | `PROJECT`, `PROJECT_PATH`, `HUB_NAME`, `HUB_TITLE`, `HUB_INTRO` |
| `tasks.base.tmpl` | `<project>/tasks/tasks.base` | `TASKS_PATH`, `TASK_DEPTH`, `ARCHIVE_DEPTH`, `STATUS_DEPTH`, `CHILD_DEPTH`, `SPRINT_ID`, `PARENT_LABEL` |
| `task-readme.md.tmpl` | a task README | `ID`, `TITLE`, `TOPIC_TAGS`, `UP_LINK` |
| `task-envs.md.tmpl` | the environment-set additions | `ID`, `ENV` |
| `ticket-description.md.tmpl` | paste-ready ticket text | none |
| `sprint-note.md.tmpl` | a sprint note | `PROJECT`, `SPRINT_ID`, `START`, `END`, `UP_LINK` |
| `subproject.md.tmpl` | `<project>/claude/subprojects/<name>.md` | `PROJECT`, `SUBPROJECT`, `REPOS`, `UP_LINK`, `PROFILE_LINK`, `DOCS_LINK` |
| `subproject-docs.md.tmpl` | `<topics_root>/<name>/README.md` | `PROJECT`, `SUBPROJECT`, `UP_LINK`, `NOTE_LINK` |
| `validation.md.tmpl` | `<project>/claude/validation.md` | `PROJECT`, `PROJECT_PATH` |
| `validation-repo.md.tmpl` | one `## <repo>` section of a `validation.md` | `REPO` |

A link in a generated note carries the full vault path of a `README.md`, with the alias as display
text.

### A project's own templates

A project may keep its own `task-readme.md.tmpl` and `ticket-description.md.tmpl` in
`<project>/claude/templates/`, under those names. No other template is read from there.

- A project's own template wins over the plugin's. The plugin's is used when the project has none.
- `task new` fills the project's `task-readme.md.tmpl`.
- story-tracker fills the project's `ticket-description.md.tmpl` for ticket text, as
  `skills/story-tracker/SKILL.md` says.
- A project's template takes the placeholders of the plugin's. Any other is left unfilled, so
  `task new` exits 5 and names the template.
- A project's `task-readme.md.tmpl` opens with frontmatter. When the README filled from it has
  none, as from an empty template, `task new` exits 5, names the template and leaves no README.
- A project's `task-readme.md.tmpl` keeps the frontmatter keys the helper writes: `aliases`,
  `title`, `status`, `next`, `branch`, `epic` and `type`.
- It keeps the sections the helper or story-tracker writes under: `## Status notes` and
  `## Discovery log`.
- The doctor's `task-template` check warns about a key or a section it lacks.

## 9. Skills and agents

- The plugin's namespace is `odsb`, the `name` in `.claude-plugin/plugin.json`. Skills run as
  `/odsb:<skill>`, and agents show as `odsb:<agent>`.
- The marketplace entry in `.claude-plugin/marketplace.json` keeps the name
  `obsidian-dev-second-brain`, so an install stays `obsidian-dev-second-brain@second-brain` and
  updates in place.
- Frontmatter: `name` (equals the folder or file name), `description` (one sentence, under 200
  characters, quoted if it contains `: `).
- A skill's `allowed-tools` names each tool its steps use. One that edits notes names `Edit`, one
  that writes a whole note `Write`, and one that hands work to another skill
  `Skill(odsb:<that skill> *)`. `Skill(<name>)` matches only a call with no arguments, and the
  call names a ticket id.
- A command other than the helper gets a pattern only where nothing its wildcard can take, an
  option or a `-c` setting, can make it write a file or run a program, such as `Bash(ls -d *)`.
- Any other command prompts. A `git -C *` pattern never qualifies: the wildcard for the repo path
  can take `-c gpg.program=<command>`, which a signature check runs.
- A skill that runs only by name sets `disable-model-invocation: true`.
  `vault-setup` is the one: it writes the pointer and the links into `~/.claude`.
- Claude may call `vault-doctor` from a request: its check writes nothing, and its fix repairs only
  what is safe and asks before anything else.
- A skill's `SKILL.md` holds the router and the rules needed on every run. Detail for one mode goes
  in a sibling file that is read only in that mode.
- Every skill and agent carries this pointer near the top and does not restate the conventions:
  `Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.`
- Every skill runs `second-brain context` as its first tool call, and resolves the project with
  `second-brain project`.
- No skill uses a command that runs at load time.
- When the helper is missing, the skill says so and stops. It does not guess paths.
- Agents call skills through the Skill tool as `odsb:<name>`.
- A skill names a project's parent stories by its `parent_label`: features or epics. The
  frontmatter key it writes stays `epic`.
- **Two skills keep the work.** `story-tracker` owns each ticket. `scrum-master` refines the
  stories, plans the sprints and releases, and checks the board. Each has its own `description`,
  as ticket requests come often and must pick their skill alone.
- Each `SKILL.md` is its skill's readme. It holds the context step, the rules each run needs and
  a table that routes each mode or workflow to its file in the same folder. Each file is read only
  when its mode or workflow runs.
- Neither skill has a daily status.
- **`story-tracker`** handles one ticket at a time: draft, start, update, recall, status and
  environment set. Its files are `create.md`, `status.md` and `env-split.md`.
- Its start mode shows a new story's text and writes it only on the owner's approval. A change the
  owner asks for is shown again before it is written.
- Those approval rules have one home, `## 3. Create the story` in `skills/story-tracker/create.md`.
  The scrum-master's refinement and release planning read them there.
- Every story whose text the owner approved, in start mode or in refinement, gets the status note
  `Planned: the owner approved this text.` first. The `build` skill builds only a story with that
  note.
- Refinement writes it too on each story of an approved draft that exists and lacks it, changed
  or not: the owner may approve a story as it is.
- A story it sets to `done` goes to `docs-keeper`, as below. It logs no achievement, and neither
  does the sprint close: only an achievements skill tracks them.
- **`scrum-master`** is planning, a talk with the owner, which an agent cannot hold, so it is a
  skill. Its four workflows are `refinement.md`, `sprint-planning.md`, `release-planning.md` and
  `organize-board.md`.
- `refinement` drafts or refines an epic and its stories, or one story, with the owner.
- Each story of its draft has the shape of section 1 of `skills/story-tracker/create.md`, with at
  most 4 acceptance criteria, its parent and the tasks it waits on.
- The skill shows the owner the whole draft and writes nothing until the owner approves it.
- A change the owner asks for is made in the draft and shown again. It is written only once the
  owner approves it.
- On the approval it writes through story-tracker: its start mode for each new epic, then each
  new story, and its update mode for each one that changed. Then it links each story to the tasks
  it waits on with `task dep`, and links the stories in the epic's list.
- `sprint-planning` opens a sprint, picks its stories and closes it with carry-over.
- A request to close the sprint goes to its close. With no sprint in progress, it says so and
  stops: it opens one only when the user asks.
- `release-planning` sets a release's goals, epics and stories with the owner, in the project's
  planned-releases note (section 3). A story or epic that does not exist yet goes through
  refinement first.
- It shows the release's section and writes it only once the owner approves it. It writes only
  that section and the `## Epics` lines.
- `organize-board` runs the doctor on the project, says what each failing row means, and changes
  nothing without asking.
- **The `build` skill builds approved stories.** It takes one story, or an epic's open stories in
  the order their `depends_on` sets, and builds each in turn in the owner's session. Its files
  are `SKILL.md`, `story.md`, for one story's build, and `lead.md`, for the orders note and the
  lead's check.
- It is the one flow that builds a story: from its README, with no delivery mode. The spec flow
  of versions before 0.12.0 is retired, and no skill reads a story's old `spec/` folder.
- A story is approved when its status notes hold `Planned: the owner approved this text.` One
  with no such note is not built: the skill offers `refinement`, and leaves out each story that
  waits on it.
- Each story is built in a git worktree of its own, `<repo path>-<ID>`, next to the repo's
  folder, on the story's branch. Its `implementer` and its `reviewer` work there, in story mode,
  and each `validation` and `validation run` they run takes `--path <worktree>`.
- A new build never reuses that path: when anything is there already, the skill says what it is
  and stops. A resumed build goes on in its own worktree, the repo's worktree on the story's
  branch, and says so. It never deletes what it finds.
- A branch that does not start on the base branch gets a baseline first: `reviewer` in baseline
  mode, in the worktree.
- One `implementer` builds the story. Then a fresh `reviewer` grades it. A FAIL sends the review's
  defects back to the same `implementer`, and a fresh `reviewer` grades the fix, until one passes
  or the cap stops the build for the owner.
- `reviewer` runs on `opus`. `implementer` builds the story and takes fix rounds 1 to 3 on `opus`,
  as `<ID>-implementer`. Rounds 4 and 5 go to a fresh one on `fable`, the stronger model,
  `<ID>-implementer-2`. A sixth failed review stops the build.
- The story's progress is in its status notes. The counts read them, so each note has one of
  these shapes, word for word:
  - `Build: started on <branch> at <short hash>.`
  - `Build: resumed on <branch> at <short hash>.`
  - `Build: baseline skipped: the branch starts at <base> on <base ref>.`
  - `Build: the baseline passed at <short hash>.`
  - `Build: review <n> passed at <short hash>.`
  - `Build: review <n> failed at <short hash>: <k> defects.`
  - `Build: review <n> failed at <short hash>: the owner ruled a fix.`
  - `Build: review <n> blocked at <short hash>.`
  - `Build: review <n> gave no verdict at <short hash>.`
  - `Build: stopped: <why>.`
  - `Build: the owner ruled: <the ruling, as written>.`
  - `Build: finished; review <n> passed, the branch is at <short hash>.`
  - `Build: merged <branch> into <target> at <short hash>.`
  - `Build: pushed <target> at <short hash>.`
  - `Build: the owner kept <branch> unmerged.`
  - `Build: <branch> waits for <that branch> in <target>.`
  - `Ruling: <the question> - <the decision and why>`
  - `Defect <n>: <what is wrong, at file:line> - Fix: <the fix you propose>`, which `reviewer`
    writes.
  - `Defect <n>: The owner ruled: <the ruling, as written> - Fix: <the fix it asks>`, for the
    owner's ruling to fix the story.
  - `Follow-up: <what could be better, at file:line> - <the change you propose>`, which
    `reviewer` writes.
- The notes of a build are those newer than its newest `Build: started on` note. Its `fails` is
  the number of its `Build: review <n> failed at` notes, from every session. The round of its
  next review, `<n>`, is one more than the number of its `Build: review <n>` notes.
- A build resumes in a new session from those notes, as `## 1. Where the story stands` in
  `skills/build/story.md` says. One whose newest `Build:` note is `Build: stopped: <why>.` asks
  the owner first.
- **The git flow.** Where a story's branch is cut, and where a passed story merges, is the
  project's own git flow: its rules under `## Rules` in `<project>/claude/README.md`, and in the
  story's subproject note. The skill reads them there. No profile key holds the flow.
- A rule names a branch, such as `main`, or a pattern, such as `release/<version>`. A pattern
  stands for its open branch: the highest that matches it, when no tag `<version>` or
  `v<version>` holds its version. When that one has a tag, or the next one has none either, the
  skill asks the owner.
- The branches that match are listed by their full ref, local and remote, with the ref's prefix
  stripped before they are sorted, so a pattern with no slash, or with two, matches as written.
- A story cut from another story's branch merges only once that story is in the target. Until
  then the skill writes `Build: <branch> waits for <that branch> in <target>.`, and sets `next`
  to say so.
- With no rule that names its target, the skill asks the owner where it merges first, as for any
  story, and checks that the other story is in it after the answer.
- A later run takes up an `in-review` story whose newest `Build:` note is that wait. It finds the
  target again, as the git flow says, since the release the wait named may have shipped: a
  shipped branch is no open one, so the skill asks the owner.
- It reads the project's rules for that, and asks the owner where the story merges when no rule
  names it. Then it goes straight to the merge once that branch is in the target found. It merges
  from the story's branch, so the story's worktree is not needed again.
- No rule says where a story merges: the skill asks the owner, and offers to write the answer
  under `## Rules`. It writes it only on the owner's yes. No rule says where a branch is cut: it
  is cut as story-tracker's branch check says.
- **The merge.** A passed story merges into its target only on the owner's go. The merge is
  local, in the worktree that holds the target, or in one the skill adds for it when none does.
- That worktree may be the owner's own checkout: the skill merges there only when it holds the
  target and has no change. With a change there, it asks the owner.
- A worktree the skill adds for a merge is removed whenever the merge ends: pushed or not, kept,
  stopped, or answered after a failing check.
- A conflict that only adds lines keeps both sides. The merge runs with
  `merge.conflictStyle=diff3`, so each conflict block shows the merge base's lines too. A block
  whose base part is empty, where neither side removed or changed a line, takes the target's
  lines, then the story's.
- Not when both sides share a line in that block, which would keep it twice, and not in a file
  with no base, one both sides added, which would join two files. `git ls-files -u` lists no
  stage 1 for such a file. Each of these is shown to the owner, as any other conflict.
- Any other conflict, such as a block with base lines or a file one side deleted, is shown to the
  owner, and the merge is aborted. The skill never resolves one itself.
- Then every `each merge` check of the repo runs on the merged tree, through
  `validation run --when each-merge --path`, with no `--changed`: a review runs only the
  `each story` checks its change touches, so the merge runs them even on the tree the review read.
- The merge runs no user step, as it launches no agent. The skill names each `each merge` user
  step to the owner, as one it leaves for them to ask for, so that none is skipped unsaid.
- A failing check leaves the merge local, and goes to the owner. Undoing it is the owner's call.
- A push runs only on the owner's word, asked for once the checks pass, and named before it runs.
- Once the merge is done, or the owner says not to merge, the skill removes the story's worktree
  with `git worktree remove`, never with `--force`, and the branch stays.
- `git worktree remove` refuses a worktree with a change, but deletes its ignored files, such as a
  `.env`. So the skill first lists them, the `!!` paths of `git status --porcelain --ignored`,
  and removes a worktree that holds one only on the owner's word.
- A session can end after a story passed and before its worktree is removed. An `in-review` story
  with a `Build: finished` note whose worktree is still there goes on from the merge, or from the
  removal once a merged or kept note shows the merge is settled.
- **The baseline.** A new build first launches `reviewer` on the untouched branch, in baseline
  mode, unless the branch starts on the base branch.
- The branch starts on the base branch when `git merge-base --is-ancestor <base> <base ref>`
  exits 0, `<base>` being the hash of the build's `Build: started on` note.
- The base branch is the subproject's `base_branch`, or the profile's. `<base ref>` is
  `origin/<base branch>` when the repo has it, else `<base branch>`.
- When it does, the skill skips the baseline and writes its `Build: baseline skipped:` note.
- Any other result runs the baseline, such as on a branch cut from `release/<version>` or with
  commits the base lacks.
- A resumed build skips the baseline, whatever the start.
- The baseline runs the checks through `validation run --when each-merge`, and the `each story`
  and `each merge` user steps: every one but the `release` ones.
- **One story at a time.** One story and one agent at a time, never in parallel.
- No agent launches another. The skill launches `implementer` and `reviewer` with the Agent tool,
  one at a time, and names each launch's model by role and round.
- Each `implementer` launch is named, so that a fix message reaches the agent of that name again
  with SendMessage.
- In a new session, or when SendMessage cannot reach it, a fresh `implementer` is launched in its
  place, with the same name and model.
- The skill takes each report from the agent's result. Nothing is relayed by hand.
- A notice that repeats a reply the skill took already, such as a named agent's last reply sent
  again in its idle notice, is no new event. It changes no state and gets no reply.
- **An agent with no report.** An agent can go idle before its report, such as on a reply that
  says its checks still run. Its report is an `implementer`'s `Commit:` or `BLOCKED:` line, or a
  `reviewer`'s JSON block.
- Before the skill takes such a reply as final, it checks the worktree, with `git log` and
  `git status --porcelain`, and whether a check the agent started still runs.
- A check that still runs is waited for. With none, the skill sends the agent one message to
  finish its step and report. Its next reply is final.
- That message holds no view of the result, so a `reviewer` gets it too.
- **The owner's open orders.** The skill keeps the owner's open orders of a build in
  `<project>/claude/lead-agent-task-memory.md`, linked from the project's `claude/README.md`.
- The note holds each open order, with its date, its story, the owner's words, its `Done when:`
  condition and what works on it now. Then the orders done, and one line per story on its last
  check.
- `Done when:` is one condition that a command, a file or a branch state shows to hold or not,
  such as `git merge-base --is-ancestor <branch> release/<version>` exiting 0. A judgement is no
  condition.
- The skill writes it from the owner's words when it takes the order. It asks the owner only when
  their words give none, in its reply, and then the order cannot close until they answer.
- A condition's command only reads. Only the owner changes or drops a condition.
- The skill adds its order when a build starts or resumes. Two builds of the project share the
  note, so once it is there the skill changes it only with edits, never a whole rewrite.
- A note missing while an order of the story is open is written again.
- An order closes when its `Done when:` condition holds, or when the owner stops the build or
  drops the order, at a stop or not. The check's own prompt is no order.
- Once no order of its story is open, the skill stops its check. Once no order of any story is
  open, it removes the hub's line, then the note. Removing its own note is no destructive action.
- **The lead's check.** While an order of its story is open, the skill checks on the agents, the
  worktree and the running checks against the orders, as often as the profile's
  `lead_check_minutes` says (section 3). Of each order it tests the `Done when:` condition, and
  asks whether it or an agent works toward it.
- The check closes an order whose condition holds, and never one whose condition does not. It
  never changes a condition.
- A condition the check cannot test, such as one whose command is not found, does not hold. The
  check says so once, not at each check.
- In Claude Code a session-only `CronCreate` job runs the check, off the hour and the half hour,
  and `CronDelete` ends it. The skill keeps a job `CronList` shows with the same prompt. With no
  scheduling tool, the skill checks on each notice that comes to it.
- A process counts as the agent's check only when its working directory or command line is under
  the worktree's path.
- The check goes on with an order no one works toward only when the owner has not since
  interrupted the skill or told it to hold. Otherwise it waits for the owner and says so once,
  not at each check.
- The check never pushes, merges or takes another outside action.
- **The stop list.** Once the build has started, the skill stops and asks the owner with
  AskUserQuestion only for: a destructive action, a security-sensitive one, an outside effect
  such as a push, a merge or a publish, a story too unclear to build, a story blocked or past its
  last fix round, and a failed baseline. `## 8. When to ask the owner` in `skills/build/story.md`
  holds the list.
- A `BLOCKED` review is a block too. So is a review that still gives no verdict from one fresh
  `reviewer` in its place.
- A story is too unclear to build when going on would change, add or drop an acceptance
  criterion.
- The steps before the build's `Build: started` or `Build: resumed` note ask as they say: the
  owner has just run the skill.
- **Rulings.** Any other question, such as a criterion an agent reads two ways or two reviews that
  ask for opposite fixes, the skill decides itself. It records each with
  `second-brain task note <ID> "Ruling: <the question> - <the decision and why>"`, before the next
  launch.
- A ruling never changes, adds or drops an acceptance criterion. It never lifts a stop: only the
  owner's ruling does.
- An `implementer` reply `BLOCKED:` on a question a ruling settles is no stop. The skill rules on
  it and goes on. The same question again is a stop.
- **The rulings of a build** are the status notes newer than its newest
  `Build: started on <branch> at <short hash>.` note: the skill's `Ruling:` notes and the owner's
  `Build: the owner ruled:` notes. A note below it is from an earlier build of the story. A new
  session reads them from `## Status notes`.
- Every ruling of the build goes, as written and oldest first, into each later `implementer`
  prompt and fix message, and each later `reviewer` prompt.
- The owner's is the line `Owner: <the ruling, as written>.`, the skill's
  `Ruling: <the question> - <the decision and why>.`.
- `implementer` and `reviewer` follow both. Where they differ, the `Owner:` line wins. What a
  ruling decided is never a finding.
- When the build finishes or stops, the skill lists every ruling of the build, as written, oldest
  first.
- The owner can then reverse a ruling with one of their own. A story that passed takes the
  owner's ruling to fix it as the defect of a new round, and goes to the fix loop, as
  `## 7. When the story stops` in `skills/build/story.md` says.
- Each update of a build is a status note in the README: the build started, resumed, stopped and
  why, and finished, each review, each ruling, the owner's and the skill's, and each defect and
  follow-up a review logs.
- **Who runs which check.** `implementer` runs its test and the repo's `each story` checks that
  its change touches before it commits. `reviewer` runs the same checks and the `each story` user
  steps in each review, and in baseline mode the `each merge` checks and the `each story` and
  `each merge` user steps. The merge runs every `each merge` check and no user step, as
  **The merge.** says.
- `implementer` and `reviewer` run each check in the foreground, with the Bash tool's longest
  timeout, 10 minutes, and never with `run_in_background`. A check is a `validation run`, an
  `implementer` test or a `reviewer` step run with Bash. A server a step needs is no check.
- In a background agent, such as each one the skill launches, a call may move to the background
  after 3 minutes, whatever its timeout.
- Each check's command is followed by `echo "check ended: exit $?"` on a line of its own, a marker
  rarer than a bare `exit:` in a check's output. A check that outlasts its call moves to the
  background and still runs. A message that reaches the agent may move it there too.
- The agent waits for it in the foreground, in calls under 3 minutes, until its output file holds
  the `check ended:` line, or a notice says the check ended. A check the harness stops never
  writes that line. Until then it is no pass, and one stopped before that line failed.
- The wait reads the file with `grep -qs`, so a file not written yet is no error.
- No agent replies while a check it started still runs: once it replies, the notice may never
  reach it, and its work waits unreported.
- `implementer` writes a test that fails for the story's criterion first, then makes it pass.
- A change with nothing to test, such as a doc change, gets no test, and the reply says why.
- Its checks are its own test and the repo's `each story` checks that its change touches, through
  `validation run <project> <repo> --when each-story --changed <base> --path <worktree>`, with
  the story's base.
- It commits only when they all pass, and names each result in its reply.
- It runs its own test the narrowest way the repo allows, such as the one suite that holds it,
  even an `each merge` one.
- It runs no other `each merge` check, no `release` check and no user step.
- The skill runs a `release` check only when the owner asks, with the Bash tool's
  `run_in_background`, and waits for its notice.
- `reviewer` runs each step under `### Check as a user would` with the tool its line names: a
  skill through the Skill tool, anything else through Bash.
- A line that names no tool runs through Bash when Bash can do what it says. One that needs a
  browser and names no tool is BLOCKED: its defect names the step and asks for its tool.
- A step whose tool `reviewer` cannot run, such as a skill that is not installed, is BLOCKED, and
  its defect names the tool.
- Plugin agents cannot set `mcpServers`, so a browser comes from a skill or a command, never from
  an MCP server.
- The plugin ships no browser. A repo's `validation.md` names the one it uses.
- A browser step saves its screenshots in a temp folder outside the repo, and `reviewer` names
  the folder in its reply.
- `reviewer` keeps the `git status --porcelain` output of its first step. After the user steps it
  removes only an untracked (`??`) path that output did not list, and names it.
- A tracked file a user step changed is a finding, never deleted.
- `reviewer` never runs `git checkout`, `restore`, `reset`, `clean` or `stash`. Any other change
  to the tree is a finding.
- **Story mode.** In a story build, a prompt with `Mode: story.` gives each agent the story, its
  project, the repo, its git worktree, its branch, the base and the session id. The agents read
  the story and the code themselves.
- `implementer` reads the story's `## Description`, `## Acceptance criteria` and
  `## Approach / Key decisions`, builds it test-first in the worktree, runs its test and the
  `each story` checks with `--changed <base>` and `--path <worktree>`, and commits there.
- Before it commits, it checks its whole change against the story's criteria, and against
  `## Defects and follow-ups` and `## Code quality` in `agents/reviewer.md`. It fixes what it
  finds, so that the story passes its first review.
- `reviewer` reads the story the same way, and the change from the base, or on a re-review the
  fix's commits alone. It grades each acceptance criterion, or on a re-review each defect the
  fix answers. Then it runs the `each story` checks with `--changed <base>`, the ones the story's
  change touches, and the `each story` user steps, in the worktree, and grades the code.
- It grades code quality on a FAIL too, so that one fix round answers every defect. A re-review
  grades the code quality of the fix's commits alone.
- It logs each defect and each follow-up as a status note, `<n>` its round, in the shapes the
  `build` skill's list above gives.
- A fix message names the review that failed, `Fix: review <m> failed.`, and the `implementer`
  fixes each of its `Defect <m>:` notes. A fresh `implementer` gets that line in its prompt, and
  takes the fix the same way.
- A prompt with a `Worktree:` line, in baseline mode too, has `reviewer` run every `validation`
  and `validation run` with `--path <worktree>`.
- `reviewer` is given its mode's lines and the rulings, and nothing else. The skill never gives it
  a view of its own on the result, and never the implementer's report.
- `implementer` and `reviewer` set `omitClaudeMd: true`, so no `CLAUDE.md` adds to what they are
  given.
- `implementer` replies with a `Commit:` line, one line on what it built, a `Test:` line, and a
  `Check:` line with the result of each check it ran.
- A stop is a first line `BLOCKED: <why>`, then the `Check:` lines of the checks it ran.
- `reviewer` grades each acceptance criterion, or on a re-review each defect the fix answers, and
  each check and user step it runs, as met or not. Its evidence is a file and line it read, or a
  command it ran and what it printed.
- The implementer's words, in its report, a commit message or a comment, are a claim to check,
  never evidence.
- A check is met only when the change does all it says, wherever it applies. A check not met is a
  defect, and any defect fails the story: a PASS with an open defect is not allowed.
- **Defects and follow-ups.** `reviewer` sorts each finding as a defect, which fails the story, or
  a follow-up, which does not, as `## Defects and follow-ups` in `agents/reviewer.md` says.
- A follow-up is a name that misleads, code repeated where it could be shared, or code against
  the conventions the diff shows around it. Any other finding is a defect.
- Each of these is a defect, whatever its kind: an acceptance criterion not met or a defect not
  answered, a check or step that fails, what a user would hit, a doc the change makes wrong, and
  what the story's criteria or Approach, or a rule written in the repo, names.
- A finding `reviewer` cannot place for sure is a defect.
- `reviewer` logs each defect as a `Defect <n>:` status note. Only defects count in `issues` and
  go to the fix loop.
- It logs a follow-up as a `Follow-up:` status note. A follow-up changes no count, fails no story
  and goes to no fix round.
- When the build finishes or stops, the skill lists each follow-up of the build so far, oldest
  first: the `Follow-up:` status notes newer than its newest
  `Build: started on <branch> at <short hash>.` note. The owner can have one fixed then, as a
  ruling to fix the story.
- `agents/reviewer.md` holds two short worked examples: a FAIL with its findings, and a PASS with
  its evidence.
- Its reply ends with one fenced `json` block, its verdict:
  `{"verdict": "FAIL", "issues": 1, "checks": [{"check": "...", "met": false, "evidence": "..."}]}`.
- `verdict` is `PASS`, `FAIL` or `BLOCKED`, `issues` the number of defects, and `checks` one
  entry per check it graded.
- A story's review and the baseline each end with that block.
- With browser steps, the block adds `"screenshots": "<folder>"`.
- The skill reads each verdict from the block alone. A PASS needs one check or more, every `met`
  true and `issues` 0, and in story mode no `Defect <n>:` note of its round. A FAIL needs
  `issues` 1 or more, and in story mode one `Defect <n>:` note or more.
- No block, or one that breaks these rules, is no verdict: never a PASS.
- The skill asks the same reviewer once more only when the block is missing or does not parse.
  Any other block with no verdict goes to one fresh `reviewer` at once.
- In baseline mode `reviewer` logs nothing: it puts its findings in the reply.
- Only a PASS passes a story, never the implementer's word.
- A FAIL starts the fix loop. The story's `fails` picks each round, so the cap holds across
  sessions.
- A BLOCKED, or an implementer reply that starts `BLOCKED:` on what no ruling settles, stops the
  build at once.
- The two build agents and their tools. Neither has the Agent tool:

| Agent | Tools | Job |
|---|---|---|
| `implementer` | Bash, Read, Glob, Grep, Edit, Write | builds one approved story test-first in its git worktree, runs its checks and commits it on the story's branch; reads nothing outside the worktree but its story's sections and status notes and the reviewer's agent file |
| `reviewer` | Bash, Read, Glob, Grep, Skill | runs a baseline, or grades a story's change in its git worktree and runs each user step with its tool; edits no file; logs its defects and follow-ups as status notes |

- **Docs follow production.** A doc is updated only after the change is confirmed deployed to
  production.
- Confirmed means the user says so, or the change's story shows it: its last environment is
  `done`, or the story is `done` when the project has no environments.
- The code a doc is checked against is the production branch on the remote.
- Until a change is confirmed, its planned doc edits are recorded as pending and not made: under
  `## Docs to update` in the task README when there is a ticket, else as a line starting
  `pending production:` in the profile's debt file.
- **A ticket marked done starts `docs-keeper`.** When `story-tracker` sets a story `done` in a
  project with no environments, or sets its last environment `done`, it starts the `docs-keeper`
  agent with the ticket id and the README path.
- `docs-keeper` makes the edits under `## Docs to update` and ticks them. With no such section it
  checks the ticket's change against the "Code to doc map".
- A gap `docs-keeper` does not fix goes to the debt file, and it adds a status note to the ticket.
- **A renamed command goes to `docs-keeper`.** It rewrites every live reference in the vault,
  leaves the history the doctor's `old-namespace` check does not read, and adds a status note to
  each story it changed.
- The sprint close only reports done tasks with unticked doc lines, from `task docs`.
- Frontmatter is the source of truth. A status is never inferred from prose.
- A missing or non-standard status is reported as "Needs a status" and never set without asking.
- Notes are moved and renamed with `second-brain move` / `rename`, never `mv`.
- No skill or agent runs `ln`, `mklink` or the Obsidian CLI. The pointer is made with
  `second-brain pointer set` and the links with `second-brain link --apply`.
- Read cheapest first: the helper, then part of a note (`second-brain outline`, then a ranged
  read), then a scoped search, and a whole note last.
- The plugin's hooks are written in shell form, a `command` string with no `args`, so that Claude
  Code runs them through a shell on every system: Git Bash on Windows.
- `hooks/hooks.json` holds two hooks. SessionStart runs `second-brain session-check`, which prints
  the session block (see session-check).
- PreToolUse runs `hooks/search-rule.sh` on every Bash, Grep and Read call, with
  `"onFailure": "continue"`, so that a hook that cannot run never holds a call back. The key needs
  Claude Code 2.1.295 or later, which the README names.
- `search-rule.sh` warns and never blocks. It sets no `permissionDecision`, so the call goes on
  through the normal permission flow. It always exits 0.
- It warns when one of these reaches into the vault: a Grep call; a Read of a whole task note, a
  `tasks/<ID>/README.md`, `tasks/<status>/<ID>/README.md` or `tasks/archive/<YYYY>/<ID>/README.md`
  read with no `offset` and no `limit`; a Bash command that runs grep, egrep, fgrep, rg, cat or
  sed.
- A whole task note is also a `tasks/<folder>/<ID>/README.md` one group folder down, such as
  `tasks/backlog/<ID>/README.md` or one in a sprint's folder. The hook takes a status folder,
  `backlog` or a folder with no `README.md` of its own, looked up in the letter case of the path.
- A README in a folder inside a task, such as `tasks/<ID>/notes/README.md`, is no task note, and
  neither is one directly in `archive`, in any letter case.
- One level deeper in such a group folder, `tasks/<folder>/<parent>/<ID>/README.md` is a whole
  task note too when its `epic` names `<parent>`: its folder name, or an alias of
  `<parent>/README.md`, without letter case. The hook reads the note's frontmatter for it.
- With no `<parent>/README.md`, it is one when `<parent>` is named for a task found elsewhere in
  the tasks folder, as `## 4. A task` says, so the hook and the helper take the same notes.
- The warning is one JSON object whose `hookSpecificOutput.additionalContext` says what the call
  does, then the search and read rule. Otherwise it prints nothing.
- A call reaches into the vault when one of its paths, or the working directory, holds the last
  two parts of the vault's path, through the pointer or the physical one, as whole names: after a
  slash, a quote, a blank or the start, and at the end of a name.
- Letter case is ignored and a backslash counts as a slash, so `~/`, `$HOME/`, `C:\` and `/c/`
  forms all match. A Bash command also reaches into the vault when it holds `second-brain root`.
- Edit and Write are never matched. A ranged Read, or a Read of another note, passes in silence.
- It loads no library, starts one awk, and reads a long command in one pass. A Read one level
  deeper, in a folder with no `README.md` of its own, also runs one `find` over the tasks folder
  for its READMEs, then the awk again over what it lists.
- The shell runs that `find`, with the path in a variable as one argument. No path is ever text a
  shell reads, so a quote, a `$(...)`, a backquote or a `;` in a folder name runs nothing.
- With no vault, or with input it cannot read, it prints nothing.

## 10. Writing rules for every file in this repo

- Plain hyphens only. No long dashes, no emojis, no decorative symbols.
- No absolute paths, project names, ticket keys or people's names. `scripts/leak-check.sh`
  checks part of this.
- Examples use `EX-123`, `Example`, `example-api`, `docs/billing/invoices`.
- Do not name any file-sync product.
- Tests may use other made-up keys (`ZZ`, `TWO`) where they need two projects or a clash.
- Short sentences. One idea per bullet.
- Name a file by its path and code by its function. Do not describe them.
- One idea per bullet.
- Do not restate: say a rule once, in its home.
- A rule stated in several files has one home. The others point to it by path, and by heading
  when it is one section.
