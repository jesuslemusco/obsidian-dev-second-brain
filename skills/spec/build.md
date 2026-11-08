# Building the approved tasks

Read this file only when all three approvals count, as Step 1 of `SKILL.md` says. The build runs
in this session: you launch `implementer` and `reviewer` yourself, and each one's report comes back
to you as its result.

- `<path>` is the repo's path and `<branch>` the story's branch, as `## 2. Ready to build` finds
  them.
- `<session id>` is the session id for notes in `SKILL.md`. Every `task note`, `spec status` and
  `spec issue` takes `--session <session id>`.
- `<short hash>` is what `git -C "<path>" rev-parse --short HEAD` prints.
- `<start>` is where the branch starts: the `<short hash>` that item 2 of `## 2. Ready to build`
  notes, before a spec is committed.
- Once the build has started, ask the owner only for the stops `## 8. When to ask the owner`
  lists. Decide any other question yourself, as a ruling.

## 1. Where the build stands

1. Show the owner `second-brain spec status <ID>` as it prints.
   - It prints nothing: the build has not started.
   - It prints a line: the build resumes, from the states `build.json` in the story's folder
     holds.
2. `second-brain spec tasks <ID>` must list a task. None, or exit 1 as for a split bundle: say so
   and stop.

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
   - Then note `<short hash>`: it is `<start>`.
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
  - A bundle's build, and fix rounds 1 to 3 of its tasks: `name: "<ID>-bundle-<n>-implementer"`,
    with `<n>` its bundle.
  - From fix round 4 on: `name: "<ID>-<task>-implementer-2"`.
- An agent fetches its own packet. Never run `spec packet` here, and never put a packet, a diff or
  the spec in a prompt.
- `implementer`'s prompt, one line each:
  - `Story: <ID>, project <project>.`
  - `Task: <task>.`
  - `Session: <session id>.`
  - The task's ruling lines, one per ruling of this build on it, as `### Rulings in each prompt`
    says: `Owner: <the ruling, as written>.` or `Ruling: <the question> - <the decision and why>.`
  - Last, the commit line: `Commit it as "<ID> <task>: <title>".`
- The fix message, sent with SendMessage to an `implementer` by its name, one line each:
  - `Fix: the review of <task> failed. Fetch your packet again: its ## Issues lists the findings.`
  - `Session: <session id>.`
  - The task's ruling lines.
  - Last, the commit line.
- `implementer`'s prompt for a bundle, one line each:
  - `Story: <ID>, project <project>.`
  - `Bundle: <n>.`
  - `Tasks: <task>, <task>.`: the tasks of the bundle it builds, in order.
  - `Session: <session id>.`
  - The ruling lines of those tasks, each led by its task:
    `Owner on <task>: <the ruling, as written>.` or
    `Ruling on <task>: <the question> - <the decision and why>.`
  - Last, one commit line per task, in order: `Commit <task> as "<ID> <task>: <title>".`
- A fix is always on one task, with the prompt and message above, even for a task of a bundle.
- `reviewer`'s prompt in task mode: `Mode: task.`, then the story, task and session lines, and the
  task's ruling lines.
- `reviewer`'s prompt for a bundle, in task mode: `Mode: task.`, the story line, `Bundle: <n>.`,
  the `Tasks:` line of the tasks it reviews, the session line and their ruling lines, each led by
  its task.
- `reviewer`'s prompt in baseline mode: `Mode: baseline.`, `Project: <project>.`,
  `Repo: <repo> at <path>.` and `Branch: <branch>.`
- `reviewer`'s prompt in user mode: `Mode: user.`, the story and session lines,
  `Repo: <repo> at <path>.` and `Branch: <branch>.`, then the ruling lines of every task, each led
  by its task.
- `reviewer`'s prompt in branch mode: the same lines with `Mode: branch.`, then `Base: <hash>.`:
  the hash of the newest `Build: started on <branch> at <short hash>.` note.
- A `reviewer` prompt holds only these lines, and a message to it only the one
  `### Reading a verdict` gives. Never add a view of your own on the result, such as the
  implementer's report, its `Test:` or `Check:` lines, or the verdict you expect.

### Reading a verdict

`reviewer`'s reply ends with a JSON block, as `## Verdict` in `agents/reviewer.md` says. Take its
verdict from that block alone, never from the words before it.

1. The block is the reply's last fenced block tagged `json`. It is good when:
   - It is one JSON object with `verdict`, `issues` and `checks`. A bundle's has `tasks` in their
     place: one entry per task of its `Tasks:` line, each with `task` and those three.
   - `verdict` is `PASS`, `FAIL` or `BLOCKED`, and `issues` is a whole number.
   - `checks` is a list. Each entry has a `check` text and a `met` of `true` or `false`.
   - A `PASS` has every `met` `true` and `issues` 0. In task mode it has one check or more.
   - A `FAIL` has `issues` 1 or more.
2. No block, or one that is not good, is no verdict, and never a PASS. In a bundle, so is a task
   with no entry, or with one that is not good.
3. No verdict: ask the reviewer once more with SendMessage,
   `Your reply has no good verdict block: <the rule of item 1 it breaks>. Reply with the block alone.`
   - Still none: launch one fresh `reviewer` in its place, with the same prompt. In a bundle,
     launch it on the tasks with none, with the bundle's prompt for those tasks.
   - Still none: take it as BLOCKED.

## 4. The baseline

The baseline tells a break already on the branch from one a task makes. A branch that starts on
the base branch holds nothing of its own yet, and the base is tested, so it needs none.

1. Skip it when the build resumes, whatever the start.
2. The base branch is the `base_branch` that `second-brain subproject <project> <subproject>`
   prints when `task head` names a subproject. Else it is the one
   `second-brain profile <project> --keys` prints.
   - `<base>` is `origin/<base_branch>` when
     `git -C "<path>" rev-parse --verify --quiet "refs/remotes/origin/<base_branch>"` prints a
     hash, else `<base_branch>`.
   - No base branch: item 4.
3. Run `git -C "<path>" merge-base --is-ancestor <start> <base>`.
   - Exit 0: the branch starts on the base. Skip the baseline: write
     `second-brain task note <ID> "Build: baseline skipped: the branch starts at <start> on <base>."`,
     then go on to `## 5. Each task in turn`.
   - Any other exit, such as on a branch cut from `release/<version>` or with commits the base
     lacks: item 4.
4. Launch `reviewer` in baseline mode on the branch as it is.
5. Read its verdict as `### Reading a verdict` says. A FAIL or a BLOCKED: stop, as
   `## 7. When the build stops` says.
6. PASS: `second-brain task note <ID> "Build: the baseline passed at <short hash>."`.

The build-wide checks in `## 6. When every task passed` run either way.

## 5. Each task in turn

Take each task whose review is not `passed`, in the order `spec tasks` lists them. Build it, then
review it right after, before the next task starts. A task that fails holds up the tasks after it
until it passes or the build stops.

A task whose `spec tasks` row names a bundle, in its last column, goes with the other tasks of
that bundle, as `### A bundle` says. One task or bundle at a time, never in parallel.

### Where the task stands

A resumed build finds each task as an earlier session left it. Go on from its state:

1. Build `todo`: `### Build it`.
2. Build `building`: it was cut off in an earlier session. Look for a commit it made, by its full
   hash: the first line of `git -C "<path>" log --format="%H %s" --grep="^<ID> <task>: "` whose
   subject is not `<ID> <task>: passed review`. That one is the tick of a `spec_home: repo` spec.
   - A hash `spec status` lists under the task is that commit when the full hash starts with it.
   - The full hash starts with no listed hash: that run committed. Run
     `second-brain spec status <ID> <task> built --commit <hash>`, with the hash
     `git -C "<path>" rev-parse --short <full hash>` prints, then `### Review it`.
   - No hash, or one `spec status` lists already: `### The fix loop` when the task's `fails` is 1
     or more, else `### Build it`.
3. Build or review `blocked`: its ruling is the owner's ruling on it, the status note
   `Build: the owner ruled on <task>: <the ruling, as written>.`, when that note is newer than the
   newest `Build: stopped at <task>: <why>.` note. Status notes are newest first, so it is above.
   - A `Spec: <phase> reopened.` note newer than that stop note answers the stop too: the owner
     changed the spec, and the phases were approved again.
   - Such a ruling or reopen: a review `blocked` goes on at `### Review it`. A build `blocked` goes
     on at `### The fix loop` when the task's `fails` is 1 or more, else at `### Build it`.
   - No such ruling or reopen: ask the owner first, as `## 7. When the build stops` says.
4. Review `failed`: look for its ruling as item 3 says, since a stop may have left one.
   - Its newest `Build: stopped at <task>: <why>.` note has no newer owner's ruling and no newer
     reopen note: the build stopped there, and the owner has not answered. Ask the owner first,
     as `## 7. When the build stops` says.
   - A `fix` in `spec status` that is not `-`: its fix was built before the session ended.
     `### Review it`, with its ruling lines, as `### Rulings in each prompt` says.
   - `fails` 5 or less: `### The fix loop`, with its ruling lines, as `### Rulings in each prompt`
     says.
   - `fails` 6 or more, the build stopped at the cap: the answer sends one more round, as for
     `fails` 4, with its ruling lines, as `### Rulings in each prompt` says.
5. Build `built`, review `-` or `in-review`: `### Review it`.

### Build it

1. `second-brain spec status <ID> <task> building`.
2. Launch `implementer` on the task, named for the build.
3. Its reply has no `Commit:` line, and does not start with `BLOCKED:`: look for its commit
   first, as item 2 of `### Where the task stands` says. A commit found goes on as that item
   says. None found: item 4.
4. Its reply starts with `BLOCKED:`, or no commit was found: a stop, unless a ruling settles it.
   - A `BLOCKED:` on a question a ruling settles, such as a requirement it reads two ways: rule on
     it as `### A ruling` says, and write no stop note. Then go on from the task's state, as
     `### Where the task stands` says, or item 1 of `### A bundle` for a task of a bundle. Its
     next prompt holds the ruling.
   - Any other, or the same question again after its ruling: first the stop note,
     `second-brain task note <ID> "Build: stopped at <task>: <why>."`, then
     `second-brain spec status <ID> <task> blocked`, and stop.
5. Otherwise: `second-brain spec status <ID> <task> built --commit <short hash>`, with the hash
   its `Commit:` line names. Then `### Review it`.
   - Its `Test:` and `Check:` lines are its own report. The review runs the checks again: never
     skip it on them.

### Review it

1. `second-brain spec status <ID> <task> in-review`.
2. Launch a fresh `reviewer` in task mode on the task. Its packet gives it the task's diff, or on
   a re-review the fix's commits and the findings they answer.
   - Read its verdict as `### Reading a verdict` says, then take it as items 3 to 5 say.
3. PASS: `second-brain spec tick <ID> <task>`. Exit 6 means it is ticked already: go on.
   - With `spec_home: repo`, commit the tick:
     `git -C "<path>" commit -m "<ID> <task>: passed review" -- spec/<ID>/tasks.md`.
   - Then `second-brain spec status <ID> <task> passed`.
4. FAIL: `second-brain spec status <ID> <task> failed`.
5. BLOCKED: first the stop note,
   `second-brain task note <ID> "Build: stopped at <task>: <why>."`, then
   `second-brain spec status <ID> <task> blocked`, and stop.
6. Show the owner `second-brain spec status <ID>`.
7. PASS: go on to the next task. FAIL: `### The fix loop`.

### The fix loop

The task's `fails` in `spec status <ID>` is its failed reviews in `build.json`, from every session.
It picks the round. Never count the rounds yourself.

1. `fails` 6 or more, right after a FAIL: the cap is reached. First the stop note,
   `second-brain task note <ID> "Build: stopped at <task>: <why>."`, then stop, as
   `## 7. When the build stops` says. The review stays `failed`.
   - A ruling the owner gives at that stop sends one more round, as for `fails` 4, with its
     ruling lines, as `### Rulings in each prompt` says.
2. Otherwise, `second-brain spec status <ID> <task> building`, then the round:
   - `fails` 1 to 3: the same `implementer`. Send the fix message to
     `<ID>-<task>-implementer`, or to `<ID>-bundle-<n>-implementer` for a task of bundle `<n>`,
     and wait for its reply.
   - SendMessage is not there, or no agent has that name, as in a new session: launch a fresh
     `implementer` in its place, with the build's prompt, name and model.
   - `fails` 4: launch a fresh `implementer` on the stronger model, named from round 4 on, with
     the build's prompt.
   - `fails` 5: send the fix message to `<ID>-<task>-implementer-2`, or launch a fresh one as for
     `fails` 4 when it cannot be reached.
   - `fails` 6 or more, on a ruling: as for `fails` 4, with its ruling lines, as
     `### Rulings in each prompt` says.
3. Take its reply as items 3 to 5 of `### Build it` say. Its review then reads only the fix.

### A bundle

A bundle's tasks are built in one `implementer` run, one commit per task. Then one `reviewer`
reviews them all, before the next task or bundle starts. Take the bundle's tasks whose review is
not `passed`, in order:

1. Where they stand: a build `building` looks for its commit, and sets `built` when it finds one,
   as item 2 of `### Where the task stands` says. A `blocked` one looks for its ruling, as item 3
   says. Then go on to item 2 here, not to the step those items name.
   - A `blocked` task with no ruling: ask the owner first, as `## 7. When the build stops` says.
2. Build the tasks with `fails` 0 whose build is `todo`, `building` with no commit found, or
   `blocked` with a ruling. None: item 3.
   1. `second-brain spec status <ID> <task> building` for each of them, in order.
   2. Launch one fresh `implementer` on them, with the bundle's prompt and name.
   3. Its reply holds one report per task, in order, each under a line `Task: <task>`. Take each
      task in order:
      - A report with a `Commit:` line:
        `second-brain spec status <ID> <task> built --commit <hash>`, with the hash it names.
      - No report, or one with no `Commit:` and no `BLOCKED:` line: look for its commit first, as
        item 1 does.
      - A report with `BLOCKED:`, or no commit found: that task stopped the run. Take no task
        after it.
   4. A task stopped the run: first `second-brain spec status <ID> <task> todo` for each task
      after it. Then take its stop as item 4 of `### Build it` says: a ruling, or a stop of the
      build.
3. Review the tasks whose build is `built` and whose review is `-`, `in-review`, or `blocked` with
   a ruling. Review too each task whose review is `failed` and whose `fix` in `spec status` is
   not `-`, as item 4 of `### Where the task stands` says. Only one: items 1 to 6 of
   `### Review it`, then item 4 here. Two or more:
   1. `second-brain spec status <ID> <task> in-review` for each of them, in order.
   2. Launch one fresh `reviewer` in task mode on them, with the bundle's prompt.
   3. Read each task's verdict from its entry in the block, as `### Reading a verdict` says.
   4. Set each task's result as items 3 to 5 of `### Review it` say. Set every PASS and FAIL
      first, then a BLOCKED, which stops the build.
   5. Show the owner `second-brain spec status <ID>`, as item 6 of `### Review it` says.
4. Fix each task left whose review is not `passed`, one at a time, in order. Go on from its state
   as `### Where the task stands` says: it takes `### The fix loop`, and `### Review it` reviews
   its fix alone.
5. Every task of the bundle has passed: go on to the next task or bundle.

## 6. When every task passed

A resumed build with every task passed comes straight here.

1. Run the build-wide checks once, with no agent:
   `second-brain validation run "<project>" <repo> --when each-build`.
   - Run it with the Bash tool's `run_in_background: true`, and wait for its notice. A run can
     take longer than a Bash call's timeout, and a helper that a timeout kills leaves its check
     running.
   - Every row passes or is skipped: go on to item 2.
   - A `fail` row: find the task whose files it covers, the one whose `- Files:` line in
     `tasks.md` holds the code its lines name or test. Several: the last of them in order.
   - No task you can tell: the last task in order, with a ruling, as `### A ruling` says.
   - Log each failing row on its task:
     `second-brain spec issue <ID> <task> "<command> fails in the build-wide run, exit <code>: <its lines>" --fix "<the fix you propose>"`.
   - Then `second-brain spec status <ID> <task> failed` for each such task, and go back to
     `## 5. Each task in turn`. It comes back here once every task has passed again.
2. Launch `reviewer` in user mode on the finished branch.
   - Before the launch, note each task's issue count: the length of its `issues` in
     `second-brain spec status <ID> --json`.
   - Read its verdict as `### Reading a verdict` says.
   - BLOCKED: stop, as `## 7. When the build stops` says.
   - FAIL: it logged each finding it could tie to a task. Log each finding its reply lists on the
     last task in order, with a ruling, and with the fix you propose:
     `second-brain spec issue <ID> <task> "<the finding>" --fix "<the fix you propose>"`.
   - Then `second-brain spec status <ID> <task> failed` for each task whose issue count grew since
     the launch, and go back to `## 5. Each task in turn`, as item 1 does.
3. Launch `reviewer` in branch mode: one review of the whole branch ends the build. BLOCKED or
   FAIL: as item 2 says.
   - Read its verdict as item 2 does.
4. `second-brain task set <ID> status=in-review next="Owner reviews the built story"`.
5. `second-brain task note <ID> "Build: finished; every task passed review, the branch is at <short hash>."`.
6. Show the owner `second-brain spec status <ID>` and the final validation result.
   - Then list the rulings of the build, as `### The list of rulings` says.
7. Read `finish.md`, next to this file, and follow it. The story is `in-review`: story-tracker
   takes it from there.

## 7. When the build stops

Only a stop that `## 8. When to ask the owner` lists comes here.

1. Show the owner `second-brain spec status <ID>`, the task that stopped the build, and why: the
   agent's reply, and the issues `spec status` lists under the task.
   - A stop in `## 6. When every task passed` names its step in place of the task: the user
     check or the branch review.
   - Then list the rulings of the build, as `### The list of rulings` says.
2. `second-brain task note <ID> "Build: stopped at <task>: <why>."`, unless a block or the cap
   wrote it already. A block writes it before it sets `blocked`, so a new session never takes an
   older ruling for this stop.
3. Ask the owner with AskUserQuestion what to do.
   - A ruling on the task:
     `second-brain task note <ID> "Build: the owner ruled on <task>: <the ruling, as written>."`.
     Then go on from the step that stopped, with its ruling lines in the next prompt for that
     task, as `### Rulings in each prompt` says.
   - A ruling to fix a task, such as one that passed, or one the user check or the branch review
     logged issues on: the same note. Then log what it asks:
     `second-brain spec issue <ID> <task> "The owner ruled: <the ruling, as written>" --fix "<the fix it asks>"`.
     Then `second-brain spec status <ID> <task> failed`, and back to `## 5. Each task in turn`,
     with its ruling lines, as `### Rulings in each prompt` says.
   - The owner reverses a ruling of yours: their ruling on its task, as above. It wins over yours.
     A task that passed already takes it as a ruling to fix the task, as the bullet above says.
   - The spec needs a change, such as in the phase a ruling touched: write
     `Spec: <phase> reopened.` as a status note, then go back to Step 2 of `SKILL.md` for that
     phase.
     - The reopen retires every ruling before it, as `### The rulings of this build` says. Write
       into the changed phase each one the owner keeps.
     - The owner approves the phases after it again too. Only then does the build go on.
   - The owner stops here: `build.json` keeps where the build stands, and a new session goes on
     from it.

## 8. When to ask the owner

Once the build has started, stop and ask the owner with AskUserQuestion only for these. Each one
waits for the owner, as `## 7. When the build stops` says:

1. A destructive action, such as discarding the owner's changes or deleting a branch.
2. A security-sensitive action, such as one that needs a secret, a credential or a permission.
3. An outside effect, such as a push, a merge or a publish.
4. A spec too broken to follow: going on would change, add or drop a requirement, a design
   decision, a task or a check.
5. A task blocked, or past its last fix round. A `BLOCKED` from the user check or the branch
   review is a block too.
6. A failed baseline.

- Any other question you decide yourself, as `### A ruling` says. Never ask the owner it.
- The steps before the `Build: started` or `Build: resumed` note ask as they say: the owner has
  just run the skill. So does `finish.md`: each of its questions is an outside effect or a
  destructive action.

### A ruling

A question comes in an agent's reply, such as an `implementer`'s `BLOCKED:` on a requirement it
reads two ways, or from two agents that disagree, such as two reviews of a task that ask for
opposite fixes. Rule on it before the next launch or message.

1. Decide by the approved spec first, then the story, then the code on the branch. Pick what keeps
   to the spec and is easiest to undo.
   - A ruling never changes, adds or drops a requirement, a design decision, a task or a check.
     One that would is a spec too broken to follow: a stop.
2. Write it:
   `second-brain task note <ID> "Ruling: <task>: <the question> - <the decision and why>"`.
   - `<task>` is the task the question touches. A question on several tasks gets one note per
     task. One that touches no task names `build`, and goes in no prompt.
   - The why names what settled it, such as a requirement, a design heading or the code.
3. Go on. The next prompt for that task holds it.

- A ruling of yours never lifts a stop. Only the owner's ruling, newer than the task's stop note,
  lets a `blocked` task, or one at the cap, go on, as `### Where the task stands` says.

### The rulings of this build

- They are the status notes newer than the newest
  `Build: started on <branch> at <short hash>.` note: each of your `Ruling: <task>:` notes and
  each `Build: the owner ruled on <task>:` note. A note below it is from an earlier build of the
  story.
- They are newer too than the newest `Spec: <phase> reopened.` note. The changed phase holds what
  the owner kept of the rulings before it.
- A new session finds them there: `second-brain outline <note>`, with `<note>` the `path:` that
  `second-brain task head <ID>` prints, then a ranged read of `## Status notes`. Status notes are
  newest first: take them in reverse, oldest first.

### Rulings in each prompt

- Every ruling of this build on a task goes, as written and oldest first, into each later prompt
  and fix message for that task: each `implementer`'s and each `reviewer`'s.
  - The owner's, from `Build: the owner ruled on <task>: <the ruling, as written>.`:
    `Owner: <the ruling, as written>.`
  - Yours, from `Ruling: <task>: <the question> - <the decision and why>`:
    `Ruling: <the question> - <the decision and why>.`
  - Led by its task in a bundle's prompt, and in the user and branch reviews:
    `Owner on <task>:` and `Ruling on <task>:`, with the same text.
- The user and branch reviews get the ruling lines of every task.
- The agents follow both. Where they differ, the `Owner:` line wins.

### The list of rulings

When the build finishes or stops, show the owner every ruling of this build, as written, oldest
first: yours and the owner's.

- Name for each the phase it touched: the requirements, the design or the tasks.
- None: say the build has no rulings.
- The owner can reopen the phase a ruling touched, or reverse a ruling with one of their own. At a
  stop, as item 3 of `## 7. When the build stops` says. At the finish, in the free-text answer of
  its question, as `## 2. Ask the owner` in `finish.md` says.

## Rules

- You keep track of the build: set each state with `spec status` as the agents report it.
- A task's progress is in `build.json` alone. The README gets the story-level notes above: the
  build started, stopped and why, and finished, and each ruling, the owner's and yours.
- Only a reviewer's PASS, read from its JSON block, ticks a task. Never on the implementer's word.
- The packet is the implementer's whole context. Never give it the other tasks or this
  conversation. A bundle's run gets its own tasks' packets alone.
- Never skip, merge or reorder tasks. A task of a bundle keeps its own commit, verdict and states.
- One agent at a time: wait for each agent's result or reply before the next step.
- Run a `release` check only when the owner asks:
  `second-brain validation run "<project>" <repo> --when release`, in the background as
  `## 6. When every task passed` says.
- Write no code, and commit nothing but the spec files and the ticks of a `spec_home: repo` spec.
