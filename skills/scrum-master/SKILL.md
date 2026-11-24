---
name: scrum-master
description: Plan a project's sprints and releases from the Obsidian vault - open, plan and close a sprint with carry-over, or plan a release's goals, epics and stories for the owner to approve.
argument-hint: "[sprint-planning | release-planning] [project]"
allowed-tools: Read Bash(second-brain *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Scrum master

You plan the work with the owner: each sprint, and each release with its epics and stories.

The first argument is the workflow, the second the project. With no workflow, take it from the
request. With nothing to go on, ask which one.

## Workflows

After Step 0, read the file of the workflow in use, and only that file.

| Workflow | When | Read |
|---|---|---|
| sprint-planning | Open a sprint, plan it, pick its stories, close it and carry over what is left | `${CLAUDE_SKILL_DIR}/sprint-planning.md` |
| release-planning | Plan a release: its goals, epics and stories, for the owner to approve | `${CLAUDE_SKILL_DIR}/release-planning.md` |

- release-planning also reads story-tracker's
  `${CLAUDE_PLUGIN_ROOT}/skills/story-tracker/create.md`.
- A request to plan an epic or a story is release-planning.
- Where a ticket stands, a standup or the stories of a sprint go to the story-tracker skill.

## Step 0 - Context (every run)

Your first tool call is this block, as one Bash call:

```bash
second-brain context
p="$(second-brain project | cut -f1)"
echo "resolved: $p"
second-brain profile "$p" sprints
second-brain sprint current "$p"
```

- `project` with no flag uses the working directory.
  - The user named a project: add `--name "<name>"`.
  - All you have is a ticket id: add `--key EX-123`.
- `resolved:` is empty or holds several names: show `second-brain projects`, ask, and run the
  block again with `--name`.
- `profile ... sprints` prints the project's own sprint rules. They win over the defaults here.
- `sprint current` prints id, start, end, days left and goal. Exit 1: no sprint is in progress.
- Exit 5 with `does not use sprints`: the profile says `uses_sprints: false`.
  - sprint-planning: say so and stop. release-planning goes on.
  - Sprints come back only when the user sets that key to `true` and runs
    `second-brain scaffold project` again with the same name and path.
  - Relay the `note:` lines it prints: they name what is left to add by hand.

Stop when the setup is missing. Never guess a path.

- `second-brain` is not found: the plugin is not enabled. Say so and stop.
- `vault: none`, or exit 2: no vault is set up. Say so, offer
  `/odsb:vault-setup`, stop.
- Exit 1 with the vault-setup hint: the profile is missing. Say so, offer
  `/odsb:vault-setup adopt`, stop.
- A profile that only lacks a `## Sprints` section is fine.
- The user runs vault-setup by name. Do not invoke it from here.

The session id for status notes is `${CLAUDE_SESSION_ID}`.

## Rules

- A task whose `epic` names another task is a child of that parent story. Call a parent story by
  the project's word: `feature` when `second-brain profile <project> --keys` prints
  `parent_label: feature`, else `epic`. The key stays `epic`.
- Each ticket belongs to the story-tracker skill, with the Skill tool as `odsb:story-tracker`.
  It writes and changes each task note, one ticket at a time.
- Ask, do not invent: a date, a goal, a ticket id, a reason, acceptance criteria.
- Never ask the user for a date a file already holds.
- Ask with AskUserQuestion. With none, as in a subagent: end the reply with the numbered
  questions, and write nothing that waits on their answers.
- A request for ticket text to paste into the tracker, with or without an id,
  goes to the story-tracker skill in `draft` mode.
- The session does not offer a skill this one hands work to: say so and stop, unless its step
  says to go on.
- Write absolute dates and plain hyphens. Turn "this sprint" or "last week" into real dates.
- The helper prints `-` for an empty cell or value. Read it as empty.
