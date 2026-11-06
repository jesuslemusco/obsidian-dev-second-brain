# Sprint close

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Step 0 of `SKILL.md` has run.

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
6. The same call closes the sprint note. Do not edit it, as `## Rules` in `SKILL.md` says.
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
    - Offer to open the next sprint.
11. Carried tasks point at the `next:` id before that sprint's note exists. That is expected: open
    the next sprint, and never re-point them by hand.
