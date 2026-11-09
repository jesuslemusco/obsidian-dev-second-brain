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
- Each agent fetches its own packet and replies in a few short lines, so your session stays small
  through a long build. `reviewer` reads the task's diff from a file the helper writes.
- Each task is reviewed right after it is built, before the next one starts, so no task builds on
  an unreviewed one. The review reads the task's diff, against its requirements first, then for
  code quality.
- Before the first task, the baseline runs the repo's checks on the branch as it is, so a break
  already there is not taken for a task's. It is skipped when the branch starts on the base
  branch, which is tested already, and when a build resumes, as `## 4. The baseline` in
  `skills/spec/build.md` says.
- Small, alike tasks may form a bundle, which you approve with the task list. A bundle's tasks go
  to one `implementer` run, one commit per task, then one review, before the next task starts, as
  `### A bundle` in `skills/spec/build.md` says.
- `second-brain spec tasks EX-2` prints each task's bundle in its last column.
- `implementer` builds each task test-first. It writes a test that fails for the task's
  requirement, then makes it pass. A task with nothing to test, such as a doc change, says why.
- Who runs which check: `implementer` runs the task's `Check` and the repo's `each task` checks
  before it commits, as its packet's `## Checks` names them. It commits only when they pass, and
  its reply names each result. A step it has no tool for, such as a browser step, is left to the
  review.
- `reviewer` runs those checks again in the task's review, with the `each task` user steps.
- `reviewer` grades each check as met or not, with its evidence, and ends its reply with a JSON
  verdict. The skill reads that verdict, and a PASS with an open finding never counts, as
  `### Reading a verdict` in `skills/spec/build.md` says.
- A task that fails goes back to its `implementer` with the findings, in a fix loop of at most five
  rounds, the last two on a stronger model. The rounds are counted in `build.json`, so a new
  session counts on. `## 5. Each task in turn` in `skills/spec/build.md` holds the loop.
- When every task has passed, the helper runs the repo's checks once, with no agent. Then one
  review runs the user steps and one, on the most capable model, reads the whole branch, as
  `## 6. When every task passed` in `skills/spec/build.md` says.
- A task may name what it provides on `- Provides:` lines. A task that names it on `- Uses:` gets
  those lines in its packet, as `## 4. A task` in `docs/contract.md` says.
- Once the build has started, it stops and asks you only for a short list: a destructive action,
  a security-sensitive one, an outside effect such as a push, a merge or a publish, a spec too
  broken to follow, a task blocked or past its last fix round, and a failed baseline. The list is
  under `## 8. When to ask the owner` in `skills/spec/build.md`.
- Any other question, such as an ambiguous requirement or two agents that disagree, the skill
  decides itself. It records each as a status note,
  `Ruling: <task>: <the question> - <the decision and why>`.
- Each ruling, and each answer you give on a task, goes as written into that task's next
  `implementer` and `reviewer` prompts, so no review flags what was decided.
- When the build stops, your session shows where it stands, lists the build's rulings and asks
  you what to do. When it finishes, it lists them too. You can reopen the phase a ruling touched,
  or reverse the ruling.
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
