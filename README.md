# obsidian-dev-second-brain

A Claude Code plugin that keeps a developer's work in an [Obsidian](https://obsidian.md) vault:
tickets, sprints and project docs, as plain markdown notes that Claude reads and updates for you.

## What it is for

- **Tickets.** Each ticket is one note with its status, branch, next step and a dated log. Ask
  Claude to draft a ticket's text, start one, update it, or tell you where things stand.
- **Sprints.** Open a sprint, plan it, see its status, close it and carry work over. Sprints are
  optional per project.
- **Docs.** Keep a project's docs in step with its code.
- **Fast answers.** A helper command, `second-brain`, answers from the vault's files in one call,
  so Claude does not read whole notes to find one fact.

Your notes stay in your vault. The plugin holds no project data and needs no credentials.

## How it works

- Your vault is a folder of markdown notes. Each project has a folder in it, and each ticket is
  one note whose first lines hold its status, branch, sprint and next step.
- A link on your machine points to the vault, and a short index of your projects is loaded into
  every Claude session, so Claude knows where each project's notes are.
- When you ask for something, a skill tells Claude the steps and the `second-brain` helper does
  the reading and writing, straight on the files.
- You read the result in Obsidian: the notes, the links between them, and a task board per
  project that is a live table of its tickets.

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

## Your own skills and agents

The vault can hold skills and agents of your own, next to the ones the plugin ships.

- **Global ones**, useful in any project, go in `claude/` at the vault root:
  `claude/skills/<name>/SKILL.md` and `claude/agents/<name>.md`.
- **Project ones** go in that project's folder: `<project>/claude/skills/<name>/SKILL.md` and
  `<project>/claude/agents/<name>.md`. Start the name with the project, as in `example-deploy`,
  because all names share one list.
- The folder or file name must equal the `name` in its frontmatter.
- List each one in the `claude/README.md` beside it, with a line on when to use it. Claude reads
  that note before it works on the project.
- After you add, rename or remove one, run `/obsidian-dev-second-brain:vault-setup link`. It links
  each one into `~/.claude`, where Claude Code looks. The file in the vault stays the only copy.

Skills and agents you keep straight in `~/.claude`, outside the vault, are never touched.

## Pull request descriptions

Every pull request description Claude writes uses four headings, in this order: `What was
changed?`, `What was added?`, `Dependencies:` and `Risks:`, with a few one-line bullets in plain
English under each. The format is the note `claude/pull-request.md` in your vault: edit it to
change the format. A project that keeps its own `<project>/claude/pull-request.md` uses that one.

## More

- [docs/guide.md](docs/guide.md): what the plugin ships, how a vault is laid out, notes on Windows,
  and how to run the tests.
- [docs/contract.md](docs/contract.md): every helper command and the format of the notes.
- [CHANGELOG.md](CHANGELOG.md): what changed in each version.

## License

MIT. See [LICENSE](LICENSE).
