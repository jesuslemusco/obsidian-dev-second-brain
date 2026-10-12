# obsidian-dev-second-brain

A Claude Code plugin that keeps a developer's work in an [Obsidian](https://obsidian.md) vault:
tickets, sprints and project docs, as plain markdown notes that Claude reads and updates for you.

## What it is for

- **Tickets.** Each ticket is one note with its status, branch, next step and a dated log. Ask
  Claude to start one, update it, or tell you where things stand.
- **Sprints.** Open a sprint, plan it, see its status, close it and carry work over. Sprints are
  optional per project.
- **Docs.** Keep a project's docs in step with its code.
- **Fast answers.** A helper command, `second-brain`, answers from the vault's files in one call,
  so Claude does not read whole notes to find one fact.

Your notes stay in your vault. The plugin holds no project data and needs no credentials.

## What you need

- [Claude Code](https://claude.com/claude-code).
- [Obsidian](https://obsidian.md/download), version 1.9 or later, to read the vault and its task
  boards. The plugin works on the files and never calls the app, so it does not have to be running.
- macOS, Linux, or Windows with [Git for Windows](https://gitforwindows.org).

## Install

In Claude Code:

```
/plugin marketplace add jesuslemusco/obsidian-dev-second-brain
/plugin install obsidian-dev-second-brain@second-brain
```

Then set it up:

1. Open the folder you want as your vault in Obsidian.
2. Run `/obsidian-dev-second-brain:vault-setup init` and give it that folder.
3. Run `/obsidian-dev-second-brain:vault-setup project <name>` to add a project.
4. Ask Claude to start tracking a ticket.

Run `/obsidian-dev-second-brain:vault-doctor` whenever you want the setup checked.

## More

- [docs/guide.md](docs/guide.md): what the plugin ships, how a vault is laid out, notes on Windows,
  and how to run the tests.
- [docs/contract.md](docs/contract.md): every helper command and the format of the notes.
- [CHANGELOG.md](CHANGELOG.md): what changed in each version.

## License

MIT. See [LICENSE](LICENSE).
