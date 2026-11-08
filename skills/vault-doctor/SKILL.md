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
   - Then offer `/obsidian-dev-second-brain:vault-setup init` and stop. The user runs it by name.
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
   - Say how many tasks it will archive, the row's count, and name them.
   - Then run `second-brain snapshot` before it.
   - With no such row, `--fix` needs no snapshot.
4. Run `second-brain doctor --fix`. It prints one `fixed:` line per change, then the table.
5. Run `second-brain doctor` again. The checks `--fix` repaired are now `ok`: that is the proof.
6. After an archive, run `second-brain compare` with that snapshot. It is the proof of the move.
   - It lists the aliases of each archived task folder as removed at the old path and added under
     `archive/<YYYY>/`, and nothing else.
   - An `unresolved added:` line, or a `tasks added:`, `tasks removed:` or `tasks changed:` line,
     is a link or a task the move broke. Report it.
7. Every other check: propose the fix from its `checks.md` entry, one check at a time.
   - Do it only after the user agrees to that one.
   - A fix that touches more than one note is a bulk change: snapshot before it and compare after
     it, as `## snapshot and compare` says.
8. Run check again. Report what is left.

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
- A template named in `checks.md` is under the plugin root, in `templates/`.
