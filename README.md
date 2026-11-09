# obsidian-dev-second-brain

A Claude Code plugin that keeps a developer's work in an [Obsidian](https://obsidian.md) vault:
tickets, sprints and project docs, as plain markdown notes that Claude reads and updates for you.
It can also build a story from a spec you approve, one task at a time, each tested and reviewed.

## Overview

- **Tickets.** Claude drafts a ticket's text, starts its story, updates it and says where it
  stands. Each ticket is one note, `<project>/tasks/<ID>/README.md`.
- **Sprints.** Claude opens a sprint, plans it, shows its status, and closes it with the open work
  carried over.
- **Docs.** When a ticket reaches production, `docs-keeper` brings the project's docs in step
  with its code.
- **Spec-driven builds.** You approve a story's requirements, design and tasks. Claude then builds
  the tasks one at a time, test-first, and has each reviewed before the next one starts.
- **Validation.** Each repo's commands to check it, and the steps to try it as a user would, are
  in a `validation.md`, in the vault or in the repo.
- **Several repos.** A project's repos can split into subprojects, each with its own branches and
  docs, under one ticket key and one board.
- **A health check.** The doctor checks the vault, its projects and their registration in Claude
  Code, and fixes what it safely can.

The plugin keeps no project data and needs no credentials: your notes stay in your vault.

## What you need

- [Claude Code](https://claude.com/claude-code), version 2.1.295 or later.
- [Obsidian](https://obsidian.md/download), version 1.9 or later, to read the vault and its task
  boards. It need not be running.
- macOS, Linux, or Windows with [Git for Windows](https://gitforwindows.org).

## Quick start

1. Install the plugin in Claude Code:

   ```
   /plugin marketplace add jesuslemusco/obsidian-dev-second-brain
   /plugin install obsidian-dev-second-brain@second-brain
   ```

2. Open the folder you want as your vault in Obsidian.
3. Run `/odsb:vault-setup init` and give it that folder.
4. Run `/odsb:vault-setup project Example` to add a project.
5. Start a ticket: `Start EX-1: add a dark mode toggle to the settings page.`

To check the setup at any time, ask Claude to check your vault, or run `/odsb:vault-doctor`.
Other ways to install are under `## Other ways to install` in `docs/guide.md`.

## Commands

Claude loads a skill when your request matches it, so you seldom type one. You can also type its
name, as in the headings below. Which requests load which skill is under
`## What to say` in `docs/guide.md`.

### `/odsb:story-tracker`

Drafts, starts, updates and recalls tickets, and gives a standup.

- Use it for any question or change on a ticket.
- Starting a ticket writes its story: a summary, a description and up to four acceptance
  criteria, checked against the code.
- An update adds a dated status note, ticks the criteria that are met and keeps the branch line
  current.
- When work starts, it builds a simple story direct, and asks you when a spec would help.

```
Where does EX-2 stand?
Update EX-2: the sort is merged, move it to in review.
```

### `/odsb:sprint`

Opens, plans, shows and closes a project's sprint, and carries open work over.

- Use it to start a sprint, pick its stories, see its status or close it.
- A project can run without sprints, as `### Profile frontmatter` in `docs/contract.md` says.

```
Open a new sprint for the Example project.
/odsb:sprint close Example
```

### `/odsb:spec`

Writes a story's spec with you, then builds and reviews it in your session.

- Use it for a story that is big or unclear, or one you want built with few questions.
- You approve its requirements, then its design, then its tasks. Before you approve the design,
  and again the tasks, `spec-checker` reads the spec alone and lists what it could not build.
- Then Claude builds the tasks in order. `implementer` builds each one test-first when it has
  something to test, and a fresh `reviewer` reviews it right away. The review grades each check
  and ends with a JSON verdict.
- A failed task goes back for a fix, in a capped number of rounds.
- Once the build has started, Claude asks you only for a short list, such as a push or a task
  that is stuck. It settles any other question itself and records the ruling in the story.
- Progress is kept in `build.json`, so a new session picks the build up where it stopped.
- At the end, Claude offers to merge the branch, open a pull request or keep it.

The whole flow is under `## Spec-driven delivery` in `docs/guide.md`, and the build's steps are
in `skills/spec/build.md`.

```
/odsb:spec EX-2
Implement EX-2 spec-driven, starting with its requirements.
```

### `/odsb:vault-setup`

Sets up the vault and its projects, and links your own skills and agents into Claude Code.

- `init`: set up a vault in a folder, and link it to Claude Code.
- `project <name>`: add a project, with its profile, hubs and task board.
- `adopt <path>`: bring a folder of notes you already have up to the standard. It writes only
  what is missing.
- `repo <project>`: add a repository to a project.
- `subproject <project>`: split a project's repos into subprojects.
- `validation <project>`: draft each repo's validation steps for you to confirm. Their shape is
  under `### Validation` in `docs/contract.md`.
- `link`: link the skills and agents kept in your vault into Claude Code.

```
/odsb:vault-setup project Example
/odsb:vault-setup validation Example
```

### `/odsb:vault-doctor`

Checks the vault, its projects and their registration in Claude Code against the standard.

- Use it after you set up or update the plugin, or when a note or link looks wrong.

- `check [project]`, the default: one row per check, `ok`, `warn` or `fail`, with the fix. What
  each check finds is in `skills/vault-doctor/checks.md`.
- `fix`: repairs what is safe, and proposes the rest one check at a time. What it changes without
  asking is under `## fix` in `skills/vault-doctor/SKILL.md`.
- `snapshot` and `compare`: save the vault's links, aliases and task statuses before a bulk
  change, and compare them after it.

```
Check my vault for problems.
/odsb:vault-doctor fix
```

## Agents

Most are started by a skill, and you can ask for any of them by name.

| Agent | Does | Started by |
|---|---|---|
| `docs-keeper` | Keeps a project's docs, in its repos and in the vault, in step with its code. Also audits drift and rewrites renamed commands. | `story-tracker` when a ticket reaches production, `vault-doctor fix` on an `old-namespace` row, or you. |
| `scrum-master` | Runs a project's sprint cadence: plan, daily status, close and carry-over. | You. |
| `implementer` | Builds one task, or each task of a bundle, test-first, runs its checks and commits it. | `spec`, during a build. |
| `reviewer` | Runs the repo's checks on the branch before the first task, and grades a task's diff, the user steps or the whole branch. Edits no file and ends with a JSON verdict. | `spec`: before the first task, after each task and at the end of a build. |
| `spec-checker` | Reads a spec alone, as a fresh build agent would, and lists what it could not build from it. Writes no file. | `spec`, before you approve the design and the tasks. |

## Examples

### Start a ticket

```
Start EX-123: the invoice export drops the tax column.
```

Claude finds no story for EX-123 and checks the repo's branch. It asks you for anything it cannot
tell. Then it writes `<project>/tasks/EX-123/README.md` with a summary, a description and up to
four acceptance criteria, checked against the code. A simple story is built direct. For one a
spec would help, Claude asks you.

### Ask where things stand

```
Standup for the Example project.
```

```
ID: EX-123
Summary: The invoice export keeps the tax column
Topics: billing/invoices
Status: in-progress
Branch: feature/EX-123-tax-column
Current step: Review the fix on the branch
1 active, 0 done/abandoned.
```

### Build a story from a spec

```
/odsb:spec EX-2
```

Claude writes the requirements with you and waits for your approval, then the design, then the
tasks. Then it builds the tasks one by one. After each review it shows where the build stands:

```
T1 - build: built - review: passed - fails 0 - commits 3f2a9c1 - fix - - Add the tax column
T2 - build: built - review: failed - fails 1 - commits 8b41d07 - fix - - Total the tax column
  - Issue 2026-10-08: The total skips credit notes. Fix: Add the credit notes to the total.
T3 - build: todo - review: - - fails 0 - commits - - fix - - Document the column
```

T2 goes back to its `implementer` with the issue. T3 starts once T2 passes.

### Check the vault

```
Check my vault for problems.
```

Claude runs `second-brain doctor`, which prints one row per check, such as:

```
ok | pointer | vault | 0 | - | -
ok | conventions | vault | 0 | - | -
ok | links | vault | 0 | - | -
warn | descriptions | vault | 1 | example-skill:227 | give each one a description of one sentence under 200 characters
```

Claude shows you the rows that are not `ok`, the `fail` rows first, and counts the `ok` ones. It
says what each one means and how to fix it. `/odsb:vault-doctor fix` repairs what it can.

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

## Update

1. Refresh the marketplace: `claude plugin marketplace update second-brain` in your shell, or
   `/plugin marketplace update second-brain` in Claude Code.
2. Update the plugin: `claude plugin update obsidian-dev-second-brain@second-brain` in your shell.
   Or run `/plugin` in Claude Code, open the Installed tab, pick the plugin and choose Update now.
3. Restart Claude Code, so the new hook and `second-brain` command load.
4. Bring the vault up to the new version: run `/odsb:vault-doctor check`, then
   `/odsb:vault-doctor fix`.

What changed in each version, and what to do after it, is in [CHANGELOG.md](CHANGELOG.md). An
update that does not take, and auto-update, are under `## Updating` in `docs/guide.md`.

## Your own skills and agents

Keep skills and agents of your own in the vault: in `claude/` at its root for every project, or in
`<project>/claude/` for one project.

- Add one by the steps under `## Adding a skill or agent` in `templates/vault-claude-hub.md.tmpl`,
  the template of your vault's `claude/README.md`.
- After you add, rename or remove one, run `/odsb:vault-setup link`. What it links into
  `~/.claude`, and what it leaves alone, is under `## link` in `skills/vault-setup/SKILL.md`.

## Pull request descriptions

Claude writes every pull request description in the format of the note `claude/pull-request.md`
in your vault, written from `templates/pull-request.md.tmpl`. Edit that note to change the format.
A project's own `<project>/claude/pull-request.md` wins over it.

## More

- [docs/guide.md](docs/guide.md): what to say to load each skill, updating, the vault layout,
  spec-driven delivery, Windows, the tests and releases.
- [docs/contract.md](docs/contract.md): every helper command and note format.
- [CHANGELOG.md](CHANGELOG.md): what changed in each version.

## License

MIT. See [LICENSE](LICENSE).
