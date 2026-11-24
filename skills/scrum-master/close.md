# Sprint close

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Read this in close mode only, after Step 0 of `SKILL.md`.

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
6. The same call closes the sprint note. Do not edit it, as `## Rules` in `SKILL.md` says.
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
    - Offer to open the next sprint.
11. Carried tasks point at the `next:` id before that sprint's note exists. That is expected.
    Opening the next sprint fixes it: never re-point them by hand.
