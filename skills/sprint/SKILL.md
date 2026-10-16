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

- `project` with no flag uses the working directory. Add `--name "<name>"` when the user named a
  project, or `--key EX-123` when all you have is a ticket id.
- `resolved:` is empty or holds several names: show `second-brain projects`, ask, and run the
  block again with `--name`.
- `profile ... sprints` prints this project's own sprint rules. They win over the defaults here.
- `sprint current` prints id, start, end, days left and goal. Exit 1: no sprint is in progress.
- Exit 5 with `does not use sprints`: the profile says `uses_sprints: false`. Say so and stop, in
  every mode. Its stories are read through story-tracker. Sprints come back only when the user
  sets that key to `true` and runs `second-brain scaffold project` again with the same name and
  path; relay the `note:` lines it prints, they name what is left to add by hand.

Stop when the setup is missing. Never guess a path.

- `second-brain` is not found: the plugin is not enabled. Say so and stop.
- `vault: none`, or exit 2: no vault is set up. Say so, offer
  `/obsidian-dev-second-brain:vault-setup`, stop.
- The profile is missing (exit 1 with the vault-setup hint): say so, offer
  `/obsidian-dev-second-brain:vault-setup adopt`, stop. A profile that only lacks a `## Sprints`
  section is fine. The user runs vault-setup by name; do not invoke it from here.

The session id for status notes is `${CLAUDE_SESSION_ID}`.

## The model

- A sprint is one note, named by its end date: `<sprints_root>/2026-01-14.md`. That date is its id.
- A task joins a sprint through one property: `sprint: "2026-01-14"`.
- `carried_from` on a task lists the sprints it was carried out of.
- The board's `Current sprint` view filters on the open sprint's id. `sprint open` rewrites it.
- Nobody maintains a list by hand. The sprint note holds no task list.
- `committed`, `completed` and `carried_over` on the sprint note are counts, not lists.

## open

1. If Step 0 found a sprint in progress, do not open another. Name it, offer close, stop.
2. Run `second-brain sprint next <project>`. It prints the id, start and end that the profile's
   cadence gives (`sprint_anchor_end`, `sprint_length_days`) and writes nothing. Do no date
   arithmetic yourself.
3. Exit 1 there means the profile has no `sprint_anchor_end` yet. Ask the user for the end date
   of this sprint and pass it as `--end`. The helper writes that date as the cadence anchor.
4. Otherwise show the dates and confirm them. In the same round as 3 or 4, ask for the goal when
   none was given.
5. A different end date from the user is off cadence. Confirm it by its date, then pass it as
   `--end`. It does not move the cadence, unless the profile had no anchor.
6. Run `second-brain sprint open <project> [--end <YYYY-MM-DD>] [--goal "<goal>"]`. It creates the
   note, adds the hub line and rewrites the board's sprint id. Exit 6 means a sprint is still in
   progress: go back to 1.
7. Report the note it created. Carried tasks normally point at this sprint already. A
   `re-pointed:` line appears only when the sprint opens on a different date than the one carried
   tasks were pointing at. Report those lines too.
8. A goal given or changed later: `second-brain sprint set <project> goal="<goal>"`.
9. Go to plan.

## plan

1. Plan needs a sprint in progress. With none, offer open.
2. Run `second-brain board <project>` for the Active view. Each row is
   `id | title | status | sprint | topics | branch | next | envs | depends_on`.
3. Show two short groups: in this sprint, and backlog (`sprint` is `-`). Carried tasks are
   already in the sprint. Do not ask about them one by one.
4. Ask which tasks join and which leave.
5. Joining: `second-brain task set <ID> sprint=<id> --project <project>`. Leaving:
   `second-brain task set <ID> sprint= --project <project>`.
6. A task that does not exist yet is created through the story-tracker skill, called with the
   Skill tool as `obsidian-dev-second-brain:story-tracker`. Then set its sprint as in 5. Never
   create a task file from this skill.
7. Run `second-brain board <project> "Current sprint"` and show the list back. Freeze the row
   count with `second-brain sprint set <project> committed=<count>`. When the sprint started
   before today, ask before changing `committed`.

## status

1. Read-only: write nothing. One call: `second-brain board <project> "Current sprint"`.
2. It returns no rows when no sprint is in progress: say "no sprint in progress" and offer to open
   one. No rows with a sprint in progress means it has no tasks yet: offer plan.
3. Head the answer with the sprint id, the goal and the days left from Step 0.
4. Render a short list grouped by status, in this order: in-progress, in-review, planned, done,
   abandoned. One line per task: id, title, then its `next`.
5. Under "Needs attention" call out: a task whose `next` is `-`; a task still `planned` when less
   than half the sprint is left; a row whose status is outside that list, as "Needs a status".
6. A row carries no date. Only when the user asks what has stalled, run
   `second-brain task head <ID>` for the open tasks and compare the date of the newest status note
   with today. Never open a whole README for status.

## close

Read `${CLAUDE_SKILL_DIR}/close.md` and follow it. Read it only in this mode.

## Rules

- Frontmatter is the truth. Never infer a status or a sprint from prose.
- Sprint ids are always quoted in frontmatter. The helper writes them; never retype one by hand.
- A task belongs to at most one sprint. Setting `sprint` replaces the old value.
- Backlog means no `sprint` key. Not an empty value, not a placeholder word.
- A done task keeps the sprint it finished in.
- Nothing is written into the sprint note by hand except under `## Notes`, and there only when
  the user asks. The rest of the note belongs to `sprint open`, `sprint set` and `sprint close`.
- A missing or non-standard status is reported as "Needs a status" and never set without asking.
- Task files belong to the story-tracker skill. This skill touches a task only through
  `second-brain task set`, `second-brain task note` and the sprint commands that move tasks.
- Ask, do not invent: a date, a goal, a ticket id, a reason.
- A request to write a ticket (its summary, description or acceptance criteria, with or without
  an id) goes to the story-tracker skill in `draft` mode. This skill never writes ticket text.
- The helper prints `-` for an empty cell or value. Read it as empty.
