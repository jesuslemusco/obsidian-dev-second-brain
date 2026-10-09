# Environment sets

One goal tracked as a ticket per environment. The environment names and their order are the
profile's `environments`; `second-brain profile <project> environments` says what differs between
them. The examples use dev, qa and prod.

## One file for the whole set

One task folder and one README hold the whole set, named for the FIRST environment's ticket id.
The set is one change promoted through the environments; separate files would mean several copies
of the root cause and the code walk, which drift. Create it with
`second-brain task new EX-123 --title "..." --envs`. With three environments tracked, the
frontmatter carries:

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

- `aliases` lists every id, so `second-brain find` and every `second-brain task` command reach
  this file from any of them. An alias still does not make a bare link resolve.
- Top-level `status` is the set's: the least advanced environment still open, `done` only when the
  last one is done. Per-environment statuses live in `envs:`, the one part edited by hand. Keep
  its shape.
- One branch, named for the first environment's id, carries the work through every environment.
  The branch check in `SKILL.md` has the rule.
- Add `envs:` only when the user really runs a per-environment split. Most stories are standalone.
- In the overview the set is one board row and one block, counted once. The row's `envs` cell
  carries each environment's id and status; `status.md` has the format.

## Shared and per environment

- Shared, written once: Summary, Description, Findings, Approach, Code verification, Changes. It
  is the same change everywhere.
- Per environment, each under its own `### <ENV> - <ID> (<status>)` heading: Acceptance criteria
  and Verification. Each environment has its own configuration and data, so write different
  checks, the top 4 for each. Do not copy the first four down.
- `## Status notes` and `## Discovery log` stay single logs for the set, newest first, each entry
  naming its environment: `second-brain task note EX-123 "qa: promotion validated" --session <id>`.
  A finding in one environment usually explains a result in the next.

## Add the next environment

Edit the existing file; a later id never gets a folder (`SKILL.md`, "Find the story"). Ask for the
new ticket id; do not assume it is the previous one plus one. Run
`second-brain task alias EX-123 add EX-151`, add `prod: { id: EX-151, status: planned }` to `envs:`
by hand, add its Acceptance criteria and Verification subsections, then
`second-brain task set EX-123 status=<set status>` if the set moved.
