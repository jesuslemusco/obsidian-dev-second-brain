# Changelog

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
