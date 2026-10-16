# Contract

The interfaces every part of this plugin agrees on. Skills and agents call the helper by the
commands below; the helper fills the templates by the placeholders below; notes carry the
frontmatter below. Change this file first, then the code.

## 1. Words and paths

| Word | Meaning |
|---|---|
| vault | The Obsidian vault root, the folder that holds `.obsidian/`. |
| link directory | `~/.claude`, or `SECOND_BRAIN_CLAUDE_HOME` when set (tests set it). Holds the pointer and the links to the vault's own skills and agents. |
| pointer | `second-brain-vault` in the link directory, a link to the vault: a symlink on macOS and Linux, a directory junction on Windows. `second-brain pointer set` creates it. The environment variable `SECOND_BRAIN_VAULT` overrides it (tests use this). |
| index | `<vault>/CLAUDE.md`. Always loaded by Claude through an import in `~/.claude/CLAUDE.md`. Holds the only list of projects. |
| conventions | `<vault>/obsidian-conventions.md`. Skills point to it as `~/.claude/second-brain-vault/obsidian-conventions.md`. Its first section, "The short version", is the default read. |
| project | A folder inside the vault, listed in the index by its vault-relative path. |
| profile | `<vault>/<project path>/claude/profile.md`. The one per-project settings note. |
| subproject | A part of a project with its own repos, branches and docs folder, declared by one note `<project>/claude/subprojects/<name>.md`. It shares the project's ticket keys, tasks and board. |
| helper | `bin/second-brain`. On the Bash PATH while the plugin is enabled. It reads and writes the vault's files and never calls Obsidian, which is only the viewer. |
| vault path | A path relative to the vault root, with forward slashes on every system. |

Generic files (everything in this repo) never contain an absolute path, a project name, a ticket
key or a person's name. `scripts/leak-check.sh` enforces part of that.

## 2. The index

`<vault>/CLAUDE.md` contains a `## Projects` section with exactly this table. The helper parses it.

```markdown
## Projects

| Project | Path | Keys | Use when |
|---|---|---|---|
| Example | clients/acme/projects/example | EX, EXOPS | Anything about the Example service. |
```

- `Project` is the display name, unique, matched case-insensitively.
- `Path` is vault-relative, no leading or trailing slash. It is a folder in the vault, and no two
  rows share one: paths are compared without letter case, with `//` and `/./` folded.
- `Keys` are ticket key prefixes, comma separated; may be empty. A key belongs to one row. An
  item with no letter or digit, such as `-`, is no key.
- A project's folder may sit inside another project's folder. Each row is its own project. The
  doctor's `task-location` check leaves the notes of the inner project to that project; a check
  that goes by the path alone, such as `unresolved-links`, lists them under both.
- A path names no project folder when, with `//` and `/./` folded, it is `.`, holds a `..` part
  or holds a backslash. The doctor reports such a row in `index`, prints no project rows for it,
  and opens and writes nothing under it.

The file opens with frontmatter that holds `index_version`, a whole number:

```markdown
---
index_version: 1
---
```

- It is the version of `templates/vault-index.md.tmpl` that the text above `## Projects` follows.
  The template's number goes up when that text changes.
- The doctor's `index` check warns when the vault's number is missing or lower than the template's.
  A number too long to compare counts as newer. The same holds for `conventions_version`.
- No command brings an index up to date, because it may hold the user's own lines. It is edited by
  hand: the text above `## Projects` is brought in line with the template, the table is kept, and
  `index_version` is set to the template's number.
- The text says where a rule the user asks Claude to save goes. A rule about one project goes
  under `## Rules` in `<Path>/claude/README.md`, or in its subproject's note. Only a rule for every
  project goes in `~/.claude/CLAUDE.md`. When Claude cannot tell which, it asks.
- It says to read the subproject's note with the project's `claude/README.md` when
  `second-brain context` prints a `subproject` line, so the subproject's rules load with the
  project's.

## 3. The project

```
<project>/
  README.md
  claude/README.md
  claude/profile.md
  claude/subprojects/<name>.md  one per subproject; none by default
  tasks/README.md
  tasks/tasks.base
  tasks/<TICKET-ID>/README.md
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
achievements_skill: ""
tags:
  - type/profile
---
```

- `production_branch` is the branch production runs. Empty means `base_branch`.
- `persona` is the role a story's description opens with (`*As a* <persona>,`).
- `topics_root: "."` means topic folders sit at the project root.
- `tasks_root`, `topics_root` and `sprints_root` are folders inside the project, written with
  forward slashes. A slash in front or behind is dropped by every command, so `/tasks` is
  `tasks`. One that holds a `..` part or a backslash leaves the project: the doctor's `profile`
  check fails, and the doctor checks the project under that root's default, so nothing is
  opened through the value.
- `uses_sprints` says whether the project runs sprints. Only `false`, in any letter case, turns
  them off; a profile without the key uses sprints. With `false` the project has no sprints hub and
  no `Current sprint` view, the three sprint keys are ignored, every `sprint` command exits 5,
  `task set` refuses a sprint id and `board <project> "Current sprint"` has no rows.
  - Turning them on later: set the key to `true` and run `scaffold project` again. It creates the
    hub and names on stderr what it leaves to add by hand in files that exist: the map line in the
    project README, and the board's `Current sprint` view and sprint columns.
  - Turning them off on a project that ran sprints: close the sprint in progress first. One left
    in progress can no longer be closed, and the doctor warns about it.
- `environments` lists environment names in promotion order, or is empty.
- `repos` are folder names of the code repositories, used to match the working directory. The first
  one is the default repo for branch checks.
- `repos_root` is the folder those repositories usually sit in on this machine, absolute or starting
  with `~`. `repo_paths` lists the exceptions, one `name=path` string per repo stored elsewhere.
  Both may be empty; then a repo's location is unknown and the skills ask for it.
- `achievements_skill` names a skill to hand finished stories to, or is empty.

### Profile sections

Fixed level-2 headings, read one at a time with `second-brain profile <project> <section>`:
`## Stories`, `## Topics`, `## Repos`, `## Environments`, `## Sprints`, `## Docs`, `## Live systems`.

`## Docs` holds, as level-3 headings: `### Repo doc surfaces`, `### Vault doc surfaces`,
`### Code to doc map`, `### Facts in several places`, `### Not drift`, `### Terminology`,
`### Reference implementation`, `### Neighbours`, `### Debt file`.

`### Code to doc map` is a table with the columns `Repo`, `Change in the code`, `Docs to update`.
Every repository in `repos` has at least one row. Adding a repository to a project means adding its
rows in the same change; the doctor's `code-doc-map` check enforces it. So does every repository of
a subproject, with the subproject's docs folder in its Docs cell; the `subprojects` check enforces it.

### Subprojects

A project made of several repos, each with its own branches and docs, splits them into
subprojects. They split repos and docs, not tracking: one ticket key, one board.

Path: `<project>/claude/subprojects/<name>.md`. The name is the file name without `.md`, and is a
folder name: no slash, none of `| [ ] " # ^ : * ? < >` and the backslash, no blank at either end,
not starting with `.` or `-`.

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
tags:
  - type/subproject
---
```

- `repos` lists the subproject's repositories, the first the default for branch checks. Each one
  belongs to one subproject. It need not be in the profile's `repos`: the project's repositories
  are the profile's, then each subproject's that the profile does not list.
- `base_branch`, `production_branch`, `branch_pattern`, `environments` and `repo_paths` mean what
  they mean in the profile. One that is absent or empty (`""`, `[]`) takes the profile's value. So
  a subproject cannot have fewer environments than the project; the empty list means "as the
  project".
- An empty effective `production_branch` still means the effective `base_branch`.
- `repos_root` is the profile's. A `repo_paths` entry of a subproject wins over the profile's
  entry for the same repo.
- The body has a `## Rules` section: the rules Claude follows in that subproject.
- Its docs folder is `<topics_root>/<name>/`, or `<name>/` at the project root when the topics
  root is `.`. It is a topic folder like any other, with a `README.md` hub.
- A working directory resolves to a subproject the way it resolves to a project: the deepest
  recorded folder of a project repository that holds it decides; with none, the deepest folder on
  the way up whose name is a repo of the project, the profile's included. A directory in a
  repository of the profile alone is in no subproject, and neither is a folder of the vault.
- A project with no `claude/subprojects/` folder behaves exactly as before.

## 4. A task

Path: `<project>/<tasks_root>/<ID>/README.md`. `<ID>` is the ticket id, or a kebab-case slug when
there is no ticket yet.

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
type: task
tags:
  - <topic/tag>               # zero or more; the folder path under the topics root, lowercased
  - type/task
  - status/active             # status/done for done and abandoned, status/active otherwise
---
```

- The helper never writes `jira_id`. Notes that already have it keep it; readers ignore it.
- Environment sets add an `envs:` mapping (`<env>: { id: <ID>, status: <status> }`) and list every
  id in `aliases`.
- Strings are written double-quoted when they contain `: `, `#`, start with `-` or `[`, or look
  like a date or number. Sprint ids are always quoted.
- Body sections of a new task, in order: `# <ID> - <title>`, `**Summary:**`, `**Branch:**`,
  `## Description`, `## Findings` (optional), `## Acceptance criteria`,
  `## Approach / Key decisions`, `## Code verification (read-only)`, `## Changes`,
  `## Verification`, `## Status notes`, `## Discovery log`. A task may also carry
  `## Docs to update`: one checkbox line per doc edit waiting for the change to reach production.
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

`<project>/<tasks_root>/tasks.base`, an Obsidian Bases file. Views, by exact name: `Active`,
`Current sprint`, `By topic`, `Needs a status`, `All`. It lists only the README directly inside each
task folder (a folder-depth filter), shows `file.asLink(aliases[0])` as the task name, and the
`Current sprint` view filters on one literal sprint id that `sprint open` rewrites. A project with
`uses_sprints: false` is scaffolded without the `Current sprint` view and the sprint columns.

`board <project> "Current sprint"` goes by the sprint in progress, not by that literal. When the
two differ, Obsidian shows another sprint than the helper reports; the doctor's `board` check
warns about it.

## 7. The helper

`second-brain <command> [args]`. Bash 3.2 and awk only; must run on macOS, on Linux, and on Windows
in Git Bash, the shell Claude Code uses there. Output is plain text meant to be read by Claude:
short, stable, no colour.

Exit codes: `0` ok, `1` not found, `2` setup missing (no pointer or not a vault), `4` ambiguous,
`5` bad usage, `6` already exists. `3` is retired: it meant the Obsidian CLI was unavailable.

Rules that hold for every command:

- An empty cell or value prints `-`. Callers read `-` as empty.
- Every read and every write is a file operation on the vault. No command needs Obsidian to be
  installed or running.
- Wherever a command takes `<ID>`, the folder id or any alias of the task is accepted. Task commands
  resolve it from the task READMEs on disk.
- A lookup that finds nothing exits 1 (`find`, `topic`, `search`). A listing that finds nothing
  exits 0 with no rows (`board`, `projects`, `backlinks`, `unresolved`).
- Writes change only the lines they must and keep the file's line endings.
- Wherever a command takes `<path>`, it is a vault path. One that leaves the vault, enters a dot
  folder or holds a backslash is refused with exit 5, and so is an absolute path.
- An absolute path is printed with forward slashes; on Windows in the drive form, `C:/...`, which
  Git Bash and Windows programs both accept. An absolute path that is read (an argument, an
  environment override, `repos_root`, a `repo_paths` entry) may be in that form, written with
  backslashes, or in Git Bash's own form, `/c/...`.
- Environment overrides: `SECOND_BRAIN_VAULT` (vault root), `SECOND_BRAIN_CLAUDE_HOME` (link
  directory), `SECOND_BRAIN_TODAY` (today's date, for tests).

| Command | Output | Notes |
|---|---|---|
| `help` | the command list | |
| `version` | the plugin version | read from `.claude-plugin/plugin.json` |
| `conventions [section]` | one level-2 section of the vault's conventions note | default section `The short version`; the name is matched case-insensitively; exit 1 when the note or the section is missing |
| `root` | absolute physical path of the vault | exit 2 when the pointer is missing or not a vault |
| `context [--cwd DIR]` | at most 5 `key: value` lines: `vault`, `project`, `project_path`, `subproject`, `sprint` | always exits 0; unknown values print `none`. `sprint` is `off` for a project that does not use sprints. The `subproject` line is there only when one subproject's repository holds the directory |
| `projects` | one TSV row per project: name, path, keys | from the index table |
| `project --name N` / `--key K` / `--cwd DIR` | one TSV row: name, path, keys | `K` is a key prefix or a full id (`EX` or `EX-123`). With no flag it uses the working directory. Exit 1 none, exit 4 several (prints them) |
| `repo <project> [name]` | with no name, one TSV row per repo in the profile's order, then each subproject's repos the profile does not list, by subproject name: name, path, state (`ok`, `missing`, or `unknown` when no location is recorded; path is then `-`). With a name, the path alone | paths are absolute, with `~` expanded. With a name: exit 1 when the name is not in `repos`, when no location is recorded, or when the folder is missing; the message says which |
| `subproject <project>` | one TSV row per subproject, by name: name, repos (comma separated, or `-`), docs folder as a vault path | exit 0 with no rows for a project with none; exit 1 when the profile is missing |
| `subproject <project> <name>` / `--cwd DIR` | the effective settings as `key: value` lines: `subproject`, `note`, `docs`, `repos`, `base_branch`, `production_branch`, `branch_pattern`, `environments`, `repo_paths` | the name is matched exact first, then without letter case. `base_branch` to `environments` are each the note's value, or the profile's when the note's is absent or empty; lists are joined with `, `. `repo_paths` is `<repo>=<path>` for each of its repos with a location, found as `repo` finds it (the note's entry, the profile's, then `repos_root`), or `-`. `--cwd` takes the subproject whose repository holds the directory. Exit 1 none, exit 4 several (prints their names) |
| `profile <project> --keys` | profile frontmatter as `key: value` lines | exit 1 when the profile is missing, with a hint to run vault-setup adopt |
| `profile <project> <section>` | the body of that level-2 section | section name matched case-insensitively; exit 1 when absent |
| `board <project> [view]` | one row per task (no rows for `Current sprint` when no sprint is in progress): `id | title | status | sprint | topics | branch | next | envs` | default view `Active` (status planned, in-progress or in-review). Reads the frontmatter of the task READMEs and applies the view's own rule; the board file is what Obsidian shows and is not read. `envs` is `-` or `dev:EX-1:done,qa:EX-2:planned`, each name as the note spells it. `title` falls back to the note's first heading when the property is absent |
| `find <ID-or-alias> [--project P]` | vault path(s) | tries the task path, then the aliases in frontmatter: task READMEs first, then every note of the project; exit 1 none |
| `task head <ID> [--project P]` | at most 15 lines: id, path, title, status, next, sprint, branch, epic, subproject (only when set), topics, envs, summary line, newest status note | |
| `task set <ID> key=value... [--project P]` | the changed keys, or `no change` | scalar keys only; setting `status` also sets the `status/` tag, and setting `type` the `type/` tag; `key=` removes the key. Exit 5 for a status outside the five, for `jira_id`, for list keys, and for a sprint id on a project that does not use sprints (`sprint=` still removes one). `subproject` must name a subproject of the task's project, matched as by `subproject <project> <name>` and written as its note is named; exit 1 when none matches |
| `task tag <ID> add\|remove <tag> [--project P]` | the resulting topic tags | edits the `tags:` list; refuses `type/` and `status/` tags (exit 5) |
| `task alias <ID> add <alias> [--project P]` | the resulting aliases | appends to `aliases:`, quoting when needed; the first alias never changes; exit 6 when the alias already names another task. Renaming a slug-named task to its ticket id (a new first alias and folder name) is not covered yet and is done by hand |
| `task new <ID> [--project P] [--title T] [--topics a,b] [--envs] [--subproject S]` | the new README's vault-relative path | `--project` may be left out when the id's key names one project. Exit 6 when the task already has a README or the id is another task's alias; a folder with no README gets one. Exit 5 for `--envs` when the profile lists no environments. A topic with no folder is still written, with a `note:` on stderr. `--subproject` writes the `subproject` key as `task set` does, exit 1 when it names none; with `--envs` the subproject's own environments come first |
| `task note <ID> "<text>" [--project P] [--session S]` | the line it added | prepends a dated line under `## Status notes` |
| `topic <project> <tag>` | paths of task READMEs carrying the tag or a sub-tag | |
| `search <project> "<text>" [--in SUBPATH]` | `path:line: text` matches, at most 40 | the text is split into terms at blanks, and a part in double quotes is one term, a phrase. A note matches when it holds every term, in any letter case. A note gives at most three lines: for one term, the first lines that hold it; for several, the lines that hold the most terms among those holding at least two, or, when it has none, the first line that holds each term. When more than 40 lines are left, every note's best line is kept before any note's second. Lines holding more of the terms come first, then by path and line. Exit 1 when no note matches, exit 5 when the text holds no term |
| `outline <path>` | one row per heading: `<line>: <hashes> <heading>`, as in `12: ## Status notes` | headings are lines that open with one to six `#` and a space; those in frontmatter or a fenced code block are skipped. Exit 1 when the note is missing |
| `backlinks <path>` | `path:line: <link as written>`, one row per link that resolves to the note | covers every note of the vault; exit 1 when the note is missing. A note that cannot be read is named on stderr as `note: <path> could not be read` |
| `unresolved [project]` | `path:line: <link as written>`, one row per link that resolves to no file | the whole vault, or the notes under one project. A note that cannot be read is named on stderr in the same way |
| `move <from> <to> [--dry-run]` | `moved: <from> -> <to>`, then one line `links: <path> \| <count>` per note it rewrote, with the note's path after the move | moves a note, any other file, or a folder with everything under it, and rewrites the links (see Links between notes). `<to>` is the new vault path, taken as written: no extension is added. When it names an existing folder or ends with `/`, the item goes inside it under its own name. Missing folders are created. Exit 1 when `<from>` is missing, exit 6 when the destination exists. Exit 5 when `<from>` is the vault root, or is or holds what the helper finds at a fixed path (the index, the conventions note, an index project's folder or its profile), and when a name in `<to>` cannot be written in a link. `--dry-run` prints the same lines after a first line `dry run`, writes nothing, and exits as the move would. `--` ends the options, for a name that starts with a hyphen |
| `rename <path> <name> [--dry-run]` | the same lines as `move` | a new name in the same folder; `--` ends the options here too. The extension never changes: `<name>` may end with the file's own extension, in any letter case, or leave it out, and anything else is part of the name, so `api.v2` gives `api.v2.md`. Exit 5 when `<name>` holds a slash |
| `sprint current <project>` | TSV: id, start, end, days_left, goal | exit 1 when no sprint is in progress. This and every other `sprint` command exits 5 with `<project> does not use sprints` when the profile says `uses_sprints: false` |
| `sprint next <project>` | TSV: id, start, end | what `sprint open` would create with no `--end`; writes nothing; exit 1 when the profile has no `sprint_anchor_end` |
| `sprint open <project> [--end YYYY-MM-DD] [--goal G]` | the new sprint note's path, then one line per task it re-pointed | refuses (exit 6) while another sprint is in progress. With no `--end` it takes the first cadence end on or after today that has no note. It writes `sprint_anchor_end` only when the profile has none. It rewrites the board's sprint literal, and moves every open task (status not done or abandoned) whose `sprint` id has no sprint note onto the sprint being opened, printing `re-pointed: <ID> from <old> to <new>` |
| `sprint set <project> key=value...` | the changed keys | sets `goal` or `committed` on the sprint in progress; exit 1 when there is none, exit 5 for any other key |
| `sprint close <project> [--carry ID,ID] [--backlog ID,ID] [--abandon ID,ID]` | a summary: `sprint:`, `done:`, `carried:`, `backlog:`, `abandoned:`, `next:` | every open task of the sprint must be named in exactly one list, else exit 5 listing the problem. On tasks it writes `carried_from`, `sprint`, `status` and the tag. On the sprint note it writes the `## Close` lists, `completed`, `carried_over`, `status: done` and the tag. It writes no status notes; the caller adds the reason with `task note`. `next:` is the id carried tasks now point at |
| `scaffold vault [DIR]` | the files it created | never overwrites; creates index, conventions, `claude/README.md`. A file that already exists is reported on stderr as `exists: <path>` |
| `scaffold project <name> --path P [--keys K1,K2] [--use-when TEXT] [--tasks-root R] [--topics-root R] [--sprints-root R] [--no-sprints]` | the files it created | never overwrites (`exists: <path>` on stderr); adds the index row; exit 6 when a key in `--keys` already belongs to another project. The three root flags adopt a project whose notes already live elsewhere: they are written into a new profile and the hubs and board are created under them. `--topics-root .` creates no topics hub. When the profile exists its roots win and the flags are ignored. Exit 5 for a root that leaves the project, repeats another root, or sits inside the tasks root. `--no-sprints` writes `uses_sprints: false` into a new profile, creates no sprints hub and no map line for it, and writes the board without its sprint parts; exit 5 together with `--sprints-root`. An existing profile decides here too: its `uses_sprints` wins over the flag |
| `scaffold subproject <project> <name> [--repos R1,R2]` | the files it created: the subproject note and the `README.md` of its docs folder | never overwrites (`exists: <path>` on stderr). Adds a link to the new docs hub under `## Topics` in the topics hub, once. A repo named twice in `--repos`, in any letter case, is written once. Exit 5 for a name that is not a folder name or a repo name that holds a character outside letters, digits, `.`, `_` and `-`; exit 6 when another subproject has that name in another letter case, or already lists one of the repos; exit 1 for an unknown project or a missing profile. Writes no Code to doc map row: the user names the docs |
| `pointer` | the absolute path of the folder the pointer leads to | exit 2 when there is no pointer, or when a real file or folder sits in its place. A pointer whose folder is gone still prints where it leads, with a `note:` on stderr |
| `pointer set <DIR> [--replace]` | the folder the pointer now leads to | creates the pointer in the link directory: a symlink on macOS and Linux, a junction on Windows. Exit 5 when `DIR` has no `.obsidian` folder. A pointer that already leads to `DIR` is left alone. One that leads elsewhere, or to a folder that is gone, is kept, and the command exits 6 naming where it leads, unless `--replace` is given. A real file or folder in the pointer's place is never replaced: exit 6 |
| `link [--check \| --apply]` | one row per skill or agent: `name \| kind \| state \| target` | scans `<vault>/claude/` and each index project's `claude/`, but not that of a row whose path holds a `..` part or a backslash; never touches links it did not make. Exit 1 when a row is neither `linked` nor `foreign`. `--apply` reports what it did as `note:` lines on stderr |
| `doctor [project] [--json] [--fix]` | one row per check: `result \| check \| scope \| count \| offenders \| fix` | exit 0 when no check fails, 1 when one does, 2 when there is no vault. `--fix` prints `fixed: ...` lines, then the table |
| `snapshot [name]`, `compare [name]` | where the snapshot is, or the differences | stored under `<vault>/.second-brain/snapshots/`. `snapshot` exits 6 when the name exists. `compare` covers unresolved links, aliases, task ids and statuses, and links; it does not compare tags or doctor rows. It exits 0 with `no differences`, and 1 on a difference or when there is no snapshot |
| `session-check` | nothing when set up, else one line | always exits 0 |

### Links between notes

`backlinks`, `unresolved`, `move`, `rename`, the doctor's `unresolved-links` check and the snapshot
share one reading of a note's links, in `scripts/lib/graph.sh`.

- A link is a wikilink, `[[target]]`, or a markdown link to a file, `[text](target)`. A wikilink
  may carry `#heading` or `#^block` after the target, `|text` after that, and a leading `!` for an
  embed. A markdown target may be wrapped in `<>` or percent-encoded. One with a scheme (`https:`,
  `mailto:`) or one that starts with `#` is not a link to a file.
- Text in a fenced code block or an inline code span holds no links. Frontmatter does.
- A link with an empty target, such as `[[#heading]]`, points inside its own note and is skipped.
- A target is tried as written, then with `.md` added. Letter case is ignored (ASCII letters).
- A target resolves to the first of these that exists: the file at that vault path; the file at
  that path taken from the linking note's folder; the file whose vault path ends with the target
  at a folder boundary. When several files match the last rule, the one in the linking note's
  folder wins, then the one with the fewest folders in its path, then the first in byte order.
- A target that starts with `./` or `../` is taken from the linking note's folder only. One that
  starts with `/` is a vault path only.
- A target that resolves to no file is unresolved.
- The files of the vault are every file under the vault root outside dot folders (`.obsidian`,
  `.trash`, `.second-brain`). Notes are the `.md` files among them; only notes are read for links.
  A symlink inside the vault is not followed: what lies behind it is not a file of the vault.
- A markdown link sits on one line. One whose text is wrapped over two lines is not read.

What `move` and `rename` do to links:

- Every link keeps leading to the file it led to. A link that resolved to a moved file is
  rewritten to resolve to it at its new place. So is a link inside a moved note, and a link
  anywhere that the moved file would capture at its new place, when it would otherwise resolve to
  another file or to none. A link that still resolves to the same file is left as written.
- A rewritten wikilink is the new file name alone when the old target was a file name alone and
  the new name is unique in the vault; otherwise it is the new vault path. It has `.md` only when
  the old target had it. `!`, `#heading` and `|text` are kept.
- A rewritten markdown link keeps its form: a path taken from its note's folder stays one, a vault
  path stays one, and `<>` or percent-encoding is kept.
- In frontmatter, a link inside a single-quoted value is written, and read, with each apostrophe
  of its target doubled, as YAML asks. Not covered: a quoted value that runs over several lines,
  a block scalar, a quoted value behind a tag or an anchor, an unquoted link whose new name YAML
  reads as structure, and a note whose opening `---` is never closed.
- Files that are not notes are moved and never edited. A `.canvas` or `.base` file that mentions a
  moved file's old vault path is named on stderr as `note: <path> mentions <old path>`.
- The links are worked out before anything is written; the files are moved, then the notes edited.
- A destination is refused with exit 5 when a name the move creates, the new name or a folder
  that does not exist yet, holds one of `# ^ [ ] | \ : * ? " < >`, a backtick or a control
  character, or starts or ends with a blank: Obsidian forbids them, and a link could not spell
  the name. So is a source or a destination that lies behind a symlinked folder.
- Where the file system ignores letter case, `<from>` may be written in another case of ASCII
  letters. A spelling that reaches the file only through a fold the helper does not make, a
  Unicode form or the case of a letter outside ASCII, is refused with exit 1.
- Nothing is moved or written unless every note of the vault can be read in full and every note
  to rewrite can be written. A note that cannot is named on stderr and the command exits 1.
- Every rewritten line is read again before anything is moved: each rewritten link must be found
  and must resolve to its file. One that does not stops the command with exit 1, naming the note
  and the line.
- A note that changed while the command ran is left as it is and named on stderr as still
  holding old links. The other notes are rewritten and the command exits 1.
- The destination is looked at again right before the move and is never overwritten.
- Not covered: a rename that changes only the letter case of a name, on a file system that
  ignores case. It exits 6.

### link, doctor, snapshot

Library files: `scripts/lib/link.sh` (`cmd_link`, `cmd_pointer`, `sb_link_scan`),
`scripts/lib/doctor.sh` (`cmd_doctor`, `cmd_session_check`), `scripts/lib/snapshot.sh`
(`cmd_snapshot`, `cmd_compare`). Their private helpers are named `sb_link_*`, `sb_doc_*` and
`sb_snap_*`.

- On macOS and Linux every link is a symlink: one per skill folder in the link directory's
  `skills/`, one per agent file in its `agents/`.
- On Windows every link is a directory junction, which needs no special rights: one per skill
  folder, and one per claude folder for its whole `agents` folder, because a junction cannot lead
  to a file. The agents junction is named `second-brain-vault` for the vault's own `claude/` and
  `second-brain-project-<project path with each slash as a hyphen>` for a project's. Claude Code
  reads `agents/` through its sub-folders, so every agent file in a linked folder is found, and so
  is any other `.md` file kept there.
- `link` prints one row per agent on every system. On Windows each agent row carries the state of
  its folder's junction. Two project paths that give the same junction name cannot both be linked:
  the agents of the later one are `duplicate`.
- A junction needs a folder on a local drive, so a vault on a network share cannot be linked.
- A plain `ln -s` is never used on Windows, where Git Bash turns it into a copy.
- `sb_link_scan` prints one row per item, no header: `name | kind | state | target`. `kind` is
  `skill` or `agent`. `state` is one of `linked`, `missing`, `wrong-target`, `name-mismatch`,
  `duplicate`, `dangling`, `foreign`. `cmd_link --check` prints the same rows.
- A doctor row is `result | check | scope | count | offenders | fix`. `result` is `ok`, `warn` or
  `fail`. `scope` is `vault` or a project name. `offenders` holds at most five, comma separated,
  or `-`.
- A long offender is cut and ends with `...`: at 48 bytes, or at 120 for the paths of `hubs` and
  `task-location`. A short tag after its last colon, such as `:no-folder`, is kept whole: the
  cut falls in the value before it.
- A check prints one row. Where it has a fail case and a warn case, a fail wins: the row is the
  fail row, with the fail offenders only. `subprojects` is the one exception: a project with no
  subproject note gets no row for it.
- The doctor follows no `..`. An index path or a profile root is judged as it is written, and
  nothing is opened through one that holds a `..` part or a backslash, or through a root that
  starts with `/`. A link inside the vault is the user's own choice: the doctor does not check
  where a project folder that is one leads.
- Doctor check names, exactly as printed:

| Scope | Check | Fails or warns when |
|---|---|---|
| vault | `pointer` | the pointer does not resolve to a vault (fail) |
| vault | `index` | the index is missing, has no Projects table, has a row whose path is not a folder in the vault (`<Project>:no-folder`; a path that is `.`, or holds a `..` part or a backslash, is never one and is not looked for on disk), or has a name, a key or a path on two rows (`<value>:twice`, with names and paths compared without letter case, `//` and `/./` in a path folded, and keys compared in upper case) (fail); or its `index_version` is missing or lower than the template's (warn, `CLAUDE.md:<version or none>`) |
| vault | `conventions` | the conventions note is missing (fail), or its `conventions_version` is lower than the template's (warn) |
| vault | `import` | no import line for the index in the link directory's `CLAUDE.md` (warn) |
| vault | `global-rules` | a line of the link directory's `CLAUDE.md` names an index project: its name as a whole word, as written, or its path in any letter case (`<project>:<line number>`, or `<project>:@<line number>` for an `@` import line, whose fix is to remove it) (warn). A whole word has no letter, digit, `_` or `-` on either side. The import line of the index and the table rows under a `## Projects` heading are not read, nor the files the `CLAUDE.md` imports |
| vault | `links` | a vault-owned skill or agent is missing, wrong-target, dangling, name-mismatch or duplicate (fail) |
| vault | `double-registration` | a link in the link directory points inside the plugin (warn) |
| vault | `always-loaded-size` | the index is over 60 lines or the link directory's `CLAUDE.md` over 40 (warn) |
| vault | `descriptions` | a scanned skill or agent has no description (`<name>:none`), or one over 200 characters (`<name>:<length>`) (warn) |
| vault | `skill-size` | a scanned `SKILL.md` is over 150 lines (warn) |
| project | `profile` | the profile is missing, lacks a contract key, lacks one of the seven sections, or has a root that leaves the project (`<key>:leaves-project`) (fail) |
| project | `board` | the board file is missing (fail); or, while a sprint is in progress, its `Current sprint` view filters on another sprint id (`tasks.base:<that id>`), its filter is not written as `sprint == "<id>"`, the one form the helper reads and `sprint open` rewrites (`tasks.base:filter`), or it has no such view (`tasks.base:no-view`) (warn). With no sprint in progress, or for a project that does not use sprints, the view is not looked at |
| project | `hubs` | a hub is missing or empty (warn): `README.md`, `claude/README.md`, `<tasks_root>/README.md`, `<topics_root>/README.md` unless the topics root is `.`, and `<sprints_root>/README.md` when the project uses sprints. Offenders are paths under the project, and a hub that two roots share is named once |
| project | `task-frontmatter` | first alias differs from the folder name, or `type` or its tag is missing (fail) |
| project | `needs-a-status` | status missing or not one of the five (warn; never changed) |
| project | `status-tag` | the `status/` tag disagrees with `status` (warn; the only check `--fix` repairs) |
| project | `yaml-traps` | an unquoted alias holding a colon and a space, an unquoted lone dash value, an unquoted sprint id (fail) |
| project | `alias-unique` | one alias on two notes among task READMEs and hubs (fail) |
| project | `no-readme` | a task folder without a README (warn) |
| project | `task-location` | a note under the project has `type: task` in its frontmatter and is not `<tasks_root>/<ID>/README.md` (warn). Offenders are paths under the project. Dot folders are not read, and neither is the folder of another index project that sits inside this one |
| project | `topic-tags` | a topic tag on a task maps to no folder under the topics root (warn). The profile's `## Topics` section may hold exceptions as lines `- <tag> -> <folder>` |
| project | `code-doc-map` | a repository in `repos` has no row in the profile's Code to doc map (warn) |
| project | `repos` | a repo of the project, a subproject's included, has a recorded location whose folder is missing (warn). Nothing recorded is ok |
| project | `subprojects` | only for a project with a subproject note. A note whose `type` is not `subproject` (`<name>:type`), one with no repos (`<name>:no-repos`), no docs folder (`<name>:no-docs`), a repo with no row in the profile's Code to doc map (`<name>/<repo>:no-map-row`), a repo whose folder is missing (`<name>/<repo>:missing`) or that has no recorded location (`<name>/<repo>:no-location`), or a repo listed by two subprojects, compared without letter case (`<repo>:twice`) (warn) |
| project | `sprints` | two sprints in progress, one in progress past its end, or a task pointing at a sprint with no note (fail). Not an offender: an open task pointing at the id `sprint next` gives while no sprint is in progress, which is where a close leaves carried tasks. For a project that does not use sprints, the one offender is a sprint note still in progress (warn) |
| project | `unresolved-links` | a note under the project holds a link that resolves to no file (warn) |
| project | `bare-links` | a task README links a repeated file name without a path, such as `[[README]]` (warn) |
| project | `line-endings` | a task README with mixed line endings (warn) |

- `task-location` takes a note's type from frontmatter that opens on the first line and closes.
  The key is `type:` followed by a blank: `type:task` is no property, and frontmatter that
  never closes holds none.
- Not covered: a tasks root spelled in the profile with a letter outside ASCII in another
  Unicode form than the folder has on disk. macOS still finds the tasks through it, and
  `task-location` may then report each of them.
- Not covered: the notes behind a project folder that is a link. `task-location` and
  `unresolved-links` go by the files of the vault, and a link is not followed there.
- A snapshot is a folder `<vault>/.second-brain/snapshots/<name>/` holding `unresolved.txt`,
  `aliases.txt`, `tasks.tsv` (project, id, status), `links.txt` and `doctor.txt`, all read from
  the vault's files.

### Code layout

`bin/second-brain` resolves its own real directory, sources every `scripts/lib/*.sh`, then calls
the function `cmd_<command>` (dashes become underscores) with the remaining arguments. An unknown
command prints usage and exits 5. A library file only defines functions.

Two more library files: `scripts/lib/graph.sh` (`cmd_outline`, `cmd_backlinks`, `cmd_unresolved`,
`cmd_move`, `cmd_rename`; private helpers `sb_graph_*`) and `scripts/lib/platform.sh` (what differs
between systems; private helpers `sb_plat_*`). `cmd_pointer` lives in `scripts/lib/link.sh`.
`scripts/lib/subproject.sh` holds `cmd_subproject` and the subproject helpers, `sb_sub_*` and
`sb_need_sub`; `sb_scaffold_subproject` is in `scaffold.sh`.

Inside the helper every absolute path is in the shell's own form, which on Windows is Git Bash's
`/c/...`. `sb_path_in` turns a path that was read into that form and `sb_path_out` turns one into
the form that is printed. On macOS and Linux both print the path unchanged.

Git Bash's `awk`, `grep` and `sed` read in text mode and drop the CR of every line. On Windows
`platform.sh` defines shell functions with those three names that run the tools in binary mode,
so a CRLF file is read and written byte for byte. They are the one exception to the `sb_*` naming
rule. A library calls the three tools by their plain names, never through `env` or `command`.

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

Every helper function is named `sb_*` and every command `cmd_*`. A library must not redefine a
function another library owns. Also shared: `sb_need_root`, `sb_need_project`, `sb_setting`,
`sb_fm_edit`, `sb_fm_keys`, `sb_section`, `sb_task_files`, `sb_task_scan`, `sb_sprint_current_id`,
`sb_uses_sprints`, `sb_need_sprints`, `sb_fill`, `sb_body_insert`, `sb_note`, `sb_md_files`,
`sb_board_sprint_literal`.

## 8. Templates

`templates/*.tmpl`, filled by the helper (`sb_fill`, awk). Placeholders are `{{UPPER_SNAKE}}`. A
line that holds only an empty placeholder is dropped. A filled file must contain no `{{`.

| Template | Becomes | Placeholders |
|---|---|---|
| `vault-index.md.tmpl` | `<vault>/CLAUDE.md` | none |
| `obsidian-conventions.md.tmpl` | `<vault>/obsidian-conventions.md` | none |
| `vault-claude-hub.md.tmpl` | `<vault>/claude/README.md` | none |
| `project-readme.md.tmpl` | `<project>/README.md` | `PROJECT`, `PROJECT_PATH`, `TASKS_HUB_LINE`, `TOPICS_HUB_LINE`, `SPRINTS_HUB_LINE` |
| `project-claude-hub.md.tmpl` | `<project>/claude/README.md` | `PROJECT`, `PROJECT_PATH` |
| `profile.md.tmpl` | `<project>/claude/profile.md` | `PROJECT`, `PROJECT_PATH`, `TICKET_KEYS`, `TASKS_ROOT`, `TOPICS_ROOT`, `SPRINTS_ROOT` |
| `hub.md.tmpl` | `tasks/README.md`, `docs/README.md`, `sprints/README.md` | `PROJECT`, `PROJECT_PATH`, `HUB_NAME`, `HUB_TITLE`, `HUB_INTRO` |
| `tasks.base.tmpl` | `<project>/tasks/tasks.base` | `TASKS_PATH`, `TASK_DEPTH`, `SPRINT_ID` |
| `task-readme.md.tmpl` | a task README | `ID`, `TITLE`, `TOPIC_TAGS`, `UP_LINK` |
| `task-envs.md.tmpl` | the environment-set additions | `ID`, `ENV` |
| `ticket-description.md.tmpl` | paste-ready ticket text | none |
| `sprint-note.md.tmpl` | a sprint note | `PROJECT`, `SPRINT_ID`, `START`, `END`, `UP_LINK` |
| `subproject.md.tmpl` | `<project>/claude/subprojects/<name>.md` | `PROJECT`, `SUBPROJECT`, `REPOS`, `UP_LINK`, `PROFILE_LINK`, `DOCS_LINK` |
| `subproject-docs.md.tmpl` | `<topics_root>/<name>/README.md` | `PROJECT`, `SUBPROJECT`, `UP_LINK`, `NOTE_LINK` |

Links inside generated notes follow the conventions: a bare `[[Alias]]` does not resolve, so a link
carries the full vault path for a `README.md` and the alias as display text.

## 9. Skills and agents

- Frontmatter: `name` (equals the folder or file name), `description` (one sentence, under 200
  characters, quoted if it contains `: `). Skills run only by name set
  `disable-model-invocation: true`.
- A skill's `SKILL.md` holds the router and the rules needed on every run. Detail for one mode goes
  in a sibling file that is read only in that mode.
- Every skill and agent carries this pointer near the top and does not restate the conventions:
  `Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.`
- Every skill begins its work by running `second-brain context` itself, as its first tool call, and
  resolves the project with `second-brain project`. No skill uses a command that runs at load time:
  a load-time command that fails its permission check aborts the whole skill. When the helper is
  missing the skill says so and stops; it does not guess paths.
- Agents call skills through the Skill tool as `obsidian-dev-second-brain:<name>`.
- **Docs follow production.** A doc is updated only after the change is confirmed deployed to
  production. Confirmed means the user says so, or the change's story shows it: its last environment
  is `done`, or the story is `done` when the project has no environments. The code a doc is checked
  against is the production branch on the remote. Until a change is confirmed, the planned doc
  edits are recorded as pending and not made: under `## Docs to update` in the task README when
  there is a ticket, else as a line starting `pending production:` in the profile's debt file.
- Frontmatter is the source of truth. A status is never inferred from prose. A missing or
  non-standard status is reported as "Needs a status" and never set without asking.
- Notes are moved and renamed with `second-brain move` / `rename`, never `mv`.
- No skill or agent runs `ln`, `mklink` or the Obsidian CLI. The pointer is made with
  `second-brain pointer set` and the links with `second-brain link --apply`.
- Read cheapest first: the helper, then part of a note (`second-brain outline`, then a ranged
  read), then a scoped search, and a whole note last.
- The plugin's hooks are written in shell form, a `command` string with no `args`, so that Claude
  Code runs them through a shell on every system: Git Bash on Windows.

## 10. Writing rules for every file in this repo

- Plain hyphens only. No long dashes, no emojis, no decorative symbols.
- No absolute paths, project names, ticket keys or people's names. Examples use `EX-123`,
  `Example`, `example-api`, `docs/billing/invoices`.
- Do not name any file-sync product.
- Tests may use other made-up keys (`ZZ`, `TWO`) where they need two projects or a clash.
- Short sentences. One idea per bullet.
