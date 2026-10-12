# Changelog

## 0.2.0 - unreleased

The helper works on the vault's files alone, and the plugin runs on Windows.

- The helper never calls Obsidian. Obsidian is where the vault is read: its command line interface
  is no longer needed, and the app does not have to be running.
- New commands replace what went through Obsidian's index: `outline`, `backlinks`, `unresolved`,
  `move` and `rename`. `move` and `rename` rewrite the links to a moved note in the vault's notes
  and take `--dry-run`.
- Removed: `second-brain ob`, `second-brain probe`, the `--files` flag and the `source:` line of
  `board`, the `obsidian` and `search` lines of `context`, the doctor checks `obsidian-cli` and
  `index-fresh`, and exit code 3.
- `search` finds the notes that hold every word of the text.
- Windows is supported in Git Bash, the shell Claude Code uses there. The links are directory
  junctions, which need no special rights: one per skill folder, and one per `claude/agents`
  folder. Paths are printed as `C:/...`.
- `second-brain pointer set <folder>` creates the vault pointer on every system. `vault-setup` uses
  it in place of a hand-made symlink.
- The SessionStart hook is written in shell form, so it runs on Windows.
- The conventions note is at version 2: it describes the helper commands in place of the Obsidian
  command line interface.
- The tests run on Linux, macOS and Windows. An end-to-end check runs Claude Code itself against a
  scratch vault on a Linux and a Windows runner.

Upgrading a vault that was set up with 0.1.0:

- The pointer and the links keep working as they are.
- `scaffold vault` never overwrites, so the vault keeps its version 1 conventions note, which
  still names the removed commands. Delete `obsidian-conventions.md` and run
  `second-brain scaffold vault` to get the new one, or edit it by hand.
- In the vault's `CLAUDE.md`, the rule about moving notes should name `second-brain move` and
  `second-brain rename`.
- A snapshot taken with 0.1.0 does not compare with one taken now.

## 0.1.0 - unreleased

First version.

- Skills: `story-tracker`, `sprint`, `vault-setup`, `vault-doctor`.
- Agents: `scrum-master`, `docs-keeper`.
- Helper: `second-brain` (lookups, board, task and sprint writes, scaffolding, link, doctor).
- Templates for a vault, a project, a task, a sprint and the task board.
- A project profile records where its code repositories are stored (`repos_root`, `repo_paths`);
  `second-brain repo <project> [name]` returns the path, and the doctor warns when a folder is missing.
- Docs follow production: `docs-keeper` edits a doc only after the change is confirmed deployed, and
  records the planned edits until then. Every repository has rows in the profile's code-to-doc map;
  `vault-setup repo <project>` adds a repository with its rows, and the doctor warns when one has none.
- The helper works where `awk` is gawk in a UTF-8 locale, as on the Ubuntu CI runner: every awk
  program that loads the shared functions now runs in the C locale.
- Sprints are optional per project: `uses_sprints: false` in the profile, written by
  `second-brain scaffold project --no-sprints`, turns them off. The project gets no sprints hub and
  no `Current sprint` view, the `sprint` commands refuse it, and the doctor skips its sprint checks.
