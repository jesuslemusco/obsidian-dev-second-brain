# Daily status

Read this in status mode only, after Step 0 of `SKILL.md`. Status writes nothing.

## One project

1. Run one call: `second-brain board <project> "Current sprint"`.
   - A project that does not use sprints: run `second-brain board <project>`, the Active view,
     instead. Show it as in 4 and 5, with no sprint line.
2. It returns no rows when no sprint is in progress: say "no sprint in progress" and offer open.
   - No rows with a sprint in progress: it has no tasks yet. Offer pick.
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

- Every active story, in the sprint or not: `second-brain board <project>`, the Active view.
- One ticket: the story-tracker skill.

## Every project

- Run `second-brain projects`, then `second-brain sprint current <project>` for each row.
- A sprint in progress: `second-brain board <project> "Current sprint"`.
- No sprint, or a project that does not use sprints: `second-brain board <project>`, the Active
  view.
- Give one short block per project: sprint id, days left, tasks by status, what needs attention.
- Read no README.

## A story moves

- The user reports a decision, a root cause, a status change or a validation: update the story
  through the story-tracker skill.
- The board says what is open and what is done. Keep no tally of your own.
