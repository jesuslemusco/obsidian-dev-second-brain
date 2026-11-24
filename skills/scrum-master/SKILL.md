---
name: scrum-master
description: Plan an epic and its stories, or one story, for the owner to approve, and run a project's sprint cadence from the Obsidian vault - open, plan, daily status, close and carry over.
argument-hint: "[plan | open | pick | status | close | done | hygiene] [project]"
allowed-tools: Read Bash(second-brain *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Scrum master

You plan the work with the owner and run the sprint: open it, pick its stories, track them, close
it and carry over what is left.

The first argument is the mode, the second the project. With no mode, take it from the request.
With nothing to go on, run status.

## Modes

After Step 0, read the file of the mode in use, and only that file.

| Mode | When | Read |
|---|---|---|
| plan | An epic and its stories, or one story, to draft and write once the owner approves | `${CLAUDE_SKILL_DIR}/plan.md` |
| open | A new sprint | `${CLAUDE_SKILL_DIR}/open.md` |
| pick | Plan the sprint: which tasks join it and which leave | `${CLAUDE_SKILL_DIR}/pick.md` |
| status | The sprint's status, or a daily status of one project or of every project | `${CLAUDE_SKILL_DIR}/status.md` |
| close | The sprint ends: close it and carry over what is left | `${CLAUDE_SKILL_DIR}/close.md` |
| done | A story finished: its update and its achievement | `${CLAUDE_SKILL_DIR}/done.md` |
| hygiene | A health pass on one project | `${CLAUDE_SKILL_DIR}/hygiene.md` |

- A request to plan the sprint is pick. A request to plan an epic, a feature or a story is plan.
- plan also reads story-tracker's `${CLAUDE_PLUGIN_ROOT}/skills/story-tracker/create.md`.
- One mode leads to another only where its file says so. Then read that file too.

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
  - A status of every project needs no project: go to status.
- `profile ... sprints` prints the project's own sprint rules. They win over the defaults here.
- `sprint current` prints id, start, end, days left and goal. Exit 1: no sprint is in progress.
- Exit 5 with `does not use sprints`: the profile says `uses_sprints: false`.
  - open, pick and close: say so and stop.
  - status reports the project's stories from the Active view. plan, done and hygiene go on.
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

## The model

- A sprint is one note, named by its end date: `<sprints_root>/2026-01-14.md`. That date is its id.
- A task joins a sprint through one property: `sprint: "2026-01-14"`.
- A task whose `epic` names another task is a child of that parent story. Call a parent story by
  the project's word: `feature` when `second-brain profile <project> --keys` prints
  `parent_label: feature`, else `epic`. The key stays `epic`.
- With `task_layout: status` or `sprint`, every move keeps a child inside a folder named for its
  parent, in the folder it moves to, and a parent's move takes its own files alone.
- Nobody keeps a task list by hand. The sprint note holds none.
- `committed`, `completed` and `carried_over` on the sprint note are counts, not lists.

## Rules

- Frontmatter is the truth. Never infer a status or a sprint from prose.
- Sprint ids in frontmatter are always quoted. The helper writes them: never retype one by hand.
- A task belongs to at most one sprint. Setting `sprint` replaces the old value.
- Backlog means no `sprint` key: not an empty value, not a placeholder word.
- A done task keeps the sprint it finished in.
- Write into the sprint note by hand only under `## Notes`, and only when the user asks.
  `sprint open`, `sprint set` and `sprint close` write the rest.
- Report a missing or non-standard status as "Needs a status". Never set one without asking.
- A new story is written only in plan, once the owner approves its text. Any other change to a
  story goes through the story-tracker skill, with the Skill tool as `odsb:story-tracker`.
- This skill touches a task only through `second-brain task set`, `second-brain task note`, the
  sprint commands that move tasks, the writes of plan once the owner approves and, after
  a yes at close, `second-brain task archive`.
- Ask, do not invent: a date, a goal, a ticket id, a reason, acceptance criteria, a result.
- Never ask the user for a date a file already holds.
- Ask with AskUserQuestion. With none, as in a subagent: end the reply with the numbered
  questions, and write nothing that waits on their answers.
- A request for ticket text to paste into the tracker, with or without an id, goes to the
  story-tracker skill in `draft` mode.
- The session does not offer a skill this one hands work to: say so and stop, unless its step
  says to go on.
- Write absolute dates and plain hyphens. Turn "this sprint" or "last week" into real dates.
- The helper prints `-` for an empty cell or value. Read it as empty.
