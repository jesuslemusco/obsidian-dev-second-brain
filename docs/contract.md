# Contract

The interfaces every part of this plugin agrees on. Skills and agents call the helper by the
commands below; the helper fills the templates by the placeholders below; notes carry the
frontmatter below. Change this file first, then the code.

## 1. Words and paths

| Word | Meaning |
|---|---|
| vault | The Obsidian vault root, the folder that holds `.obsidian/`. |
| pointer | `~/.claude/second-brain-vault`, a symlink to the vault. The environment variable `SECOND_BRAIN_VAULT` overrides it (tests use this). |
| index | `<vault>/CLAUDE.md`. Always loaded by Claude through an import in `~/.claude/CLAUDE.md`. Holds the only list of projects. |
| conventions | `<vault>/obsidian-conventions.md`. Skills point to it as `~/.claude/second-brain-vault/obsidian-conventions.md`. Its first section, "The short version", is the default read. |
| project | A folder inside the vault, listed in the index by its vault-relative path. |
| profile | `<vault>/<project path>/claude/profile.md`. The one per-project settings note. |
| helper | `bin/second-brain`. On the Bash PATH while the plugin is enabled. |

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
- `Path` is vault-relative, no leading or trailing slash.
- `Keys` are ticket key prefixes, comma separated; may be empty.

## 3. The project

```
<project>/
  README.md
  claude/README.md
  claude/profile.md
  tasks/README.md
  tasks/tasks.base
  tasks/<TICKET-ID>/README.md
  <topics_root>/...            default docs/
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
rows in the same change; the doctor's `code-doc-map` check enforces it.

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

## 7. The helper

`second-brain <command> [args]`. Bash 3.2 and awk only; must run on macOS and Linux. Output is
plain text meant to be read by Claude: short, stable, no colour.

Exit codes: `0` ok, `1` not found, `2` setup missing (no pointer or not a vault), `3` Obsidian CLI
unavailable, `4` ambiguous, `5` bad usage, `6` already exists.

Rules that hold for every command:

- An empty cell or value prints `-`. Callers read `-` as empty.
- Wherever a command takes `<ID>`, the folder id or any alias of the task is accepted. Task commands
  resolve it from the task READMEs on disk, never from Obsidian's index, so a write cannot land on
  the wrong task while the index lags.
- A lookup that finds nothing exits 1 (`find`, `topic`, `search`). A listing that finds nothing
  exits 0 with no rows (`board`, `projects`).
- Writes are file edits, never Obsidian CLI calls. They change only the lines they must and keep the
  file's line endings.
- Environment overrides: `SECOND_BRAIN_VAULT` (vault root), `SECOND_BRAIN_TODAY` (today's date, for
  tests), `SECOND_BRAIN_OBSIDIAN` (CLI binary; `none` disables it), `SECOND_BRAIN_OB_TIMEOUT`.

| Command | Output | Notes |
|---|---|---|
| `help` | the command list | |
| `version` | the plugin version | read from `.claude-plugin/plugin.json` |
| `conventions [section]` | one level-2 section of the vault's conventions note | default section `The short version`; the name is matched case-insensitively; exit 1 when the note or the section is missing |
| `root` | absolute physical path of the vault | exit 2 when the pointer is missing or not a vault |
| `context [--cwd DIR]` | at most 6 `key: value` lines: `vault`, `obsidian` (up, down, missing), `search` (ok, unreliable, unknown), `project`, `project_path`, `sprint` | always exits 0; unknown values print `none`. `sprint` is `off` for a project that does not use sprints. `search` is read from the line `- search: ok ...` or `- search: unreliable ...` in the conventions' `## Limits on this install` block, which `probe` writes |
| `projects` | one TSV row per project: name, path, keys | from the index table |
| `project --name N` / `--key K` / `--cwd DIR` | one TSV row: name, path, keys | `K` is a key prefix or a full id (`EX` or `EX-123`). With no flag it uses the working directory. Exit 1 none, exit 4 several (prints them) |
| `repo <project> [name]` | with no name, one TSV row per repo in the profile's order: name, path, state (`ok`, `missing`, or `unknown` when no location is recorded; path is then `-`). With a name, the path alone | paths are absolute, with `~` expanded. With a name: exit 1 when the name is not in `repos`, when no location is recorded, or when the folder is missing; the message says which |
| `profile <project> --keys` | profile frontmatter as `key: value` lines | exit 1 when the profile is missing, with a hint to run vault-setup adopt |
| `profile <project> <section>` | the body of that level-2 section | section name matched case-insensitively; exit 1 when absent |
| `ob <args...>` | the Obsidian CLI's output | finds the binary (PATH, then the macOS app bundle); exit 3 when it is missing or the app is not running |
| `board <project> [view] [--files]` | first line `source: board` or `source: files`, then one row per task (no rows for `Current sprint` when no sprint is in progress, whatever the source): `id | title | status | sprint | topics | branch | next | envs` | default view `Active` (status planned, in-progress or in-review). Asks Obsidian which notes the view holds, then reads their frontmatter; `--files` or a closed app reads the files directly. `envs` is `-` or `dev:EX-1:done,qa:EX-2:planned`, each name as the note spells it. `title` falls back to the note's first heading when the property is absent |
| `find <ID-or-alias> [--project P]` | vault-relative path(s) | tries the task path, then `obsidian aliases`, then a frontmatter grep; exit 1 none |
| `task head <ID> [--project P]` | at most 15 lines: id, path, title, status, next, sprint, branch, epic, topics, envs, summary line, newest status note | |
| `task set <ID> key=value... [--project P]` | the changed keys, or `no change` | scalar keys only; setting `status` also sets the `status/` tag, and setting `type` the `type/` tag; `key=` removes the key. Exit 5 for a status outside the five, for `jira_id`, for list keys, and for a sprint id on a project that does not use sprints (`sprint=` still removes one) |
| `task tag <ID> add\|remove <tag> [--project P]` | the resulting topic tags | edits the `tags:` list; refuses `type/` and `status/` tags (exit 5) |
| `task alias <ID> add <alias> [--project P]` | the resulting aliases | appends to `aliases:`, quoting when needed; the first alias never changes; exit 6 when the alias already names another task. Renaming a slug-named task to its ticket id (a new first alias and folder name) is not covered yet and is done by hand |
| `task new <ID> [--project P] [--title T] [--topics a,b] [--envs]` | the new README's vault-relative path | `--project` may be left out when the id's key names one project. Exit 6 when the task already has a README or the id is another task's alias; a folder with no README gets one. Exit 5 for `--envs` when the profile lists no environments. A topic with no folder is still written, with a `note:` on stderr |
| `task note <ID> "<text>" [--project P] [--session S]` | the line it added | prepends a dated line under `## Status notes` |
| `topic <project> <tag>` | paths of task READMEs carrying the tag or a sub-tag | |
| `search <project> "<text>" [--in SUBPATH]` | `path:line: text` matches, at most 40 | `obsidian search:context` scoped with `path=`, retried once when empty; grep fallback |
| `sprint current <project>` | TSV: id, start, end, days_left, goal | exit 1 when no sprint is in progress. This and every other `sprint` command exits 5 with `<project> does not use sprints` when the profile says `uses_sprints: false` |
| `sprint next <project>` | TSV: id, start, end | what `sprint open` would create with no `--end`; writes nothing; exit 1 when the profile has no `sprint_anchor_end` |
| `sprint open <project> [--end YYYY-MM-DD] [--goal G]` | the new sprint note's path, then one line per task it re-pointed | refuses (exit 6) while another sprint is in progress. With no `--end` it takes the first cadence end on or after today that has no note. It writes `sprint_anchor_end` only when the profile has none. It rewrites the board's sprint literal, and moves every open task (status not done or abandoned) whose `sprint` id has no sprint note onto the sprint being opened, printing `re-pointed: <ID> from <old> to <new>` |
| `sprint set <project> key=value...` | the changed keys | sets `goal` or `committed` on the sprint in progress; exit 1 when there is none, exit 5 for any other key |
| `sprint close <project> [--carry ID,ID] [--backlog ID,ID] [--abandon ID,ID]` | a summary: `sprint:`, `done:`, `carried:`, `backlog:`, `abandoned:`, `next:` | every open task of the sprint must be named in exactly one list, else exit 5 listing the problem. On tasks it writes `carried_from`, `sprint`, `status` and the tag. On the sprint note it writes the `## Close` lists, `completed`, `carried_over`, `status: done` and the tag. It writes no status notes; the caller adds the reason with `task note`. `next:` is the id carried tasks now point at |
| `scaffold vault [DIR]` | the files it created | never overwrites; creates index, conventions, `claude/README.md`. A file that already exists is reported on stderr as `exists: <path>` |
| `scaffold project <name> --path P [--keys K1,K2] [--use-when TEXT] [--tasks-root R] [--topics-root R] [--sprints-root R] [--no-sprints]` | the files it created | never overwrites (`exists: <path>` on stderr); adds the index row; exit 6 when a key in `--keys` already belongs to another project. The three root flags adopt a project whose notes already live elsewhere: they are written into a new profile and the hubs and board are created under them. `--topics-root .` creates no topics hub. When the profile exists its roots win and the flags are ignored. Exit 5 for a root that leaves the project, repeats another root, or sits inside the tasks root. `--no-sprints` writes `uses_sprints: false` into a new profile, creates no sprints hub and no map line for it, and writes the board without its sprint parts; exit 5 together with `--sprints-root`. An existing profile decides here too: its `uses_sprints` wins over the flag |
| `link [--check \| --apply]` | one row per skill or agent: `name \| kind \| state \| target` | scans `<vault>/claude/` and each index project's `claude/`; never touches links it did not make. Exit 1 when a row is neither `linked` nor `foreign`. `--apply` reports what it did as `note:` lines on stderr |
| `doctor [project] [--json] [--fix]` | one row per check: `result \| check \| scope \| count \| offenders \| fix` | exit 0 when no check fails, 1 when one does, 2 when there is no vault. `--fix` prints `fixed: ...` lines, then the table |
| `snapshot [name]`, `compare [name]` | where the snapshot is, or the differences | stored under `<vault>/.second-brain/snapshots/`. `snapshot` exits 6 when the name exists. `compare` covers unresolved links, aliases, task ids and statuses, and links; it does not compare tags or doctor rows. It exits 0 with `no differences`, and 1 on a difference or when there is no snapshot |
| `probe` | the verdict line, `search: ok (...)` or `search: unreliable (...)` | records it in the conventions' limits block; exit 3 and no change when Obsidian is not up |
| `session-check` | nothing when set up, else one line | always exits 0 |

### link, doctor, snapshot

Library files: `scripts/lib/link.sh` (`cmd_link`, `sb_link_scan`), `scripts/lib/doctor.sh`
(`cmd_doctor`, `cmd_session_check`), `scripts/lib/snapshot.sh` (`cmd_snapshot`, `cmd_compare`,
`cmd_probe`). Their private helpers are named `sb_link_*`, `sb_doc_*` and `sb_snap_*`.

- The link directory is `~/.claude`, or `SECOND_BRAIN_CLAUDE_HOME` when set (tests set it).
- `sb_link_scan` prints one row per item, no header: `name | kind | state | target`. `kind` is
  `skill` or `agent`. `state` is one of `linked`, `missing`, `wrong-target`, `name-mismatch`,
  `duplicate`, `dangling`, `foreign`. `cmd_link --check` prints the same rows.
- A doctor row is `result | check | scope | count | offenders | fix`. `result` is `ok`, `warn`,
  `fail` or `skip` (the check needs Obsidian and it is not up). `scope` is `vault` or a project
  name. `offenders` holds at most five, comma separated, or `-`.
- Doctor check names, exactly as printed:

| Scope | Check | Fails or warns when |
|---|---|---|
| vault | `pointer` | the pointer does not resolve to a vault (fail) |
| vault | `index` | the index is missing or has no Projects table (fail) |
| vault | `conventions` | the conventions note is missing (fail) |
| vault | `import` | no import line for the index in the link directory's `CLAUDE.md` (warn) |
| vault | `links` | a vault-owned skill or agent is missing, wrong-target, dangling, name-mismatch or duplicate (fail) |
| vault | `double-registration` | a link in the link directory points inside the plugin (warn) |
| vault | `obsidian-cli` | the CLI binary is missing or the app is not up (warn) |
| vault | `always-loaded-size` | the index is over 60 lines or the link directory's `CLAUDE.md` over 40 (warn) |
| vault | `descriptions` | a scanned skill or agent description is over 200 characters (warn) |
| vault | `skill-size` | a scanned `SKILL.md` is over 150 lines (warn) |
| project | `profile` | the profile is missing, lacks a contract key, or lacks one of the seven sections (fail) |
| project | `board` | the board file is missing, or a view does not answer (fail; skip the view part when Obsidian is down). `Current sprint` is not asked for when the project does not use sprints |
| project | `index-fresh` | task READMEs on disk differ in number from the rows of view `All` (warn; skip when down) |
| project | `task-frontmatter` | first alias differs from the folder name, or `type` or its tag is missing (fail) |
| project | `needs-a-status` | status missing or not one of the five (warn; never changed) |
| project | `status-tag` | the `status/` tag disagrees with `status` (warn; the only check `--fix` repairs) |
| project | `yaml-traps` | an unquoted alias holding a colon and a space, an unquoted lone dash value, an unquoted sprint id (fail) |
| project | `alias-unique` | one alias on two notes among task READMEs and hubs (fail) |
| project | `no-readme` | a task folder without a README (warn) |
| project | `topic-tags` | a topic tag on a task maps to no folder under the topics root (warn). The profile's `## Topics` section may hold exceptions as lines `- <tag> -> <folder>` |
| project | `code-doc-map` | a repository in `repos` has no row in the profile's Code to doc map (warn) |
| project | `repos` | a repo listed in the profile has a recorded location whose folder is missing (warn). Nothing recorded is ok |
| project | `sprints` | two sprints in progress, one in progress past its end, or a task pointing at a sprint with no note (fail). Not an offender: an open task pointing at the id `sprint next` gives while no sprint is in progress, which is where a close leaves carried tasks. For a project that does not use sprints, the one offender is a sprint note still in progress (warn) |
| project | `unresolved-links` | Obsidian lists unresolved links from notes under the project (warn; skip when down) |
| project | `bare-links` | a task README links a repeated file name without a path, such as `[[README]]` (warn) |
| project | `line-endings` | a task README with mixed line endings (warn) |

- A snapshot is a folder `<vault>/.second-brain/snapshots/<name>/` holding `unresolved.txt`,
  `aliases.txt`, `tasks.tsv` (project, id, status), `links.txt` and `doctor.txt`. A file whose source
  was unavailable holds the single line `unavailable`.

### Code layout

`bin/second-brain` resolves its own real directory, sources every `scripts/lib/*.sh`, then calls
the function `cmd_<command>` (dashes become underscores) with the remaining arguments. An unknown
command prints usage and exits 5. A library file only defines functions.

Shared functions, defined in `scripts/lib/core.sh`, `obsidian.sh` and `projects.sh`:

| Function | Does |
|---|---|
| `sb_die <code> <message>` | prints to stderr, exits |
| `sb_root` | prints the vault root or exits 2 |
| `sb_plugin_root` | prints the repo root |
| `sb_fm_get <file> <key>` | prints a scalar frontmatter value, unquoted |
| `sb_fm_list <file> <key>` | prints a list value, one item per line (block or inline form) |
| `sb_fm_set <file> <key> <value>` | sets or removes (empty value) a scalar key, keeping line endings |
| `sb_ob <args...>` | runs the Obsidian CLI, returns 3 when unavailable |
| `sb_ob_up` | returns 0 when the CLI answers |
| `sb_projects_tsv` | name, path, keys per line |
| `sb_project_path <name>` | prints the vault-relative path or returns 1 |
| `sb_profile <name>` | prints the profile's absolute path or returns 1 |
| `sb_repo_rows <project>` | prints the `repo` rows (name, path, state) for other libraries to reuse |
| `sb_today` | prints today's date; honours `SECOND_BRAIN_TODAY` for tests |

Every helper function is named `sb_*` and every command `cmd_*`. A library must not redefine a
function another library owns. Also shared: `sb_need_root`, `sb_need_project`, `sb_setting`,
`sb_fm_edit`, `sb_fm_keys`, `sb_section`, `sb_task_files`, `sb_task_scan`, `sb_sprint_current_id`,
`sb_uses_sprints`, `sb_need_sprints`, `sb_fill`, `sb_body_insert`, `sb_note`.

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
- Notes are moved and renamed with `second-brain ob move` / `ob rename`, never `mv`.
- Read cheapest first: the helper, then part of a note (`ob outline`, then a ranged read), then a
  scoped search, and a whole note last.

## 10. Writing rules for every file in this repo

- Plain hyphens only. No long dashes, no emojis, no decorative symbols.
- No absolute paths, project names, ticket keys or people's names. Examples use `EX-123`,
  `Example`, `example-api`, `docs/billing/invoices`.
- Do not name any file-sync product.
- Tests may use other made-up keys (`ZZ`, `TWO`) where they need two projects or a clash.
- Short sentences. One idea per bullet.
