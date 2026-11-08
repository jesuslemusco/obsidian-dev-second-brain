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
- Name each launch's model by its role and round:
  - `odsb:implementer`: `model: "opus"`. It builds a task from its packet alone, and takes fix
    rounds 1 to 3.
  - `odsb:implementer` from fix round 4 on: `model: "fable"`, the stronger model.
  - `odsb:reviewer` in task, baseline or user mode: `model: "opus"`.
  - `odsb:reviewer` in branch mode: `model: "fable"`, the most capable model.
- Name each `implementer` launch, so that a fix can reach it again with SendMessage:
  - The build and fix rounds 1 to 3: `name: "<ID>-<task>-implementer"`.
  - From fix round 4 on: `name: "<ID>-<task>-implementer-2"`.
- An agent fetches its own packet. Never run `spec packet` here, and never put a packet, a diff or
  the spec in a prompt.
- `implementer`'s prompt, one line each:
  - `Story: <ID>, project <project>.`
  - `Task: <task>.`
  - `Session: <session id>.`
  - The owner's ruling on this task, when there is one: `Owner: <the ruling, as written>.`
  - Last, the commit line: `Commit it as "<ID> <task>: <title>".`
- The fix message, sent with SendMessage to an `implementer` by its name, one line each:
  - `Fix: the review of <task> failed. Fetch your packet again: its ## Issues lists the findings.`
  - `Session: <session id>.`
  - The `Owner:` line, when there is one.
  - Last, the commit line.
- `reviewer`'s prompt in task mode: `Mode: task.`, then the story, task and session lines, and the
  `Owner:` line when there is one.
- `reviewer`'s prompt in baseline mode: `Mode: baseline.`, `Project: <project>.`,
  `Repo: <repo> at <path>.` and `Branch: <branch>.`
- `reviewer`'s prompt in user mode: `Mode: user.`, the story and session lines,
  `Repo: <repo> at <path>.` and `Branch: <branch>.`
- `reviewer`'s prompt in branch mode: the same lines with `Mode: branch.`, then `Base: <hash>.`:
  the hash of the newest `Build: started on <branch> at <short hash>.` note.

## 4. The baseline

- Skip it when the build resumes.
- Launch `reviewer` in baseline mode on the branch as it is.
- `VERDICT: FAIL` or `VERDICT: BLOCKED`: stop, as `## 7. When the build stops` says.
- `VERDICT: PASS`: `second-brain task note <ID> "Build: the baseline passed at <short hash>."`.

## 5. Each task in turn

Take each task whose review is not `passed`, in the order `spec tasks` lists them. Build it, then
review it right after, before the next task starts. A task that fails holds up the tasks after it
until it passes or the build stops.

### Where the task stands

A resumed build finds each task as an earlier session left it. Go on from its state:

1. Build `todo`: `### Build it`.
2. Build `building`: it was cut off in an earlier session. Look for a commit it made, by its full
   hash: `git -C "<path>" log -1 --format=%H --grep="^<ID> <task>: "`.
   - A hash `spec status` lists under the task is that commit when the full hash starts with it.
   - The full hash starts with no listed hash: that run committed. Run
     `second-brain spec status <ID> <task> built --commit <hash>`, with the hash
     `git -C "<path>" rev-parse --short <full hash>` prints, then `### Review it`.
   - No hash, or one `spec status` lists already: `### The fix loop` when the task's `fails` is 1
     or more, else `### Build it`.
3. Build or review `blocked`: its `Owner:` line is the owner's ruling on it, the status note
   `Build: the owner ruled on <task>: <the ruling, as written>.`, when that note is newer than the
   newest `Build: stopped at <task>: <why>.` note. Status notes are newest first, so it is above.
   - Such a ruling: a review `blocked` goes on at `### Review it`. A build `blocked` goes on at
     `### The fix loop` when the task's `fails` is 1 or more, else at `### Build it`.
   - No such ruling: ask the owner first, as `## 7. When the build stops` says.
4. Review `failed`, with `fails` 5 or less: `### The fix loop`.
   - With `fails` 6 or more the build stopped at the cap. A ruling found as item 3 says sends one
     more round, as for `fails` 4, with the ruling as its `Owner:` line. None: ask the owner first.
5. Build `built`, review `-` or `in-review`: `### Review it`.

### Build it

1. `second-brain spec status <ID> <task> building`.
2. Launch `implementer` on the task, named for the build.
3. Its reply starts with `BLOCKED:`, or names no commit: first the stop note,
   `second-brain task note <ID> "Build: stopped at <task>: <why>."`, then
   `second-brain spec status <ID> <task> blocked`, and stop.
4. Otherwise: `second-brain spec status <ID> <task> built --commit <short hash>`, with the hash
   its reply names. Then `### Review it`.

### Review it

1. `second-brain spec status <ID> <task> in-review`.
2. Launch a fresh `reviewer` in task mode on the task. Its packet gives it the task's diff, or on
   a re-review the fix's commits and the findings they answer.
   - Its reply has a line `VERDICT: PASS`, `VERDICT: FAIL` or `VERDICT: BLOCKED`.
   - No such line: ask it once more with SendMessage. Still none: stop.
3. Show the owner `second-brain spec status <ID>`.
4. PASS: `second-brain spec tick <ID> <task>`. Exit 6 means it is ticked already: go on.
   - With `spec_home: repo`, commit the tick:
     `git -C "<path>" commit -m "<ID> <task>: passed review" -- spec/<ID>/tasks.md`.
   - Then `second-brain spec status <ID> <task> passed`, and go on to the next task.
5. BLOCKED: first the stop note,
   `second-brain task note <ID> "Build: stopped at <task>: <why>."`, then
   `second-brain spec status <ID> <task> blocked`, and stop.
6. FAIL: `second-brain spec status <ID> <task> failed`, then `### The fix loop`.

### The fix loop

The task's `fails` in `spec status <ID>` is its failed reviews in `build.json`, from every session.
It picks the round. Never count the rounds yourself.

1. `fails` 6 or more, right after a FAIL: the cap is reached. First the stop note,
   `second-brain task note <ID> "Build: stopped at <task>: <why>."`, then stop. The review stays
   `failed`.
   - A ruling the owner gives at that stop sends one more round, as for `fails` 4, with the
     ruling as its `Owner:` line.
2. Otherwise, `second-brain spec status <ID> <task> building`, then the round:
   - `fails` 1 to 3: the same `implementer`. Send the fix message to
     `<ID>-<task>-implementer`, and wait for its reply.
   - SendMessage is not there, or no agent has that name, as in a new session: launch a fresh
     `implementer` in its place, with the build's prompt, name and model.
   - `fails` 4: launch a fresh `implementer` on the stronger model, named from round 4 on, with
     the build's prompt.
   - `fails` 5: send the fix message to `<ID>-<task>-implementer-2`, or launch a fresh one as for
     `fails` 4 when it cannot be reached.
   - `fails` 6 or more, on a ruling: as for `fails` 4, with the ruling as its `Owner:` line.
3. Take its reply as items 3 and 4 of `### Build it` say. Its review then reads only the fix.

## 6. When every task passed

A resumed build with every task passed comes straight here.

1. Run the build-wide checks once, with no agent:
   `second-brain validation run "<project>" <repo> --when each-build`.
   - Every row passes or is skipped: go on to item 2.
   - A `fail` row: find the task whose files it covers, the one whose `- Files:` line in
     `tasks.md` holds the code its lines name or test. Several: the last of them in order.
   - No task you can tell: stop, as `## 7. When the build stops` says.
   - Log each failing row on its task:
     `second-brain spec issue <ID> <task> "<command> fails in the build-wide run, exit <code>: <its lines>" --fix "<the fix you propose>"`.
   - Then `second-brain spec status <ID> <task> failed` for each such task, and go back to
     `## 5. Each task in turn`. It comes back here once every task has passed again.
2. Launch `reviewer` in user mode on the finished branch. FAIL or BLOCKED: stop, as
   `## 7. When the build stops` says.
3. Launch `reviewer` in branch mode: one review of the whole branch ends the build. FAIL or
   BLOCKED: stop, as `## 7. When the build stops` says.
4. `second-brain task set <ID> status=in-review next="Owner reviews the built story"`.
5. `second-brain task note <ID> "Build: finished; every task passed review, the branch is at <short hash>."`.
6. Show the owner `second-brain spec status <ID>` and the final validation result.
7. Read `finish.md`, next to this file, and follow it. The story is `in-review`: story-tracker
   takes it from there.

## 7. When the build stops

1. Show the owner `second-brain spec status <ID>`, the task that stopped the build, and why: the
   agent's reply, and the issues `spec status` lists under the task.
   - A stop in `## 6. When every task passed` names its step in place of the task: the
     build-wide checks, the user check or the branch review.
2. `second-brain task note <ID> "Build: stopped at <task>: <why>."`, unless a block wrote it
   already. A block writes it before it sets `blocked`, so a new session never takes an older
   ruling for this stop.
3. Ask the owner with AskUserQuestion what to do.
   - A ruling on the task:
     `second-brain task note <ID> "Build: the owner ruled on <task>: <the ruling, as written>."`.
     Then go on from the step that stopped, with the ruling as the `Owner:` line of the next
     prompt for that task.
   - A ruling to fix a task the user check or the branch review logged issues on: the same note,
     then `second-brain spec status <ID> <task> failed`, and back to `## 5. Each task in turn`,
     with the ruling as its `Owner:` line.
   - The spec needs a change: write `Spec: <phase> reopened.` as a status note, then go back to
     Step 2 of `SKILL.md` for that phase.
     - The owner approves the phases after it again too. Only then does the build go on.
   - The owner stops here: `build.json` keeps where the build stands, and a new session goes on
     from it.

## Rules

- You keep track of the build: set each state with `spec status` as the agents report it.
- A task's progress is in `build.json` alone. The README gets the story-level notes above: the
  build started, stopped and why, and finished, and each ruling.
- Only a reviewer's `VERDICT: PASS` ticks a task. Never on the implementer's word.
- The packet is the implementer's whole context. Never give it the other tasks or this
  conversation.
- Never skip, merge or reorder tasks.
- One agent at a time: wait for each agent's result or reply before the next step.
- Run a `release` check only when the owner asks:
  `second-brain validation run "<project>" <repo> --when release`.
- Write no code, and commit nothing but the spec files and the ticks of a `spec_home: repo` spec.
