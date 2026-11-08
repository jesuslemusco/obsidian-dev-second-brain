# Building the approved tasks

Read this file only when all three approvals count, as Step 1 of `SKILL.md` says. The build runs
in this session: you launch `implementer` and `reviewer` yourself, and each one's report comes back
to you as its result.

- `<path>` is the repo's path and `<branch>` the story's branch, as `## 2. Ready to build` finds
  them.
- `<session id>` is the session id for notes in `SKILL.md`. Every `task note`, `spec status` and
  `spec issue` takes `--session <session id>`.
- `<short hash>` is what `git -C "<path>" rev-parse --short HEAD` prints.

## 1. Where the build stands

1. Show the owner `second-brain spec status <ID>` as it prints.
   - It prints nothing: the build has not started.
   - It prints a line: the build resumes, from the states `build.json` in the story's folder
     holds.
2. `second-brain spec tasks <ID>` must list a task. None: say so and stop.

## 2. Ready to build

1. Check the branch as `## Branch check (start, update, recall)` in
   `skills/story-tracker/SKILL.md` says.
   - The repo is the one `second-brain spec <ID>` names, at the path
     `second-brain repo <project> <repo>` prints.
   - The branch is the story's `branch`, from `second-brain task head <ID>`.
   - No branch yet: ask, then cut it as the branch check says, named by `branch_pattern`.
     Record it with `second-brain task set <ID> branch=<branch>`.
2. The repo must be on that branch, with nothing uncommitted but the spec files of a
   `spec_home: repo` spec.
   - On another branch: ask, then `git -C "<path>" switch <branch>`.
   - Never stash or discard the owner's changes: ask them to.
3. `spec_home: repo`, with `spec/<ID>` not yet committed: commit the spec files on the story's
   branch, `git -C "<path>" add spec/<ID>` and `git -C "<path>" commit -m "<ID>: spec"`.
4. `second-brain validation <project> <repo>` must print the repo's steps, with no `<...>` text
   left.
   - Otherwise offer `/odsb:vault-setup validation <project>` and stop.
5. `second-brain task set <ID> status=in-progress next="The spec skill builds the approved tasks"`.
6. A new build: `second-brain task note <ID> "Build: started on <branch> at <short hash>."`.
   - A resumed one: `second-brain task note <ID> "Build: resumed on <branch> at <short hash>."`.

## 3. Launching an agent

- Launch one agent at a time with the Agent tool, and wait for its result. Its result is its
  report: never relay a report by hand, and never read an agent's transcript.
- Name each launch's model by role:
  - `odsb:implementer`: `model: "opus"`. It builds a task from its packet alone.
  - `odsb:reviewer`, in either mode: `model: "opus"`. It judges the change and runs every check.
- An agent fetches its own packet. Never run `spec packet` here, and never put a packet, a diff or
  the spec in a prompt.
- `implementer`'s prompt, one line each:
  - `Story: <ID>, project <project>.`
  - `Task: <task>.`
  - `Session: <session id>.`
  - The owner's ruling on this task, when there is one: `Owner: <the ruling, as written>.`
  - Last, the commit line: `Commit it as "<ID> <task>: <title>".`
- `reviewer`'s prompt in task mode: `Mode: task.`, then the story, task and session lines, and the
  `Owner:` line when there is one.
- `reviewer`'s prompt in baseline mode: `Mode: baseline.`, `Project: <project>.`,
  `Repo: <repo> at <path>.` and `Branch: <branch>.`

## 4. The baseline

- Skip it when the build resumes.
- Launch `reviewer` in baseline mode on the branch as it is.
- `VERDICT: FAIL` or `VERDICT: BLOCKED`: stop, as `## 7. When the build stops` says.
- `VERDICT: PASS`: `second-brain task note <ID> "Build: the baseline passed at <short hash>."`.

## 5. Build every task

For each task whose build is `todo` or `building`, in the order `spec tasks` lists them:

1. A `building` task was cut off in an earlier session. Look for its commit:
   `git -C "<path>" log -1 --format=%h --grep="^<ID> <task>: "`.
   - It prints a hash: `second-brain spec status <ID> <task> built --commit <hash>`, then go to
     item 6.
2. `second-brain spec status <ID> <task> building`.
3. Launch `implementer` on the task.
4. Its reply starts with `BLOCKED:`, or names no commit:
   `second-brain spec status <ID> <task> blocked`, and stop.
5. Otherwise: `second-brain spec status <ID> <task> built --commit <short hash>`, with the hash
   its reply names.
6. Show the owner `second-brain spec status <ID>`.

## 6. Review every task

Then, for each task whose review is not `passed`, in the same order:

1. `second-brain spec status <ID> <task> in-review`.
2. Launch `reviewer` in task mode on the task.
   - Its reply has a line `VERDICT: PASS`, `VERDICT: FAIL` or `VERDICT: BLOCKED`.
   - No such line: ask it once more with SendMessage. Still none: stop.
3. PASS: `second-brain spec tick <ID> <task>`. Exit 6 means it is ticked already: go on.
   - With `spec_home: repo`, commit the tick:
     `git -C "<path>" commit -m "<ID> <task>: passed review" -- spec/<ID>/tasks.md`.
   - Then `second-brain spec status <ID> <task> passed`.
4. BLOCKED: `second-brain spec status <ID> <task> blocked`, and stop.
5. FAIL: `second-brain spec status <ID> <task> failed`.
   - Retry the task: `second-brain spec status <ID> <task> building`, then launch `implementer`
     on it again. Its packet now holds the issues the reviewer logged.
   - Take its reply as items 4 and 5 of `## 5. Build every task` say, then review it again from
     item 1.
   - At most two retries for a task. Still FAIL: stop.
6. Show the owner `second-brain spec status <ID>`.

A task that fails holds up the review of the tasks after it until it passes or the build stops.

## 7. When the build stops

1. Show the owner `second-brain spec status <ID>`, the task that stopped the build, and why: the
   agent's reply, and the issues `spec status` lists under the task.
2. `second-brain task note <ID> "Build: stopped at <task>: <why>."`.
3. Ask the owner with AskUserQuestion what to do.
   - A ruling on the task:
     `second-brain task note <ID> "Build: the owner ruled on <task>: <the ruling, as written>."`.
     Then go on from the step that stopped, with the ruling as the `Owner:` line of the next
     prompt for that task.
   - The spec needs a change: write `Spec: <phase> reopened.` as a status note, then go back to
     Step 2 of `SKILL.md` for that phase.
     - The owner approves the phases after it again too. Only then does the build go on.
   - The owner stops here: `build.json` keeps where the build stands, and a new session goes on
     from it.

## 8. When every task passed

A resumed build with every task passed comes straight here.

1. Launch `reviewer` in baseline mode once more, on the finished branch. FAIL or BLOCKED: stop, as
   `## 7. When the build stops` says.
2. `second-brain task set <ID> status=in-review next="Owner reviews the built story"`.
3. `second-brain task note <ID> "Build: finished; every task passed review, the branch is at <short hash>."`.
4. Show the owner `second-brain spec status <ID>` and the final validation result.
5. Read `finish.md`, next to this file, and follow it. The story is `in-review`: story-tracker
   takes it from there.

## Rules

- You keep track of the build: set each state with `spec status` as the agents report it.
- A task's progress is in `build.json` alone. The README gets the story-level notes above: the
  build started, stopped and why, and finished, and each ruling.
- Only a reviewer's `VERDICT: PASS` ticks a task. Never on the implementer's word.
- The packet is the implementer's whole context. Never give it the other tasks or this
  conversation.
- Never skip, merge or reorder tasks.
- One agent at a time: wait for each agent's result before the next step.
- Write no code, and commit nothing but the spec files and the ticks of a `spec_home: repo` spec.
