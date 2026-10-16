# Changelog

## 0.2.0 - unreleased

The helper works on the vault's files alone, and the plugin runs on Windows.

- The helper never calls Obsidian. Obsidian is where the vault is read: its command line interface
  is no longer needed, and the app does not have to be running.
- New commands replace what went through Obsidian's index: `outline`, `backlinks`, `unresolved`,
  `move` and `rename`. `move` and `rename` rewrite the links to a moved note in the vault's notes
  and take `--dry-run`. They refuse, before a file is touched, a move that would lose or break a
  link: a name a link cannot spell, a note that cannot be read in full or written, a destination
  that exists.
- Removed: `second-brain ob`, `second-brain probe`, the `--files` flag and the `source:` line of
  `board`, the `obsidian` and `search` lines of `context`, the doctor checks `obsidian-cli` and
  `index-fresh`, and exit code 3.
- `search` finds the notes that hold every term of the text; a part in double quotes is a phrase.
  A note gives at most three lines, the ones that hold the most terms, so the forty rows show
  more notes.
- Windows is supported in Git Bash, the shell Claude Code uses there. The links are directory
  junctions, which need no special rights: one per skill folder, and one per `claude/agents`
  folder. Absolute paths are printed as `C:/...` and read in any form Windows writes them. A path
  inside the vault uses forward slashes on every system, and one with a backslash is refused.
- `second-brain pointer set <folder>` creates the vault pointer on every system. `vault-setup` uses
  it in place of a hand-made symlink.
- The SessionStart hook is written in shell form, so it runs on Windows.
- The conventions note is at version 2: it describes the helper commands in place of the Obsidian
  command line interface.
- The vault's `CLAUDE.md` carries a version, `index_version`, in frontmatter. The doctor's `index`
  check warns about an index older than the plugin's template. It now fails on a row whose path
  is not a folder in the vault, and on a name, a key or a path that two rows share.
- The index says first what holds in every session: a new personal skill or agent is created in
  the vault, not straight in `~/.claude/skills` or `~/.claude/agents`. Its closing line, to
  ignore the file for a task outside the projects, is gone: it cancelled that rule.
- The index also tells every session to answer in short, plain English and lead with the answer,
  unless the user or their own instructions say otherwise. A vault learns of it on upgrade: the
  release raises the template's `index_version`, so the doctor's `index` check warns until the
  vault's index is brought in line.
- The doctor checks more. `hubs` warns about a project's hub that is missing or empty.
  `task-location` warns about a note with `type: task` that is not the README of its own folder
  under the tasks root. `board` warns, while a sprint is in progress, about a `Current sprint`
  view that filters on another sprint, has a filter the helper cannot read, or is not there.
  `descriptions` warns about a skill or an agent of the vault with no description.
- The doctor opens nothing outside the vault. An index row whose path is `.` or holds a `..`
  part or a backslash fails `index` and gets no project rows, and `doctor --fix` writes nothing
  under it. A `tasks_root`, `topics_root` or `sprints_root` that leaves the project fails
  `profile`, and the project is checked under that root's default.
- The tests run on Linux, macOS and Windows. An end-to-end check runs Claude Code itself against a
  scratch vault on a Linux and a Windows runner.

Upgrading a vault that was set up with 0.1.0:

- The pointer and the links keep working as they are.
- `scaffold vault` never overwrites, so the vault keeps its version 1 conventions note, which
  still names the removed commands. The doctor warns about it. Delete `obsidian-conventions.md`
  and run `second-brain scaffold vault` to get the new one, or edit it by hand.
- The vault's `CLAUDE.md` has no `index_version`, so the doctor warns about it. Bring the text
  above `## Projects` in line with `templates/vault-index.md.tmpl`: it opens with
  `## In every session`, which says where new skills and agents go, it no longer says to ignore
  the file, and its rule about moving notes names `second-brain move` and `second-brain rename`.
  Keep your own lines and the table, and put the template's frontmatter, with its
  `index_version`, at the top. The `vault-doctor` skill does this after asking.
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
