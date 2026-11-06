---
name: spec
description: Implement a story spec-driven - write its requirements, design and tasks with the owner in this chat, one approved phase at a time, then have spec-lead build and review each task.
argument-hint: "<ticket id>"
allowed-tools: Read Bash(second-brain *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Spec

A spec-driven story is built in two halves. The spec is written here, in the owner's session:
you draft each phase with the context this session already has, ask the owner as you go, and the
owner approves it or says what to change. The build runs in `spec-lead` once the owner has
approved the task list: it builds and reviews one task at a time and stops only on a task it
cannot get through review. The owner talks to this session alone. An agent has no
AskUserQuestion, so it can never ask the owner anything.

The session id for notes is `${CLAUDE_SESSION_ID}`.

## Step 0 - Context

1. Your first tool call is `second-brain context`. Command not found: the plugin is not enabled;
   say so and stop. `vault: none`: offer `/obsidian-dev-second-brain:vault-setup` and stop.
2. The ticket id is the argument; with none, ask. `second-brain project --key <ID>` names the
   project. Then run `second-brain spec <ID> --project "<project>"`.
   - No task found: the story is not tracked. Offer story-tracker to start it, and stop.
   - Exit 1 about a repo: say which case it is and stop.
3. `delivery: direct`: ask whether to build this story from a spec. Yes:
   `second-brain task set <ID> delivery=spec`.

## Step 1 - Where the spec stands

Read the story's status notes: `second-brain outline <path>`, then a ranged read of
`## Status notes`. Each approval is a note in exactly these words:

- `Spec: requirements approved by the owner.`
- `Spec: design approved by the owner.`
- `Spec: tasks approved by the owner.`

A phase changed after it was approved has a note `Spec: <phase> reopened.`. An approval counts
only when it is newer than every `reopened` note of its own phase or an earlier one. The first
phase with no approval that counts is the one to work on. All three count: go to Step 3. A spec
file is missing: `second-brain spec new <ID>` lays out the empty templates.

## Step 2 - One phase at a time

For requirements, then design, then tasks, write the phase yourself, in this session. Read
`${CLAUDE_SKILL_DIR}/phases.md` once: what to read and the rules of each phase.

1. Read only what this session does not have yet, as `phases.md` says: the story, the approved
   phases, the code the story touches and the repo's validation steps. Never the whole repo.
2. Ask the owner, with AskUserQuestion, what the story and the code do not settle, before you
   write what depends on it. Never invent a requirement, a decision or a task.
3. Write the phase file with the Edit or Write tool.
4. Show the owner the path and the phase in short: each requirement with its checks, each design
   decision, or each task with the requirements it meets.
5. Ask with AskUserQuestion whether to approve the phase or change it; the owner says what to
   change in the free-text answer. Approve only when the owner picks it. A change: make it, then
   go back to item 4.
6. Approved: `second-brain task note <ID> "Spec: <phase> approved by the owner." --session ${CLAUDE_SESSION_ID}`.
   After the tasks note, run `second-brain spec link <ID>`: it links the story's Approach,
   Changes and Verification to the spec, so the story does not repeat it. Then the next phase.

## Step 3 - Ready to build

1. The branch, as the branch check in story-tracker's `SKILL.md` says: the story's `branch` from
   `second-brain task head <ID>`, in the repo `spec <ID>` names, at the path
   `second-brain repo <project> <repo>` prints. No branch yet: ask, then create it from the base
   branch, named by `branch_pattern`, and record it with `second-brain task set <ID> branch=<branch>`.
2. The repo must be on that branch with nothing uncommitted. On another branch: ask, then
   `git -C "<path>" switch <branch>`. Never stash or discard the owner's changes: ask them to.
3. With `spec_home: repo` the spec files are in the repo: commit them on the story's branch,
   `git -C "<path>" add spec/<ID>` and `git -C "<path>" commit -m "<ID>: spec"`, so the tree is
   clean for the build.
4. `second-brain validation <project> <repo>` must print the repo's steps, with no `<...>` text
   left. Otherwise offer `/obsidian-dev-second-brain:vault-setup validation <project>` and stop.
5. `second-brain task set <ID> status=in-progress next="spec-lead builds the approved tasks"`.
6. Launch `obsidian-dev-second-brain:spec-lead` with the Agent tool. Its prompt: the project, the
   ticket id, the session id `${CLAUDE_SESSION_ID}`, and `The owner approved the task list.`
   Keep its agent id, and wait for its report.

## Step 4 - When spec-lead stops

- It stopped on a task, or on the baseline: show the owner its report and ask what to do. Resume
  `spec-lead` with SendMessage and the owner's answer as written. In a new session its agent id
  is gone: launch it again as Step 3 says. It finds where the build stands from the `Build:`
  notes on the story.
- The spec needs a change: write `Spec: <phase> reopened.` as a status note, then go back to Step
  2 for that phase. The phases after it are approved again too, and only then does the build go on.
- It finished: show the task list, one commit per task and the final validation result. The story
  is `in-review`; story-tracker takes it from there.

## Rules

- Only the owner approves. Never write an approval note the owner did not give, and never pass
  on an agent's word as theirs.
- This skill writes the spec and no code. `spec new` lays out the empty templates, the skill
  fills them, and `implementer` writes the code. `spec-lead` alone launches `implementer` and
  `reviewer`.
- Never start the build before the tasks approval note is written.
