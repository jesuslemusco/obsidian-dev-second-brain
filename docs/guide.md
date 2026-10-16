# Guide

What the plugin ships, how a vault is laid out, what differs on Windows, and how to work on the
plugin itself. The short version is in the [README](../README.md); every helper command and note
format is in the [contract](contract.md).

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

Sprints are optional per project. `uses_sprints: false` in a project's profile, written by
`vault-setup` when you say the project runs none, leaves out the sprints hub and the board's
`Current sprint` view; its stories are tracked by status alone.

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
runner. It costs API usage, so the `e2e` workflow runs only when started from the Actions tab.

`docs/contract.md` is the interface every part agrees on: helper commands, note frontmatter,
template placeholders. Change it first, then the code.
