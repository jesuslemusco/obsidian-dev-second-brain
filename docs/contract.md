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
| project | A folder inside the vault, listed in the index by its vault-relative path. |
| profile | `<vault>/<project path>/claude/profile.md`, the project's one settings note. |
| subproject | A part of a project with its own repos, branches and docs folder. It shares the project's ticket keys, tasks and board. |
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
index_version: 4
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
  claude/subprojects/<name>.md  one per subproject; none by default
  claude/validation.md          how to run and check each repo, with validation_home: vault
  tasks/README.md
  tasks/tasks.base
  tasks/<TICKET-ID>/README.md
  tasks/<TICKET-ID>/spec/       the story's spec, with spec_home: vault
  tasks/archive/<YYYY>/<TICKET-ID>/README.md   a done or abandoned task, with task_layout: archive
  <topics_root>/...            default docs/
  <topics_root>/<name>/README.md   the docs folder of a subproject
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
delivery: direct
spec_home: vault
validation_home: vault
achievements_skill: ""
tags:
  - type/profile
---
```

- `base_branch` is the branch a new story's branch is cut from, as
  `## Branch check (start, update, recall)` in `skills/story-tracker/SKILL.md` says.
- `production_branch` is the branch production runs. Empty means `base_branch`.
- `persona` is the role a story's description opens with (`*As a* <persona>,`).
- `topics_root: "."` puts the topic folders at the project root.
- `tasks_root`, `topics_root` and `sprints_root` are folders inside the project, written with
  forward slashes.
- Every command drops a slash in front of or behind a root: `/tasks` is `tasks`.
- A root that holds a `..` part or a backslash leaves the project. What the doctor does with one
  is under `### link, doctor, snapshot`.
- `task_layout` is `flat` or `archive`, in any letter case. A missing key or another value is
  `flat`.
- `flat`: every task stays in `<tasks_root>/<ID>/`.
- `archive`: a done or abandoned task moves to the archive through `task archive`, as its row
  under `## 7. The helper` says.
- Commands find a task at either depth in both layouts.
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
- `achievements_skill` names a skill to hand finished stories to, or is empty.
- `delivery` is how a story is built. `direct`: from its README. `spec`: from a spec of
  requirements, design and tasks that the owner approves first.
- A subproject's note and a task may set `delivery` too. The most specific value wins: the
  task's, then its subproject's, then the profile's.
- A value a story inherits from its subproject or the profile is what `spec <ID>` and the `spec`
  skill fall back to.
- When work starts on a story with no `delivery` of its own, `story-tracker` weighs it and writes
  the story's own, as `## Spec-driven stories` in `skills/story-tracker/SKILL.md` says.
- `spec_home` is where a story's spec lives. `vault`: `spec/` next to the task's `README.md`.
  `repo`: `spec/<ID>/` in the story's repo. A subproject's note may set it.
- The story's repo is the first repo of its subproject, else the project's first repo, in the
  order `repo <project>` lists them.
- `validation_home` is where `validation.md` lives. `vault`: `claude/validation.md` in the
  project. `repo`: `validation.md` at the root of each repo. A subproject's note may set it for its
  repos.
- `delivery`, `spec_home` and `validation_home` take any letter case.
- A missing or empty value passes to the next level. At the profile it means the default:
  `direct`, `vault` and `vault`.
- The first value found decides. One that is not allowed means the default.

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
delivery: ""
spec_home: ""
validation_home: ""
tags:
  - type/subproject
---
```

- `repos` lists the subproject's repositories. The first is the default for branch checks.
- A repository belongs to one subproject. It need not be in the profile's `repos`.
- The project's repositories are the profile's, then each subproject's that the profile does not
  list.
- `base_branch`, `production_branch`, `branch_pattern`, `environments`, `repo_paths`, `delivery`,
  `spec_home` and `validation_home` mean what they mean in the profile. One that is absent or
  empty (`""`, `[]`) takes the profile's value.
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
  `` - `npm test` - the unit tests - when: each task ``.
- Each bullet under `### Checks` and `### Check as a user would` ends with when it runs:
  `when: each task`, `when: each build` or `when: release`.
- `each task` runs in each task's review. `each build` runs once every task of a build has passed.
  `release` runs only before a release or when the owner asks, such as an end-to-end suite.
- A bullet with no `when:` is `each build`.
- The `when:` is the last one in the bullet outside code spans. Its value is read without letter
  case, with a hyphen as a blank and a final period dropped.
- Any other value is unknown and counts as `each build`, so a typo never drops a check.
  `validation run` names it as a warning in every run.
- A bullet is its first line and the indented lines under it, up to a blank line, a nested item
  or the next bullet. A nested item is part of no check.
- A section is written when something is under its heading. One with nothing is `empty`.

## 4. A task

Path: `<project>/<tasks_root>/<ID>/README.md`. `<ID>` is the ticket id, or a kebab-case slug when
there is no ticket yet.

- An archived task is `<project>/<tasks_root>/archive/<YYYY>/<ID>/README.md` (see `task_layout`
  in the profile).
- The folder `archive` directly under the tasks root holds the archive in every layout. It is
  never a task. `archive`, in any letter case, is no task id and no alias.

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
delivery: spec                # optional; omit it to take the subproject's or the profile's
sprint: "2026-10-14"          # omit the key when the task is in the backlog
carried_from: []              # sprint ids this task was carried over from
depends_on:                   # optional; the tasks this one waits on, as quoted path links
  - "[[<project>/<tasks_root>/<other ID>/README|<other ID>]]"
type: task
tags:
  - <topic/tag>               # zero or more; the folder path under the topics root, lowercased
  - type/task
  - status/active             # status/done for done and abandoned, status/active otherwise
---
```

- The helper never writes `jira_id`. Notes that have it keep it; readers ignore it.
- An archived task carries `archived: "YYYY-MM-DD"`, quoted: the day `task archive` moved it.
- The tasks that wait on a task are never stored: Obsidian shows them as backlinks.
- `delivery` is `direct` or `spec`. `task set <ID> delivery=<value>` writes it in lower case. Any
  other value exits 5.
- A spec is three files: `requirements.md`, `design.md` and `tasks.md`.
- With `spec_home: vault` each spec file has frontmatter: the alias `"<ID> Requirements"`,
  `"<ID> Design"` or `"<ID> Tasks"`, `type: spec` and the tag `type/spec`. It opens with `> Up:`
  and a link to the task's README.
- With `repo` the spec files have no frontmatter and no up link.
- A task folder with a `spec/` folder is still one task.
- In `requirements.md` each requirement is a `## R<n> - <name>` section: a `- Serves:` line
  directly under the heading, then the requirement, then its acceptance checks as `- [ ]` lines.
- The `- Serves:` line names the story's criteria the requirement meets, comma separated:
  `- Serves: AC1, AC3`. `AC<n>` is the n-th criterion, counted from 1, in any letter case.
- Every `- Serves:` line of a requirement counts, `Serves` in any letter case.
- A criterion is a line under `## Acceptance criteria` in the task's README, up to the next `## `
  or `# ` heading, that starts with `- [ ]`, `- [x]` or `- [X]`, then a blank or the line's end.
  Lines in `###` subsections count, in the order they come.
- Fenced code in the README or in `requirements.md` is not read.
- In `tasks.md` each task is one item, `- [ ] T<n> - <what it builds>`, with four indented lines:
  `- Requirements: R1, R2`, `- Design: <design.md headings>`, `- Files: <paths>` and
  `- Check: <command or step> - expected: <what it prints or shows>`.
- A task item may add `- Provides: <signatures>` lines: what later tasks call. A task that calls
  them names those tasks on one line, `- Uses: T1, T2`.
- A task item may add `- Bundle: <n>`, a whole number. The tasks with the same number are one
  bundle, and stand next to each other in `tasks.md`.
- A task of a bundle uses no other task of its bundle on its `- Uses:` line.
- `none`, `n/a`, `-`, an empty value or one that starts with `<` names no bundle.
- A spec story's build progress is `build.json` in its task folder in the vault, whatever its
  `spec_home`, so a build never dirties the repo's tree. The README holds none of it.
- `spec status` and `spec issue` write `build.json`. It is never edited by hand.
- `build.json` is one object: `story`, the task's id, and `tasks`, an array of one object per task,
  in the order of `tasks.md`. A task whose item left `tasks.md` stays at the end.
- A task object holds `id`, `title`, `build`, `review`, `commits`, `issues` and `history`.
- `build` is `todo`, `building`, `built` or `blocked`. `review` is `-`, `in-review`, `passed`,
  `failed` or `blocked`.
- A task first written starts `todo` and `-`, or `built` and `passed` when it is ticked.
- `commits` is an array of hashes. Each issue is an object: `at`, `session`, `issue`, `fix` and
  `round`.
- `round` is the number of `in-review` states in the task's history when the issue was logged.
  An issue with none, such as a moved one, reads as `0`.
- `history` holds one object per state set, oldest first: `at`, `session`, `field` (`build` or
  `review`) and `state`, and `commit` when `--commit` named one.
- A task's `fails` is the number of `failed` review states in its history, from every session.
- After a failed review, the findings a fix answers are the issues whose `round` is the number of
  `in-review` states before the task's last `failed` one.
- The fix's commits are the `commit` of each history entry after that `failed` one.
- `at` is the local time, as `YYYY-MM-DDTHH:MM:SS+HH:MM`. `session` is `-` when none was given.
- A README's `## Build` section, which versions before 0.7.0 wrote, is read as its task rows. The
  next `spec status` or `spec issue` write moves it into `build.json` and removes it from the
  README.
- Its rows move as: `todo` to `todo` and `-`; `built` to `built` and `-`; `in-review`, `passed` and
  `failed` to `built` and that review state; `blocked` to `built` and `blocked` when the row has a
  commit, else to `blocked` and `-`.
- A moved row has no `history`. A moved issue's `at` is the date it was written with.
- A task that `build.json` holds too is taken from `build.json`.
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
  filter takes `<tasks_root>/<ID>/` and `<tasks_root>/archive/<YYYY>/<ID>/`.
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
- Wherever a command takes `<path>`, it is a vault path. A path that leaves the vault, enters a
  dot folder, holds a backslash or is absolute exits 5.
- An absolute path is printed with forward slashes; on Windows in the drive form, `C:/...`.
- An absolute path that is read (an argument, an environment override, `repos_root`, a
  `repo_paths` entry) may be in that form, written with backslashes, or in Git Bash's own form,
  `/c/...`.
- Environment overrides: `SECOND_BRAIN_VAULT` (vault root), `SECOND_BRAIN_CLAUDE_HOME` (link
  directory), `SECOND_BRAIN_TODAY` (today's date, for tests), `SECOND_BRAIN_NOW` (the time
  `build.json` records, for tests).
- With `SECOND_BRAIN_TODAY` set and `SECOND_BRAIN_NOW` unset, the time is that day at
  `00:00:00+00:00`.
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
| `subproject <project> <name>` / `--cwd DIR` | the effective settings as `key: value` lines: `subproject`, `note`, `docs`, `repos`, `base_branch`, `production_branch`, `branch_pattern`, `environments`, `delivery`, `spec_home`, `validation_home`, `repo_paths` | the name is matched exact first, then without letter case. `base_branch` to `environments` are as `### Subprojects` says; lists are joined with `, `. `delivery`, `spec_home` and `validation_home` include the defaults (section 3). `repo_paths` is `<repo>=<path>` for each of its repos with a location, found as `repo` finds it, or `-`. `--cwd` takes the subproject whose repository holds the directory. Exit 1 none, exit 4 several (prints their names) |
| `profile <project> --keys` | the profile frontmatter as `key: value` lines | exit 1 when the profile is missing, with a hint to run vault-setup adopt |
| `profile <project> <section>` | the body of that level-2 section | the name is matched without letter case; exit 1 when absent |
| `board <project> [view] [--subproject S]` | one row per task: `id | title | status | sprint | topics | branch | next | envs | depends_on`. The `By subproject` view adds a tenth cell, `subproject` (`-` for none). `Current sprint` has no rows when no sprint is in progress or the project does not use sprints | default view `Active`: status planned, in-progress or in-review. `By subproject` lists the active tasks by subproject, those with none last. `--subproject` keeps the tasks whose `subproject` is that subproject, in any letter case; the name is matched as by `subproject <project> <name>`, exit 1 when none matches. Rows come from the frontmatter of the task READMEs, by the view's own rule; the board file is not read. `envs` is `-` or `dev:EX-1:done,qa:EX-2:planned`, each name as the note spells it. `depends_on` is `-` or `EX-1:done,EX-2:planned`: the folder of each linked task README and that task's status. The folder is spelled as on disk for a task of the project, whatever the link's letter case. The status is `-` when it has none, or `missing` when the link leads to no note in the vault. `title` falls back to the note's first heading when the property is absent |
| `find <ID-or-alias> [--project P]` | vault path(s) | tries the task path, live or archived, then the aliases in frontmatter: task READMEs first, then every note of the project; exit 1 none |
| `task head <ID> [--project P] [--json]` | at most 15 lines: id, path, title, status, next, sprint, branch, epic, subproject (only when set), topics, envs, summary line, newest status note | `--json` prints one object whose keys are the lines' keys, `subproject` only when set. `topics` and `envs` are arrays, each env as `<env>:<id>:<status>` |
| `task docs <ID>[,<ID>...] [--project P]` | for each task with unticked `- [ ]` lines under `## Docs to update`: a line `<id> <vault path>`, then those lines as written; nothing for a task with none | ids may be comma-separated or given as several arguments; exit 1 when an id names no task |
| `task set <ID> key=value... [--project P]` | the changed keys, or `no change` | scalar keys only. Setting `status` also sets the `status/` tag, and setting `type` the `type/` tag. `key=` removes the key. Exit 5 for a status outside the five, for `jira_id`, for a list key (`depends_on` goes through `task dep`), and for a sprint id on a project that does not use sprints (`sprint=` still removes one). `subproject` must name a subproject of the task's project, matched as by `subproject <project> <name>`, and is written as its note is named; exit 1 when none matches |
| `task tag <ID> add\|remove <tag> [--project P]` | the resulting topic tags | edits the `tags:` list; exit 5 for a `type/` or `status/` tag |
| `task alias <ID> add <alias> [--project P]` | the resulting aliases | appends to `aliases:`, quoted when needed; the first alias never changes. Exit 6 when the alias already names another task, exit 5 for the alias `archive` in any letter case. Renaming a slug-named task to its ticket id is done by hand |
| `task dep <ID> add\|remove <ID> [--project P]` | the resulting `depends_on` links, or `-` when none is left | the second id is the task the first waits on, found by id or alias like the first; `--project` applies to both. `add` appends `"[[<vault path of its README, no .md>\|<its folder id>]]"` and puts the key after `carried_from`; a task already linked is not added twice. `remove` drops the item whose link leads to that README, whatever its display text, and leaves `depends_on: []` when none is left. Exit 1 for an unknown task, exit 5 for the task itself. No cycle check: the doctor's `depends-on` check reports one |
| `task new <ID> [--project P] [--title T] [--topics a,b] [--envs] [--subproject S]` | the new README's vault path | `--project` may be left out when the id's key names one project. Exit 6 when the task already has a README, live or archived, or the id is another task's alias; a folder with no README gets one. Exit 5 for the id `archive` in any letter case, and for `--envs` when the profile lists no environments. A topic with no folder is still written, with a `note:` on stderr. `--subproject` writes the `subproject` key as `task set` does, exit 1 when it names none. With `--envs` the subproject's own environments come first |
| `task note <ID> "<text>" [--project P] [--session S]` | the line it added | prepends a dated line under `## Status notes` |
| `task archive <ID> [--project P]` | the README's new vault path, then the move's `links: <path> \| <count>` lines | moves a done or abandoned task's folder with `move` to `<tasks_root>/archive/<YYYY>/<ID>/`, the year being today's, then writes `archived: "<today>"`. Exit 5 when the project's `task_layout` is not `archive`, or when the task's status is not `done` or `abandoned`. Exit 6, moving nothing, when it is archived already or when anything is at the destination, an empty folder or a link too. Exit 1 for an unknown task. A move that fails exits as `move` does |
| `spec <ID> [--project P]` | `key: value` lines: `id`, `delivery`, `spec_home`, `repo`, `dir`, `requirements`, `design`, `tasks` | `delivery` and `spec_home` are the values that hold for the task (section 3). `dir` is the spec folder: a vault path with `vault`, the absolute path of `spec/<ID>` in the story's repo with `repo`. The last three are the files in it, whether they exist or not. `repo` is the story's repo, or `-` when the project lists none. Exit 1 for an unknown task. With `repo`, also exit 1 when the project lists no repo, or the repo has no recorded location or no folder; the message says which. The lines are then still printed, with `dir` and the three files as `-`, so `delivery` can be read |
| `spec new <ID> [--project P]` | the files it created, as `spec` names them | writes the three spec files from their templates, with the task's title. Never overwrites (`exists: <path>` on stderr). Exits as `spec` does |
| `spec tasks <ID> [--project P] [--json]` | one TSV row per task item of `tasks.md`, in order: id, `todo` or `done`, title (`-` when none), bundle (`-` when none). An item is `- [ ] T<n> - <title>`, or `T<n>:`; fenced code is not read | the bundle is the item's `- Bundle:` line, read as section 4 says, with `Bundle` in any letter case, and printed as a number. Exit 1 with no row when a bundle is not a whole number, when a bundle's tasks are not next to each other, or when a task's `- Uses:` line names a task of its own bundle; the message names the task. Exit 1 when `tasks.md` is missing; otherwise exits as `spec` does. `--json` prints the rows with the keys `id`, `state`, `title` and `bundle` |
| `spec tick <ID> <task> [--project P]` | `ticked: <task>` | ticks the item, `- [ ]` to `- [x]`, in the file's line endings. The task id is matched without letter case; fenced code is not read. Exit 1 when no item or two items have it, or `tasks.md` is missing or cannot be written; exit 6 when it is ticked already |
| `spec packet <ID> <task> [--project P]` | the context packet of one task: `story`, `task`, `title`, `repo`, `repo_path`, `branch`, `validation`, `commits`, `fails` and `diff` lines, then `## Task` (the item as written), `## Requirements` (each requirement it names, as `### <heading>` and its body), `## Design` (each design heading it names, likewise; left out when it names none), `## Uses` (for each task its `- Uses:` line names, `### <task> - <title>` and that item's `- Provides:` lines, as written; left out when it names none), `## Issues` (the task's issues in `build.json`, as `spec status` prints them; left out when there is none), `## Checks` (the checks `implementer` runs before it commits: `- task: <the item's Check, as written>`, then `- each task: <command>` for each command `validation run <project> <repo> --when each-task` runs, in order) and `## Validation` (the repo's section) | `validation` is the repo's `validation.md` path, or `none (<state>)` with no `## Validation` part and no `each task` line. A task with no `Check`, or one that is `none`, `n/a` or `-` or starts with `<` as the template's does, has `- task: none`. A check with no command is not in `## Checks`. `commits` is the task's commits in `build.json`, comma separated, or `-`. `fails` is the task's `fails` (section 4). With `fails: 0`, `diff` is a temp file outside the repo and the vault that the command writes with `git show` of each of those commits, in order, and `## Issues` holds every issue. With more, the packet is a fix's: `diff` holds only the fix's commits, and `## Issues` only the findings the fix answers (section 4). `diff` is `none (no commit)` with no commit, `none (no fix commit)` for a fix with none yet, and `none (git show failed)` when git shows none of them; a commit git cannot show is named on stderr as `note: git show <hash> failed in <repo>`. Each field of a task is one line, and a design heading holds no comma. `none`, `n/a` or `-` in `Design` or `Uses` names nothing. Exit 1 when a spec file is missing, no item or two items have the task, the task names no requirement, a field ends in a comma, a requirement id or design heading it names has no section or two (the message names it), a task it uses is not in `tasks.md`, is not an earlier task or has no `- Provides:` line, `build.json` is not a JSON object with a `tasks` array, or the project has no repo to build in |
| `spec link <ID> [--project P]` | `linked: <heading>` for each section it changed, or `no change` | for a story whose `delivery` that holds is `spec`: writes `See [[<dir>/design\|<ID> Design]].` as the first line of `## Approach / Key decisions`, and `See [[<dir>/tasks\|<ID> Tasks]].` as the first line of `## Changes` and `## Verification`. With `spec_home: repo` the line names `` `spec/<ID>/design.md` `` or `` `tasks.md` `` and the repo instead. A section that holds only `None yet.` or the task template's text gets the link alone; any other keeps its text under the link; one that has its link is left alone. Line endings and the final newline are kept; frontmatter and fenced code are not read. A missing heading is named on stderr as `note: no ## <heading> in <path>`. A `direct` story prints `no change: <ID> is not built from a spec (delivery: direct)` and writes nothing. Exit 1 when `design.md` or `tasks.md` is missing, or as `spec` does about the repo |
| `spec status <ID> [--project P] [--json]` | one line per task, `T<n> - build: <build> - review: <review> - fails <n> - commits <hashes or -> - fix <hashes or -> - <title>`, each of its issues under it as `  - Issue <date>: <issue> Fix: <fix>`; nothing when the story has no `build.json` and no `## Build` section | the tasks of `build.json`, read as section 4 says, with each task of `tasks.md` it lacks as a task first written. The hashes are comma separated. `<date>` is the issue's `at` up to the day. Writes nothing. `fails` is the task's `fails` (section 4). `fix` is the fix's commits (section 4), each once, `-` with none: a fix built since the last failed review. `--json` prints the rows with the keys `id`, `build`, `review`, `fails`, `commits`, `fix`, `title` and `issues`; `fails` is a count, and `commits` and `fix` are lists. `issues` holds the issue lines, each as written from `Issue` on. A line break in an issue, its fix or a title prints as a blank. Exit 1 when `build.json` is not a JSON object with a `tasks` array, blank text included |
| `spec status <ID> <task> <state> [--commit <hash>] [--session S] [--project P]` | `<task>: <state>` | sets the field of `build.json` that `state` belongs to, and adds the state to the task's `history`, with its commit when `--commit` names one. `todo`, `building` and `built` are build states; `in-review`, `passed` and `failed` are review states. `blocked` sets the review when it is `in-review`, else the build. `--commit` adds a hash to the task's commits once. Adds no status note. A README `## Build` section moves into `build.json`, as section 4 says, with `note: moved ## Build of <README path> into <build.json path>` on stderr. Exit 5 for another state or a `--commit` that is not hex. The new `build.json` is written next to the old one, then moved in its place. Exit 1 when `tasks.md` is missing, neither it nor `build.json` has the task, or `build.json` is not a JSON object with a `tasks` array |
| `spec issue <ID> <task> "<issue>" --fix "<fix>" [--session S] [--project P]` | `<task>: issue` | adds the issue to the task in `build.json`, with its time, session and `round` (section 4). Adds no status note, and moves a README `## Build` section as `spec status` does. Exit 5 without both texts; exit 1 as `spec status` does |
| `validation <project> [--json]` | one TSV row per repo, in the order `repo` lists them: name, home (`vault` or `repo`), path, state (`ok`, `missing`, `no-section`, `empty`, or `unknown` when a `repo` home has no recorded location) | path is a vault path for `vault`, absolute for `repo`, `-` when unknown. `missing`: the file is not there. `no-section`: it has no `## <repo>` section. `empty`: nothing is under its heading. A project with no repo prints nothing. Exit 1 when the profile is missing. `--json` prints the rows with the keys `name`, `home`, `path` and `state` |
| `validation <project> <repo> [--json]` | `path: <path>`, then the body of the repo's `## <repo>` section, as `profile <project> <section>` prints a section | the repo is matched exact first, then without letter case. Exit 1 when it is not a repo of the project, has no recorded location with a `repo` home, or when the file or its section is missing. `--json` prints one object: `path`, and `body`, the body as one string. `body` is `""` when the section is empty |
| `validation run <project> <repo> [--when each-task\|each-build\|release] [--timeout <seconds>] [--json]` | one TSV row per check it runs or skips, in order: command, result (`pass`, `fail` or `skipped`), exit code, seconds, log. Under a `fail` or `skipped` row, its lines, each indented by two blanks | runs the command of each bullet under `### Checks` in the repo's section whose `when:` the run takes (section 3): `each-task` takes `each task`, `each-build` takes `each task` and `each build`, and `release` takes all three. `--when` is `each-build` by default. The repo and its section are found as `validation <project> <repo>` finds them. Each command runs through bash, one at a time, from the repo's root, with stdin from `/dev/null` and its output and errors in its log, a temp file outside the repo and the vault. It is stopped after `--timeout` seconds, 1800 by default: it and the processes it started get TERM, then KILL 5 seconds later, and its exit code is 124. On Windows, `taskkill` also stops the Windows processes under it. What a command leaves running when it exits gets TERM, then KILL 5 seconds later, before the next command starts. On Windows this reaches only the shell's own processes. `seconds` is whole seconds. A `fail` row's lines are `stopped after <n> seconds` for a timeout, then the first 10 lines of its output that hold `fail` or `error` in any letter case, or its last 10 lines when none does, blank lines left out and each cut at 200 bytes. A bullet with no code span is `skipped`, with the line `no command`. A bullet with an unknown `when:` runs as `each build`, and every run names it on stderr as `note: unknown when: <value>, read as each build: <the bullet's text>`. A skipped row's command is the bullet's text, on one line, and its exit code, seconds and log are `-`. A section with no `### Checks` prints no row, with `note: no ### Checks in <path>` on stderr. Exit 0 when no row fails, 1 when one does. Exit 1 with no row as `validation <project> <repo>` does, and when the repo's folder is missing. Exit 5 for another `--when`, or a `--timeout` that is not a whole number above 0. `--json` prints the rows with the keys `command`, `result`, `exit`, `seconds`, `log` and `lines`; `exit` and `seconds` are numbers, `null` on a skipped row, and `lines` is a list |
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
| `sprint open <project> [--end YYYY-MM-DD] [--goal G]` | the new sprint note's path, then one line per task it re-pointed | exit 6 while another sprint is in progress. With no `--end` it takes the first cadence end on or after today that has no note. It writes `sprint_anchor_end` only when the profile has none. It rewrites the board's sprint literal. It moves every open task (status not done or abandoned) whose `sprint` id has no sprint note onto the sprint being opened, printing `re-pointed: <ID> from <old> to <new>` |
| `sprint set <project> key=value...` | the changed keys | sets `goal` or `committed` on the sprint in progress; exit 1 when there is none, exit 5 for any other key |
| `sprint close <project> [--carry ID,ID] [--backlog ID,ID] [--abandon ID,ID]` | a summary: `sprint:`, `done:`, `carried:`, `backlog:`, `abandoned:`, `next:` | every open task of the sprint must be named in exactly one list, else exit 5 listing the problem. On tasks it writes `carried_from`, `sprint`, `status` and the tag. On the sprint note it writes the `## Close` lists, `completed`, `carried_over`, `status: done` and the tag. It writes no status notes; the caller adds the reason with `task note`. `next:` is the id carried tasks now point at |
| `scaffold vault [DIR]` | the files it created | never overwrites; creates the index, the conventions note, `claude/README.md` and `claude/pull-request.md`. A file that exists is named on stderr as `exists: <path>` |
| `scaffold project <name> --path P [--keys K1,K2] [--use-when TEXT] [--tasks-root R] [--topics-root R] [--sprints-root R] [--no-sprints]` | the files it created | never overwrites (`exists: <path>` on stderr); adds the index row; exit 6 when a key in `--keys` already belongs to another project. The three root flags are written into a new profile, and the hubs and board are created under them. `--topics-root .` creates no topics hub. When the profile exists its roots win and the flags are ignored. Exit 5 for a root that leaves the project, repeats another root, or sits inside the tasks root. `--no-sprints` writes `uses_sprints: false` into a new profile, creates no sprints hub and no map line for it, and writes the board without its sprint parts; exit 5 together with `--sprints-root`. An existing profile's `uses_sprints` wins over the flag |
| `scaffold subproject <project> <name> [--repos R1,R2]` | the files it created: the subproject note and the `README.md` of its docs folder | never overwrites (`exists: <path>` on stderr). Adds a link to the new docs hub under `## Topics` in the topics hub, once. A repo named twice in `--repos`, in any letter case, is written once. Exit 5 for a name that is not a folder name, or a repo name that holds a character outside letters, digits, `.`, `_` and `-`. Exit 6 when another subproject has that name in another letter case, or already lists one of the repos. Exit 1 for an unknown project or a missing profile. Writes no Code to doc map row: the user names the docs |
| `pointer` | the absolute path of the folder the pointer leads to | exit 2 when there is no pointer, or when a real file or folder sits in its place. A pointer whose folder is gone still prints where it leads, with a `note:` on stderr |
| `pointer set <DIR> [--replace]` | the folder the pointer now leads to | creates the pointer in the link directory: a symlink on macOS and Linux, a junction on Windows. Exit 5 when `DIR` has no `.obsidian` folder. A pointer that already leads to `DIR` is left alone. One that leads elsewhere, or to a folder that is gone, is kept, and the command exits 6 naming where it leads, unless `--replace` is given. A real file or folder in the pointer's place is never replaced: exit 6 |
| `link [--check \| --apply]` | one row per skill or agent: `name \| kind \| state \| target` | scans `<vault>/claude/` and each index project's `claude/`, but not that of a row whose path holds a `..` part or a backslash; never touches links it did not make. Exit 1 when a row is neither `linked` nor `foreign`. `--apply` reports what it did as `note:` lines on stderr |
| `doctor [project] [--json] [--fix]` | one row per check: `result \| check \| scope \| count \| offenders \| fix` | exit 0 when no check fails, 1 when one does, 2 when there is no vault. `--fix` replaces a `pull-request` note that is older than the template and was never edited, `fixed: claude/pull-request.md -> version <n> (vault)`. It makes each `status/` tag follow its status, `fixed: <ID> -> <tag> (<project>)`. Then it archives each task that `task-layout` names `to-archive` through `task archive`, `fixed: <ID> -> <new README path> (<project>)`, and prints the table. It never moves an open task, and archives nothing in a project whose tasks root leaves it. A task that `task archive` refuses stays where it is, with the reason on stderr |
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
- A doctor row is `result | check | scope | count | offenders | fix`. `result` is `ok`, `warn` or
  `fail`. `scope` is `vault` or a project name. `offenders` holds at most five, comma separated,
  or `-`.
- A long offender is cut and ends with `...`: at 48 bytes, or at 120 for the paths of `hubs`,
  `task-location` and `old-namespace`. A short tag after its last colon, such as `:no-folder`, is
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
| vault | `import` | no import line for the index in the link directory's `CLAUDE.md` (warn) |
| vault | `global-rules` | a line of the link directory's `CLAUDE.md` names an index project: its name as a whole word, as written, or its path in any letter case (`<project>:<line number>`, or `<project>:@<line number>` for an `@` import line, whose fix is to remove it) (warn). A whole word has no letter, digit, `_` or `-` on either side. The import line of the index and the table rows under a `## Projects` heading are not read, nor the files the `CLAUDE.md` imports |
| vault | `links` | a vault-owned skill or agent is missing, wrong-target, dangling, name-mismatch or duplicate (fail) |
| vault | `double-registration` | a link in the link directory points inside the plugin (warn) |
| vault | `always-loaded-size` | the index is over 60 lines or the link directory's `CLAUDE.md` over 40 (warn) |
| vault | `descriptions` | a scanned skill or agent has no description (`<name>:none`), or one over 200 characters (`<name>:<length>`) (warn) |
| vault | `skill-size` | a scanned `SKILL.md` is over 150 lines (warn) |
| vault | `old-namespace` | a line names a skill or agent of the plugin by its old name, `obsidian-dev-second-brain:<name>`: in a note of the vault outside its history (`<vault path>:<line>`), or in the link directory's `CLAUDE.md` (`~/.claude/CLAUDE.md:<line>`); or a string of a settings file holds `obsidian-dev-second-brain:`: in the link directory (`~/.claude/<file>:<string>`), the vault root (`.claude/<file>:<string>`) or a repo (`<repo>/.claude/<file>:<string>`) (warn). See the bullets under this table |
| project | `profile` | the profile is missing, lacks a contract key, lacks one of the seven sections, or has a root that leaves the project (`<key>:leaves-project`) (fail) |
| project | `board` | the board file is missing (fail). While a sprint is in progress: its `Current sprint` view filters on another sprint id (`tasks.base:<that id>`), its filter is not written as `sprint == "<id>"` (`tasks.base:filter`), or it has no such view (`tasks.base:no-view`) (warn); with no sprint in progress, or for a project that does not use sprints, the view is not looked at. For a project with a subproject note, a board with no `By subproject` view (`tasks.base:no-subproject-view`) (warn). For a project with `task_layout: archive`, a board whose own filters do not take `<tasks_root>/archive` (`tasks.base:no-archive-filter`) (warn) |
| project | `hubs` | a hub is missing or empty (warn): `README.md`, `claude/README.md`, `<tasks_root>/README.md`, `<topics_root>/README.md` unless the topics root is `.`, and `<sprints_root>/README.md` when the project uses sprints. Offenders are paths under the project, and a hub that two roots share is named once |
| project | `placeholders` | a line of `README.md`, `claude/README.md`, `claude/profile.md` or a note in `claude/subprojects/` holds a placeholder of the template it was written from (warn, `<path under the project>:<line>`). A placeholder is text in angle brackets, with no blank after `<`, outside inline code unless it opens the code; only the template's own count, as written there. Frontmatter, fenced code and task READMEs are not read |
| project | `task-frontmatter` | first alias differs from the folder name, or `type` or its tag is missing (fail) |
| project | `needs-a-status` | status missing or not one of the five (warn; never changed) |
| project | `status-tag` | the `status/` tag disagrees with `status` (warn; `--fix` repairs it) |
| project | `yaml-traps` | an unquoted alias holding a colon and a space, an unquoted lone dash value, an unquoted sprint id (fail) |
| project | `alias-unique` | one alias on two notes among task READMEs and hubs (fail) |
| project | `no-readme` | a task folder without a README (warn): a folder directly under the tasks root other than `archive`, or one directly under `<tasks_root>/archive/<YYYY>/` |
| project | `task-location` | a note under the project has `type: task` in its frontmatter and is not `<tasks_root>/<ID>/README.md` or `<tasks_root>/archive/<YYYY>/<ID>/README.md` (warn). Offenders are paths under the project. Dot folders are not read, and neither is the folder of another index project that sits inside this one |
| project | `task-layout` | the tasks do not follow `task_layout` (warn). `flat`: an `archive` folder under the tasks root (`archive:flat`). `archive`: an open task (planned, in progress or in review) in the archive (`<ID>:open`), a done or abandoned task outside it that is due by `archive_after_days` (`<ID>:to-archive`; `--fix` archives it), or an `archive_after_days` that is not a whole number (`archive_after_days:not-a-number`) |
| project | `topic-tags` | a topic tag on a task maps to no folder under the topics root (warn). The profile's `## Topics` section may hold exceptions as lines `- <tag> -> <folder>` |
| project | `code-doc-map` | a repository in `repos` has no row in the profile's Code to doc map (warn) |
| project | `repos` | a repo of the project, a subproject's included, has a recorded location whose folder is missing (warn). Nothing recorded is ok |
| project | `subprojects` | only for a project with a subproject note. A note whose `type` is not `subproject` (`<name>:type`), one with no repos (`<name>:no-repos`), no docs folder (`<name>:no-docs`), a repo with no row in the profile's Code to doc map (`<name>/<repo>:no-map-row`), a repo whose folder is missing (`<name>/<repo>:missing`) or that has no recorded location (`<name>/<repo>:no-location`), or a repo listed by two subprojects, compared without letter case (`<repo>:twice`) (warn) |
| project | `task-subproject` | only for a project with a subproject note. A task whose `subproject` names no note in `claude/subprojects/`, compared without letter case (`<ID>:<value>`) (warn) |
| project | `delivery` | a `delivery`, `spec_home` or `validation_home` value that is not allowed, compared without letter case: in the profile (`profile:<key>`), a subproject note (`<name>:<key>`) or a task's `delivery` (`<ID>:delivery`) (warn) |
| project | `validation` | a repo of the project has no `validation.md` (`<repo>:missing`), no `## <repo>` section in it (`<repo>:no-section`), a section with nothing under its heading (`<repo>:empty`), or a section that still holds a placeholder of `validation-repo.md.tmpl`, or a retired one of an earlier version, listed in `sb_val_placeholders` (`<repo>:placeholders`) (warn). A `repo` home with no recorded location (`<repo>:no-location`). One whose folder is missing is left to the `repos` check. A project with no repo and a `vault` home: a missing `claude/validation.md` (`claude/validation.md:missing`) |
| project | `spec-trace` | an open story whose `delivery` that holds is `spec` has a criterion that no `- Serves:` line of its `requirements.md` names (`<ID>:AC<n>`), or a requirement with no `- Serves:` line, one that names no criterion, or one with an item that is not an `AC<n>` the story has (`<ID>:R<n>`) (warn). A requirement is a `## ` heading whose first word is `R` and a number. Criteria and `- Serves:` lines are read as `## 4. A task` says; the README's frontmatter, a CR at a line's end and a BOM are not read. A requirement id is named as written, once. The story's spec folder is found as `spec <ID>` finds it. Not read: a done or abandoned story, one with no `requirements.md`, and one whose spec is in a repo with no recorded location or no folder |
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
  `cmd_rename`. Its private helpers are `sb_graph_*`.
- `scripts/lib/platform.sh` holds what differs between systems. Its private helpers are
  `sb_plat_*`.
- `scripts/lib/subproject.sh` holds `cmd_subproject` and the subproject helpers, `sb_sub_*` and
  `sb_need_sub`. `sb_scaffold_subproject` is in `scaffold.sh`.
- `scripts/lib/spec.sh` holds `cmd_spec`, `cmd_validation` and their helpers, `sb_spec_*` and
  `sb_val_*`. The doctor and `scaffold project` call `sb_spec_value`, `sb_val_rows` and
  `sb_val_placeholders`, and the doctor `sb_spec_resolve` and `sb_spec_trace` too.
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
  `sb_section`, `sb_task_files`, `sb_task_readme`, `sb_task_scan`, `sb_sprint_current_id`,
  `sb_uses_sprints`, `sb_need_sprints`, `sb_fill`, `sb_body_insert`, `sb_note`, `sb_md_files`,
  `sb_board_sprint_literal`.
- Every command that looks for a task goes through `sb_task_files`, which lists a tasks folder's
  task READMEs at both depths, and `sb_task_readme`, which finds one task folder's README at
  either.

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
| `project-readme.md.tmpl` | `<project>/README.md` | `PROJECT`, `PROJECT_PATH`, `TASKS_HUB_LINE`, `TOPICS_HUB_LINE`, `SPRINTS_HUB_LINE` |
| `project-claude-hub.md.tmpl` | `<project>/claude/README.md` | `PROJECT`, `PROJECT_PATH`, `VALIDATION_LINE` (empty when the profile's `validation_home` is `repo`) |
| `profile.md.tmpl` | `<project>/claude/profile.md` | `PROJECT`, `PROJECT_PATH`, `TICKET_KEYS`, `TASKS_ROOT`, `TOPICS_ROOT`, `SPRINTS_ROOT` |
| `hub.md.tmpl` | `tasks/README.md`, `docs/README.md`, `sprints/README.md` | `PROJECT`, `PROJECT_PATH`, `HUB_NAME`, `HUB_TITLE`, `HUB_INTRO` |
| `tasks.base.tmpl` | `<project>/tasks/tasks.base` | `TASKS_PATH`, `TASK_DEPTH`, `ARCHIVE_DEPTH`, `SPRINT_ID` |
| `task-readme.md.tmpl` | a task README | `ID`, `TITLE`, `TOPIC_TAGS`, `UP_LINK` |
| `task-envs.md.tmpl` | the environment-set additions | `ID`, `ENV` |
| `ticket-description.md.tmpl` | paste-ready ticket text | none |
| `sprint-note.md.tmpl` | a sprint note | `PROJECT`, `SPRINT_ID`, `START`, `END`, `UP_LINK` |
| `subproject.md.tmpl` | `<project>/claude/subprojects/<name>.md` | `PROJECT`, `SUBPROJECT`, `REPOS`, `UP_LINK`, `PROFILE_LINK`, `DOCS_LINK` |
| `subproject-docs.md.tmpl` | `<topics_root>/<name>/README.md` | `PROJECT`, `SUBPROJECT`, `UP_LINK`, `NOTE_LINK` |
| `validation.md.tmpl` | `<project>/claude/validation.md` | `PROJECT`, `PROJECT_PATH` |
| `validation-repo.md.tmpl` | one `## <repo>` section of a `validation.md` | `REPO` |
| `spec-requirements.md.tmpl`, `spec-design.md.tmpl`, `spec-tasks.md.tmpl` | the body of a spec file, under the frontmatter and up link the helper writes in the vault | `ID`, `TITLE` |

A link in a generated note carries the full vault path of a `README.md`, with the alias as display
text.

## 9. Skills and agents

- The plugin's namespace is `odsb`, the `name` in `.claude-plugin/plugin.json`. Skills run as
  `/odsb:<skill>`, and agents show as `odsb:<agent>`.
- The marketplace entry in `.claude-plugin/marketplace.json` keeps the name
  `obsidian-dev-second-brain`, so an install stays `obsidian-dev-second-brain@second-brain` and
  updates in place.
- Frontmatter: `name` (equals the folder or file name), `description` (one sentence, under 200
  characters, quoted if it contains `: `).
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
- **A spec-driven story is built in two halves.** The `spec` skill writes requirements, then
  design, then tasks in the owner's session.
- The owner approves each phase. An approval is a status note in exactly these words:
  `Spec: <phase> approved by the owner.`
- A phase changed after its approval gets the note `Spec: <phase> reopened.` An approval counts
  only when it is newer than every `reopened` note of its own phase or an earlier one.
- Only the owner's session asks the owner: a subagent has no AskUserQuestion.
- When the owner approves the task list, the skill runs `spec link <ID>`.
- Before the owner approves the design, and again the tasks, the skill launches `spec-checker`.
  Its prompt is the paths of the spec files written so far, and nothing else.
- `spec-checker` reads and never writes. Its reply lists what it could not build from the files.
- The skill shows the owner the gaps and closes each one with the owner before it asks for the
  approval.
- Once the tasks are approved, the skill runs the build in the owner's session, as
  `skills/spec/build.md` says. `SKILL.md` reads that file only when a build starts. With
  `spec_home: repo` the skill first commits the spec files on the story's branch.
- The skill checks the approval notes itself, and keeps the build's progress in `build.json`
  through `spec status` and `spec issue`.
- **The baseline.** A new build first launches `reviewer` on the untouched branch, in baseline
  mode, unless the branch starts on the base branch.
- The branch starts on the base branch when `git merge-base --is-ancestor HEAD <base>` exits 0.
  With `spec_home: repo`, HEAD is taken before the skill commits the spec.
- The base branch is the subproject's `base_branch`, or the profile's. `<base>` is
  `origin/<base branch>` when the repo has it, else `<base branch>`.
- When it does, the skill skips the baseline and writes the status note
  `Build: baseline skipped: the branch starts at <short hash> on <base>.`
- Any other result runs the baseline, such as on a branch cut from `release/<version>` or with
  commits the base lacks.
- A resumed build skips the baseline, whatever the start. The final validation always runs.
- **Each task in turn.** The skill builds each task with one `implementer` run, and has a fresh
  `reviewer` review it right after, before the next task starts.
- **Bundles.** In the tasks phase the skill may mark small, alike tasks with `- Bundle: <n>`. The
  owner approves the bundles with the task list.
- A bundle's tasks go to one fresh `implementer` run. It builds them in order, one commit per
  task, and fetches each task's packet as it starts that task.
- Inside a bundle, each task is built test-first and runs its own packet's `## Checks` before its
  commit.
- Then one fresh `reviewer` reads each task's packet and diff. It judges each task against its own
  requirements, logs each finding on its task, and gives one verdict per task.
- It runs each task's `Check`, and the `each task` checks and user steps once for the bundle.
- The next task or bundle starts only once every task of the bundle has passed.
- Before the run, the skill sets each task it builds `building`. Before the review, it sets each
  task it reviews `in-review`. It sets each task's result from the agent's report on that task.
- The run stops at the first task it cannot commit. The tasks after it go back to `todo`, and the
  build stops at that task.
- A task of a bundle that fails its review takes the fix loop alone, in order, with a review of
  its own fix. Its own `fails` picks each round, so the cap counts per task.
- A bundle resumes in a new session from `build.json`. A task cut off while `building` takes its
  commit as a task alone does. Then the tasks left to build go to one fresh run, and the tasks
  left to review to one review, a fix found built among them.
- A task the run gives no report on, or no commit line, is looked for by its commit first, in the
  same way.
- One task or bundle at a time, never in parallel.
- No agent launches another. The skill launches `implementer` and `reviewer` with the Agent tool,
  one at a time, and names each launch's model by role and round.
- `implementer` runs on `opus`, and on `fable`, the stronger model, from the fourth fix round on.
- `reviewer` runs on `opus`, and on `fable`, the most capable model, for the review of the whole
  branch.
- Each `implementer` launch is named, `<ID>-<task>-implementer`, and from the fourth fix round on
  `<ID>-<task>-implementer-2`. A fix reaches the agent of that name again with SendMessage.
- A bundle's run is named `<ID>-bundle-<n>-implementer`. Fix rounds 1 to 3 of its tasks go to it.
- In a new session, or when SendMessage cannot reach it, a fresh `implementer` is launched in its
  place, with the same name and model. For a task of a bundle, it is given that task alone.
- The skill takes each report from the agent's result. Nothing is relayed by hand.
- It sets a task `building` before each `implementer` launch or fix message, and `in-review`
  before each `reviewer` launch on it. It sets each result as the agent reports it.
- It shows the owner `spec status <ID>` after each task's review, when the build stops or
  finishes, and when a session resumes a build.
- A build resumes in a new session from `build.json`. A task cut off while `building` takes a
  commit of its own that `build.json` does not list yet, compared by full hash, or is built
  again.
- The tick commit of a `spec_home: repo` spec, `<ID> <task>: passed review`, is never a task's own
  commit.
- A task whose reply names no commit, and that did not stop, is looked for by its commit in the
  same way before it is set `blocked`.
- A task whose review is `failed`, with a `fix` in `spec status`, had its fix built before the
  session ended. It goes to the review of its fix, not to a new fix round.
- A `blocked` task is launched again with the owner's ruling on it, when that ruling is newer than
  the note the build stopped at it with. Otherwise the owner is asked first.
- A task stopped past the fix loop's cap gets one more round in the same way: only with a ruling
  newer than its stop note.
- A resumed `failed` task below the cap looks for that ruling too, and goes on in the fix loop with
  it as its `Owner:` line when there is one.
- A block writes its `Build: stopped at <task>` note before it sets `blocked`.
- Each story-level update is a status note in the README: each phase approval, the build
  started, stopped and why, and finished, and each ruling of the owner. A task's progress is in
  `build.json` alone.
- **Who runs which check.** `implementer` runs its task's checks before it commits. `reviewer`
  runs them again in the task's review. The skill runs the `each build` checks once, at the end.
- `implementer` writes a test that fails for its task's requirement first, then makes it pass.
- A task with nothing to test, such as a doc change, gets no test, and the reply says why.
- Its checks are the ones under its packet's `## Checks`: the task's `Check`, and the repo's
  `each task` checks through `validation run <project> <repo> --when each-task`.
- It commits only when they all pass, and names each result in its reply.
- A task `Check` that is a step its tools cannot take, such as a browser or a skill step, is
  reported as `Check: <step> - skipped - needs <tool>`. It still commits, and the review takes
  the step.
- It runs its own test the narrowest way the repo allows, such as the one suite that holds it,
  even an `each build` one.
- It runs no other `each build` check, no `release` check and no user step.
- `reviewer` runs each step under `### Check as a user would` with the tool its line names: a
  skill through the Skill tool, anything else through Bash.
- A line that names no tool runs through Bash when Bash can do what it says. One that needs a
  browser and names no tool is BLOCKED: its issue names the step and asks for its tool.
- A step whose tool `reviewer` cannot run, such as a skill that is not installed, is BLOCKED, and
  its issue names the tool.
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
- `implementer` and `reviewer` are given the story, the task and the session id, and run
  `spec packet <ID> <task>` themselves. The skill never prints a packet into the owner's session.
- For a bundle, they are given its number and its tasks in place of the task, and run
  `spec packet` once per task.
- The packet, and the commit line, are all `implementer` is given. On a fix the packet holds the
  findings of the last failed review.
- In a bundle, each task's packet and commit line are all it is given, and no other task's.
- `reviewer` reads the task's diff from the file the packet's `diff:` line names.
- A task's review reads only its diff, first against the task's requirements and acceptance
  checks, then for code quality.
- It runs the task's `Check` and the `each task` checks again, through
  `validation run <project> <repo> --when each-task`, and the `each task` user steps. It runs no
  other check.
- A re-review reads only the fix's commits and the findings they answer, as the packet holds them.
- `implementer`, `reviewer` and `spec-checker` set `omitClaudeMd: true`, so no `CLAUDE.md` adds
  to what they are given.
- `implementer` replies with a `Commit:` line, one line on what it built, a `Test:` line, and a
  `Check:` line with the result of each check it ran.
- A stop is a first line `BLOCKED: <why>`, then the `Check:` lines of the checks it ran.
- In a bundle, it replies with one report per task, in order, each under a line `Task: <task>`.
  A stop is the report of the task it stopped at, and no report follows it.
- `reviewer` logs each issue with its proposed fix through `spec issue`, then replies with its
  verdict and the number of issues: `VERDICT: PASS`, `VERDICT: FAIL` or `VERDICT: BLOCKED`.
- In a bundle, it replies with one verdict line per task, in order:
  `<task>: VERDICT: <PASS, FAIL or BLOCKED> - <n> issues`.
- In baseline mode there is no task to log on: `reviewer` puts its findings in the reply.
- In user and branch mode, `reviewer` logs a finding on the task whose `- Files:` line holds its
  file, and puts the rest in the reply.
- Only a PASS ticks the task, through `spec tick`. With `spec_home: repo`, the skill commits that
  tick.
- A FAIL starts the fix loop and holds up the tasks after it. The task's `fails` picks each round,
  so the cap holds across sessions.
- Fix rounds 1 to 3 go back to the same `implementer`, with the findings in its packet. Rounds 4
  and 5 go to a fresh one on the stronger model. A sixth failed review stops the build.
- A BLOCKED, or an implementer reply that starts `BLOCKED:`, stops the build at once.
- When every task has passed, the skill runs `validation run <project> <repo> --when each-build`
  once, with no agent.
- The skill, `reviewer` and `implementer` run `validation run`, and `implementer` its tests and
  its task's `Check`, with the Bash tool's `run_in_background` and wait for its notice. A run can
  outlast a Bash call's timeout, and a helper that a timeout kills leaves its check running.
- A failing check is logged with `spec issue` on the task whose files it covers. That task is set
  `failed` and takes the fix loop, and the run goes again once every task has passed.
- Then one `reviewer` runs the user steps on the finished branch, in user mode. Then one
  `reviewer` on the most capable model reviews the whole branch, in branch mode. A FAIL or a
  BLOCKED from either stops the build.
- The baseline runs the checks through `validation run --when each-build`, and every user step but
  the `release` ones.
- A `release` check runs only when the owner asks.
- When the build finishes with every task passed, the skill asks the owner whether to merge the
  story's branch, open a pull request, or keep the branch, as `skills/spec/finish.md` says.
- A merge or a pull request runs only on the owner's pick.
- Each push or pull request is named before it runs.
- The story's branch is deleted only when the owner types `discard`.
- The three agents and their tools. None has the Agent tool:

| Agent | Tools | Job |
|---|---|---|
| `implementer` | Bash, Read, Glob, Grep, Edit, Write | builds one task test-first, or each task of a bundle in turn, runs its packet's checks and commits it on the story's branch; reads and writes nothing outside the repo but its packets |
| `reviewer` | Bash, Read, Glob, Grep, Skill | reads the diff of a task, or of each task of a bundle, and runs each user step with its tool; edits no file; logs its issues with `spec issue` |
| `spec-checker` | Read, Glob, Grep | reads the spec files it is given and lists what it could not build from them; writes nothing |

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
  `tasks/<ID>/README.md` or `tasks/archive/<YYYY>/<ID>/README.md` read with no `offset` and no
  `limit`; a Bash command that runs grep, egrep, fgrep, rg, cat or sed.
- The warning is one JSON object whose `hookSpecificOutput.additionalContext` says what the call
  does, then the search and read rule. Otherwise it prints nothing.
- A call reaches into the vault when one of its paths, or the working directory, holds the last
  two parts of the vault's path, through the pointer or the physical one, as whole names: after a
  slash, a quote, a blank or the start, and at the end of a name.
- Letter case is ignored and a backslash counts as a slash, so `~/`, `$HOME/`, `C:\` and `/c/`
  forms all match. A Bash command also reaches into the vault when it holds `second-brain root`.
- Edit and Write are never matched. A ranged Read, or a Read of another note, passes in silence.
- It loads no library, starts one awk, and reads a long command in one pass. With no vault, or
  with input it cannot read, it prints nothing.

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
