# Sprint planning

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Read this in sprint-planning only, after Step 0 of `SKILL.md`. It opens a sprint, picks its
stories and closes it with carry-over.

## Where to start

Run these two as one Bash call:

```bash
second-brain profile "<project>" sprints
second-brain sprint current "<project>"
```

- `profile ... sprints` prints the project's own sprint rules. They win over the defaults here.
  Exit 1 only means the profile has no `## Sprints` section. Carry on.
- `sprint current` prints id, start, end, days left and goal. Exit 1: no sprint is in progress.
- Exit 5 with `does not use sprints`: the profile says `uses_sprints: false`. Say so and stop.
  - Sprints come back only when the user sets that key to `true` and runs
    `second-brain scaffold project` again with the same name and path.
  - Relay the `note:` lines it prints: they name what is left to add by hand.

Then:

- No sprint in progress: `## Open`, then `## Pick`.
- The user asks to close the sprint, or its days left are 0 or less: `## Close`.
- Any other request while a sprint is in progress: `## Pick`.

## The model

- A sprint is one note, named by its end date: `<sprints_root>/2026-01-14.md`. That date is its id.
- A task joins a sprint through one property: `sprint: "2026-01-14"`.
- With `task_layout: status` or `sprint`, every move keeps a child inside a folder named for its
  parent, in the folder it moves to, and a parent's move takes its own files alone.
- Nobody keeps a task list by hand. The sprint note holds none.
- `committed`, `completed` and `carried_over` on the sprint note are counts, not lists.

## Open

1. `sprint current` found a sprint in progress: do not open another. Name it, offer `## Close`, stop.
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
9. Go to `## Pick`.

## Pick

1. Pick needs a sprint in progress. With none, offer `## Open`.
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
     the `sprint_folder` pattern: nothing was written, and the pattern is the user's to fix.
   - A move that fails exits as `second-brain move` does, with the sprint written:
     `second-brain doctor --fix` moves the task once the reason is handled.
6. A task that does not exist yet: start it through the story-track skill, with the Skill tool
   as `odsb:story-track`. It shows the owner the story's text before it writes it. Then set its
   sprint as in 5.
7. Run `second-brain board <project> "Current sprint"` and show the list back.
8. Freeze its row count: `second-brain sprint set <project> committed=<count>`.
   - The sprint started before today: ask before changing `committed`.

## Close

- No sprint in progress: say so and stop.
- Days left above zero: confirm the early close first.

1. List the sprint's tasks in one call: `second-brain board <project> "Current sprint"`.
2. Split the rows by status:
   - Done: `done`.
   - Open: `planned`, `in-progress`, `in-review`.
   - `abandoned`: nothing to do.
   - Any other status is "Needs a status": ask for the real one and set it with
     `second-brain task set <ID> status=<status>` before going on.
3. Ask the user about each open task, with its title and `next` beside it:
   - Carry over, back to backlog, or abandon, and the reason in one phrase.
   - Never decide for them, never suggest a default.
4. Apply the answers in one call. Leave out a flag whose list is empty.
   `second-brain sprint close <project> --carry EX-123,EX-124 --backlog EX-125 --abandon EX-126`
5. Exit 5 names the problem: an open task in no list, or in two. Ask about it and run the call
   again.
   - Exit 6, with `task_layout: status`: the folder `abandoned/<ID>` of a task in `--abandon` is
     taken, and nothing was written. Show that folder to the user: it is theirs to move away or
     delete. Then run the call again.
   - Exit 6, with `task_layout: sprint`: the folder a task in `--carry` or `--backlog` moves to is
     taken, or the next sprint's folder is a task, and nothing was written. Show that path to the
     user, as above. Then run the call again.
   - Exit 5 that names the `sprint_folder` pattern, with `task_layout: sprint`: it gives the next
     sprint no folder name, and nothing was written. The pattern in the profile is the user's to
     fix. Then run the call again.
6. The same call closes the sprint note. Do not edit it, as `## Rules` below says.
   - With `task_layout: status`, the call also moves each task in `--abandon` into `abandoned/`.
     After the six summary lines it prints each moved task's new README path and its `links:` lines.
   - With `task_layout: sprint`, it moves each task in `--carry` to the next sprint's folder and
     each in `--backlog` into `backlog/`, and prints their paths the same way. A done or abandoned
     task, and one in `--abandon`, stays in the closed sprint's folder.
   - In both, a child goes into a folder named for its parent in the folder it moves to, and a
     parent moves its own files alone, leaving its children where they are.
   - A move that fails is named on stderr, and the call exits with its code. The sprint is closed
     all the same: never run the call again. Tell the user the task and the reason:
     `second-brain doctor --fix` moves it to `abandoned/` once the reason is handled.
     In a sprint project it moves it to the next sprint's folder, or `backlog/`, instead.
7. Add one status note per touched task, with the reason:
   `second-brain task note <ID> "<text>" --project <project> --session <session id>`
   - carry: `Carried from 2026-01-14 to 2026-01-28: <reason>`. The second id is the summary's
     `next:` line.
   - backlog: `Back to backlog at the close of 2026-01-14: <reason>`
   - abandon: `Abandoned at the close of 2026-01-14: <reason>`
8. Run `second-brain profile <project> --keys` and read `achievements_skill`.
   - `-`: skip this step.
   - A skill name: invoke it with the Skill tool by that name. Hand it the sprint note,
     `<project_path>/<sprints_root>/<id>.md`, and the README path of each task on the `done:` line.
   - The session does not offer that skill: say so and go on.
9. `task_layout: archive` in that answer, and a `done:` or `abandoned:` line that is not `-`: ask
   once whether to archive those tasks now. Otherwise move nothing.
   - Yes: run `second-brain task archive <ID> --project <project>` for each. Exit 6 means it is
     archived already.
   - No: move nothing. `second-brain doctor --fix` archives each one when it is due by
     `archive_after_days`.
   - Never archive a task without that yes.
10. Report the summary: done, carried, backlog, abandoned.
    - Under done, list the tasks whose docs still wait. Run
      `second-brain task docs <done ids> --project <project>` with the ids of the `done:` line.
    - Skip that when `done:` is `-`.
    - Recommend the `docs-keeper` agent for those tasks.
    - Do not start it here: the close only reports.
    - Offer to open the next sprint, as `## Open` says.
11. Carried tasks point at the `next:` id before that sprint's note exists. That is expected.
    Opening the next sprint fixes it: never re-point them by hand.

## Rules

- Frontmatter is the truth. Never infer a status or a sprint from prose.
- Sprint ids in frontmatter are always quoted. The helper writes them: never retype one by hand.
- A task belongs to at most one sprint. Setting `sprint` replaces the old value.
- Backlog means no `sprint` key: not an empty value, not a placeholder word.
- A done task keeps the sprint it finished in.
- Write into the sprint note by hand only under `## Notes`, and only when the user asks.
  `sprint open`, `sprint set` and `sprint close` write the rest.
- Report a missing or non-standard status as "Needs a status". Never set one without asking.
- Task files belong to the story-track skill. Never create one from this workflow.
- This workflow touches a task only through `second-brain task set`, `second-brain task note`, the
  sprint commands that move tasks and, after a yes at close, `second-brain task archive`.
