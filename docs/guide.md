# Guide

Start with the [README](../README.md). Every helper command and note format is in the
[contract](contract.md).

## What you get

| Piece | Kind | Does |
|---|---|---|
| `story-tracker` | skill | Drafts ticket text, and starts, updates, recalls and lists your tickets. |
| `sprint` | skill | Opens, plans, shows and closes a sprint, and carries work over. |
| `vault-setup` | skill | Sets up a vault, adds or adopts a project, and registers your own skills. |
| `vault-doctor` | skill | Checks the vault and the registration against the standard. |
| `scrum-master` | agent | Runs the sprint cadence across projects through `sprint` and `story-tracker`. |
| `docs-keeper` | agent | Keeps a project's docs in step with its code. |
| `spec` | skill | Writes a story's spec with you, one approved phase at a time, then builds and reviews each task in your session. |
| `implementer` | agent | Builds and commits one task from the context packet it fetches. |
| `reviewer` | agent | Runs the repo's validation steps on a change and reads its diff. Edits no file. |
| `spec-checker` | agent | Reads a spec alone and lists what it could not build from it. Writes no file. |
| `bin/second-brain` | command | The helper the skills call. `second-brain help` lists its commands. |

## What to say

Claude loads a skill when your words match its `description`. Each of these requests loads the
skill next to it:

| You say | Skill |
|---|---|
| For the Example project: give me summary, description and AC for a new ticket, no id. | `story-tracker` |
| Where does EX-2 stand? | `story-tracker` |
| Standup for the Example project: what is in progress, and what comes next? | `story-tracker` |
| Update EX-2: the sort is merged, move it to in review. | `story-tracker` |
| Open a new sprint for the Mobile project. | `sprint` |
| Check my vault for problems. | `vault-doctor` |
| Implement EX-2 spec-driven, starting with its requirements. | `spec` |

- Any skill runs by name: `/odsb:<skill>`.
- `vault-setup` runs only by name, as `## 9. Skills and agents` in `docs/contract.md` says.

## Other ways to install

From a local clone:

```
/plugin marketplace add /path/to/obsidian-dev-second-brain
/plugin install obsidian-dev-second-brain@second-brain
```

For one session without installing: `claude --plugin-dir /path/to/obsidian-dev-second-brain`.

## How it is laid out

- The vault's files are under `## 1. Words and paths` in `docs/contract.md`.
- A project's files are under `## 3. The project` in `docs/contract.md`.
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
  `skills/sprint/close.md` says.
- `second-brain task archive EX-1` archives one task by hand.
- `second-brain doctor --fix` archives each task that is due, as
  `## fix` in `skills/vault-doctor/SKILL.md` says.

## Spec-driven delivery

- Start one with `/odsb:spec EX-2`, or with the request under
  [What to say](#what-to-say).
- You approve each phase or say what to change, as
  `## Step 2 - One phase at a time` in `skills/spec/SKILL.md` says.
- The skill asks one question at a time and shows each draft in short chunks, as
  `## The chat` in `skills/spec/phases.md` says.
- Before you approve the design, and again the tasks, `spec-checker` reads the spec alone and
  lists what it could not build from it. You close each gap first, as
  `## The spec check` in `skills/spec/phases.md` says.
- When work starts on a story with no `delivery` of its own, Claude weighs it. A simple one is
  built direct with no question. For one that needs a spec, Claude asks you. The signs are under
  `## Spec-driven stories` in `skills/story-tracker/SKILL.md`.
- One story is built from a spec with `second-brain task set EX-2 delivery=spec`.
- A project's `delivery` is a fallback, and `spec_home` says where its specs live. Both are under
  `### Profile frontmatter` in `docs/contract.md`.
- `second-brain spec EX-2` prints the story's `delivery`, `spec_home` and the paths of its three
  spec files.
- The spec files' shape is under `## 4. A task` in `docs/contract.md`, such as each task's
  `- Check: <command or step> - expected: <what it prints or shows>` line.
- The doctor's `spec-trace` check names an acceptance criterion that no requirement serves.
- Once you approve the tasks, the story's Approach, Changes and Verification link to the spec.
- The build runs in your session. The `spec` skill launches `implementer` and `reviewer` one at a
  time, and each agent's report comes back to it, so you relay nothing.
- The agents cannot ask you anything. Every question comes through your session.
- Each agent fetches its own packet and replies in a line or two, so your session stays small
  through a long build. `reviewer` reads the task's diff from a file the helper writes.
- A task may name what it provides on `- Provides:` lines. A task that names it on `- Uses:` gets
  those lines in its packet, as `## 4. A task` in `docs/contract.md` says.
- When the build stops, your session shows where it stands and asks you what to do. The cases
  that stop it are in `skills/spec/build.md`.
- `second-brain spec status EX-2` prints where the build stands, one line per task, from
  `build.json` in the story's folder. A new session goes on from there.
- Each task's build and review state, commits, issues and times are in `build.json`, never in the
  story's README. The README keeps the story-level notes, such as the build started or stopped.
- When the last task passes, the story moves to `in-review`.
- Then Claude asks whether to merge the branch into the release branch, open a pull request into
  it, or keep it, as `skills/spec/finish.md` says.

### Validation steps

- The agents read a repo's validation steps before they build or review a change, as
  `### Validation` in `docs/contract.md` says.
- A build does not start on a repo whose steps are missing, as
  `## 2. Ready to build` in `skills/spec/build.md` says.
- `second-brain validation <project>` lists each repo's steps file and its state.
- `second-brain validation <project> <repo>` prints one repo's steps.
- Each repo's steps say how to check a change as a user would, under `### Check as a user would`.
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

- Change `docs/contract.md` first, then the code.
- `.github/workflows/test.yml` runs the suites on Linux, macOS and Windows for every pull request
  to `main`.
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
