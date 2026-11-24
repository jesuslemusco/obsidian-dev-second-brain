# Building one story

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Read this file once, as `## Files` in `SKILL.md` says. It builds one story, `<ID>`, in a git
worktree of its own, with one `implementer` and a fresh `reviewer` for each review.

- `<repo>` is the repo the story touches, and `<path>` its folder, as `## 2. The worktree` finds
  them. `<branch>` is the story's branch.
- `<worktree>` is `<path>-<ID>`: a folder next to the repo's, named for the repo and the story.
- `<short hash>` is what `git -C "<worktree>" rev-parse --short HEAD` prints.
- `<base>` is where this build started: the hash of the newest
  `Build: started on <branch> at <short hash>.` note.
- `<session id>` is the session id for notes in `SKILL.md`. Every `task note` takes
  `--session <session id>`.
- `<project path>` is the project's path in the vault, the second field that
  `second-brain project --key <ID>` prints. `<vault>` is the path `second-brain root` prints.
- The story's progress is in its status notes: never count a round from memory. Read them with
  `second-brain outline <note>`, with `<note>` the `path:` that `second-brain task head <ID>`
  prints, then a ranged read of `## Status notes`. They are newest first.
- Once the build has started, ask the owner only for the stops `## 8. When to ask the owner`
  lists. Decide any other question yourself, as a ruling.

## 1. Where the story stands

The notes of this build are the status notes newer than the newest
`Build: started on <branch> at <short hash>.` note.

- No such note: a new build. `## 2. The worktree`, `## 3. The baseline`, then `### Build it`.
- `fails` is the number of `Build: review <m> failed at <hash>` notes of this build.
- `<n>`, the round of the next review, is one more than the number of `Build: review <m>` notes
  of this build, whatever their result.
- A build that resumes: read where it stands first, before `## 2. The worktree` writes its
  resumed note. Then take `## 2. The worktree`, and go on from what you read:
  1. Its newest `Build:` note is `Build: stopped: <why>.`: the owner has not answered. Ask first,
     as `## 7. When the story stops` says.
  2. Its newest review note is `Build: review <m> passed`: `## 6. When the story passed`.
  3. Its newest review note is `Build: review <m> blocked`, for a stop the owner answered, as
     item 1 shows, or `Build: review <m> gave no verdict`: `### Review it`.
  4. Commits on the branch since the hash of its newest review note, or since `<base>` with none:
     `git -C "<worktree>" log --oneline <hash>..HEAD`. Some: `### Review it`.
  5. None, with `fails` 1 or more: `### The fix loop`. With `fails` 0: `### Build it`.

## 2. The worktree

1. Find the repo and the branch as `## Branch check (start, update, recall)` in
   `skills/story-tracker/SKILL.md` says. `<path>` is what `second-brain repo <project> <repo>`
   prints.
   - The branch is the story's `branch`, from `second-brain task head <ID>`.
   - No branch yet: name it by `branch_pattern`, then record it with
     `second-brain task set <ID> branch=<branch>`. Item 2 cuts it.
2. Run `git -C "<path>" worktree list --porcelain`, and look whether `<worktree>` is there.
   - A new build, and anything is at `<worktree>`, a worktree or a folder: say what is there, from
     that list or `ls -A "<worktree>"`, and stop. Never reuse it, and never delete it.
   - A resumed build: its worktree is the entry `worktree <worktree>` with
     `branch refs/heads/<branch>`. Say that you go on in it, at its `<short hash>`, then go on.
     Anything else at `<worktree>`: say what is there, and stop.
   - `<branch>` is checked out in another folder: say where, and stop. A branch is checked out in
     one worktree at a time.
   - Nothing there, and the branch exists: `git -C "<path>" worktree add "<worktree>" <branch>`.
   - Nothing there, and no branch yet:
     `git -C "<path>" worktree add -b <branch> "<worktree>" <from>`, with `<from>` the branch it
     is cut from, as the branch check says.
3. `git -C "<worktree>" status --porcelain` must print nothing. Otherwise ask the owner to commit
   or discard the changes. Never stash or discard them yourself.
4. `second-brain validation "<project>" <repo> --path "<worktree>"` must print the repo's steps,
   with no `<...>` text left.
   - Otherwise offer `/odsb:vault-setup validation <project>` and stop.
5. `second-brain task set <ID> status=in-progress next="The build skill builds the story"`.
6. A new build: `second-brain task note <ID> "Build: started on <branch> at <short hash>."`.
   - A resumed one: `second-brain task note <ID> "Build: resumed on <branch> at <short hash>."`.
7. Write the order that ran the build in the orders note, as `## The owner's open orders` in
   `lead.md` says. Then start the lead's check, as `## The lead's check` there says.
8. A new build: `## 3. The baseline`. A resumed one: as `## 1. Where the story stands` says.

## 3. The baseline

The baseline tells a break already on the branch from one the story makes.

1. Skip it when the build resumes.
2. The base branch is the `base_branch` that `second-brain subproject <project> <subproject>`
   prints when `task head` names a subproject. Else it is the one
   `second-brain profile <project> --keys` prints.
   - `<base ref>` is `origin/<base_branch>` when
     `git -C "<worktree>" rev-parse --verify --quiet "refs/remotes/origin/<base_branch>"` prints
     a hash, else `<base_branch>`.
   - No base branch: item 4.
3. `git -C "<worktree>" merge-base --is-ancestor <base> <base ref>` exits 0: the branch starts on
   the base branch, which is tested. Skip the baseline:
   `second-brain task note <ID> "Build: baseline skipped: the branch starts at <base> on <base ref>."`.
   Any other exit: item 4.
4. Launch `reviewer` in baseline mode, in the worktree.
5. Read its verdict as `### Reading a verdict` says. A FAIL or a BLOCKED: stop, as
   `## 7. When the story stops` says.
6. PASS: `second-brain task note <ID> "Build: the baseline passed at <short hash>."`.

Then `### Build it`, whether the baseline ran or not.

## 4. Launching an agent

- Launch one agent at a time with the Agent tool, and wait for its result. Its result is its
  report: never relay a report by hand, and never read an agent's transcript.
- A named agent can send its last reply twice: as its message, then again in its idle notice. A
  notice that repeats a reply you took already is no new event: it changes no state, and gets no
  reply.
- Name each launch's model by its role and round:
  - `odsb:implementer`: `model: "opus"`. It builds the story, and takes fix rounds 1 to 3.
  - `odsb:implementer` from fix round 4 on: `model: "fable"`, the stronger model.
  - `odsb:reviewer`, in story or baseline mode: `model: "opus"`.
- Name each `implementer` launch, so that a fix can reach it again with SendMessage:
  - The build and fix rounds 1 to 3: `name: "<ID>-implementer"`.
  - From fix round 4 on: `name: "<ID>-implementer-2"`.
- An agent reads the story and the code itself. Never put the story, a diff or this conversation
  in a prompt.
- `implementer`'s prompt, one line each:
  - `Mode: story.`
  - `Story: <ID>, project <project>.`
  - `Repo: <repo>.`
  - `Worktree: <worktree>.`
  - `Branch: <branch>.`
  - `Base: <base>.`
  - `Session: <session id>.`
  - Last, the ruling lines, one per ruling of this build, as `### Rulings in each prompt` says.
- The fix message, sent with SendMessage to an `implementer` by its name, one line each:
  - `Fix: review <m> failed. Its defects are the story's Defect <m>: status notes.`, with `<m>`
    from the newest `Build: review <m> failed at <hash>` note.
  - `Session: <session id>.`
  - The ruling lines.
- `reviewer`'s prompt in story mode, one line each:
  - `Mode: story.`
  - The story, repo, worktree, branch and base lines of `implementer`'s prompt.
  - `Round: <n>.`
  - A re-review: `Last failed: review <m> at <hash>.`, from the newest
    `Build: review <m> failed at <hash>` note.
  - `Session: <session id>.`
  - The ruling lines.
- `reviewer`'s prompt in baseline mode: `Mode: baseline.`, `Project: <project>.`,
  `Repo: <repo>.`, `Worktree: <worktree>.` and `Branch: <branch>.`
- A `reviewer` prompt holds only these lines, and a message to it only the one that
  `### An agent with no report` gives, or the one that `### Reading a verdict` gives. Never add a
  view of your own on the result, such as the implementer's report, its `Test:` or `Check:`
  lines, or the verdict you expect.

### An agent with no report

An agent can go idle before its report, such as on a reply that says its checks still run, when
none runs. Its report is:

- An `implementer`'s: a `Commit:` line, or a first line `BLOCKED:`.
- A `reviewer`'s: the JSON block of `### Reading a verdict`.

Before you take the reply of an agent idle with no report as final:

1. Check the worktree and its checks.
   - `git -C "<worktree>" log --oneline <base>..HEAD` and `git -C "<worktree>" status --porcelain`:
     what it committed, and what it left uncommitted.
   - Whether a check it started still runs, such as its tests or a `validation run`: look for its
     process with `ps`. Count only a process whose working directory or command line is under
     `<worktree>`: another build's tests may run in another worktree.
2. Its check still runs: the work is real. Wait for its next reply.
3. Nothing of it runs: send that agent one message with SendMessage, by its name, or by its id
   when it has none:
   `Nothing you started is still running. Finish your step, then reply with your report.`
   - Send it once per launch or fix message, never twice.
   - SendMessage is not there: take its reply as final now.
4. Its next reply is final, with a report or not, unless its check still runs, as item 2 says.
   - Take an `implementer`'s as items 2 to 4 of `### Build it` say.
   - Read a `reviewer`'s verdict from it by `### Reading a verdict`.

## 5. Build and review

### Build it

1. Launch `implementer` on the story, named for the build.
2. Its reply has no `Commit:` line, and does not start with `BLOCKED:`: look for its commits,
   `git -C "<worktree>" log --oneline <since>..HEAD`, with `<since>` the hash of the newest review
   note of this build, or `<base>` with none. Some: `### Review it`. None: item 3.
   - It is idle with no report: first take it as `### An agent with no report` says. Then read
     its final reply as this item and item 3 say.
3. Its reply starts with `BLOCKED:`, or no commit was found: a stop, unless a ruling settles it.
   - A `BLOCKED:` on a question a ruling settles, such as a criterion it reads two ways: rule on
     it as `### A ruling` says, and write no stop note. Then go on as `## 1. Where the story
     stands` says. Its next prompt holds the ruling.
   - Any other, or the same question again after its ruling: stop, as
     `## 7. When the story stops` says.
4. Otherwise: `### Review it`.
   - Its `Test:` and `Check:` lines are its own report. The review runs the checks again: never
     skip it on them.

### Review it

1. Take `<n>` and, after a failed review, its `Last failed:` line, as `## 1. Where the story
   stands` and `## 4. Launching an agent` say.
2. Launch a fresh `reviewer` in story mode.
3. Read its verdict as `### Reading a verdict` says. Show the owner the round, its verdict and its
   defects, one line each. Then take it as items 4 to 6 say.
4. PASS: `second-brain task note <ID> "Build: review <n> passed at <short hash>."`. Then
   `## 6. When the story passed`.
5. FAIL: `second-brain task note <ID> "Build: review <n> failed at <short hash>: <k> defects."`,
   with `<k>` its `issues`. Then `### The fix loop`.
6. BLOCKED: `second-brain task note <ID> "Build: review <n> blocked at <short hash>."`. Then stop,
   as `## 7. When the story stops` says.

### Reading a verdict

`reviewer`'s reply ends with a JSON block, as `## Verdict` in `agents/reviewer.md` says. Take its
verdict from that block alone, never from the words before it.

A review sorts each finding as a defect or a follow-up, as `## Defects and follow-ups` in
`agents/reviewer.md` says. Only a defect counts in `issues`, fails the story and goes to the fix
loop. A follow-up is a `Follow-up:` status note: it changes no count.

1. The block is the reply's last fenced block tagged `json`. It parses when it is one JSON object
   with `verdict`, `issues` and `checks`.
2. A block that parses is good when:
   - `verdict` is `PASS`, `FAIL` or `BLOCKED`, and `issues` is a whole number.
   - `checks` is a list. Each entry has a `check` text and a `met` of `true` or `false`.
   - A `PASS` has one check or more, every `met` `true` and `issues` 0. In story mode the story
     holds no `Defect <n>:` note too.
   - A `FAIL` has `issues` 1 or more. In story mode the story holds one `Defect <n>:` note or
     more too. Read the status notes after the reply.
3. No good block is no verdict, and never a PASS.
4. No block, or one that does not parse: ask the reviewer once more with SendMessage,
   `Your reply has no JSON verdict block that parses. Reply with the block alone.`
   - A `reviewer` idle with no block at all: first take it as `### An agent with no report`
     says. Ask here only when its final reply has no block that parses either.
5. A block that parses and is not good, or no good block after item 4: first
   `second-brain task note <ID> "Build: review <n> gave no verdict at <short hash>."`. The
   `Defect <n>:` notes that reviewer logged stay its own. Then launch one fresh `reviewer` in
   its place, with the same prompt but the next round, `<n>` plus one, as `## 1` counts it.
6. No good block from the fresh `reviewer` either: take it as BLOCKED, in its own round.

### The fix loop

The story's `fails`, as `## 1. Where the story stands` counts it from the status notes, picks the
round, across every session.

1. `fails` 6 or more, right after a FAIL: the cap is reached. Stop, as
   `## 7. When the story stops` says.
   - A ruling the owner gives at that stop sends one more round, as for `fails` 4.
2. Otherwise, the round:
   - `fails` 1 to 3: the same `implementer`. Send the fix message to `<ID>-implementer`, and wait
     for its reply.
   - SendMessage is not there, or no agent has that name, as in a new session: launch a fresh
     `implementer` in its place, with the build's prompt and the fix message's first line, its
     name and its model.
   - `fails` 4: launch a fresh `implementer` on the stronger model, named from round 4 on, with
     the build's prompt and the fix message's first line.
   - `fails` 5: send the fix message to `<ID>-implementer-2`, or launch a fresh one as for
     `fails` 4 when it cannot be reached.
   - `fails` 6 or more, on a ruling: as for `fails` 4.
3. Take its reply as items 2 to 4 of `### Build it` say. Its review then reads only the fix.

## 6. When the story passed

1. `second-brain task set <ID> status=in-review next="Waits for the owner's go to merge"`.
2. `second-brain task note <ID> "Build: finished; review <n> passed, the branch is at <short hash>."`.
3. Show the owner each review of this build, one line each: its round, its result and its
   defects. Then list the rulings, as `### The list of rulings` says, and the follow-ups, as
   `### The list of follow-ups` says.
   - The owner answers with a ruling to fix the story, such as a follow-up to fix: take it as
     item 3 of `## 7. When the story stops` says.
4. The merge: say that `<branch>` passed its review and waits for the owner's go to merge, as the
   project's git flow says. Merge nothing here: a merge is an outside effect, item 3 of
   `## 8. When to ask the owner`.
5. Remove the worktree. The branch stays, with every commit.
   - First run `git -C "<worktree>" status --porcelain --ignored`. Each `!!` path is an ignored
     file the removal deletes, such as a `.env`. Show the owner each one, and go on only on their
     word.
   - Then `git -C "<path>" worktree remove "<worktree>"`. Never pass `--force`. It fails, as on a
     change left in the worktree: ask the owner.
6. Test each order of the build, as item 3 of `## The owner's open orders` in `lead.md` says.
7. Go on with the next story of the run, as Step 3 of `SKILL.md` says.

## 7. When the story stops

Only a stop that `## 8. When to ask the owner` lists comes here.

1. Show the owner the story, the step that stopped it, and why: the agent's reply, and the
   `Defect <m>:` notes of its last failed review.
   - Then list the rulings, as `### The list of rulings` says, and the follow-ups, as
     `### The list of follow-ups` says.
2. `second-brain task note <ID> "Build: stopped: <why>."`.
3. Ask the owner with AskUserQuestion what to do.
   - An answer that sends the build on is an order: add it to the orders note, as `lead.md` says.
   - A ruling: `second-brain task note <ID> "Build: the owner ruled: <the ruling, as written>."`.
     Then go on from the step that stopped, with its ruling line in each later prompt, as
     `### Rulings in each prompt` says.
   - A ruling to fix the story, such as one that passed, or a follow-up the owner wants fixed:
     the same note. Then log it as the defect of the next round, `<n>`:
     `second-brain task note <ID> "Defect <n>: The owner ruled: <the ruling, as written> - Fix: <the fix it asks>"`,
     then `second-brain task note <ID> "Build: review <n> failed at <short hash>: the owner ruled a fix."`,
     with `<short hash>` what `git -C "<path>" rev-parse --short <branch>` prints: the worktree
     may be gone. Then `## 2. The worktree`, as for a resumed build, and `### The fix loop`.
   - The owner reverses a ruling of yours: their ruling, as above. It wins over yours.
   - The story needs a change, such as to a criterion a ruling touched: offer
     `/odsb:scrum-master refinement`. The build goes on once the owner approves the change.
   - The owner stops here: the status notes keep where the story stands, and the worktree stays,
     for a new session to go on from. Take the build's orders to `## Done`, as `lead.md` says.

## 8. When to ask the owner

Once the build has started, stop and ask the owner with AskUserQuestion only for these. Each one
waits for the owner, as `## 7. When the story stops` says:

1. A destructive action, such as discarding the owner's changes or deleting a branch.
2. A security-sensitive action, such as one that needs a secret, a credential or a permission.
3. An outside effect, such as a push, a merge or a publish.
4. A story too unclear to build: going on would change, add or drop an acceptance criterion.
5. A story blocked, or past its last fix round. A `BLOCKED` review is a block too.
6. A failed baseline.

- An order whose words give no `Done when:` condition: ask the owner in your reply, as item 2 of
  `## The owner's open orders` in `lead.md` says. It stops nothing.
- Any other question you decide yourself, as `### A ruling` says. Never ask the owner it.
- `git worktree remove` refuses a worktree with a change, but deletes its ignored files. Removing
  one that holds no ignored file is no destructive action. One that holds some waits for the
  owner's word, as item 5 of `## 6. When the story passed` says.
- The steps before the `Build: started` or `Build: resumed` note stop and ask as they say: the
  owner has just run the skill.

### A ruling

A question comes in an agent's reply, such as an `implementer`'s `BLOCKED:` on a criterion it
reads two ways, or from two reviews that ask for opposite fixes. Rule on it before the next launch
or message.

1. Decide by the story's acceptance criteria and its Approach first, then the code on the branch.
   Pick what keeps to the story and is easiest to undo.
   - A ruling never changes, adds or drops an acceptance criterion. One that would is a story too
     unclear to build: a stop.
2. Write it: `second-brain task note <ID> "Ruling: <the question> - <the decision and why>"`.
   - The why names what settled it, such as a criterion, the Approach or the code.
3. Go on. The next prompt holds it.

- A ruling of yours never lifts a stop. Only the owner's ruling, newer than the stop note, lets
  the build go on.

### The rulings of this build

- They are the notes of this build that are `Ruling:` notes or `Build: the owner ruled:` notes.
  A note below the newest `Build: started on <branch> at <short hash>.` note is from an earlier
  build of the story.
- A new session finds them in `## Status notes`, as the top of this file says. Take them in
  reverse, oldest first.

### Rulings in each prompt

- Every ruling of this build goes, as written and oldest first, into each later prompt and fix
  message: each `implementer`'s and each `reviewer`'s.
  - The owner's, from `Build: the owner ruled: <the ruling, as written>.`:
    `Owner: <the ruling, as written>.`
  - Yours, from `Ruling: <the question> - <the decision and why>`:
    `Ruling: <the question> - <the decision and why>.`
- The agents follow both. Where they differ, the `Owner:` line wins.

### The list of rulings

When the build finishes or stops, show the owner every ruling of this build, as written, oldest
first: yours and the owner's.

- None: say the build has no rulings.
- The owner can reverse a ruling with one of their own, at a stop, as item 3 of
  `## 7. When the story stops` says.

### The list of follow-ups

When the build finishes or stops, show the owner each follow-up of this build so far, as written,
oldest first.

- They are the `Follow-up:` notes of this build.
- Every session reads them from `## Status notes`, as the top of this file says: the reviews
  write them, and no reply holds them.
- List the same text once, even when two reviews logged it.
- None: say the build has no follow-ups.
- The owner can have one fixed: it is a ruling to fix the story, as item 3 of
  `## 7. When the story stops` says.

## Rules

- You keep track of the build in the story's status notes: the `Build:` notes, the rulings, and
  the `Defect` and `Follow-up` notes the reviews write.
- Only a reviewer's PASS, read from its JSON block, passes a story. Never on the implementer's
  word.
- The agents read the story and the code themselves. Never give them this conversation.
- Never skip a review.
- One agent at a time: wait for each agent's result or reply before the next step.
- Run a `release` check only when the owner asks:
  `second-brain validation run "<project>" <repo> --when release --path "<worktree>"`, with the
  Bash tool's `run_in_background: true`, and wait for its notice.
- Write no code, and commit nothing.
