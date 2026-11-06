# Status overview

Read this in status mode only, after Step 0 of `SKILL.md`. This mode only reads and reports: never
edit a story, set a status or repair a field here.

## Gather the rows

- Get the rows in one call: `second-brain board <project> [view]`.
- Each line is one story:
  `id | title | status | sprint | topics | branch | next | envs | depends_on`.
- `depends_on` is `-`, or each task the story depends on with that task's status:
  `EX-1:done,EX-2:planned`. The status is `missing` when the link leads to no note.
- In a subproject's repo, Step 0's `second-brain context` prints a `subproject:` line. Then
  add `--subproject <name>` to every `board` call, and name the subproject in the count line.
- Leave the flag out when the user asks for the whole project.

| The user asks for | Do |
|---|---|
| nothing specific | `second-brain board <project>`. Its default view, `Active`, lists status `planned`, `in-progress` and `in-review` |
| one subproject | `--subproject <name>` on the board call. Exit 1: the name is no subproject; show `second-brain subproject <project>` |
| "all", "everything" | view `All` |
| one status | view `All`, keep the rows with that status |
| one ticket | `second-brain task head <ID>`, rendered as one block |
| a ticket key | keep the rows whose id starts with the key |
| a topic | find its tag in `second-brain profile <project> topics`, run `second-brain topic <project> <tag>`, keep the rows whose folder it lists. Exit 1: no story has the tag. A parent tag covers its sub-topics |
| "current sprint", "this sprint" | view `"Current sprint"`. No rows: say "no sprint in progress", or "this project does not use sprints" when Step 0's `profile <project> --keys` printed `uses_sprints: false` |
| what is waiting on docs | view `All`, keep the rows that reached production: status `done`, or the last entry of `envs` is `done`. Run `second-brain task docs <their ids> --project <project>` and list the stories it prints, with their paths |

- A key or topic filter narrows the `Active` view, unless the user also says "all".
- Run `second-brain task head <ID>` only for a row whose title or next is `-`.
- Never read a whole README for an overview.
- No rows in any other view: say so and stop.

## Render

- One labelled block per story, never a table.
- Six lines per block, in the order below.
- A line of hyphens between blocks, then a one-line count.

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
- An `in-progress` story waits on each task in its `depends_on` cell that is not `done`. Add
  `Waiting on: EX-123 (planned)` under `Status:`, one line per such task.
- One phrase per field.
- Add a field only when the user asks: `Sprint:` from the row, `Epic:` and `Last updated:` from
  `second-brain task head <ID>`.
- A row whose `envs` is not `-` is an environment set: one block, counted once, with the set's
  status.
- Under the set's `ID:` line add an `Envs:` line built from the cell:
  `dev:EX-123:done,qa:EX-140:planned` becomes `Envs: dev EX-123 done | qa EX-140 planned`.
- End the set's `Branch:` line with `(first environment's id, shared by the set)`.

## After the count

List each of these on its own, only when it has entries. None of them counts as an active story.

- `Needs a status:` a story whose status is missing or is not one of the five.
  - Get the ids from `second-brain board <project> "Needs a status"`, in the same Bash call as
    the main view. The `Active` view never lists them.
  - In view `All`, list such rows here, not as blocks.
  - Skip this list for a one-ticket or one-status request.
  - Never guess the status.
- `No README:` a task folder without a `README.md`.
- `Not in tasks/:` a story found outside the tasks root.

Report the last two only when a call in this run surfaced one. Never scan for them: the
`vault-doctor` skill runs that check.

Add at most two one-line callouts that matter, such as a blocking open question or an ambiguous
canonical branch. Then offer to expand a story into its open items and acceptance criteria
checklist, or to add fields. Never expand unasked.
