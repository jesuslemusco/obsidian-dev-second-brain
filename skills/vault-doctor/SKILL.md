---
name: vault-doctor
description: Check the vault, its projects and the Claude registration against the second-brain standard.
argument-hint: "[check [project] | fix | snapshot | compare]"
allowed-tools: Read Grep Bash(second-brain *)
---

# Vault doctor

The first argument is the mode. With none, take it from the request. With nothing to go on, run
check.

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Plugin root: ${CLAUDE_PLUGIN_ROOT}.

## Step 0 - Context

1. Run `second-brain context` yourself, as your first tool call.
   - `second-brain` is not found: the plugin is not enabled. Say so and stop. Never guess paths.
2. `vault: none`: no vault is set up. Run check anyway: it prints the `pointer` row and exits 2.
   - Then offer `/odsb:vault-setup init` and stop. The user runs it by name.
3. A project the user named: `second-brain project --name "<name>"`.
   - Exit 1 or 4: show `second-brain projects` and ask.
   - With no project, check the whole vault.

## check (default)

1. Run `second-brain doctor`, or `second-brain doctor <project>`.
   - Each row is `result | check | scope | count | offenders | fix`.
   - `offenders` holds five at most.
2. Exit 0: no check failed. Exit 1: one did, or the named project is not in the index, which
   prints no rows. Exit 2: no vault.
3. Show the rows that are not `ok` as a table, the `fail` rows first, then the `warn` rows. Close
   with one line that counts the `ok` rows.
4. Read the entries of those checks in `${CLAUDE_SKILL_DIR}/checks.md` with one Grep, not one per
   check.
   - Join the names with `|`, as in `^### (links|status-tag|sprints)$`, with 4 lines after each
     match.
   - Never read the whole file.
5. Say what each one means, why it matters and the fix. Change nothing in this mode.

## fix

1. Start from a check run in this session. Run one when there is none.
2. `second-brain doctor --fix` repairs three checks only: `status-tag`, `pull-request` and
   `task-layout`. Their `Fix` lines in `checks.md` say what it changes.
3. A `task-layout` row with `to-archive` offenders makes the `--fix` run a bulk change: it moves
   task folders and rewrites links.
   - So does a row with `<ID>:<status>` or `archive:status` offenders, in a status project:
     `--fix` moves each task to the folder of its status.
   - So does a row with `<ID>:<folder>` offenders, in a sprint project: `--fix` moves each task to
     the folder of its sprint, or to `backlog/`, and removes each group folder it leaves empty.
   - Say how many tasks it will archive or move, and name them: each `<ID>:to-archive` or
     `<ID>:<status>` offender.
   - In a sprint project, name each `<ID>:<folder>` offender, with the folder it moves to.
   - The number is the row's count, less each offender that is not a task it moves:
     `archive:status`, whose task the row counts as `<ID>:<status>` too, and in an archive
     project `<ID>:open`, `archive_after_days:not-a-number` and `<status>:archive`.
   - In a sprint project, `sprint_folder:invalid` is no task either. In a status project, neither
     is a `<folder>:status` offender, whose tasks the row counts as `<ID>:<status>` too.
   - The count is above five: say that the doctor names only the first five, and name those. The
     count is then the most it will move, and the `fixed:` lines of step 4 name every task moved.
   - Then run `second-brain snapshot` before it.
   - With no such row, `--fix` needs no snapshot.
4. Run `second-brain doctor --fix`. It prints one `fixed:` line per change, then the table.
5. Run `second-brain doctor` again. The checks `--fix` repaired are now `ok`: that is the proof.
6. After an archive, run `second-brain compare` with that snapshot. It is the proof of the move.
   - It lists the aliases of each archived task folder as removed at the old path and added under
     `archive/<YYYY>/`, and nothing else.
   - After a move to the folders of their status, run it too. It lists the aliases of each moved
     task folder as removed at the old path and added under `<status>/`, and nothing else.
   - After a move to the folders of their sprint, run it too. It lists the aliases of each moved
     task folder as removed at the old path and added under the sprint's folder or `backlog/`,
     and nothing else.
   - An `unresolved added:` line, or a `tasks added:`, `tasks removed:` or `tasks changed:` line,
     is a link or a task the move broke. Report it.
7. A `foreign` row: run `second-brain link --foreign`, which lists every item. Take them one at
   a time.
   - Ask the user with AskUserQuestion where it goes. Name it, its kind, and what it is: a folder,
     a file, or a link and where it leads.
   - Options: the vault's general `claude/`, the one or two projects of `second-brain projects`
     that fit it best, and `Stays where it is`. The free-text answer names another project.
   - Nothing moves without that answer. `Stays where it is`: leave it, and go on to the next.
   - Otherwise run `second-brain link move <skill or agent> <name>`, with `--project "<project>"`
     for a project's `claude/`.
   - A link into the vault: the move rewrites the links to what it leads to. Snapshot before it
     and compare after it, as `## snapshot and compare` says.
   - It prints `moved:` or `copied:`, then `listed:` with the `README.md` it added the row to,
     then the item's row, `linked`. Report them.
   - A `copied:` line: the original stays where it was. Once the item's row is `linked`, ask with
     AskUserQuestion whether to delete the original, named by its path.
   - On a yes, run `second-brain link drop-original <skill or agent> <name> "<path>"`. It removes
     the original only when it matches the copy. On a no, the original stays: name its path in the
     report.
   - Exit 5: read the message. Only one on the `name in its frontmatter`, missing or not the folder
     or file name, is fixed here: ask which one to change, change it after a yes, then run the
     move again.
   - Any other exit 5, and exit 1: show the message and stop.
   - Exit 6: the destination exists. Show it, and ask again.
   - `link drop-original` exits 1 or 5: show the message. The original stays: name its path.
8. Every other check: propose the fix from its `checks.md` entry, one check at a time.
   - Do it only after the user agrees to that one.
   - A fix that touches more than one note is a bulk change: snapshot before it and compare after
     it, as `## snapshot and compare` says.
9. Run check again. Report what is left.

## snapshot and compare

- Before a bulk change: `second-brain snapshot [name]`. Exit 6: that name exists. Pick another.
- After the change: `second-brain compare [name]`, with the same name.
- Compare covers unresolved links, aliases, task ids and statuses, and the registered links. It
  does not cover tags or doctor rows.
- Exit 0 with `no differences`: nothing it covers changed. Exit 1: a difference, or no snapshot by
  that name.
- Report every difference, and say which ones the change was meant to make.
- An unresolved link is listed as `<note path>: <link>`, an alias as the alias and its note's path.
- A note that moved shows each of its rows twice: once removed, once added.
- A `not compared:` line names a file the snapshot folder lacks. Say that the comparison covers
  less.

## Rules

- Never delete a note, except a file that a `checks.md` fix says to delete, after the user agrees to
  that fix.
- Run `second-brain move` with `--dry-run` first.
- The helper prints `-` for an empty cell. Read it as empty.
- A template named in `checks.md` is under the plugin root, in `templates/`, unless the entry says
  it is in the project, in `claude/templates/`.
