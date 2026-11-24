# Sprint open

Read this in open mode only, after Step 0 of `SKILL.md`.

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
9. Go to pick: read `pick.md`, at the path `## Modes` in `SKILL.md` gives.
