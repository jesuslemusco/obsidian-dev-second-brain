# Sprint close

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Step 0 of `SKILL.md` has run: the project, the sprint id, the days left and the session id are
known. With no sprint in progress, say so and stop. With days left above zero, confirm the early
close first.

1. One call for the sprint's tasks: `second-brain board <project> "Current sprint"`.
2. Split the rows. Done: `done`. Open: `planned`, `in-progress`, `in-review`. Already `abandoned`:
   nothing to do. Any other status is "Needs a status": ask for the real one and set it with
   `second-brain task set <ID> status=<status>` before going on.
3. For each open task ask the user: carry over, back to backlog, or abandon, and the reason in one
   phrase. Show its title and `next` beside it. Never decide for them, never suggest a default.
4. Apply the answers in one call. Leave out a flag whose list is empty.
   `second-brain sprint close <project> --carry EX-123,EX-124 --backlog EX-125 --abandon EX-126`
   - carry: appends this sprint's id to `carried_from` and moves `sprint` to the next id
   - backlog: removes `sprint`
   - abandon: sets `status: abandoned` and its tag
5. Exit 5 names the problem: an open task in no list, or in two. Ask about it and run the call
   again.
6. The same call finishes the sprint note: the `## Close` lists, `completed`, `carried_over`,
   `status: done` and the tag. Do not edit the note.
7. The call writes no status notes. Add one per touched task, with the reason:
   `second-brain task note <ID> "<text>" --project <project> --session <session id>`
   - carry: `Carried from 2026-01-14 to 2026-01-28: <reason>`. The second id is the `next:` line
     of the summary.
   - backlog: `Back to backlog at the close of 2026-01-14: <reason>`
   - abandon: `Abandoned at the close of 2026-01-14: <reason>`
8. Run `second-brain profile <project> --keys`. If `achievements_skill` names a skill, invoke it
   with the Skill tool by that name. Hand it the sprint note,
   `<project_path>/<sprints_root>/<id>.md`, and the README path of each task on the `done:` line.
   It reads the outcome from those files. If the value is `-`, skip this step. If the session
   does not offer the named skill, say so and go on.
9. Report the summary: done, carried, backlog, abandoned. Under done, list the tasks whose docs
   are still waiting: `second-brain task docs <done ids> --project <project>`, with the ids of the
   `done:` line, prints each task with unticked `- [ ]` lines and its path. If `done:` is `-`, skip
   this. Recommend the `docs-keeper` agent for them.
   Do not start it here: the close only reports. Offer to open the next sprint.
10. Carried tasks now point at the `next:` id before that sprint's note exists. That is expected
    and the doctor does not flag it. The fix is to open the next sprint, never to re-point by hand.
