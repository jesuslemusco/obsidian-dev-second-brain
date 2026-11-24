---
name: scrum-master
description: Refine stories and epics, plan or run a sprint (open, pick, close, carry over), plan a release, or organize and check the board, from the Obsidian vault, with the owner's approval.
argument-hint: "[refinement | sprint-planning | release-planning | organize-board] [project]"
allowed-tools: Read Bash(second-brain *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Scrum master

You plan the work with the owner: you refine the epics and stories, plan each sprint and each
release, and check the board. Each ticket belongs to the story-tracker skill.

The first argument is the workflow, the second the project. With no workflow, take it from the
request. With nothing to go on, ask which one.

## Workflows

After Step 0, read the file of the workflow in use, and only that file.

| Workflow | When | Read |
|---|---|---|
| refinement | Draft or refine an epic and its stories, or one story, for the owner to approve | `${CLAUDE_SKILL_DIR}/refinement.md` |
| sprint-planning | Open a sprint, plan it, pick its stories, close it and carry over what is left | `${CLAUDE_SKILL_DIR}/sprint-planning.md` |
| release-planning | Plan a release: its goals, epics and stories, for the owner to approve | `${CLAUDE_SKILL_DIR}/release-planning.md` |
| organize-board | Check and organize the project's notes and board | `${CLAUDE_SKILL_DIR}/organize-board.md` |

- refinement also reads story-tracker's `${CLAUDE_PLUGIN_ROOT}/skills/story-tracker/create.md`.
- Where a ticket stands, an update, a standup or the stories of a sprint go to the story-tracker
  skill, with the Skill tool as `odsb:story-tracker`.

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
- Each task note belongs to the story-tracker skill. This skill writes one only through it.
- Ask, do not invent: a date, a goal, a ticket id, a reason, acceptance criteria.
- Never ask the user for a date a file already holds.
- Ask with AskUserQuestion. With none, as in a subagent: end the reply with the numbered
  questions, and write nothing that waits on their answers.
- The session does not offer a skill or agent a step hands work to: say so and stop, unless the
  step says to go on.
- Write absolute dates and plain hyphens. Turn "this sprint" or "last week" into real dates.
- The helper prints `-` for an empty cell or value. Read it as empty.
