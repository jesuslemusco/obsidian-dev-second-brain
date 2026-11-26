# Guide

Start with the [README](../README.md). Every helper command and note format is in the
[contract](contract.md).

## What you get

- The skills are under [Commands](../README.md#commands) in the README, and the agents under
  [Agents](../README.md#agents).
- `bin/second-brain` is the helper the skills call. `second-brain help` lists its commands.

## What to say

Claude loads a skill when your words match its `description`. Each of these requests loads the
skill next to it:

| You say | Skill |
|---|---|
| For the Example project: give me summary, description and AC for a new ticket, no id. | `story-tracker` |
| Where does EX-2 stand? | `story-tracker` |
| Standup for the Example project: what is in progress, and what comes next? | `story-tracker` |
| Update EX-2: the sort is merged, move it to in review. | `story-tracker` |
| Refine EX-2 for the Example project: split it into two stories. | `scrum-master` |
| Plan the 0.2.0 release for the Example project: export the invoices as CSV, in three stories. | `scrum-master` |
| Open a new sprint for the Mobile project. | `scrum-master` |
| Organize the board of the Example project. | `scrum-master` |
| Check my vault for problems. | `vault-doctor` |
| Build the approved stories of EX-1. | `build` |

- Any skill runs by name: `/odsb:<skill>`.
- `vault-setup` runs only by name, as `## 9. Skills and agents` in `docs/contract.md` says.

## Other ways to install

From a local clone:

```
/plugin marketplace add /path/to/obsidian-dev-second-brain
/plugin install obsidian-dev-second-brain@second-brain
```

For one session without installing: `claude --plugin-dir /path/to/obsidian-dev-second-brain`.

## Updating

The steps are under [Update](../README.md#update) in the README.

- `claude plugin list` shows your version. Compare it with the newest section of
  [CHANGELOG.md](../CHANGELOG.md).
- When nothing is newer, `claude plugin update` prints `already at the latest version`.
- `/reload-plugins` loads new skills and agents into an open session. Only a restart is sure to
  load a new session-start hook and `second-brain` command.

### When an update does not take

If `claude plugin list` still shows the old version after the refresh and the update, uninstall
the plugin and install it again:

```
claude plugin uninstall obsidian-dev-second-brain@second-brain
claude plugin install obsidian-dev-second-brain@second-brain
```

Your vault and notes are not touched. Then restart Claude Code and run the doctor's `check` and
`fix`.

### Auto-update

- Auto-update is off for a marketplace you added yourself.
- To turn it on, run `/plugin` in Claude Code, open the Marketplaces tab, pick `second-brain` and
  choose Enable auto-update.
- Claude Code then updates the plugin in the background, and the next session starts on the new
  version.
- It runs no doctor. After a release that changes the vault, run the doctor's `check` and `fix`.

## How it is laid out

- The vault's files are under `## 1. Words and paths` in `docs/contract.md`.
- A project's files are under `## 3. The project` in `docs/contract.md`.
- Claude writes notes in the style of the vault's `claude/writing-style.md`. A project's own
  `<project>/claude/writing-style.md` wins.
- A task names what it is about with topic tags, and never sits in the topic's folder, as
  `## The short version` in `templates/obsidian-conventions.md.tmpl` says.
- An existing project keeps its folders. `/odsb:vault-setup adopt <path>`
  records them in its profile, as
  `## 2. Scaffold only what is missing` in `skills/vault-setup/adopt.md` says.
- A subproject is one note, as `### Subprojects` in `docs/contract.md` says.
- A story started in a subproject's repo gets that subproject. Elsewhere Claude asks which one, if
  any, as `## 3. Create the story` in `skills/story-tracker/create.md` says.
- In a subproject's repo the status overview lists that subproject's tasks.
- The board's `By subproject` view groups the tasks by subproject.
- A rule you ask Claude to save goes where it applies, as
  `## 2. The index` in `docs/contract.md` says.
- The doctor's `global-rules` check warns about a line of `~/.claude/CLAUDE.md` that names a
  project.
- The doctor's `foreign` check warns about a skill or agent in `~/.claude/skills` or
  `~/.claude/agents` that no vault `claude/` folder provides.
- `/odsb:vault-doctor fix` asks where each one goes, the vault's `claude/` or a project's, and
  moves it there, as `## fix` in `skills/vault-doctor/SKILL.md` says.
- To run a project without sprints, say so when `vault-setup` sets it up, as
  `## project <name>` in `skills/vault-setup/SKILL.md` says.
- Tell Claude a story waits on another task, and it runs `second-brain task dep EX-2 add EX-1`.
- The board shows the tasks a story waits on in its `Depends on` column.
- The status overview flags a story in progress that waits on a task not done, as
  `## Render` in `skills/story-tracker/status.md` says.
- The doctor's `depends-on` check warns about a link to no task, and about tasks that wait on each
  other in a ring.

### Archived tasks

- `task_layout: archive` in the profile lets a done or abandoned task move once to
  `tasks/archive/<year>/<ID>/`. The keys are under `### Profile frontmatter` in `docs/contract.md`.
- `vault-setup` asks for the layout when it sets up or adopts a project, as
  `## project <name>` in `skills/vault-setup/SKILL.md` says.
- When a story is set done, Claude asks once whether to archive it now, as
  `## Edit an existing story` in `skills/story-tracker/SKILL.md` says.
- When a sprint closes, Claude asks once whether to archive its done tasks, as
  `## Close` in `skills/scrum-master/sprint-planning.md` says.
- `second-brain task archive EX-1` archives one task by hand.
- `second-brain doctor --fix` archives each task that is due, as
  `## fix` in `skills/vault-doctor/SKILL.md` says.

### Status folders

- `task_layout: status` in the profile keeps each task in the folder of its status: `planned`,
  `in-progress`, `in-review`, `done` or `abandoned`, as `## 4. A task` in `docs/contract.md` says.
- A new story starts in `tasks/planned/<ID>/`.
- When its status changes, `second-brain task set` moves the folder to `tasks/<status>/<ID>/`, and
  every link to it follows. Nothing is archived, so Claude asks nothing.
- When a sprint closes, each task it abandons moves to `tasks/abandoned/<ID>/`.
- A status edited in the board moves nothing: `second-brain doctor --fix` moves each task to the
  folder of its status.
- To switch a project that has tasks, set the key, then run `second-brain doctor --fix` once.
  Every run also removes the archive's empty folders, and each empty folder directly under the
  tasks root other than the five status folders, such as an empty `backlog/`, a sprint's folder or
  a task folder with no README there, whether or not a move emptied it. An empty status folder
  stays, and so does an empty folder inside one, such as `planned/<ID>/`.

### Sprint folders

- `task_layout: sprint` in the profile keeps each task in the folder of its sprint, and a task in
  no sprint in `tasks/backlog/<ID>/`, as `## 4. A task` in `docs/contract.md` says. It needs a
  project that runs sprints.
- A sprint's folder is named by `sprint_folder` in the profile: by default its end date, as in
  `tasks/2026-10-14/`, or a pattern such as `sprint-<n>`, as `### Profile frontmatter` in
  `docs/contract.md` says.
- A new story starts in `tasks/backlog/<ID>/`.
- When it joins a sprint, `second-brain task set` moves the folder to that sprint's folder, and
  every link to it follows. When it leaves, the folder goes back to `tasks/backlog/<ID>/`.
- When a sprint opens, each task it re-points to the new sprint moves to that sprint's folder.
- When a sprint closes, each carried task moves to the next sprint's folder, and each task sent to
  the backlog to `tasks/backlog/<ID>/`. Done and abandoned tasks stay where they are.
- A sprint edited in the board moves nothing: `second-brain doctor --fix` moves each task to the
  folder of its sprint.
- To switch a project that has tasks, or to rename the folders with a new `sprint_folder`, set the
  key, then run `second-brain doctor --fix` once. It also removes each empty group folder, a
  status folder too, whether or not a move emptied it.

### Feature and epic folders

- A child task is one whose `epic` names another task, its parent. A project calls its parent
  stories features or epics, as `parent_label` in its profile says.
- Tell Claude a story belongs to EX-1, and it runs `second-brain task set EX-2 epic=EX-1`.
- In a status or sprint project, a child sits inside a folder named for its parent, in the folder
  of its own status or sprint, such as `tasks/backlog/EX-1/EX-2/` or `tasks/done/EX-1/EX-2/`, as
  `## 4. A task` in `docs/contract.md` says. In a flat or archive project nothing moves.
- The parent's own note stays where its own status or sprint puts it. A child that joins a sprint
  moves to `tasks/<sprint folder>/EX-1/EX-2/` while EX-1 stays in `tasks/backlog/EX-1/`.
- A parent's move takes its own files alone. A parent done or abandoned leaves its open children
  where they are, and every command still finds them.
- A child's own move removes the folder named for its parent that it leaves empty.
- `second-brain doctor --fix` moves a child that is outside its parent's folder. It leaves one
  whose `epic` names no single task where it is, and the doctor names it.
- `vault-setup` asks whether a project calls its parent stories features or epics, as
  `## project <name>` in `skills/vault-setup/SKILL.md` says. The word changes labels only: the key
  in a task's frontmatter stays `epic`.

## Planning

- The `scrum-master` skill plans with you. It has four workflows, each a file of its own, read only
  when it runs: `refinement`, `sprint-planning`, `release-planning` and `organize-board`. Its
  `SKILL.md` routes each request to one of them.
- Ask for an epic and its stories, or one story, as under [What to say](#what-to-say), and
  `refinement` drafts them with you, in story-tracker's shape, with at most four acceptance
  criteria, its parent and the tasks it waits on, as `## 2. The draft` in
  `skills/scrum-master/refinement.md` says.
- It shows you the draft in short chunks and writes nothing until you approve it. A change you ask
  for is shown again first, as `## 3. The approval` in `skills/scrum-master/refinement.md` says.
- Then story-tracker writes each story, and the skill links each one to the tasks it waits on
  with `second-brain task dep`.
- A ticket you start with no story is shown to you the same way before story-tracker writes it.
- Before story-tracker writes a new story, yours or one from refinement, it shows each story that
  already does the same, with its status, and the open epics the story could join, with the one
  it proposes. You pick: change the story that exists, file the new one under an epic, or write
  it on its own, as `## 3. Create the story` in `skills/story-tracker/create.md` says.
- `sprint-planning` opens a sprint, picks its stories and closes it with carry-over, as
  `## Open`, `## Pick` and `## Close` in `skills/scrum-master/sprint-planning.md` say.
- `release-planning` keeps each release's goals, epics and stories in `planned-releases.md`, in
  the project's topics root, `docs/` by default. Its shape is under `### Planned releases` in
  `docs/contract.md`. A story or epic that does not exist yet goes through `refinement` first.
- `organize-board` runs the doctor on the project and says what each failing row means. It changes
  nothing without asking. `/odsb:vault-doctor fix` makes the repairs.

## Building a story

- Build one with `/odsb:build EX-2`, or an epic's stories with `/odsb:build EX-1`, or with the
  request under [What to say](#what-to-say).
- Only a story whose text you approved is built. story-tracker writes the note that says so when
  it starts a story, and refinement has it written on each story you approve, new or not, as
  Step 2 of `skills/build/SKILL.md` says.
- Each story is built in a git worktree of its own, next to the repo's folder. The
  `implementer` and the `reviewer` work there, and the checks run there:
  `second-brain validation run <project> <repo> --path <worktree>`.
- `implementer` builds the story test-first, and checks its whole change against the story's
  criteria and the reviewer's list of defects before it commits.
- A fresh `reviewer` then grades each acceptance criterion, runs the repo's `each build` checks
  and user steps, and grades the code. A defect fails the story. A follow-up does not: the build
  lists it for you when it finishes or stops.
- A failed review goes back to the same `implementer`, for at most five fix rounds, the last two
  on a stronger model, as `### The fix loop` in `skills/build/story.md` says.
- Once the build has started, Claude asks you only for the short list under
  `## 8. When to ask the owner` in `skills/build/story.md`.
- A passed story merges where your project's git flow says, as you write it under `## Rules` in
  the project's `claude/README.md`, such as into the open `release/<version>`. With none written,
  Claude asks you, and offers to write your answer there.
- The merge is local, and only on your go. A conflict where both sides only add lines keeps both.
  Any other is shown to you. The checks run on the merged branch, and Claude pushes only on your
  word, as `### The merge` in `skills/build/story.md` says.
- Once the merge is done, or you say not to merge, the story's worktree is removed, after Claude
  shows you any ignored file in it, such as a `.env`. The branch stays.
- Progress is kept in the story's status notes, so a new session goes on where the build stopped.
- Once the build has started, Claude settles any other question itself, such as a criterion an
  agent reads two ways, and records it as a status note,
  `Ruling: <the question> - <the decision and why>`. Each ruling goes into the next prompts, so no
  review flags what was decided.
- `reviewer` grades each check as met or not, with its evidence, and ends its reply with a JSON
  verdict. The skill reads that verdict, and a PASS with an open defect never counts, as
  `### Reading a verdict` in `skills/build/story.md` says.
- A review sorts each finding as a defect, which fails the story, or a follow-up, which does not.
  A name that misleads, repeated code or code against the conventions around it is a follow-up,
  unless it is a defect in another way, such as one a user would hit or a rule of the repo names.
  `## Defects and follow-ups` in `agents/reviewer.md` draws the line.
- When the build finishes or stops, it lists the rulings and the follow-ups so far, and you can
  have one fixed then.
- A build writes your open orders to `claude/lead-agent-task-memory.md` in the project's folder of
  your vault, with a line in the project's `claude/README.md`, and removes both once no order is
  open, as `## The owner's open orders` in `skills/build/lead.md` says.
- While one is open, it runs a check in your session, as often as `lead_check_minutes` in the
  project's profile says, as `## The lead's check` in `skills/build/lead.md` says.
- Each order has a `Done when:` line, a condition a command, a file or a branch state can test.
  Claude writes it from your words, and asks you only when they give none. The check closes an
  order when its condition holds, and only you change a condition.

### A vault with specs

Version 0.12.0 retires the spec flow. A story is built one way: from its README, with
`/odsb:build`. What the spec flow left in a vault stays where it is.

- A story's `spec/` folder and `build.json` stay in its task folder, as plain notes and files of
  the task. No command reads them, a move takes them with the task, and no doctor check is about
  them, as `## 4. A task` in `docs/contract.md` says.
- A spec kept in a repo, in `spec/<ID>/`, stays there too. Delete it in a commit of your own when
  you no longer want it.
- A `delivery` or `spec_home` key in a profile, a subproject note or a task is read by nothing,
  and the doctor's `settings` check does not name it. Remove it when you like.
- To build a story you started from a spec, read its spec for what the README lacks, and bring
  its criteria into the README through `/odsb:scrum-master refinement`. Once you approve the text,
  run `/odsb:build <ID>`.
- The vault's conventions note is at version 11, with no `spec` note type and no `delivery` key.
  The doctor's `conventions` check warns about an older one.

### Validation steps

- The agents read a repo's validation steps before they build or review a change, as
  `### Validation` in `docs/contract.md` says.
- A build does not start on a repo whose steps are missing, as item 4 of
  `## 2. The worktree` in `skills/build/story.md` says.
- `second-brain validation <project>` lists each repo's steps file and its state.
- `second-brain validation <project> <repo>` prints one repo's steps.
- Each repo's steps say how to check a change as a user would, under `### Check as a user would`.
- Each check and user step ends with when it runs: `when: each task`, `when: each build` or
  `when: release`, as `### Validation` in `docs/contract.md` says. A `release` one runs only when
  you ask.
- `second-brain validation run <project> <repo> --when each-task` runs the matching checks one at a
  time, each stopped after `--timeout` seconds, and prints a row per check. Its form is under
  `## 7. The helper` in `docs/contract.md`.
- Each of those steps starts with its tool, which `reviewer` runs as `## 9. Skills and agents`
  in `docs/contract.md` says.
- The plugin ships no browser. Name the browser skill or command your repo uses.
- The doctor's `validation` check names a repo whose steps are missing or still the template's
  text.

## On Windows

- Claude Code and the helper run in Git Bash, which comes with Git for Windows. PowerShell alone is
  not enough.
- The links are directory junctions, which need no administrator rights and no Developer Mode.
- Keep only agents in a `claude/agents` folder: it is linked whole, so Claude Code reads every `.md`
  file in it.
- Keep the vault on a local drive. A vault on a network share cannot be linked.
- A path you give may use backslashes. The helper prints an absolute path as `C:/...`.
- Write a path inside the vault, and a repository location in a profile, with forward slashes.
- How the links work on Windows is under `### link, doctor, snapshot` in `docs/contract.md`.

## Why it is cheap to run

- Claude always loads one short index. The doctor's `always-loaded-size` check warns when it grows.
- A skill reads only the file of the mode in use, and notes are read cheapest first, as
  `## 9. Skills and agents` in `docs/contract.md` says.

## What it does not do

- It never calls Obsidian: the helper works on the files.
- It does not talk to your ticket tracker or to any live system.
- It moves or renames a note only when you ask. What a move does to links is under
  `### Links between notes` in `docs/contract.md`.
- It supports one vault per machine.

## Development

From the repo root:

```
bash scripts/test.sh
bash scripts/test-link.sh
bash scripts/test-graph.sh
bash scripts/test-doctor.sh
bash scripts/test-snapshot.sh
bash scripts/leak-check.sh
claude plugin validate . --strict
```

- `scripts/test.sh` runs each area file in `scripts/tests/` and prints one total. Each area builds
  its own scratch vault, so one runs alone: `bash scripts/test.sh tasks` runs `tasks.sh`.
- The areas run in parallel, one per processor, and print in area order.
  `SECOND_BRAIN_TEST_JOBS=1 bash scripts/test.sh` runs them one at a time.
- A new check goes in the area of the command it tests. The helpers and fixtures the areas share
  are in `scripts/tests/lib.sh`.
- The fixtures in `scripts/tests/lib.sh` and `scripts/tests/generated.sh` copy the commands of the
  sections that write the vault. A change to what such a section writes goes into those copies too.
- `bash scripts/test-doctor.sh --shard 2/4` runs the second of four shards of the doctor tests.
  The shards together run each case once.
- A new block follows the comment above `block()` in `scripts/test-doctor.sh`.
- Change `docs/contract.md` first, then the code.
- `.github/workflows/test.yml` runs the suites on Linux, macOS and Windows for every pull request
  to `main`.
- It runs the doctor tests as four shards, each a job of its own, beside one job for the other
  suites.
- On Windows the suites build symlinks as fixtures, which takes Developer Mode or an elevated
  shell.
- `scripts/e2e-claude.sh` runs Claude Code itself on a scratch vault. It fails when a request under
  [What to say](#what-to-say) does not load its skill.
- It costs API usage, so `.github/workflows/e2e.yml` runs only when started from the Actions tab.
- A request that fails is fixed in the skill's `description`, in the user's words, never in the
  request.

## Releases

Claude Code updates an installed plugin only when `version` in `.claude-plugin/plugin.json`
changes. So `version` changes in one commit only, at the end of a release.

- A release starts with a `release/<version>` branch cut from `main`, such as `release/0.3.0`.
- A feature branch is cut from `main` and merges into the release branch.
- A story that needs another story's code not yet in `main` is cut from that story's branch. It
  merges into the release branch after that story.
- Every release has a section in `CHANGELOG.md`, written as the feature branches merge.
- Neither a feature branch nor the release branch changes `version`.
- One pull request takes the release branch into `main`.
- After it is merged, one commit on `main` sets `version` and dates the changelog section:
  `## 0.3.0 - unreleased` becomes `## 0.3.0 - 2026-10-21`, with the release date.
- Tag that commit `v<version>`, as in `git tag v0.3.0`, and push the tag.

A user updates with the steps in the [README](../README.md#update).
