# Status overview

Read this in status mode only, after Step 0 of `SKILL.md`. This mode reads and reports. Never edit
a story, set a status or repair a field here.

## Gather the rows

One call: `second-brain board <project> [view]`. Its first line is `source: board` or
`source: files`; both are valid. Every other line is one story:
`id | title | status | sprint | topics | branch | next | envs`.

| The user asks for | Do |
|---|---|
| nothing specific | `second-brain board <project>`. The default view is `Active`: status `planned`, `in-progress` or `in-review` |
| "all", "everything" | view `All` |
| one status | view `All`, keep the rows with that status |
| one ticket | `second-brain task head <ID>`, rendered as one block |
| a ticket key | keep the rows whose id starts with the key |
| a topic | find its tag in `second-brain profile <project> topics`, run `second-brain topic <project> <tag>` (exit 1: none), keep the rows whose folder it lists. A parent tag includes its sub-topics |
| "current sprint", "this sprint" | view `"Current sprint"`. No rows: say "no sprint in progress", or "this project does not use sprints" when the `profile <project> --keys` answer of Step 0 holds `uses_sprints: false` |
| what is waiting on docs | view `All`, keep the rows that reached production (status `done`, or the last entry of `envs` is `done`). One Grep for `^## Docs to update` over those stories' READMEs, read just that section, and list the stories with unticked lines |

- A key or topic filter narrows the `Active` view unless the user also says "all".
- Run `second-brain task head <ID>` only for a row whose title or next is `-`. Never read a whole
  README for an overview.
- No rows in any other view: say so and stop.

## Render

Labelled blocks, one per story, never a table. Six lines in this order, a line of hyphens between
blocks, then a one-line count.

```
ID: EX-123
Summary: <title, one line>
Topics: <topic tags, comma separated, or ->
Status: <status>
Branch: <branch, or none yet>
Current step: <next>
----------------------------------------
ID: EX-130
...
N active, N done/abandoned.
```

- Sort by status (`in-progress`, `in-review`, `planned`, then `done` and `abandoned`), then by id.
- One phrase per field. Extra fields only when the user asks for them: `Sprint:` from the row,
  `Epic:` and `Last updated:` from `second-brain task head <ID>`.
- A row whose `envs` is not `-` is an environment set: ONE block, counted once, with the set's
  status. Under `ID:` add an `Envs:` line built from the cell: `dev:EX-123:done,qa:EX-140:planned`
  becomes `Envs: dev EX-123 done | qa EX-140 planned`. End its Branch line with
  `(first environment's id, shared by the set)` so it does not read as a mistake.

## After the count

List each of these separately, and only when it has entries. None counts as an active story.

- `Needs a status:` a story whose status is missing or is not one of the five. It is never in the
  `Active` view: get the ids from `second-brain board <project> "Needs a status"`, in the same Bash
  call as the main view. In view `All` such rows are listed here, not as blocks. Skip this for a
  one-ticket or one-status request. Never guess the status and never set it here.
- `No README:` a task folder without a `README.md`.
- `Not in tasks/:` a story found outside the tasks root.

Report the last two only when a call in this run surfaced one. Do not scan for them; the
vault-doctor skill runs the full check. Add at most two one-line callouts that matter, such as a
blocking open question or an ambiguous canonical branch. Then offer to expand any story into its
open items and acceptance-criteria checklist, or to add fields. Never expand unasked.
