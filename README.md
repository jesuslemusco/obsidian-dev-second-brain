# obsidian-dev-second-brain

A Claude Code plugin that keeps a developer's work in an [Obsidian](https://obsidian.md) vault:
tickets, sprints and project docs, as plain markdown notes that Claude reads and updates for you.
It can also build a story you approve, in a git worktree of its own, tested and reviewed.

## Overview

- **Tickets.** Claude drafts a ticket's text, starts its story, updates it and says where it
  stands. Each ticket is one note, `<project>/tasks/<ID>/README.md`, or
  `<project>/tasks/<status>/<ID>/README.md` in a project that keeps each task in the folder of its
  status. A project that keeps each task in the folder of its sprint has it at
  `<project>/tasks/<sprint folder>/<ID>/README.md`, or `<project>/tasks/backlog/<ID>/README.md`
  in no sprint.
- **Features and epics.** In those two kinds of project, a ticket whose `epic` names another
  ticket sits inside a folder named for that parent, such as
  `<project>/tasks/done/<parent>/<ID>/README.md`. Each project calls its parent stories features
  or epics.
- **Planning.** Claude refines the epics and stories with you, and plans each release's goals,
  epics and stories in the project's planned-releases note. It writes only what you approve.
- **Sprints.** Claude opens a sprint, plans it, and closes it with the open work carried over.
- **Docs.** When a ticket reaches production, `docs-keeper` brings the project's docs in step
  with its code.
- **Builds.** Claude builds each story you approve, test-first, in a git worktree of its own, and
  has a separate reviewer grade it against its acceptance criteria before it waits for your merge.
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

Claude loads most skills when your request matches one, so you seldom type them. You can also
type a skill's name, as in the headings below. Which requests load which skill is under
`## What to say` in `docs/guide.md`.

### `/odsb:story-tracker`

Drafts, starts, updates and recalls tickets, one at a time, and gives a standup.

- Use it for any question or change on a ticket.
- Starting a ticket writes its story: a summary, a description and up to four acceptance
  criteria, checked against the code. It shows you the text first, and writes it once you approve.
- An update adds a dated status note, ticks the criteria that are met and keeps the branch line
  current.
- When work starts on a story you approved, it offers `/odsb:build` to build it.
- A story set to done goes to `docs-keeper`, which brings the project's docs in step.

```
Where does EX-2 stand?
Update EX-2: the sort is merged, move it to in review.
```

### `/odsb:scrum-master`

Refines the stories and plans the sprints and releases with you, and checks the board. It has
four workflows, each a file of its own in `skills/scrum-master/`, read only when it runs.

- `refinement`: drafts or refines an epic and its stories, or one story, with you. Each story has
  a summary, a description, up to four acceptance criteria, its parent and the tasks it waits on.
  It writes nothing until you approve the draft, and shows a change you ask for again first. Then
  story-tracker writes each story.
- `sprint-planning`: opens a sprint, picks its stories, and closes it with the open work carried
  over. A project can run without sprints, as `### Profile frontmatter` in `docs/contract.md`
  says.
- `release-planning`: sets a release's goals, epics and stories with you, in the project's
  planned-releases note, once you approve it. A story or epic that does not exist yet goes through
  refinement first.
- `organize-board`: runs the doctor on the project, says what each failing row means, and changes
  nothing without asking.

```
Refine EX-1 for the Example project: split it into stories.
Plan the 0.2.0 release for the Example project: export the invoices as CSV.
Open a new sprint for the Example project.
/odsb:scrum-master sprint-planning Example
```

### `/odsb:build`

Builds approved stories, each in a git worktree of its own: one at a time, or side by side as
your profile's `build_pairs` sets.

- Give it a story, or an epic: it takes the epic's open stories in the order their dependencies
  set.
- It builds only a story whose text you approved: when story-tracker started it, or in
  refinement, as it is or changed.
- One `implementer` builds each story test-first and checks its own change. Then a `reviewer`
  grades its acceptance criteria and runs the repo's checks, in the same worktree.
- Up to 3 related stories, such as those of one epic, share one `implementer` and one `reviewer`,
  built in turn. Each keeps its own branch and passes or fails on its own review.
- A `build_pairs` key in the profile, 1 to 5, builds that many batches side by side, when none of
  their stories waits on another's. With no key it is 1.
- A failed review sends its defects back to the same `implementer`, in a capped number of rounds.
- A passed story merges where your project's git flow says, written under `## Rules` in its
  Claude hub, only on your go. The checks run on the merged branch, and nothing is pushed
  without your word. Then its worktree is removed, once any ignored file in it is shown to you.
  The branch stays.
- Progress is kept in the story's status notes, so a new session picks the build up where it
  stopped.

The flow is under `## Building a story` in `docs/guide.md`, and its steps are in
`skills/build/story.md`.

```
/odsb:build EX-2
Build the approved stories of EX-1.
```

### `/odsb:vault-setup`

Sets up the vault and its projects, and links your own skills and agents into Claude Code.

- Use it to set up the vault, add a project or a repo, or link your own skills and agents.
- It runs only by name, as `## 9. Skills and agents` in `docs/contract.md` says.
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

### `/odsb:define-validation-scope`

Proposes which checks run at each stage of a repo's validation, from your project's docs or its
code, and writes the repo's section once you approve it.

- Each check it drafts has its command, its stage, `each story`, `each merge` or `release`, and
  the `paths:` it covers, in the shape of `templates/validation-repo.md.tmpl`.
- It reads the project's docs first. A project with none is offered `docs-keeper`'s setup,
  and on a no it reads the repo's test scripts, CI workflows and package manifests.
- It proposes only the stages your project uses: no `release` check in a project that plans no
  releases.
- It shows you the whole draft, and each change you ask for again, and writes the section only
  once you approve it, through `second-brain validation new` for a missing one.
- `vault-setup` offers it when it adds a repo.

```
/odsb:define-validation-scope Example example-api
Define the validation scope of example-api for the Example project.
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
| `docs-keeper` | Keeps a project's docs, in its repos and in the vault, in step with its code. Also audits drift, rewrites renamed commands and drafts the docs of a project that has none. | `story-tracker` when a ticket reaches production, `define-validation-scope` in a project with no docs, `vault-setup` when it adds a project or a repo, `vault-doctor fix` on an `old-namespace` row, or you. |
| `implementer` | Builds one approved story in its git worktree, test-first, runs its checks and commits it. | `build`. |
| `reviewer` | Runs the repo's checks on the branch as a baseline when a build needs one, and grades a story's change. Edits no file and ends with a JSON verdict. | `build`: for the baseline, and after each build and fix of a story. |

## Examples

### Start a ticket

```
Start EX-123: the invoice export drops the tax column.
```

Claude finds no story for EX-123 and checks the repo's branch. It asks you for anything it cannot
tell, and shows you the story's text. Once you approve it, Claude writes
`<project>/tasks/EX-123/README.md`, or `<project>/tasks/planned/EX-123/README.md`
in a project that keeps each task in the folder of its status, or
`<project>/tasks/backlog/EX-123/README.md` in one that keeps it in the folder of its sprint, with a
summary, a description and up to four acceptance criteria, checked against the code. Then Claude
offers `/odsb:build EX-123` to build it.

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

### Build a story

```
/odsb:build EX-123
```

Claude builds the story in `<repo path>-EX-123`, a git worktree next to the repo's folder. After
each review it shows the round, its verdict and its defects. A failed review goes back to the same
`implementer` with its defects, and a passed story waits for your go to merge.

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

### A vault with specs

Version 0.12.0 retires the spec flow: every story is built with `/odsb:build`.

- A story's `spec/` folder and `build.json` stay in its task folder as plain notes, which nothing
  reads. A `delivery` or `spec_home` key left in a note is read by nothing too.
- How to build a story you started from a spec is under `### A vault with specs` in
  `docs/guide.md`.

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

## Story templates

A project can give its stories its own shape. Copy `templates/task-readme.md.tmpl` or
`templates/ticket-description.md.tmpl` into `<project>/claude/templates/` in your vault, under the
same name, and edit it there.

- `second-brain task new` fills the project's README template in place of the plugin's.
- story-tracker fills the project's ticket text template for a draft or ticket text.
- A project with no template of its own gets the plugin's.
- The helper and story-tracker write some frontmatter keys and sections of the README template.
  The doctor's `task-template` check warns when the project's template lacks one.
- What a project's template must keep is under `### A project's own templates` in
  `docs/contract.md`.

## Writing style

Claude writes notes in the style of the note `claude/writing-style.md` in your vault, written from
`templates/writing-style.md.tmpl`. Edit that note to change the style. A project's own
`<project>/claude/writing-style.md` wins over it.

## More

- [docs/guide.md](docs/guide.md): what to say to load each skill, updating, the vault layout,
  planning, building a story, Windows, the tests and releases.
- [docs/contract.md](docs/contract.md): every helper command and note format.
- [CHANGELOG.md](CHANGELOG.md): what changed in each version.

## License

MIT. See [LICENSE](LICENSE).
