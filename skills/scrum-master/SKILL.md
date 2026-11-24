---
name: scrum-master
description: Use for any question or change on a vault ticket - where it stands, an update, a standup, a draft, ticket text - and to open, plan or close a sprint, plan a release or epic, or organize the board.
argument-hint: "[story-track | sprint-planning | release-planning | organize-board] [project or ticket id]"
allowed-tools: Read Grep Glob Bash(second-brain *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Scrum master

The plugin's skill for the work kept in the vault: each ticket, each sprint, each release and the
board. It has four workflows, one file each.

The first argument is the workflow, the second the project or a ticket id. With no workflow, take
it from the request. A ticket id alone, or any question or change on one ticket, is story-track.

## Workflows

After Step 0, read the file of the workflow in use, and only that file.

| Workflow | When | Read |
|---|---|---|
| story-track | Any question or change on one ticket: where it stands, an update, a standup, a draft, ticket text | `${CLAUDE_SKILL_DIR}/story-track.md` |
| sprint-planning | Open a sprint, plan it, pick its stories, close it and carry over what is left | `${CLAUDE_SKILL_DIR}/sprint-planning.md` |
| release-planning | Plan a release, an epic or a story with the owner, for the owner to approve | `${CLAUDE_SKILL_DIR}/release-planning.md` |
| organize-board | Check and organize the project's notes and board | `${CLAUDE_SKILL_DIR}/organize-board.md` |

A workflow file reads these only when one of its steps names them:

- `${CLAUDE_SKILL_DIR}/story-track-create.md`
- `${CLAUDE_SKILL_DIR}/story-track-status.md`
- `${CLAUDE_SKILL_DIR}/story-track-env-split.md`
- The plugin's templates, such as `${CLAUDE_PLUGIN_ROOT}/templates/ticket-description.md.tmpl`.

## Step 0 - Context (every run)

Run these yourself, before anything else. Chain them in one Bash call where that helps.

1. `second-brain context`.
   - Command not found: the plugin is not enabled. Say so and stop.
   - `vault: none`, or exit 2: no vault is set up. Say so, offer `/odsb:vault-setup`, stop.
2. Resolve the project, first match wins: the name the user gave
   (`second-brain project --name <N>`), the ticket id (`--key EX-123`), else the `project:` line.
   - `none`, exit 1 or exit 4: show `second-brain projects` and ask.
3. `second-brain profile <project> --keys` prints the settings the workflows name.
   - Exit 1: no profile. Say so, offer `/odsb:vault-setup adopt`, stop.

Stop when the setup is missing. Never guess a path. The user runs vault-setup by name: do not
invoke it from here.

The session id for status notes is `${CLAUDE_SESSION_ID}`.

## Rules

- A task whose `epic` names another task is a child of that parent story. Call a parent story by
  the project's word: `feature` when `second-brain profile <project> --keys` prints
  `parent_label: feature`, else `epic`. The key stays `epic`.
- Ask, do not invent: a date, a goal, a ticket id, a reason, acceptance criteria.
- Never ask the user for a date a file already holds.
- Ask with AskUserQuestion. With none, as in a subagent: end the reply with the numbered
  questions, and write nothing that waits on their answers.
- The session does not offer a skill or agent a step hands work to: say so and stop, unless the
  step says to go on.
- Write absolute dates and plain hyphens. Turn "this sprint" or "last week" into real dates.
- The helper prints `-` for an empty cell or value. Read it as empty.
