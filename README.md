# obsidian-dev-second-brain

A Claude Code plugin that makes an Obsidian vault the place where a developer's work is tracked:
stories, sprints and project docs. It ships skills and agents that work for any project, and a
helper that asks Obsidian's own index instead of reading whole files.

The plugin holds no project data. Your vault does.

## What you get

| Piece | Kind | Does |
|---|---|---|
| `story-tracker` | skill | One README per ticket in the vault: start, update, recall, or list what is active. |
| `sprint` | skill | Open a sprint, plan it, show its status, close it and carry work over. |
| `vault-setup` | skill | Set up a vault, add a project, adopt an existing project, register your own skills. |
| `vault-doctor` | skill | Check the vault and the registration against the standard. |
| `scrum-master` | agent | Runs the sprint cadence across projects through `sprint` and `story-tracker`. |
| `docs-keeper` | agent | Keeps a project's docs in step with its code. |
| `second-brain` | command | The helper the skills call: lookups, the task board, task and sprint writes, scaffolding. |

## Requirements

- Claude Code.
- Obsidian 1.12 or later, with its command line interface turned on (Settings, General). The
  helper falls back to reading files when Obsidian is closed.
- macOS or Linux. The setup relies on symlinks.

## Install

```
/plugin marketplace add <owner>/obsidian-dev-second-brain
/plugin install obsidian-dev-second-brain@second-brain
```

From a local clone instead:

```
/plugin marketplace add /path/to/obsidian-dev-second-brain
/plugin install obsidian-dev-second-brain@second-brain
```

To try it for one session without installing: `claude --plugin-dir /path/to/obsidian-dev-second-brain`.

## The ten-minute path

1. Open your vault in Obsidian.
2. In Claude Code, run `/obsidian-dev-second-brain:vault-setup init` and give it the vault folder.
   It creates the vault index, the conventions note and a pointer on your machine.
3. Run `/obsidian-dev-second-brain:vault-setup project <name>` to add a project.
4. Ask Claude to start tracking a ticket. `story-tracker` creates the task and it shows on the board.
5. Run `/obsidian-dev-second-brain:vault-doctor` whenever you want the setup checked.

## How it is laid out

On your machine:

```
~/.claude/second-brain-vault      a symlink to your vault; the only per-machine setting
~/.claude/CLAUDE.md               one import line for the vault index
```

In the vault:

```
CLAUDE.md                         the index: how to use the vault, and the list of projects
obsidian-conventions.md           the rules: note metadata, topic tags, links, searching
claude/                           your own global skills and agents
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

## Why it is cheap to run

- The always-loaded text is one short index. The rules live in one note that is read on demand.
- Each skill is a short core plus one file per mode. Only the mode in use is read.
- The helper returns the whole task board in one call, a note's frontmatter in one call, and a
  note's outline with line numbers, so a section is read instead of a file.

## What it does not do

- It does not talk to your ticket tracker or to any live system. It needs no credentials.
- It does not move or rename existing notes unless you ask, and then it does it through Obsidian so
  links are rewritten.
- It supports one vault per machine.
- Windows is not supported.

## Development

```
bash scripts/test.sh          builds a scratch vault and checks every helper command
bash scripts/test-link.sh     checks symlink registration on a scratch vault
bash scripts/test-doctor.sh   checks every doctor check on a scratch vault
bash scripts/test-snapshot.sh checks snapshot, compare and probe
bash scripts/leak-check.sh    fails if a generic file carries a home path or a session id
claude plugin validate . --strict
```

`docs/contract.md` is the interface every part agrees on: helper commands, note frontmatter,
template placeholders. Change it first, then the code.

## Licence

MIT. See `LICENSE`.
