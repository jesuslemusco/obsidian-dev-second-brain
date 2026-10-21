# Guide

What the plugin ships, how a vault is laid out, what differs on Windows, how to work on the plugin
itself, and how a release is made. The short version is in the [README](../README.md); every helper
command and note format is in the [contract](contract.md).

## What you get

| Piece | Kind | Does |
|---|---|---|
| `story-tracker` | skill | Writes ticket text, and keeps one README per ticket in the vault: draft, start, update, recall, or list what is active. |
| `sprint` | skill | Open a sprint, plan it, show its status, close it and carry work over. |
| `vault-setup` | skill | Set up a vault, add a project, adopt an existing project, register your own skills. |
| `vault-doctor` | skill | Check the vault and the registration against the standard. |
| `scrum-master` | agent | Runs the sprint cadence across projects through `sprint` and `story-tracker`. |
| `docs-keeper` | agent | Keeps a project's docs in step with its code. Runs when a ticket is marked done. |
| `second-brain` | command | The helper the skills call: lookups, the task board, task and sprint writes, moving notes with their links, scaffolding. |

## What to say

Claude picks a skill by matching your words against the skill's description. The end-to-end check
proves that each of these requests loads the skill next to it:

| You say | Skill |
|---|---|
| For the Example project: give me summary, description and AC for a new ticket, no id. | `story-tracker` |
| Where does EX-2 stand? | `story-tracker` |
| Standup for the Example project: what is in progress, and what comes next? | `story-tracker` |
| Update EX-2: the sort is merged, move it to in review. | `story-tracker` |
| Open a new sprint for the Mobile project. | `sprint` |
| Check my vault for problems. | `vault-doctor` |

`vault-setup` writes into `~/.claude`, so it runs only when you name it:
`/obsidian-dev-second-brain:vault-setup`. Any skill runs by name the same way.

## Other ways to install

From a local clone:

```
/plugin marketplace add /path/to/obsidian-dev-second-brain
/plugin install obsidian-dev-second-brain@second-brain
```

To try it for one session without installing: `claude --plugin-dir /path/to/obsidian-dev-second-brain`.

## How it is laid out

On your machine:

```
~/.claude/second-brain-vault      a link to your vault; the only per-machine setting
~/.claude/CLAUDE.md               one import line for the vault index
```

In the vault:

```
CLAUDE.md                         the index: how to use the vault, and the list of projects
obsidian-conventions.md           the rules: note metadata, topic tags, links, searching
claude/                           your own global skills and agents
claude/pull-request.md            the format of every pull request description Claude writes
<project>/
  README.md
  claude/profile.md               the project's settings, read by every skill and agent
  claude/subprojects/<name>.md    one note per subproject, when the project has several repos
  tasks/<TICKET-ID>/README.md     one task per folder
  tasks/tasks.base                the task board (Obsidian Bases)
  docs/                           the project's docs, organised by topic
  sprints/<YYYY-MM-DD>.md         one note per sprint, named by its end date
```

A task says what it is about with topic tags. A topic tag is a folder path under the project's
topics root, lowercased: with the default root `docs/`, the folder `docs/Billing/Invoices` is the
tag `billing/invoices`. A task never lives inside the topic it is about.

An existing project does not have to move its folders. Its profile says where its topics and
sprint notes are.

A project made of several repos, such as an app and its infrastructure, can split them into
subprojects. Each one is a note, `claude/subprojects/<name>.md`, that lists its repos and may set
its own branches and environments; what it leaves empty comes from the profile. Its docs live in
`docs/<name>/`, and its rules in the note's `## Rules` section. The project keeps one ticket key and
one board. Working in a subproject's repo, Claude knows both the project and the subproject. Run
`/obsidian-dev-second-brain:vault-setup subproject <project>` to add one. The board's
`By subproject` view groups the tasks by subproject, and in a subproject's repo the status overview
lists that subproject's tasks.

A rule you ask Claude to save goes where it applies: a rule about one project under `## Rules` in
its `claude/README.md`, or in its subproject's note. Only a rule for every project goes in
`~/.claude/CLAUDE.md`, and Claude asks when it cannot tell. `vault-doctor` warns about a line of
`~/.claude/CLAUDE.md` that names a project.

Sprints are optional per project. `uses_sprints: false` in a project's profile, written by
`vault-setup` when you say the project runs none, leaves out the sprints hub and the board's
`Current sprint` view; its stories are tracked by status alone.

A task can say which tasks it waits on. `second-brain task dep EX-2 add EX-1` writes a link to
EX-1 in the `depends_on` list of EX-2. The board shows the list in its `Depends on` column, the
status overview flags a task in progress that waits on one not done, and the doctor warns about a
link to no task and about tasks that wait on each other in a ring.

The tasks folder can stay short. `task_layout: archive` in a project's profile lets
`second-brain task archive EX-1` move a done or abandoned task, once, to
`tasks/archive/<year>/EX-1/`. Its links follow it, and every command still finds it by its id.
With `task_layout: flat`, the default, no task ever moves. The doctor names a done task still in
the live folder `archive_after_days` days after its last status note or its sprint's end, 14 by
default, and `second-brain doctor --fix` archives it. It never moves an open task.

## On Windows

Claude Code runs its Bash tool through Git Bash, which comes with Git for Windows, and so does the
helper. PowerShell alone is not enough.

- The links are directory junctions, which need no administrator rights and no Developer Mode.
- A junction cannot lead to a single file, so a vault's or a project's agents are linked as one
  folder. Every `.md` file in a `claude/agents` folder is then seen by Claude Code.
- A junction needs a folder on a local drive. A vault on a network share cannot be linked.
- Absolute paths are printed as `C:/...`, and one you give may use backslashes. Paths inside the
  vault always use forward slashes, and so does a repository location in a project's profile.

## Why it is cheap to run

- The always-loaded text is one short index. The rules live in one note that is read on demand.
- Each skill is a short core plus one file per mode. Only the mode in use is read.
- The helper returns the whole task board in one call, a note's frontmatter in one call, and a
  note's outline with line numbers, so a section is read instead of a file.
- A search prints at most forty lines, three per note, the ones that hold the most of the words.

## What it does not do

- It does not call Obsidian. Obsidian is where you read the vault; the helper works on the files.
- It does not talk to your ticket tracker or to any live system. It needs no credentials.
- It does not move or rename existing notes unless you ask, and then it rewrites the links to them
  in the vault's notes. A `.canvas` or `.base` file that mentions a moved note is named, not edited.
- It supports one vault per machine.

## Development

```
bash scripts/test.sh          builds a scratch vault and checks every helper command
bash scripts/test-link.sh     checks the pointer and link registration on a scratch vault
bash scripts/test-graph.sh    checks outline, backlinks, unresolved, move and rename
bash scripts/test-doctor.sh   checks every doctor check on a scratch vault
bash scripts/test-snapshot.sh checks snapshot and compare
bash scripts/leak-check.sh    fails if a generic file carries a home path or a session id
claude plugin validate . --strict
```

The suites run on Linux, macOS and Windows for every pull request to `main`. On Windows they
build symlinks as fixtures, which takes Developer Mode or an elevated shell; using the plugin
takes neither.

`scripts/e2e-claude.sh` runs Claude Code itself against a scratch vault, on a Linux and a Windows
runner. It costs API usage, so the `e2e` workflow runs only when started from the Actions tab. It
asks each request under [What to say](#what-to-say) and fails when one does not load its skill.
A request that fails is fixed in the skill's `description`, in the user's words, not in the
request.

`docs/contract.md` is the interface every part agrees on: helper commands, note frontmatter,
template placeholders. Change it first, then the code.

## Releases

Claude Code updates an installed plugin only when `version` in `.claude-plugin/plugin.json`
changes. Two different copies of the plugin that say the same `version` look the same to it, so
the people who have the older copy never get the newer one. That is why `version` changes in one
place only, at the end of a release.

- Feature branches merge into a `release/<version>` branch, such as `release/0.3.0`.
- One pull request takes the release branch into `main`.
- Neither a feature branch nor the release branch changes `version`.
- After that pull request is merged, one commit on `main` sets `version` in
  `.claude-plugin/plugin.json` and dates the changelog section: `## 0.3.0 - unreleased` becomes
  `## 0.3.0 - 2026-10-21`, with the release date. Tag that commit `v<version>`, as in
  `git tag v0.3.0`, and push the tag. This is the only commit that changes `version`.
- Every release has a section in `CHANGELOG.md`, written as the feature branches merge.

A user updates with the steps in the [README](../README.md#update).
