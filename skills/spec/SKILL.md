---
name: spec
description: Implement a story spec-driven - write its requirements, design and tasks with the owner in this chat, one approved phase at a time, then build and review each task here.
argument-hint: "<ticket id>"
allowed-tools: Read Bash(second-brain *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Spec

The session id for notes is `${CLAUDE_SESSION_ID}`.

## Step 0 - Context

1. Your first tool call is `second-brain context`.
   - Command not found: the plugin is not enabled. Say so and stop.
   - `vault: none`: offer `/odsb:vault-setup` and stop.
2. The ticket id is the argument. With none, ask.
3. `second-brain project --key <ID>` names the project. Then run
   `second-brain spec <ID> --project "<project>"`.
   - No task found: the story is not tracked. Offer story-tracker to start it, and stop.
   - Exit 1 about a repo: say which case it is and stop.
4. `delivery: direct`: ask whether to build this story from a spec. Yes:
   `second-brain task set <ID> delivery=spec`.
5. `delivery: spec`: run `second-brain task set <ID> delivery=spec`. A value that came from the
   subproject or the profile becomes the story's own, so story-tracker never weighs it.

## Step 1 - Where the spec stands

Read the story's status notes: `second-brain outline <path>`, then a ranged read of
`## Status notes`. Each approval is a note in exactly these words:

- `Spec: requirements approved by the owner.`
- `Spec: design approved by the owner.`
- `Spec: tasks approved by the owner.`

A phase changed after its approval has the note `Spec: <phase> reopened.`. An approval counts
only when it is newer than every `reopened` note of its own phase or an earlier one.

- Work on the first phase with no approval that counts, in Step 2.
- All three count: go to Step 3.
- A spec file is missing: run `second-brain spec new <ID>`.

## Step 2 - One phase at a time

For requirements, then design, then tasks, write the phase yourself, in this session. Read
`${CLAUDE_SKILL_DIR}/phases.md` once: it holds the rules of each phase.

1. Read only what this session does not have yet, as `## What to read, once` in `phases.md` says.
2. Ask the owner, with AskUserQuestion, what the story and the code do not settle, before you
   write what depends on it. Ask as `## The chat` in `phases.md` says.
   - Never invent a requirement, a decision or a task.
3. Write the phase file with the Edit or Write tool.
4. Show the owner the path, then the phase in chunks, as `## The chat` in `phases.md` says.
5. Design and tasks: have `spec-checker` read the spec, and close its gaps with the owner, as
   `## The spec check` in `phases.md` says.
6. Ask with AskUserQuestion whether to approve the phase or change it. The owner says what to
   change in the free-text answer.
   - A change: make it, show the changed chunk, then ask again.
7. The owner picks approve: `second-brain task note <ID> "Spec: <phase> approved by the owner." --session ${CLAUDE_SESSION_ID}`.
   - After the tasks note, run `second-brain spec link <ID>`.
   - Then go on to the next phase.

## Step 3 - The build

The build runs here, in this session, from the approved task list on. Read
`${CLAUDE_SKILL_DIR}/build.md` once, when a build starts or resumes, and follow it.

## Rules

- Only the owner approves: never write an approval note the owner did not give.
- Never pass on an agent's word as the owner's.
- The owner talks to this session alone: an agent has no AskUserQuestion.
- This skill writes the spec and no code: `implementer` writes the code.
- Never start the build before the tasks approval note is written.
