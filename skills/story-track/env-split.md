# Environment sets

One goal tracked as a ticket per environment.

- The environment names and their order are the profile's `environments`, or the subproject's
  when the story has one and it sets them.
- `second-brain profile <project> environments` says what differs between them.
- The examples use dev, qa and prod.

## One file for the whole set

- One task folder and one README hold the whole set, named for the first environment's ticket id.
- Add `envs:` only when the user runs a ticket per environment.
- Create the set with `second-brain task new EX-123 --title "..." --envs`.

With three environments tracked, the frontmatter carries:

```yaml
aliases:
  - EX-123               # first environment: the folder name, always first
  - EX-140
  - EX-151
envs:
  dev:  { id: EX-123, status: done }
  qa:   { id: EX-140, status: done }
  prod: { id: EX-151, status: planned }
```

- `aliases` lists every id. Any of them finds this file, as `## Find the story` in `SKILL.md` says.
- Link to the set as `## Links` in `SKILL.md` says: an alias does not make a bare link resolve.
- Top-level `status` is the set's: the least advanced environment still open.
- The set is `done` only when the last environment is done.
- Each environment's status lives in `envs:`.
- `envs:` is the one part of the frontmatter edited by hand. Keep its shape.
- One branch serves the whole set, as `## Branch check (start, update, recall)` in `SKILL.md` says.
- The overview shows the set as one block, counted once. `## Render` in `status.md` has the format.

## Shared and per environment

- Written once for the set: Summary, Description, Findings, Approach, Code verification, Changes.
- Acceptance criteria and Verification get one subsection per environment, headed
  `### <ENV> - <ID> (<status>)`.
- Write different checks for each environment's configuration and data, the top 4 for each. Never
  copy the first environment's checks down.
- `## Status notes` and `## Discovery log` stay one log each for the whole set.
- Each entry names its environment:
  `second-brain task note EX-123 "qa: promotion validated" --session <id>`.

## Add the next environment

Edit the existing file. A later id never gets a folder, as `## Find the story` in `SKILL.md` says.

1. Ask for the new ticket id. Never assume it is the previous one plus one.
2. Run `second-brain task alias EX-123 add EX-151`.
3. Add `prod: { id: EX-151, status: planned }` to `envs:` by hand.
4. Add its Acceptance criteria and Verification subsections.
5. The set's status moved: run `second-brain task set EX-123 status=<set status>`.
