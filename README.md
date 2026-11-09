# obsidian-dev-second-brain

A Claude Code plugin that keeps a developer's work in an [Obsidian](https://obsidian.md) vault:
tickets, sprints and project docs, as plain markdown notes that Claude reads and updates for you.

## What it is for

- **Tickets.** Ask Claude to draft a ticket's text, start one, update it, or say where things
  stand. Each ticket is one note, `<project>/tasks/<ID>/README.md`.
- **Sprints.** Ask Claude to open a sprint, plan it, show its status, or close it and carry work
  over. A project whose profile sets `uses_sprints: false` runs none, as
  `### Profile frontmatter` in `docs/contract.md` says.
- **Docs.** A ticket that reaches production starts `docs-keeper`, which brings the project's
  docs in step with its code. The hand-off is under
  `## Edit an existing story` in `skills/story-tracker/SKILL.md`.
- **Spec-driven stories.** A story is built from a spec when you ask, or when Claude thinks it
  needs one and you agree, as `## Spec-driven delivery` in `docs/guide.md` says. You approve its
  requirements, then its design, then its tasks. Then the `spec` skill builds and reviews each
  task in your session, as `skills/spec/build.md` says.
- **Validation.** Each repo's steps to run and check it are in a `validation.md`, in the vault or
  in the repo, as `### Validation` in `docs/contract.md` says.
  `/odsb:vault-setup validation <project>` drafts them for you to confirm.
- **Several repos.** `/odsb:vault-setup subproject <project>` splits a
  project's repos into subprojects, each with its own branches, docs folder and rules, under one
  ticket key and one board.

The plugin keeps no project data and needs no credentials: your notes stay in your vault.

## How it works

- `~/.claude/second-brain-vault` links to your vault.
- `~/.claude/CLAUDE.md` imports the vault's `CLAUDE.md`, the index of your projects, into every
  session.
- A skill gives Claude the steps, and the helper, `bin/second-brain`, reads and writes the notes.
- The SessionStart hook runs `second-brain session-check`, so a session in a project's repo starts
  knowing the project, the sprint, the ticket its branch names and where its story stands.
- `hooks/search-rule.sh` reminds Claude of the helper when it runs grep, cat or sed on the vault's
  notes. It never blocks a call.
- You read the notes, their links and each project's task board, `<project>/tasks/tasks.base`, in
  Obsidian.

## What you need

- [Claude Code](https://claude.com/claude-code), version 2.1.295 or later.
- [Obsidian](https://obsidian.md/download), version 1.9 or later, to read the vault and its task
  boards. It need not be running.
- macOS, Linux, or Windows with [Git for Windows](https://gitforwindows.org).

## Install

In Claude Code:

```
/plugin marketplace add jesuslemusco/obsidian-dev-second-brain
/plugin install obsidian-dev-second-brain@second-brain
```

Then set it up:

1. Open the folder you want as your vault in Obsidian.
2. Run `/odsb:vault-setup init` and give it that folder.
3. Run `/odsb:vault-setup project <name>` to add a project.
4. Ask Claude to start tracking a ticket.

To check the setup at any time, ask Claude to check your vault, or run
`/odsb:vault-doctor`.

## Update

To get a new release:

1. Refresh the marketplace: `claude plugin marketplace update second-brain` in your shell, or
   `/plugin marketplace update second-brain` in Claude Code.
2. Update the plugin: `claude plugin update obsidian-dev-second-brain@second-brain` in your
   shell. In Claude Code, run `/plugin`, open the Installed tab, pick the plugin and choose
   Update now.
3. Restart Claude Code. `/reload-plugins` loads the new skills and agents into an open session,
   but only a restart is sure to load the new session-start hook and `second-brain` command.
4. Bring the vault up to the new version: run `/odsb:vault-doctor check`,
   then `/odsb:vault-doctor fix`. What each check finds is in
   `skills/vault-doctor/checks.md`, and what `fix` changes without asking is under
   `## fix` in `skills/vault-doctor/SKILL.md`.

`claude plugin list` shows your version: compare it with the newest section of
[CHANGELOG.md](CHANGELOG.md). When nothing is newer, step 2 prints `already at the latest version`.

### When the update does not take

If `claude plugin list` still shows the old version after steps 1 and 2, uninstall the plugin and
install it again:

```
claude plugin uninstall obsidian-dev-second-brain@second-brain
claude plugin install obsidian-dev-second-brain@second-brain
```

Your vault and notes are not touched. Then restart Claude Code and run the doctor as in step 4.

An early copy of 0.2.0 never moves to the final 0.2.0, because both say `0.2.0`.

### Update by itself

Auto-update is off for a marketplace you added yourself. To turn it on, run `/plugin` in Claude
Code, open the Marketplaces tab, pick `second-brain` and choose Enable auto-update. From then on
Claude Code updates the plugin in the background, and the next session starts on the new version.
It runs no doctor: do step 4 after a release that changes the vault.

## Your own skills and agents

Keep skills and agents of your own in the vault: in `claude/` at its root for every project, or in
`<project>/claude/` for one project.

- Add one by the steps under `## Adding a skill or agent` in `templates/vault-claude-hub.md.tmpl`,
  the template of your vault's `claude/README.md`.
- After you add, rename or remove one, run `/odsb:vault-setup link`. What it
  links into `~/.claude`, and what it leaves alone, is under
  `## link` in `skills/vault-setup/SKILL.md`.

## Pull request descriptions

Claude writes every pull request description in the format of the note `claude/pull-request.md`
in your vault, written from `templates/pull-request.md.tmpl`. Edit that note to change the format.
A project's own `<project>/claude/pull-request.md` wins over it.

## More

- [docs/guide.md](docs/guide.md): what the plugin ships, the vault layout, Windows, the tests and
  releases.
- [docs/contract.md](docs/contract.md): every helper command and note format.
- [CHANGELOG.md](CHANGELOG.md): what changed in each version.

## License

MIT. See [LICENSE](LICENSE).
