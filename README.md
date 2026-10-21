# obsidian-dev-second-brain

A Claude Code plugin that keeps a developer's work in an [Obsidian](https://obsidian.md) vault:
tickets, sprints and project docs, as plain markdown notes that Claude reads and updates for you.

## What it is for

- **Tickets.** Each ticket is one note with its status, branch, next step and a dated log. Ask
  Claude to draft a ticket's text, start one, update it, or tell you where things stand.
- **Sprints.** Open a sprint, plan it, see its status, close it and carry work over. Sprints are
  optional per project.
- **Docs.** Keep a project's docs in step with its code. Marking a ticket done updates its docs.
- **Several repos.** A project made of several repos can split them into subprojects, each with
  its own branches, docs folder and rules, under one ticket key and one board.
- **Fast answers.** A helper command, `second-brain`, answers from the vault's files in one call,
  so Claude does not read whole notes to find one fact.

Your notes stay in your vault. The plugin holds no project data and needs no credentials.

## How it works

- Your vault is a folder of markdown notes. Each project has a folder in it, and each ticket is
  one note whose first lines hold its status, branch, sprint, next step and the tickets it waits on.
- A link on your machine points to the vault, and a short index of your projects is loaded into
  every Claude session, so Claude knows where each project's notes are.
- When you ask for something, a skill tells Claude the steps and the `second-brain` helper does
  the reading and writing, straight on the files.
- Each session in a project's repo starts knowing the project, the sprint, the ticket its branch
  names and where that ticket's story stands.
- When Claude reaches for grep, cat or sed on the vault's notes, a hook reminds it of the helper
  commands. It never blocks a call.
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

Ask Claude to check your vault, or run `/obsidian-dev-second-brain:vault-doctor`, whenever you want
the setup checked.

## Update

Claude Code reads the plugin from a local copy of the marketplace, and it does not refresh that
copy on its own. It updates the plugin only when the plugin's `version` changes. To get a new
release:

1. Refresh the marketplace. In your shell:
   `claude plugin marketplace update second-brain`. Inside Claude Code the same is
   `/plugin marketplace update second-brain`.
2. Update the plugin. In your shell:
   `claude plugin update obsidian-dev-second-brain@second-brain`. Inside Claude Code, run `/plugin`,
   open the Installed tab, pick the plugin and choose Update now.
3. Restart Claude Code. `/reload-plugins` loads the new skills and agents into a session that is
   open, but a restart is the sure way: the session-start hook and the `second-brain` command then
   come from the new version.
4. Bring the vault up to the new version. Run `/obsidian-dev-second-brain:vault-doctor check`, then
   `/obsidian-dev-second-brain:vault-doctor fix`. The doctor warns when the vault's index or
   conventions note is older than the plugin's template. `fix` repairs what is safe and asks
   before it changes anything else.

`claude plugin list` shows the version you have. Compare it with the newest section of the
[changelog](CHANGELOG.md). When nothing is newer, step 2 prints `already at the latest version`.

### When the update does not take

If `claude plugin list` still shows the old version after steps 1 and 2, uninstall the plugin and
install it again:

```
claude plugin uninstall obsidian-dev-second-brain@second-brain
claude plugin install obsidian-dev-second-brain@second-brain
```

The install refreshes the marketplace first. Your vault and your notes are not touched. Restart
Claude Code, then run the doctor as in step 4.

An early copy of 0.2.0 never moves to the final 0.2.0, because both say `0.2.0`. Version 0.3.0 and
later do move with the steps above.

### Update by itself

Auto-update is off for a marketplace you added yourself. To turn it on for `second-brain`, run
`/plugin` in Claude Code, open the Marketplaces tab, pick `second-brain` and choose Enable
auto-update. From then on Claude Code refreshes the marketplace and updates the plugin in the
background during a session, and the next session starts on the new version. It does not run the
doctor, so do step 4 after a release that changes the vault.

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

Every pull request description Claude writes opens with a `Goal`, one or two lines on why the
pull request exists, then uses four headings, in this order: `What was changed?`, `What was
added?`, `Dependencies:` and `Risks:`. Every heading is bold, and under each a few one-line
bullets in plain English start with a bold label. Claude writes it from the branch, with
`git log <target>..<source>` and `git diff <target>...<source>`, never from memory of the work.
The format is the note `claude/pull-request.md` in your vault: edit it to change the format. A
project that keeps its own `<project>/claude/pull-request.md` uses that one.

## More

- [docs/guide.md](docs/guide.md): what the plugin ships, how a vault is laid out, notes on Windows,
  how to run the tests, and how a release is made.
- [docs/contract.md](docs/contract.md): every helper command and the format of the notes.
- [CHANGELOG.md](CHANGELOG.md): what changed in each version.

## License

MIT. See [LICENSE](LICENSE).
