# Changelog

## 0.13.0 - unreleased

- Each helper command starts fewer processes, so it answers sooner, most of all on Windows, where
  Git Bash starts each one slowly. `second-brain doctor` starts about 40% of the processes it
  started in 0.12.0. For all of its checks it reads the index's project rows once and lists each
  tasks folder once, and it answers each scalar setting it looks up through `sb_setting` from one
  read of the profile's scalar keys. The repo settings, `repos`, `repos_root` and `repo_paths`,
  are still read from the profile apart. The `task-frontmatter`, `needs-a-status`, `status-tag`,
  `yaml-traps`, `bare-links` and `line-endings` checks and the tags of `topic-tags` read the
  tasks' rows in one `awk` pass. The shell works out letter case and dates itself.
- `sprint open`, `sprint close` and `doctor --fix` list the tasks folder once for their moves,
  however many tasks they move. The parent of each task they move is read for all of them in one
  pass, where each move read every task again, so the time grew with the square of the tasks
  moved. `doctor --fix` lists each tasks folder once more for its rows, after the moves.
- On Linux, `bash scripts/test-doctor.sh` takes about 112 s, down from 174 s.
- Validation runs in stages that fit any flow, with or without sprints and releases. A check's
  `when:` is `each story`, in the story's review, `each merge`, on the branch a story merges into
  before its push, or `release`, in a project that plans releases. `### Validation` in
  `docs/contract.md` says how each is read.
- `each task` and `each build`, the old names, still run, as `each story` and `each merge`. A
  bullet with no `when:`, or an unknown one, is `each merge`.
- The doctor's `validation` check names each check and user step that still holds an old name, as
  `<repo>:<name>:each-task` or `<repo>:<name>:each-build`: a check by its command, or by its text
  with none, a user step by its text.
- A check may name the paths it covers, as `paths: <glob>, ...`, matched as git matches a
  `:(glob)` pathspec.
- `second-brain validation run` takes `--changed <base>`: a check with `paths:` runs only when the
  diff from `<base>` touches one of them, committed or not, and is `skipped` otherwise. A check
  with no `paths:` runs every time.
- `validation run --when` takes `each-story`, `each-merge` or `release`, `each-merge` by default.
  `each-task` and `each-build` still work.
- A story's review runs the `each story` checks with `--changed` set to the story's base, so it
  runs only the checks its change can break, and the `each story` user steps. `implementer` runs
  the same checks before it commits.
- A merge runs every `each merge` check on the merged branch, even on the tree the review read. It
  runs no user step, and names each `each merge` one for you to ask for.
- The baseline runs the `each merge` checks, and the `each story` and `each merge` user steps.
- The validation template asks for `paths:`, and its `when:` line names the new stages. The
  doctor's `validation` check still names a section that holds the line the old template held.
- In your `validation.md`, write `when: each story` for `each task` and `when: each merge` for
  `each build`. A check you want in each review, such as a suite `each build` ran there: mark it
  `each story`, with the `paths:` it covers.
- `docs-keeper` sets up the docs of a project that has none, in its new
  `Workflow 7 - Set up a project's docs`. It reads each repository's README, its layout and its
  code, and drafts the topic folders, a hub for each, a first note per topic and the profile's
  Code to doc map rows.
- `vault-setup` offers it when it adds a project or a repository. The draft writes nothing:
  `vault-setup` shows it to you, with each change you ask for, and has `docs-keeper` write it only
  once you approve it, as `skills/vault-setup/docs.md` says.
- Each note it writes follows the conventions: a hub per folder, links with paths, and topic tags
  that are folder paths. It overwrites no file.
- The new `define-validation-scope` skill proposes which checks run at each stage of a repo: each
  check's command, its stage and its `paths:`, in the shape of the validation template. It reads
  the project's docs. A project with none is offered `docs-keeper`'s setup first, and on a no the
  skill reads the repo's test scripts, CI workflows and package manifests.
- It proposes only the stages the project uses: a `release` check only in a project with a
  planned-releases note. It shows you the draft, and each change you ask for again, and writes the
  repo's section only once you approve it, through `second-brain validation new` for a missing
  one.
- `vault-setup` offers it when it adds a repo, in project, repo, subproject or adopt mode.
- The vault index names the define-validation-scope skill. The plugin's index template is now at
  `index_version: 9`, so the doctor's `index` check warns. Copy the bullet that starts
  `- Call a plugin skill or agent` under `## In every session` from
  `templates/vault-index.md.tmpl` into your vault's `CLAUDE.md`, then set `index_version: 9`.

- Before story-tracker writes a new story, yours or one from refinement, it searches the project's
  open and done stories by title, summary and criteria, and shows each one with the same outcome,
  with its status. It lists the open epics the story could join and proposes one, or none, with
  the reason. You pick: change the story that exists, file the new one under an epic, or write it
  on its own. Nothing is written before you pick.
- In refinement, a story you pick in place of a new one takes its parent, its links and its line
  in the epic's list, unless you keep it under its own parent. A story you file under another
  parent, or none, is listed under that one alone.

- `second-brain branch <project> <ID>` reads a ticket's branches with read-only git: the repo, its
  current branch and head, the base branch and the branch pattern, each local or remote branch
  that carries the id, the task's recorded branch, and whether the current branch is on the
  ticket. `--show <ref> <file>` prints a file as it is on another branch, and `--started` the log
  and the diff stat of the ticket's branch against the base. `--path <dir>` reads another folder,
  such as a git worktree. It takes no git setting from outside, as its rows in `docs/contract.md`
  say.
- story-tracker's branch check and the scrum-master's refinement read git through
  `second-brain branch`, and run no `git -C` of their own. So a recall, a start, an update or a
  refinement asks for no permission, whatever your permission mode.
- A branch carries a ticket's id only with no letter or digit right before or after it:
  `feature/EX-10-sort` is no longer taken for a branch of `EX-1`.

- The `build` skill cuts its run into batches of 1 to 3 related stories, in the run's order:
  stories that share an epic, or whose text names a file in common. One `implementer` and one
  `reviewer` build a batch's stories in turn, so the pair reads the code those stories touch once,
  not again for each story. A story with no related one next to it builds alone.
- Each story of a batch keeps its own branch, worktree and commits, its own status notes, and
  passes or fails on its own review. A failed story goes back to the same `implementer` before
  the batch's next story starts, and the cap of six failed reviews counts per story.
- The batch's agents are `<batch>-implementer` and `<batch>-reviewer`, `<batch>` being the id of
  its first story. Its next story and its next review reach them with SendMessage, and each
  agent takes it as a new prompt: a story's rulings hold for that story alone, and an earlier
  review is no evidence for the next. A story's review is no longer a fresh `reviewer` each time.
- A fix message names its story, with the story, repo, worktree, branch and base lines of the
  story's prompt.
- A profile key, `build_pairs`, sets how many `implementer` and `reviewer` pairs the `build`
  skill runs at once: a whole number from 1 to 5. With no key, or any other value, it is 1, and a
  build runs one story at a time, as before. `second-brain profile <project> --keys` always prints
  its line, with the value the build takes.
- The doctor's `settings` check warns on a `build_pairs` it does not take, `build_pairs:invalid`.
- With more than one pair, batches build side by side, each by its own pair in its own stories'
  worktrees. Only stories that neither wait on each other nor sit in one batch go side by side: a
  batch starts once each story it waits on in another batch has passed.
- The lead's one check watches every pair, and a stop in one pair stops its batch alone. While
  another pair is at work the skill asks the owner in its reply, not with AskUserQuestion, so the
  other pairs go on. Merges run one at a time.

## 0.12.0 - 2026-11-24

- The `scrum-master` skill replaces the `sprint` skill and the `scrum-master` agent. It has four
  workflows, each a file of its own, read only when it runs: `refinement`, `sprint-planning`,
  `release-planning` and `organize-board`, as `## 9. Skills and agents` in `docs/contract.md`
  says.
- `/odsb:sprint` is now `/odsb:scrum-master sprint-planning`: it opens a sprint, picks its stories
  and closes it with carry-over, as the sprint skill's `open`, `plan` and `close` did. Ask for the
  agent's work as before: the skill takes it.
- `refinement` drafts or refines an epic and its stories, or one story, with you, in
  story-tracker's shape, with at most 4 acceptance criteria and the `task dep` links of each
  story. It shows a change you ask for again, and writes nothing until you approve the draft. Then
  story-tracker writes each story.
- `release-planning` sets a release's goals, epics and stories with you, in the project's
  `<topics_root>/planned-releases.md`, whose shape is under `### Planned releases` in
  `docs/contract.md`. A story or epic that does not exist yet goes through `refinement` first.
- `organize-board` is the agent's hygiene pass: it runs the doctor on a project and changes
  nothing without asking.
- The daily status is gone. story-tracker's status gives the active stories, a standup and the
  stories of the sprint.
- story-tracker's start mode shows a new story's text, and writes it only once you approve it. A
  story set to done goes to `docs-keeper`.
- story-tracker and the sprint close no longer log achievements: only an achievements skill tracks
  them. `achievements_skill` stays in the profile, and no skill reads it until the plugin's
  achievements skill, which is planned.
- A sprint close asked for with no sprint in progress says so and stops. It opens a sprint only
  when you ask for one.
- The scrum-master skill may edit and write notes and call story-tracker with no prompt, and
  story-tracker may edit notes. Both may run `ls -d` with no prompt. Their git commands still
  prompt: a pattern for `git -C <path>` would let a `-c` setting run a program.
- The doctor's `sprints` fixes name the scrum-master skill.
- The vault index names the scrum-master skill and the build skill, and no `sprint` skill or
  scrum-master agent. The plugin's index template is now at `index_version: 8`, so the doctor's
  `index` check warns. Copy the bullet that starts `- Call a plugin skill or agent` under
  `## In every session` from `templates/vault-index.md.tmpl` into your vault's `CLAUDE.md`,
  then set `index_version: 8`.
- A note, a skill or a settings rule of your own that names `odsb:sprint` or the scrum-master
  agent: change it to the `odsb:scrum-master` skill.
- `implementer` and `reviewer` run each check in the foreground, with a timeout of 10 minutes,
  and wait for one that outlasts its call, 3 minutes in a background agent: no agent replies
  while a check it started still runs.
- `reviewer` grades code quality on a failing story too, so that one fix round answers every
  defect. A re-review still grades the quality of the fix's commits alone.
- The test workflow runs `scripts/test-doctor.sh` as four parallel jobs, one per `--shard <n>/4`.
- `reviewer` sorts each finding as a defect or a follow-up, as `## Defects and follow-ups` in
  `agents/reviewer.md` says. A name that misleads, code repeated where it could be shared, or code
  against the conventions around it is a follow-up. It stays a defect when a check fails on it, a
  user would hit it, it makes a doc wrong, or the story's criteria or Approach, or a rule written
  in the repo, names it. Every other finding is a defect.
- Only a defect fails a story, counts in the verdict's `issues` and goes to the fix loop. A
  follow-up is a `Follow-up:` status note on the story. When the build finishes or stops, it lists
  each one so far for the owner, who can have one fixed then.
- Each order in `lead-agent-task-memory.md` has a `Done when:` line: one condition a command, a
  file or a branch state can test, such as `git merge-base --is-ancestor <branch> release/<version>`
  exiting 0. The lead writes it from the owner's words when it takes the order, and asks the owner
  only when the words give none.
- The lead's check tests each open order's condition, at the pace `lead_check_minutes` sets. It
  closes an order whose condition holds, never one whose condition does not, and never changes a
  condition without the owner. The finish closes only the orders whose condition holds.
- A build agent ends each check with `echo "check ended: exit $?"`, rarer in a check's output than
  a bare `exit:`. Its wait reads the file with `grep -qs`, and ends too on a notice that the check
  ended, as when the harness stops one that never writes the line. A call may move to the
  background after 3 minutes.
- A new `build` skill builds approved stories: one story, or an epic's open stories in the order
  their `depends_on` sets. Each one is built in a git worktree of its own, `<repo path>-<ID>`, by
  one `implementer`, and graded by a fresh `reviewer` against its acceptance criteria and the
  repo's `validation.md`, until one passes or the fix rounds run out. A passed story waits for the
  owner's go to merge, and its worktree is removed.
- It builds only a story whose status notes hold `Planned: the owner approved this text.`.
  story-tracker now writes that note for a story approved in start mode too.
- A story build keeps its progress in the story's status notes: a `Build: review <n>` note after
  each verdict, and the reviewer's `Defect <n>:` and `Follow-up:` notes. It keeps the owner's
  orders note and the lead's check in `skills/build/lead.md`.
- The build skill reads the project's git flow from `## Rules` in its Claude hub: where a story's
  branch is cut, and where a passed story merges, such as the open `release/<version>`. With no
  flow written, it asks the owner where the story merges, and offers to write the answer there.
- A passed story merges on the owner's go, locally. A conflict where both sides only add lines,
  with an empty merge base in `diff3` style, keeps both. Any other conflict is shown, and the
  merge aborted. The repo's checks run on the merged tree unless it is the one the review read,
  and a push runs only on the owner's word. The story's worktree is removed after the merge.
- `implementer` and `reviewer` build and review a whole story in its git worktree, in story mode.
  Before it commits, the implementer checks its whole change against the story's criteria and the
  reviewer's `## Defects and follow-ups` and `## Code quality`.
- `second-brain validation <project> <repo>` and `validation run` take `--path <dir>`: a folder
  that stands in for the repo's, such as a git worktree of it. The checks run there, and a
  `validation.md` kept in the repo is read from there, so a review checks the branch it reviews.
- The spec flow is retired, so there is one flow to learn: the `build` skill builds every approved
  story from its README. The spec skill and its checker agent are gone, and so are the helper's
  spec commands, the three spec templates and `build.json`. `second-brain help` lists no spec
  command.
- `implementer` and `reviewer` keep their story mode and the baseline, and lose the task mode,
  its bundles, and the user and branch reviews that only a spec build ran.
- The `delivery` and `spec_home` keys are gone from the profile, the subproject note and the task.
  story-tracker weighs no story: when work starts on one, it offers `/odsb:build`.
  `second-brain subproject` prints no `delivery` or `spec_home` line, and `task set` no longer
  checks a `delivery` value.
- The doctor's `delivery` check is now `settings`: it names a `validation_home` or a
  `lead_check_minutes` that is not allowed, and reads no `delivery` or `spec_home` key. The
  `spec-trace` check is gone.
- The validation commands live in `scripts/lib/validation.sh`, and `second-brain help` lists them
  under `checks:`. They work as before.
- The conventions note is at version 11: it names no `spec` note type and no `delivery` key. The
  doctor's `conventions` check warns about an older note.
- A vault with specs moves on as it is. A story's `spec/` folder and `build.json` stay in its task
  folder as plain notes: nothing reads them, a move takes them with the task, and no doctor check
  is about them. A spec kept in a repo stays there until you delete it.
- To build a story you started from a spec, bring what its spec settled into the README's
  criteria through `/odsb:scrum-master refinement`, approve the text, then run `/odsb:build <ID>`.
  Remove a `delivery` or `spec_home` key when you like: nothing reads it.
- A note, a skill or a settings rule of your own that names the spec skill: point it at the build
  skill.

## 0.11.0 - 2026-11-23

- A project can keep each task in the folder of its sprint: `task_layout: sprint` in the profile
  puts a task in a sprint at `<tasks_root>/<sprint folder>/<ID>/README.md`, and a task in no
  sprint at `<tasks_root>/backlog/<ID>/README.md`. Nothing is archived, and story-tracker asks
  nothing. With `uses_sprints: false` the key reads as `flat`.
- `sprint_folder` in the profile names a sprint's folder: its end date with no key, or a pattern
  of `<end>`, `<start>` and `<n>`, such as `sprint-<n>`, as `### Profile frontmatter` in
  `docs/contract.md` says. A pattern that gives a sprint no folder name makes each command that
  would move a task there exit 5, writing nothing.
- In a sprint project, `second-brain task new` writes a task into `backlog/`. `task set` with a
  new `sprint` moves the folder to that sprint's folder, and `sprint=` moves it back to
  `backlog/`, rewriting each link to it. It exits 6, writing nothing, when something is at the
  destination or the sprint's folder is a task. A status change moves nothing.
- `sprint open` moves each task it re-points to the new sprint's folder. `sprint close` moves each
  task named in `--carry` to the next sprint's folder, and each named in `--backlog` to
  `backlog/`; done and abandoned tasks stay in the closed sprint's folder. Both look at every
  destination before they write, and exit 6 on a taken one.
- Commands find a task in `backlog/` and in every group folder, in every layout: a folder directly
  under the tasks root with no `README.md` of its own holds tasks, such as a sprint's folder.
  `task new` and `task alias` exit 5 for `backlog`, in any letter case, as they do for `archive`.
- A new board's filters take a task in a group folder. An existing board is not rewritten: in a
  sprint project, the doctor's `board` check warns on one without that branch,
  `tasks.base:no-sprint-filter`.
- The doctor's `no-readme` check reads each folder under `backlog/` and a group folder, and
  `task-location` takes a task in one. `task-layout` names a task of a sprint project outside the
  folder of its sprint or `backlog/` (`<ID>:<folder>`), a `sprint_folder` that gives no folder
  name (`sprint_folder:invalid`), `task_layout: sprint` with sprints off (`task_layout:no-sprints`),
  and a group folder that holds a task in another layout (`<folder>:<layout>`, as `backlog:flat`).
- In a sprint project, `doctor --fix` moves each task to the folder of its sprint, or to
  `backlog/` with none, then removes each empty group folder, a status folder too, whether or not
  a move emptied it, and the archive's empty folders.
  To switch a project that has tasks, or to rename its sprint folders with a new
  `sprint_folder`, set the key, then run `doctor --fix` once.
- In a status project, `doctor --fix` now also removes each empty group folder other than the
  five status folders, whether or not a move emptied it: an empty folder directly under the tasks
  root, such as an empty `backlog/`, a sprint's folder or a task folder with no README there. An
  empty status folder stays, and so does an empty folder inside one, such as `planned/<ID>/`.
- The search rule warns on a whole Read of a task note in `backlog/` or a sprint's folder too. The
  sprint skill and scrum-master say what a sprint project's close moves, and what to do when it
  cannot. The sprint skill says the same of `sprint open` and of setting a task's sprint in plan.
- docs-keeper names `tasks/backlog/` and the sprint folders as a task's place in a sprint
  project. `vault-setup project` and `adopt` offer `task_layout: sprint`, and `sprint_folder` with
  it, and `adopt` offers the one `doctor --fix` run that moves the tasks already there.
- The vault-doctor `fix` mode counts a sprint project's moves as a bulk change, with a snapshot
  before it and `compare` after it. Its checks say what each new `board`, `no-readme`,
  `task-location` and `task-layout` row means, and how to fix it.
- The conventions note is at version 9: it names the sprint layout. The doctor's `conventions`
  check warns about an older note.
- The vault index names the sprint folders as a task's place in a sprint project. The plugin's
  index template is now at `index_version: 7`, so the doctor's `index` check warns. Copy the task
  bullet under `## Rules for notes that most often go wrong` from `templates/vault-index.md.tmpl`
  into your vault's `CLAUDE.md`, then set `index_version: 7`.
- The pull request format writes its five headings as bold lines with no `##`, as in `**Goal**`.
  The note is at `pull_request_version: 4`, so the doctor's `pull-request` check warns about an
  older note. `doctor --fix` replaces one that was never edited.
- A spec build agent that goes idle with no report, such as one that says its checks still run,
  no longer stalls the build. The `spec` skill checks the branch and whether a check the agent
  started still runs. With none running, it sends the agent one message to finish its step and
  report, then takes its next reply as final. Work that still runs is waited for.
- An idle notice that repeats a reply the skill took already, as a named agent's last reply comes
  twice, changes no state and gets no reply.
- The skill keeps your open orders of a build in `<project>/claude/lead-agent-task-memory.md`,
  linked from the project's `claude/README.md`: each order with its date and your words, what
  works on it now, the orders done, and the last check of each story. Builds of one project
  share the note and only edit it. It is removed with its hub line once no order of any story is
  open. You can stop the build or drop an order at any time: it is then closed.
- While an order is open, the skill checks on the agents, the branch and the running checks
  against your orders, as often as the profile's `lead_check_minutes` says. In Claude Code it is
  a session-only `CronCreate` job, off the hour and the half hour. It stops once no order of its
  story is open. It never takes the build back after you interrupt it or tell it to hold. The
  check never pushes, merges or takes another outside action.
- A profile key, `lead_check_minutes`, sets the pace of that check in one place, as
  `### Profile frontmatter` in `docs/contract.md` says. The doctor's `delivery` check warns on a
  value it does not take, `lead_check_minutes:invalid`.
- In a status or sprint project, a child task, one whose `epic` names another task, sits inside a
  folder named for its parent, in the folder of its own status or sprint:
  `<tasks_root>/<status>/<parent>/<ID>/README.md`, `<tasks_root>/backlog/<parent>/<ID>/README.md`
  or `<tasks_root>/<sprint folder>/<parent>/<ID>/README.md`. The parent's own note stays where
  its own status, or its sprint or `backlog/`, puts it. A flat or archive project moves nothing.
- `task set <ID> epic=<parent>` moves a child into that folder, and `epic=` moves it out. A status
  or sprint change, `sprint open` and `sprint close` keep a child under its parent. A parent's move
  takes its own files alone, so a parent done or abandoned leaves its open children where they are.
  A move that leaves a folder named for a parent empty removes it, `removed: <path>`.
- Commands find a task one level deeper in a group folder: a child inside its parent's folder, and
  each task in a folder named for a parent with no README of its own.
- `parent_label` in the profile names a project's parent stories `feature`, or `epic` with no key.
  `task head` prints the `epic` line as `feature:` where it is `feature`, and a new board names its
  column after it. `scaffold project --parent-label` writes the key, and `vault-setup` asks for it.
  The frontmatter key stays `epic`.
- A new board's filters take a task one level deeper. An existing board is not rewritten: in a
  status or sprint project with a child, the doctor's `board` check warns on one without that
  branch, `tasks.base:no-child-filter`.
- The doctor's `task-layout` check names a child outside its parent's folder
  (`<ID>:<status>/<parent>` or `<ID>:<folder>/<parent>`), which `doctor --fix` moves, a task whose
  `epic` names no single task, none or several (`<ID>:unknown-<label>`), which it leaves where it
  is, and a `parent_label` that is neither word (`parent_label:invalid`). `no-readme` and
  `task-location` take a child in its place.
- A folder with no README of its own, one level deeper in a group folder, holds tasks only when it
  is named for a task found elsewhere. A task folder that lost its README is still named by
  `no-readme`, and nothing in it is taken for a task.
- The search rule warns on a whole Read of a child task note too. story-tracker, the sprint skill,
  scrum-master and docs-keeper name a child's folder and call parent stories by the project's word.
- The conventions note is at version 10: it names a child task's folder. The doctor's
  `conventions` check warns about an older note.

## 0.10.0 - 2026-11-22

- A project can keep each task in the folder of its status: `task_layout: status` in the profile
  puts a task at `<tasks_root>/<status>/<ID>/README.md`, in `planned`, `in-progress`,
  `in-review`, `done` or `abandoned`. Nothing is archived, and story-tracker asks nothing.
- In a status project, `second-brain task new` writes a task into `planned/`. `task set` with a
  new `status` moves the folder to the folder of that status and rewrites each link to it, and
  exits 6, writing nothing, when something is there. `sprint close` moves each task named in
  `--abandon` into `abandoned/`. A task that leaves the archive loses its `archived` key.
- Commands find a task in a status folder, in every layout. `task new` and `task alias` exit 5
  for a status folder's name, in any letter case, as they do for `archive`.
- A new board's filters take the five status folders. An existing board is not rewritten: in a
  status project, the doctor's `board` check warns on one without them,
  `tasks.base:no-status-filter`.
- The doctor's `no-readme` check reads each folder under a status folder, and `task-location`
  takes a task in one. `task-layout` names a task of a status project outside the folder of its
  status (`<ID>:<status>`) or in the archive (`archive:status`), and a status folder that holds a
  task in another layout (`<status>:flat` or `<status>:archive`).
- In a status project, `doctor --fix` moves each task to the folder of its status, then removes
  the archive's empty folders. To switch a project that has tasks, set the key, then run
  `doctor --fix` once.
- The search rule warns on a whole Read of a task note in a status folder too. The sprint skill
  and scrum-master say what a status project's close moves, and what to do when it cannot.
- The conventions note is at version 8: it names the status layout. The doctor's `conventions`
  check warns about an older note.
- The vault index and docs-keeper name `tasks/<status>/` as a task's place in a status project.
  The plugin's index template is now at `index_version: 6`, so the doctor's `index` check warns.
  Copy the task line under `## Rules for notes that most often go wrong` from
  `templates/vault-index.md.tmpl` into your vault's `CLAUDE.md`, then set `index_version: 6`.

## 0.9.0 - 2026-11-21

- A project can keep its own `task-readme.md.tmpl` and `ticket-description.md.tmpl` in
  `<project>/claude/templates/`. Each wins over the plugin's template of that name.
- `second-brain task new` fills the project's README template. story-tracker fills the project's
  ticket text template for a draft or ticket text.
- `spec link` takes a section that holds the text of the project's README template or of the
  plugin's as template text, so a story made before the project had its own gets its link alone.
- A placeholder left unfilled in a project's template makes `task new` exit 5 and name the
  template by its vault path.
- A README filled from a project's template with no frontmatter, such as an empty one, makes
  `task new` exit 5 and write nothing.
- The doctor's new `task-template` check warns when a project's README template lacks a
  frontmatter key, `aliases` included, or a section the helper or story-tracker writes. Each
  project gets one more doctor row.
- story-tracker adds no section to a new story that the project's README template leaves out.
- `task note`, `task head`, `task new --envs`, `sprint open`, `sprint close` and
  `scaffold subproject` take no line in fenced code for the heading they write under or read.
  `task note` once wrote into a fenced `## Status notes` example that came before the real
  heading, and `task head` showed that example as the newest note.
- `second-brain link --foreign` lists each skill and agent in `~/.claude/skills` and
  `~/.claude/agents` that no vault `claude/` folder provides: a real folder or file, or a link and
  where it leads.
- `second-brain link move <skill|agent> <name> [--project P]` moves one of them into the vault's
  `claude/` or a project's, links it as `link --apply` does, and adds its row to the Skills or
  Agents table of that folder's `README.md`.
- What a link into the vault leads to is moved as `second-brain move` moves it, and the links to
  it are rewritten. What a link out of the vault leads to is copied, and the original stays.
- `second-brain link drop-original <skill|agent> <name> <path>` removes that original, only when
  the item is linked from the vault and the original matches the copy byte for byte.
- After a copy, `/odsb:vault-doctor fix` asks whether to delete the original. On a yes it runs
  `link drop-original`. On a no the original stays, and the report names it.
- The doctor's new `foreign` check warns on each of them, named with what it is:
  `skills/<name>:folder`, `agents/<name>.md:file` or `skills/<name>:link to <target>`. A folder
  with no `SKILL.md` and a link into the plugin are not read.
- `/odsb:vault-doctor fix` asks with AskUserQuestion, one at a time, whether each goes to the
  vault's `claude/`, to a project's `claude/`, or stays. Only on that answer does it run
  `second-brain link move`.
- The vault-setup skill's link mode points to that check: it still leaves a foreign entry alone.
- Notes follow `claude/writing-style.md`, which `scaffold vault` creates; a project's own wins.
- The plugin's index template is now at `index_version: 5`, so the doctor's `index` check warns.
  Run `second-brain scaffold vault`, which creates `claude/writing-style.md` and overwrites
  nothing. Then add the template's new line under `## In every session` and set
  `index_version: 5`. The doctor's new `writing-style` check warns while the note is missing.
- `scripts/test.sh` runs the areas of `scripts/tests/` in parallel, or one: `scripts/test.sh tasks`.

## 0.8.0 - 2026-11-08

- The README has a quick start, a section for each `/odsb:` command and a table of the agents, each
  with what it does and when to use it.
- Its new examples show what you type and what Claude does: a ticket, a standup, a spec build and
  a vault check.
- Its overview says what each feature does in place. Its `/odsb:spec` section describes the build:
  test-first tasks, a review of each, the capped fix rounds and the JSON verdict.
- The README's update steps are four steps. What to do when an update does not take, and
  auto-update, moved to `## Updating` in `docs/guide.md`. The note on an early 0.2.0 copy is gone.
- `## What you get` in `docs/guide.md` links to the README's commands and agents, in place of its
  own table.

## 0.7.0 - 2026-11-08

- The vault-doctor skill's `validation` row says it also warns on a placeholder an earlier
  validation template had, as the doctor has done since 0.6.0.
- The 0.6.0 note on the Windows doctor tests gives their time as 25 minutes, not 17.
- `scripts/test.sh` checks the agents' descriptions in a form the bash 3.2 of macOS can parse.
- The `spec` skill runs the build in your session. It launches `implementer` and `reviewer`
  itself with the Agent tool, one at a time, and takes each report from the agent's result, so
  no report is relayed by hand.
- The `spec-lead` agent is gone. The skill took over its build.
- The skill's build part is in the new `skills/spec/build.md`, read only when a build starts.
  `skills/spec/SKILL.md` stays a short router.
- Each launch names its model by role and round: `opus` for `implementer` and `reviewer`, and
  `fable` for the last two fix rounds and for the review of the whole branch.
- A spec story's build progress is in `build.json` in its task folder in the vault, whatever its
  `spec_home`, never in its README. Per task it holds a build state, a review state, the commits,
  each issue with its proposed fix, and the time each state was set.
- The new `building` state is set before each `implementer` launch, a retry included.
  `in-review` is set before each `reviewer` launch.
- `second-brain spec status <ID> <task> <state>` sets the field its state belongs to, and adds no
  status note. `spec issue` adds the issue to `build.json`.
- `second-brain spec status <ID>` prints one line per task:
  `T1 - build: built - review: failed - fails 1 - commits <hashes> - fix <hashes> - <title>`, its
  issues under it. `--json` has the keys `id`, `build`, `review`, `fails`, `commits`, `fix`,
  `title` and `issues`.
- Upgrading: a README `## Build` section, such as one an earlier build wrote, is read as it is.
  The next `spec status` or `spec issue` write moves it into `build.json` and removes it from the
  README, whose line endings it keeps, on Windows too.
- The skill shows you `spec status <ID>` after each task's review, when the build stops or
  finishes, and when a session resumes a build. The build started, stopped and why, and
  finished, and each ruling, stay in the README as status notes.
- `implementer` and `reviewer` get the story, the task and the session id, and run
  `second-brain spec packet` themselves. The skill never prints a packet into your session.
- The packet has `commits` and `diff` lines. `diff` names a temp file the helper writes with each
  of the task's commits, and `reviewer` reads the change from it.
- A task may name `- Provides: <signatures>`. A task that names `- Uses: T<n>` gets those lines
  in its packet, under `## Uses`. On a retry the packet holds the task's logged issues, under
  `## Issues`.
- `reviewer` logs its findings with `spec issue` and replies with its verdict and the number of
  issues.
- The tasks phase checks every task's packet without printing it.
- A resumed build takes a cut-off task's commit only when `build.json` does not list it yet,
  compared by full hash. It launches a `blocked` task again only with a ruling newer than the
  stop, and asks the owner otherwise.
- A block writes its stop note before it sets `blocked`, so a new session never takes an older
  ruling for it.
- A `build.json` that is blank, or not an object with a `tasks` array, makes `spec status`,
  `spec issue` and `spec packet` exit 1. It never reads as a build that has not started.
- `build.json` is written next to itself, then moved in place, so a write cut off leaves the old
  file.
- A line break in an issue prints as a blank in `spec status` and the packet, so each issue stays
  one line.
- `SECOND_BRAIN_NOW` sets the time `build.json` records, for tests.
- Each task is reviewed right after it is built, before the next one starts. A fresh `reviewer`
  reads only its diff, against its requirements first, then for code quality, and runs only its
  `each task` checks.
- A failed task goes back to the same `implementer` with its findings, which the skill reaches
  again with SendMessage by the name it launched it with. A fresh one takes over when it cannot.
- The fix loop has five rounds: three on the same `implementer`, then two on a fresh one on the
  stronger model. A sixth failed review stops the build.
- The rounds are a task's `fails`, its failed reviews in `build.json`, so the cap holds across
  sessions. A task stopped at the cap waits for a ruling newer than its stop, as a blocked one
  does.
- A re-review reads only the fix's commits and the findings it answers. The packet's new `fails`
  line says which it is: its `diff` and `## Issues` then hold only those.
- `build.json` records the commit of each state set with `--commit`, and the review round of each
  issue.
- When every task has passed, the skill runs `second-brain validation run <project> <repo>
  --when each-build` once, with no agent. A failing check is logged on the task whose files it
  covers and takes the fix loop.
- Then `reviewer` runs the user steps on the finished branch, in the new user mode. One review of
  the whole branch, in the new branch mode, ends the build.
- Each check and user step in `validation.md` ends with `when: each task`, `when: each build` or
  `when: release`. None means `each build`, and so does any other value, which every run names
  as a warning. A `release` check runs only when you ask.
- The new `second-brain validation run <project> <repo> [--when each-task|each-build|release]
  [--timeout <seconds>] [--json]` runs the matching checks from the repo's root, one at a time,
  each stopped after 1800 seconds by default. It prints one row per check and exits 0 only when
  all pass.
- `validation run` stops what a command leaves running when it exits, before the next check
  starts. On Windows a timeout also stops the command's Windows processes with `taskkill`.
- `validation run --json` gives `exit` and `seconds` as numbers, `null` on a skipped row.
- The skill and `reviewer` run `validation run` in the background and wait for its notice, since a
  build-wide run can outlast a Bash call's timeout.
- The skill shows `spec status` once a review's state is set. A resumed failed task looks for the
  owner's ruling as a blocked one does, and the cap writes one stop note.
- The validation template asks for each check's command in backticks and for when it runs.
  `/odsb:vault-setup validation` drafts both. The doctor still flags the template's earlier
  lines.
- Upgrading: in a `validation.md` with no `when:`, every check runs once, at the end of each
  build, and none in a task's review. Add `when: each task` to a quick check to run it in each
  review, and `when: release` to a costly one.
- `implementer` builds each task test-first. It writes a test that fails for the task's
  requirement, makes it pass, and runs the checks its packet names before it commits. A task with
  nothing to test, such as a doc change, says why.
- The packet's new `## Checks` part names those checks: the task's `Check`, then each command
  `validation run --when each-task` runs. The `each build` checks still run once, when every task
  has passed.
- `implementer` commits only when its checks pass. Its reply adds a `Test:` line and a `Check:`
  line per check with its result. It runs them in the background, so a long suite is never cut
  off.
- A task's `- Check:` step that `implementer` has no tool for, such as a browser or a skill step,
  is reported as skipped and left to the review. The build goes on.
- A task's `- Check:` now runs before its commit and again in its review. Write it as the
  narrowest command that runs the task's test, not every suite.
- A new build skips the baseline when the story's branch starts on the base branch, which is
  tested already. The test is `git merge-base --is-ancestor`, against `origin/<base>` when the
  repo has it, else `<base>`. The base is the subproject's `base_branch`, or the profile's.
- A skipped baseline writes the status note
  `Build: baseline skipped: the branch starts at <short hash> on <base>.` A branch cut from a
  release branch, or with commits the base lacks, still gets the baseline. The final validation
  always runs.
- In the tasks phase the `spec` skill may mark small, alike tasks with `- Bundle: <n>`, for you
  to approve with the task list.
- A bundle's tasks go to one `implementer` run, one commit per task, each built test-first with
  its own checks. Then one `reviewer` judges each task against its own requirements and gives one
  verdict per task, before the next task or bundle starts. Nothing builds in parallel.
- A task of a bundle that fails its review takes the fix loop alone, with its own cap. A bundle
  cut off part way resumes from `build.json`.
- A resumed task cut off while `building` no longer takes the tick commit of a `spec_home: repo`
  spec, `<ID> <task>: passed review`, for its own.
- `spec status` names each task's `fix`: the commits built since its last failed review. A
  resumed failed task with a fix goes to the review of that fix, not to a new fix round.
- A task whose reply names no commit is looked for by its commit before it is set `blocked`.
- `second-brain spec tasks` prints each task's bundle in a fourth column, `-` for none, and
  `--json` adds the key `bundle`. A bundle that is not a whole number, whose tasks are not next to
  each other, or whose task uses another of its tasks, exits 1.
- Once the build has started, the `spec` skill stops and asks you only for a short list: a
  destructive action, a security-sensitive one, an outside effect such as a push, a merge or a
  publish, a spec too broken to follow, a task blocked or past its last fix round, and a failed
  baseline. `## 8. When to ask the owner` in `skills/spec/build.md` holds it.
- Any other question, such as an ambiguous requirement or two agents that disagree, the skill
  decides itself and records as a status note,
  `Ruling: <task>: <the question> - <the decision and why>`.
- A ruling never changes, adds or drops a requirement, a design decision, a task or a check. One
  that would is a spec too broken to follow, and stops the build.
- An `implementer` `BLOCKED:` on such a question, such as a requirement it reads two ways, gets a
  ruling and the task goes on. The same question again stops the build.
- Every ruling of the build on a task, the skill's and yours, goes as written into that task's
  next `implementer` and `reviewer` prompts, as `Ruling:` and `Owner:` lines. The user and branch
  reviews get them all. Where the two differ, yours wins.
- The rulings of a build are the status notes newer than its newest `Build: started` note, so a
  new session finds them and never takes those of an earlier build. A `Spec: <phase> reopened`
  note retires the rulings before it: the changed phase holds what you kept of them.
- When the build finishes or stops, the skill lists every ruling of the build, with the phase
  each touched. You can reopen that phase, or reverse a ruling with your own. A task that passed
  then takes your ruling as an issue to fix.
- A resumed failed task whose stop you have not answered asks you first, whatever its fix round.
  A `Spec: <phase> reopened` note newer than the stop answers it, for a blocked task too.
- A FAIL of the user check or the branch review no longer stops the build. Each task it logged a
  finding on takes the fix loop, as a failing build-wide check does.
- A failing build-wide check, or a user or branch finding, that no task covers goes to the last
  task, with a ruling. A review that still gives no verdict, asked again and then from a fresh
  `reviewer`, is taken as BLOCKED.
- `reviewer` grades each acceptance check, and each check and user step it runs, as met or not,
  with its evidence. A check not met fails the task, and so does any other finding: a PASS with
  an open finding is not allowed.
- `reviewer` takes the implementer's report, commit messages and comments as claims to check,
  never as evidence. The `spec` skill gives it no view of its own on the result.
- `reviewer` ends its reply with a JSON block, `{"verdict": ..., "issues": <n>, "checks": [...]}`,
  in place of the `VERDICT:` line. A bundle's block holds one entry per task. The `spec` skill
  reads each verdict from it, as `### Reading a verdict` in `skills/spec/build.md` says.
- No block, or one that breaks its rules, is no verdict and never a PASS. So is a PASS with a
  check not met or an issue logged in its review, and a FAIL that adds no issue. The skill
  asks once more only when the block is missing or does not parse. Otherwise it launches one
  fresh `reviewer`, judged against the issue counts taken before the first, then takes it as
  BLOCKED.
- `agents/reviewer.md` holds two worked examples, a FAIL with its findings and a PASS with its
  evidence. Its grading is tuned on the reviews of an earlier build: a check on every item of a
  kind is met only when each item meets it, a defect it sees is a finding even when no check
  names it, and a check a ruling settles is met.

## 0.6.0 - 2026-11-08

- The test workflow runs the doctor tests in a job of their own on each runner, in parallel with
  the leak check and the other suites. On Windows they took 25 of the run's 40 minutes.
- `--json` on `task head`, `spec tasks`, `spec status <ID>` and `validation <project> [repo]`
  prints the same fields as one JSON value, as `doctor --json` does, so an agent never misreads a
  field. `docs/contract.md` section 7 gives each shape.
- A `## Build` row with no commit keeps `commits -` when `spec status` or `spec issue` writes the
  section again.
- A `## Build` row whose task left `tasks.md` keeps its title when the section is written again.
- The `spec` skill asks one question at a time and shows each draft in chunks of about 200 to 300
  words, as `## The chat` in `skills/spec/phases.md` says.
- Each task's check names its command or step and its expected result:
  `- Check: <command or step> - expected: <what it prints or shows>`. The tasks template shows it.
- Before you approve the design, and again the tasks, the new `spec-checker` agent reads the spec
  files alone and lists what it could not build from them. You close each gap before you approve.
- `story-tracker` weighs a story with no `delivery` of its own when work starts on it. A simple
  one is set `direct` with no question. For one that needs a spec it asks the owner, and on
  `spec` offers `/odsb:spec <ID>`.
- A `delivery` from the profile or a subproject is now a fallback, as `### Profile frontmatter` in
  `docs/contract.md` says. The `spec` skill writes `delivery=spec` on a story that inherits it.
- The conventions note is at version 7: a task's `delivery` is set when work starts on it. The
  doctor's `conventions` check warns about an older note. Its fix is under `### conventions` in
  `skills/vault-doctor/checks.md`.
- Upgrading: a story built from an inherited `spec` before 0.6.0 has no `delivery` of its own.
  `story-tracker` takes its `Spec: <phase> approved by the owner.` note as `spec` and writes the
  key. To set it ahead, run `second-brain task set <ID> delivery=spec`.
- Each step under `### Check as a user would` names its tool: a skill such as a browser-testing
  skill, a command, an API call or a query. The plugin ships no browser.
- `reviewer` has the Skill tool and runs each step with its tool. A step it cannot run is BLOCKED
  and names the tool, and a browser step's screenshots go in a temp folder it names.
- A step written before, with no tool, runs through Bash when Bash can do what it says. One that
  needs a browser is BLOCKED and asks for its tool.
- `reviewer` removes only an untracked path its first `git status --porcelain` did not list, and
  never runs `git checkout`, `restore`, `reset`, `clean` or `stash`.
- The doctor's `validation` check also warns about the earlier template's user-check line.
- When a spec build passes, the `spec` skill asks whether to merge the branch into the release
  branch, open a pull request into it, or keep it, as the new `skills/spec/finish.md` says. It
  names each push or pull request before it runs, and deletes the branch only when the owner
  types `discard`.

## 0.5.0 - 2026-11-08

The plugin's skills and agents are named `odsb:<name>`, so the agent panel shows which agent runs.

- The plugin's namespace is `odsb`. Skills run as `/odsb:<skill>`, such as `/odsb:spec EX-2`, and
  agents show as `odsb:<agent>`, such as `odsb:spec-lead`.
- The old `obsidian-dev-second-brain:` names stop working: a command, a call or a permission rule
  that uses one finds nothing.
- An install keeps its id, `obsidian-dev-second-brain@second-brain`, and updates in place: the
  marketplace entry keeps its name.
- After updating, run the doctor's `check`. Its new `old-namespace` row (warn) names each line of
  a vault note, a vault skill or agent, or `~/.claude/CLAUDE.md` that still names a skill or agent
  the old way. It also names each string that holds `obsidian-dev-second-brain:` in a
  `settings.json` or `settings.local.json`: in `~/.claude`, and in `.claude/` at the vault root and
  in each repo a profile lists, where a "don't ask again" answer is saved.
- Hand the row's vault lines to `docs-keeper`. Its new `Workflow 6 - A renamed command` rewrites
  every live reference, leaves status notes, discovery logs, a story's build log and changelogs as
  written, and adds a status note to each story it changed.
- `vault-doctor fix` rewrites a `~/.claude/CLAUDE.md` line once you say yes. Change the settings
  rules yourself: nothing edits a settings file.
- No template goes up a version: none named the old namespace. `index_version` stays 4,
  `conventions_version` 6 and `pull_request_version` 3.

## 0.4.0 - 2026-11-07

A project can build its stories from a spec, and every project says how its code is run and checked.

- Three new profile keys, also in a subproject's note: `delivery` (`direct` or `spec`),
  `spec_home` (`vault` or `repo`) and `validation_home` (`vault` or `repo`). A task may set its own
  `delivery` with `second-brain task set <ID> delivery=spec`. The most specific value wins: the
  task's, its subproject's, then the profile's.
- `second-brain spec <ID>` prints the delivery and the spec folder that hold for a story, and the
  paths of its `requirements.md`, `design.md` and `tasks.md`: in `spec/` in the task's folder, or in
  `spec/<ID>/` in the story's repo. `second-brain spec new <ID>` writes them from three new
  templates and never overwrites.
- Every project has a `validation.md`: how to set up and start each repo, the checks that must
  pass, how to check a change as a user would, and what a pass is. It is `claude/validation.md` in
  the vault, one section per repo, or a file at each repo's root. `scaffold project` writes the
  vault note. `second-brain validation <project> [repo]` lists the files or prints one repo's
  steps, and `second-brain validation new <project> <repo>` adds a missing file or section.
- Three new doctor checks. `delivery` warns about a value that is not allowed. `validation` warns
  about a repo with no `validation.md`, no section in it, or a section that still holds the
  template's text. `spec-trace` warns about an open spec story with a criterion no requirement
  serves, or a requirement that serves none.
- Each requirement of a spec names the story's criteria it serves on a `- Serves: AC1, AC3` line,
  which the requirements template writes.
- `second-brain spec link <ID>` links a spec story's Approach, Changes and Verification to its
  `design.md` and `tasks.md`; the `spec` skill runs it when the owner approves the task list.
- `vault-setup` asks for the three keys, and a new `validation` mode drafts each repo's steps from
  its README, scripts and CI config for the user to confirm.
- The project's Claude hub links to `claude/validation.md`, and `subproject <project> <name>`
  shows the three keys.
- A new `spec` skill builds a story from its spec. It writes the requirements, the design and the
  tasks with the owner in the chat, and the owner approves each one. Then the new
  `spec-lead` agent builds the tasks: `implementer` gets each task's context packet
  alone, and `reviewer` runs the repo's validation steps and reads the diff. Only a passing review
  ticks a task, and a task that fails three times stops the build for the owner.
- `second-brain spec tasks <ID>` lists a story's tasks, `spec tick <ID> <task>` ticks one, and
  `spec packet <ID> <task>` prints a task's context packet: the task, its requirements, the design
  sections it names and the repo's validation steps.
- `story-tracker` offers the `spec` skill when work starts on a story whose `delivery` is `spec`.
- The build runs in two passes: `implementer` builds every task, running no check, then
  `reviewer` runs every check task by task. `spec-lead` keeps track in the story's `## Build`
  section, written by `second-brain spec status`, and `reviewer` logs each issue with a proposed
  fix through `second-brain spec issue`, which `spec-lead` hands back to `implementer`.
- The conventions note is at version 5: it names the `spec` and `subproject` note types and a
  task's `delivery`. The doctor's `conventions` check warns about an older note.
- The skills, agents, templates and docs are trimmed to short plain English. Each changed template
  goes up one version: `index_version` to 4, `conventions_version` to 6 and `pull_request_version`
  to 3. Run the doctor's `check` and `fix`, then update by hand each note it names.
- `scripts/test-doctor.sh` defines `exists`, so its two `task-layout --fix` checks on the archive
  run again; they were skipped before.
- A call to an undefined command fails the `scripts/test*.sh` suites, and the result names it.
- `story-tracker` and the `spec` skill cut a new story's branch from `base_branch`. This repo's
  feature branches start from `main`, as `## Releases` in `docs/guide.md` says.
- `story-tracker`'s description says to use it for any question or change on a vault ticket, even
  one the helper could answer, and the index names where a ticket stands, a standup and an update.
- The test workflow gives each runner 60 minutes, up from 30: the Windows run now takes longer.

## 0.3.0 - 2026-10-22

Tasks can be archived and seen by subproject, every session starts knowing its project and ticket,
and the doctor checks more of what the skills write.

- The conventions note is at version 4: it describes the archive layout, the `By subproject` view
  and `board --subproject`, and how a task names its subproject. The doctor's `conventions` check
  warns about an older note.
- The README has an Update section: refresh the marketplace, update the plugin, restart Claude Code,
  then run the doctor's `check` and `fix`. It says what to do when the update does not take, and
  how to turn on auto-update for the `second-brain` marketplace.
- The guide has a Releases section: `version` changes in one commit on `main`, after the release
  pull request is merged, and that commit is tagged `v<version>`. An early copy of 0.2.0 never
  moved to the final 0.2.0, because both say `0.2.0`; 0.3.0 does move.
- A new doctor check, `placeholders`, warns about each line of a project's hub, `claude/README.md`,
  profile or subproject note that still holds the `<...>` text of its template, such as
  `<A rule Claude must follow in this project, one per bullet.>`. Only the template's own text
  counts, and task READMEs are not read. `vault-setup` asks for the project's paragraph and rules
  after `scaffold project`.
- The pull request format opens with a `Goal` section, one or two lines on why the pull request
  exists. Every heading is bold, and every bullet starts with a bold label, as in
  `- **doctor:** warns on an old index`; a heading with nothing to say gets `- **None.**`. The
  description is written from the branch, with `git log <target>..<source>` and
  `git diff <target>...<source>`, both branches named, never from memory of the work.
- The pull request note carries a version, `pull_request_version: 2`, in frontmatter. The doctor's
  `pull-request` check warns about a note older than the plugin's template. `doctor --fix`
  replaces an old note that was never edited with the template. An edited one is left alone, and
  its row says to bring it in line with `templates/pull-request.md.tmpl` by hand: add the goal,
  bold the headings and the labels, take the rules, keep your own, and set
  `pull_request_version: 2`.
- The board shows a task's `subproject` and has a `By subproject` view, which groups the active
  tasks by subproject. `scaffold project` writes it into a new board. The doctor's `board` check
  warns when a project with a subproject has a board without it (`tasks.base:no-subproject-view`).
- `second-brain board <project> [view] --subproject <name>` lists only the tasks of that
  subproject, and `board <project> "By subproject"` lists the active tasks by subproject, with the
  subproject in a last column.
- Inside a subproject's repo, the story-tracker status overview lists that subproject's stories.
- The doctor's new `task-subproject` check warns about a task whose `subproject` names no
  subproject of the project (`<ID>:<value>`). Only a project with a subproject gets the row.
- A profile key, `task_layout`, keeps the tasks folder short: `flat`, the default, or `archive`.
  With `archive`, `second-brain task archive <ID>` moves a done or abandoned task once, through
  `move`, to `tasks/archive/<YYYY>/<ID>/`, writes `archived: "<date>"` and rewrites the links to
  it. When anything is at that path already, even an empty folder, it moves nothing and exits 6.
  Every command still finds the task by id, at either depth, in both layouts.
- The board file that `scaffold project` writes lists archived tasks too. A board written before
  lists only the live ones in Obsidian until its filters block is copied from
  `templates/tasks.base.tmpl`. In a project with `task_layout: archive`, the doctor's `board` check
  warns about such a board (`tasks.base:no-archive-filter`).
- `task new` refuses an id that is archived, and the id `archive`, the archive's folder, in any
  letter case. `task alias` refuses the alias `archive` the same way.
- A doctor check, `task-layout`, keeps a project in its layout: an `archive` folder in a `flat`
  project, an open task in the archive, and a done task left out of it, all warn. A done task is
  left out once `archive_after_days`, 14 by default, have passed since its newest status note or
  its sprint's end; one with neither does not warn, and `task archive` moves it by hand.
  `doctor --fix` archives those tasks through `task archive`, one `fixed:` line each, and never
  moves an open task.
- `no-readme` and `task-location` accept a task at `tasks/archive/<YYYY>/<ID>/README.md`.
- The vault index has a rule for finding and reading notes, under
  `## Rules for notes that most often go wrong`: `second-brain find`, `search`, `task head`, then
  `outline` and a ranged read, a whole note last, and never grep, cat or sed on vault files. Every
  session has it without running `second-brain conventions`.
- The plugin's index template is now at `index_version: 3`, so the doctor's `index` check warns
  about a vault index without the rule. Add the rule from `templates/vault-index.md.tmpl` under
  `## Rules for notes that most often go wrong`, keep your own lines and the table, and set
  `index_version: 3`. The `vault-doctor` skill does this after asking.
- A new PreToolUse hook warns Claude when a Grep call, a Read of a whole task note, or a shell
  grep, cat or sed reaches into the vault, and names the helper commands to use. It only adds
  context: it never blocks a call and never approves one. Edits pass as before. It sets
  `"onFailure": "continue"`, so a hook that cannot run lets the call go on, on Windows too; the
  plugin now needs Claude Code 2.1.295 or later.
- The SessionStart hook prints the session's context in a repo of a project: the project, the
  subproject, the sprint in progress, the branch and the ticket it names, and that ticket's story
  with its status and next step, or `story: none - run story-tracker start`. It ends with the
  rule for finding and reading notes. It reads the repo's files and runs no git command, and
  outside every project it prints nothing, as before.
- story-tracker writes a new story's `subproject` from the `subproject:` line of
  `second-brain context`, and asks which subproject, or none, when the repo is in none of a
  project that has some. A story set to `done` or `abandoned` in an `archive` project gets one
  question: archive it now with `task archive`? The sprint close asks the same once for the
  sprint's done and abandoned tasks. Neither moves a task without a yes.
- `vault-setup project` and `adopt` ask for `task_layout`, and `archive_after_days` with
  `archive`, and write them into the profile. `vault-setup subproject` says how a task names its
  subproject and offers to set it on the tasks that exist.
- docs-keeper and scrum-master take a task's path from `find` or `task head`, so they reach an
  archived task too. The story-tracker overview of what waits on docs uses `task docs` for the
  same reason.
- The vault index and the conventions say where a task lives in each layout and that a task names
  its subproject in `subproject`. Copy the task line under `## Rules for notes that most often go
  wrong` from `templates/vault-index.md.tmpl` into your vault's `CLAUDE.md`.
- The vault-doctor `fix` mode says that `doctor --fix` also archives the tasks `task-layout` names
  in an `archive` project, and replaces an old pull request note that was never edited. Before an
  archive it takes a snapshot, and `compare` after it proves that only those tasks moved.
- Claude can now run the doctor's check on its own: a request such as "Check my vault for
  problems." loads `vault-doctor`, which ran only by name before. Its check writes nothing, and its
  fix repairs only what is safe and asks before anything else. `vault-setup` still runs only by
  name, and offers the doctor for the detail of a check.
- The `story-tracker` description names where a ticket stands and a standup, and the index says to
  call a plugin skill for its work rather than the helper alone, so "Where does EX-2 stand?" and
  "Standup for the Example project" load it. The index is two lines shorter, to keep room for
  project rows under the doctor's 60-line limit.
- The end-to-end check asks five more requests in plain words: where a ticket stands, a standup,
  an update to a ticket, a new sprint and a vault check. A request that does not load its skill
  fails the job, which may now take 30 minutes. The guide lists every request it proves under
  `What to say`.

## 0.2.0 - 2026-10-15

The helper works on the vault's files alone, and the plugin runs on Windows.

- The helper never calls Obsidian. Obsidian is where the vault is read: its command line interface
  is no longer needed, and the app does not have to be running.
- New commands replace what went through Obsidian's index: `outline`, `backlinks`, `unresolved`,
  `move` and `rename`. `move` and `rename` rewrite the links to a moved note in the vault's notes
  and take `--dry-run`. They refuse, before a file is touched, a move that would lose or break a
  link: a name a link cannot spell, a note that cannot be read in full or written, a destination
  that exists.
- Removed: `second-brain ob`, `second-brain probe`, the `--files` flag and the `source:` line of
  `board`, the `obsidian` and `search` lines of `context`, the doctor checks `obsidian-cli` and
  `index-fresh`, and exit code 3.
- `search` finds the notes that hold every term of the text; a part in double quotes is a phrase.
  A note gives at most three lines, the ones that hold the most terms, so the forty rows show
  more notes.
- Windows is supported in Git Bash, the shell Claude Code uses there. The links are directory
  junctions, which need no special rights: one per skill folder, and one per `claude/agents`
  folder. Absolute paths are printed as `C:/...` and read in any form Windows writes them. A path
  inside the vault uses forward slashes on every system, and one with a backslash is refused.
- `second-brain pointer set <folder>` creates the vault pointer on every system. `vault-setup` uses
  it in place of a hand-made symlink.
- The SessionStart hook is written in shell form, so it runs on Windows.
- The conventions note is at version 3: it describes the helper commands in place of the Obsidian
  command line interface, and names `depends_on`.
- The vault's `CLAUDE.md` carries a version, `index_version`, in frontmatter. The doctor's `index`
  check warns about an index older than the plugin's template. It now fails on a row whose path
  is not a folder in the vault, and on a name, a key or a path that two rows share.
- The index says first what holds in every session: a new personal skill or agent is created in
  the vault, at `~/.claude/second-brain-vault/`, not straight in `~/.claude/skills` or
  `~/.claude/agents`, and is registered with `second-brain link --apply`. Its closing line, to
  ignore the file for a task outside the projects, is gone: it cancelled that rule. The rules
  for notes say that they are for notes.
- The index also tells every session to answer in short, plain English and lead with the answer,
  unless the user or their own instructions say otherwise.
- Pull request descriptions have one format: the headings `What was changed?`, `What was added?`,
  `Dependencies:` and `Risks:`, in that order, with a few one-line bullets in plain English under
  each. It lives in a new vault note, `claude/pull-request.md`, which `scaffold vault` creates and
  you can edit. One line in the index points every session to it. A project's own
  `<project>/claude/pull-request.md` wins. The doctor's new `pull-request` check warns when the
  vault note is missing.
- The doctor checks more. `hubs` warns about a project's hub that is missing or empty.
  `task-location` warns about a note with `type: task` that is not the README of its own folder
  under the tasks root. `board` warns, while a sprint is in progress, about a `Current sprint`
  view that filters on another sprint, has a filter the helper cannot read, or is not there.
  `descriptions` warns about a skill or an agent of the vault with no description.
- The doctor opens nothing outside the vault. An index row whose path is `.` or holds a `..`
  part or a backslash fails `index` and gets no project rows, and `doctor --fix` writes nothing
  under it. A `tasks_root`, `topics_root` or `sprints_root` that leaves the project fails
  `profile`, and the project is checked under that root's default.
- The tests run on Linux, macOS and Windows. An end-to-end check runs Claude Code itself against a
  scratch vault on a Linux and a Windows runner.
- CI uses `actions/checkout@v7`, which runs on Node.js 24, in place of `@v4`, which runs on
  Node.js 20.
- A task can list the tasks it waits on in `depends_on`, as quoted path links.
  `second-brain task dep <ID> add|remove <ID>` edits the list, and `task set` refuses it.
  `board` has a ninth column, `depends_on`, with each task and its status. The board template
  has a `Depends on` column, the `story-tracker` status overview flags a task in progress that
  waits on one not done, and a new doctor check, `depends-on`, warns about a link to no note and
  about tasks that wait on each other in a ring.
- A project can hold subprojects, one note each at `<project>/claude/subprojects/<name>.md`: its
  repos, its own branches and environments, which fall back to the profile's, and its rules. Its
  docs live in `docs/<name>/`. `second-brain scaffold subproject` creates one, and
  `vault-setup subproject <project>` walks through it. `second-brain subproject <project> [name]`
  lists them or prints one's settings; `context` adds a `subproject:` line in a subproject's
  repo; a task carries the `subproject` key (`task new --subproject`, `task set subproject=`).
  The doctor's new `subprojects` check looks at each one. A project with none works as before.
- A rule the user asks Claude to save goes where it applies. The index says that a rule about one
  project goes under `## Rules` in its `claude/README.md`, or in its subproject's note, and only a
  rule for every project goes in `~/.claude/CLAUDE.md`. It also says to read the subproject's note
  with the project's rules. The doctor's new `global-rules` check warns about a line of
  `~/.claude/CLAUDE.md` that names a project of the index.
- `story-tracker` has a `draft` mode. It writes a ticket's summary, description and acceptance
  criteria from the ticket template, with or without an id, and writes no file until the id
  arrives. Its description names ticket text, so a request to write a ticket loads it.
- The vault index says ticket text is never written freehand and names `story-tracker`. The
  `sprint` skill sends a request to write a ticket there.
- Marking a ticket done starts the `docs-keeper` agent. `story-tracker` starts it when a story is
  set `done` in a project with no environments, or when its last environment is set `done`.
  `docs-keeper` has a new Workflow 5 for it: it makes and ticks the edits under
  `## Docs to update`, or, with no such section, checks the ticket's change against the
  "Code to doc map". A gap it does not fix goes to the debt file, and the ticket gets a status
  note naming what was updated.
- New command `second-brain task docs <ID>[,<ID>...]` prints each task with unticked lines under
  `## Docs to update`, its path and those lines.
- The sprint close lists the done tasks whose `## Docs to update` lines are still unticked, with
  `task docs`. It recommends `docs-keeper` for them and does not start it. The `scrum-master`
  agent cannot start `docs-keeper` either, so it reports it as an action for the caller.

Upgrading a vault that was set up with 0.1.0:

- The pointer and the links keep working as they are.
- `scaffold vault` never overwrites, so the vault keeps its version 1 conventions note, which
  still names the removed commands. The doctor warns about it. Delete `obsidian-conventions.md`
  and run `second-brain scaffold vault` to get the new one, or edit it by hand.
- The vault's `CLAUDE.md` has no `index_version`, so the doctor warns about it. Bring the text
  above `## Projects` in line with `templates/vault-index.md.tmpl`: it opens with
  `## In every session`, which says where new skills and agents go, it no longer says to ignore
  the file, and its rule about moving notes names `second-brain move` and `second-brain rename`.
  Keep your own lines and the table, and put the template's frontmatter, with its
  `index_version`, at the top. The `vault-doctor` skill does this after asking.
- The vault has no `claude/pull-request.md`, so the doctor warns about it. Run
  `second-brain scaffold vault`: it creates the note and overwrites nothing. Then add the index
  line about pull requests from `templates/vault-index.md.tmpl` under `## In every session`.
- The plugin's index template is now at `index_version: 2`, and its conventions note at
  `conventions_version: 3`. The doctor's `index` and `conventions` checks warn about a vault whose
  copy is older, and say so. Bring the index's text above `## Projects` in line with
  `templates/vault-index.md.tmpl`: it adds the answer-style line, the rule about where a saved rule
  goes, the line about pull requests, the subproject note to read with a project's rules, the
  ticket text line under `## Rules for notes that most often go wrong`, and on the plugin lines
  that `story-tracker` writes ticket text and that `docs-keeper` runs for a ticket marked done.
  Keep your own lines and the table, and set `index_version: 2`. Delete
  `obsidian-conventions.md` and run `second-brain scaffold vault` for the new conventions note.
- A snapshot taken with 0.1.0 does not compare with one taken now.
- A `tasks.base` written before has no `Depends on` column. Add `note.depends_on` and the
  `depends_on` column from `templates/tasks.base.tmpl` by hand to show it in Obsidian.

## 0.1.0 - unreleased

First version.

- Skills: `story-tracker`, `sprint`, `vault-setup`, `vault-doctor`.
- Agents: `scrum-master`, `docs-keeper`.
- Helper: `second-brain` (lookups, board, task and sprint writes, scaffolding, link, doctor).
- Templates for a vault, a project, a task, a sprint and the task board.
- A project profile records where its code repositories are stored (`repos_root`, `repo_paths`);
  `second-brain repo <project> [name]` returns the path, and the doctor warns when a folder is missing.
- Docs follow production: `docs-keeper` edits a doc only after the change is confirmed deployed, and
  records the planned edits until then. Every repository has rows in the profile's code-to-doc map;
  `vault-setup repo <project>` adds a repository with its rows, and the doctor warns when one has none.
- The helper works where `awk` is gawk in a UTF-8 locale, as on the Ubuntu CI runner: every awk
  program that loads the shared functions now runs in the C locale.
- Sprints are optional per project: `uses_sprints: false` in the profile, written by
  `second-brain scaffold project --no-sprints`, turns them off. The project gets no sprints hub and
  no `Current sprint` view, the `sprint` commands refuse it, and the doctor skips its sprint checks.
