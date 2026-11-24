# Sprint pick

Read this in pick mode only, after Step 0 of `SKILL.md`, or at the end of open. It plans the
sprint: which tasks join it and which leave.

1. Pick needs a sprint in progress. With none, offer open.
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
6. A task that does not exist yet: plan it first, as `plan.md` says. Once it is written, set
   its sprint as in 5.
7. Run `second-brain board <project> "Current sprint"` and show the list back.
8. Freeze its row count: `second-brain sprint set <project> committed=<count>`.
   - The sprint started before today: ask before changing `committed`.
