---
name: sprint
description: Run a project's sprint from the Obsidian vault - open, plan, daily status, close and carry over.
argument-hint: "[open | plan | status | close] [project]"
allowed-tools: Read Bash(second-brain *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Sprint

The first argument is the mode, the second the project. With no mode, take it from the request.
With nothing to go on, run status.

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
  - Say so and stop, in every mode.
  - Its stories are read through story-tracker.
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

## open

1. Step 0 found a sprint in progress: do not open another. Name it, offer close, stop.
2. Run `second-brain sprint next <project>`. It prints the id, start and end the profile's cadence
   gives, and writes nothing.
   - Do no date arithmetic yourself.
3. Exit 1: the profile has no `sprint_anchor_end` yet. Ask the user for this sprint's end date.
   `sprint open` writes it as the cadence anchor.
4. Otherwise show the dates and confirm them.
   - In the same round as 3 or 4, ask for the goal when none was given.
5. A different end date from the user is off cadence. Confirm it by its date. It does not move
   the cadence.
6. Run `second-brain sprint open <project> [--end <YYYY-MM-DD>] [--goal "<goal>"]`.
   - Pass the date from 3 or 5 as `--end`.
   - It creates the note, adds the hub line and rewrites the board's sprint id.
   - Exit 6: a sprint is still in progress. Go back to 1.
   - Exit 6 with `the destination exists: <path>` or `the sprint folder is a task: <path>`, in a
     project with `task_layout: sprint`: the folder a re-pointed task moves to is taken, and
     nothing was written. Show that path to the user: it is theirs to move away or delete. Then
     run the call again.
   - Exit 5 that names the `sprint_folder` pattern: it gives the new sprint no folder name, and
     nothing was written. The pattern in the profile is the user's to fix. Then run the call again.
7. Report the note it created and each `re-pointed:` line it prints.
   - With `task_layout: sprint`, each re-pointed task also moves to the new sprint's folder. After
     the `re-pointed:` lines it prints each moved task's new README path and its `links:` lines.
     A child goes into a folder named for its parent there.
   - A move that fails is named on stderr, and the call exits with its code. The sprint is open
     all the same: never run the call again. Tell the user the task and the reason:
     `second-brain doctor --fix` moves it to the folder of its sprint once the reason is handled.
8. A goal given or changed later: `second-brain sprint set <project> goal="<goal>"`.
9. Go to plan.

## plan

1. Plan needs a sprint in progress. With none, offer open.
2. Run `second-brain board <project>` for the Active view. Each row is
   `id | title | status | sprint | topics | branch | next | envs | depends_on`.
3. Show two short groups: in this sprint, and backlog, where `sprint` is `-`.
   - Carried tasks are in the sprint already. Do not ask about them one by one.
4. Ask which tasks join and which leave.
5. Set each answer:
   - Joining: `second-brain task set <ID> sprint=<id> --project <project>`.
   - Leaving: `second-brain task set <ID> sprint= --project <project>`.
   - With `task_layout: sprint`, each call also moves the task's folder, to the sprint's folder or
     back to `backlog/`, and prints its new README path and its `links:` lines after the keys.
     A child goes into a folder named for its parent there, and its parent's note stays where it
     is. A `removed: <path>` line names the folder named for the parent that it left empty.
   - Exit 6 there, as in open: the destination is taken, or the sprint's folder is a task, and
     nothing was written. Show that path to the user, then set that task again. Exit 5 that names
     the `sprint_folder` pattern: as in open.
   - A move that fails exits as `second-brain move` does, with the sprint written:
     `second-brain doctor --fix` moves the task once the reason is handled.
6. A task that does not exist yet: create it through the story-tracker skill, with the Skill tool
   as `odsb:story-tracker`. Then set its sprint as in 5.
7. Run `second-brain board <project> "Current sprint"` and show the list back.
8. Freeze its row count: `second-brain sprint set <project> committed=<count>`.
   - The sprint started before today: ask before changing `committed`.

## status

Status writes nothing.

1. Run one call: `second-brain board <project> "Current sprint"`.
2. It returns no rows when no sprint is in progress: say "no sprint in progress" and offer open.
   - No rows with a sprint in progress: it has no tasks yet. Offer plan.
3. Head the answer with the sprint id, the goal and the days left from Step 0.
4. Show a short list grouped by status, in this order: in-progress, in-review, planned, done,
   abandoned.
   - One line per task: id, title, then its `next`.
5. Under "Needs attention", call out:
   - a task whose `next` is `-`;
   - a task still `planned` when less than half the sprint is left;
   - a row whose status is outside that list.
6. Only when the user asks what has stalled: run `second-brain task head <ID>` for each open task.
   Compare the date of its newest status note with today.
   - Never open a whole README for status.

## close

Read `${CLAUDE_SKILL_DIR}/close.md` and follow it. Read it only in this mode.

## Rules

- Frontmatter is the truth. Never infer a status or a sprint from prose.
- Sprint ids in frontmatter are always quoted. The helper writes them: never retype one by hand.
- A task belongs to at most one sprint. Setting `sprint` replaces the old value.
- Backlog means no `sprint` key: not an empty value, not a placeholder word.
- A done task keeps the sprint it finished in.
- Write into the sprint note by hand only under `## Notes`, and only when the user asks.
  `sprint open`, `sprint set` and `sprint close` write the rest.
- Report a missing or non-standard status as "Needs a status". Never set one without asking.
- Task files belong to the story-tracker skill. Never create one from this skill.
- This skill touches a task only through `second-brain task set`, `second-brain task note`, the
  sprint commands that move tasks and, after a yes at close, `second-brain task archive`.
- Ask, do not invent: a date, a goal, a ticket id, a reason.
- A request to write a ticket, its summary, description or acceptance criteria, with or without
  an id, goes to the story-tracker skill in `draft` mode. This skill never writes ticket text.
- The helper prints `-` for an empty cell or value. Read it as empty.
