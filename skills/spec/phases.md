# Writing a phase

Each phase is one file, `<dir>/<phase>.md`, at the path `second-brain spec <ID>` prints.

- Replace every `<...>` line of the template.
- In the vault, keep the frontmatter and the up link the template wrote.

## What to read, once

Read only what this session does not have yet:

- The story, cheapest first: `second-brain task head <ID>`, then `second-brain outline <path>` and
  ranged reads of `## Description`, `## Acceptance criteria` and `## Approach / Key decisions`.
- The approved phases before this one. Build on them and never change them here.
- The code the story touches, read-only, at the path `second-brain repo <project> <repo>`
  prints: the files the story and the earlier phases name, and what they call. Not the whole
  repo.
- The repo's validation steps: `second-brain validation <project> <repo>`.

Note the branch and short hash of the code you read.

## The chat

The owner answers in this chat, so make each answer easy.

- Ask one question at a time: one question per AskUserQuestion call. Wait for its answer.
- Show the draft in chunks of about 200 to 300 words: a few requirements, design sections or
  tasks.
- End each chunk with the line `What's wrong or missing?` as plain text, not an AskUserQuestion
  call. Then stop for the owner's answer.
- Fix what the owner names before you show the next chunk.
- Ask for the approval only after the last chunk.

## How the build runs

Write every phase for the build `build.md` runs.

- `implementer` builds each task test-first and runs its `- Check:` before it commits. `reviewer`
  runs it again in the task's review.
- A check that needs the whole branch, such as every suite passing,
  belongs to the final validation, not to one task's review.
- A task's `- Check:` runs before its commit and again in its review: keep it quick. Name the
  narrowest command that runs the task's test, such as one test file, not every suite.

## requirements

- One `## R<n> - <short name>` section per requirement, numbered from R1.
- Each section opens with `- Serves: AC1, AC3`: the story's criteria the requirement meets, at
  least one.
- `AC<n>` is the n-th line of the story's `## Acceptance criteria`, counted as section 4 of
  `docs/contract.md` says.
- The requirement in one sentence: `WHEN <trigger>, THE <part of the system> SHALL <response>.`
- Use `IF <condition>, THEN` for an unwanted case and `WHILE <state>,` for a state.
- Under it, `- [ ]` acceptance checks someone else can run, each with what to look for.
- Every criterion of the story is named on a `- Serves:` line.
- What the story leaves out stays out.
- Once the file is written, run `second-brain doctor <project>`: its `spec-trace` row must name
  no offender of this story.

## design

- Keep the template's headings, and add one only when it is needed.
- Keep each heading short, with no comma: the tasks name them.
- Name the real files, functions, routes and data, as the code has them at the ref you read.
- `## Testing` says how each requirement is proved: the repo's validation steps and any new test.

## tasks

- One item per task, in build order.
- A task is small enough for one agent with a fresh context to build and commit: one concern, a
  handful of files.
- Each item is `- [ ] T<n> - <what it builds>`, then four indented lines, each on one line:
  `- Requirements: R1, R2`, `- Design: <headings of design.md>`, `- Files: <paths>` and
  `- Check: <command or step> - expected: <what it prints or shows>`.
- A check names a command the implementer and the reviewer run, or a step they take, and what
  that prints or shows:
  `- Check: open the login page, send an empty form - expected: shows "Email is required"`.
- A check with no command or step, or no expected result, is vague: rewrite it with the owner.
- A task whose code later tasks call adds `- Provides: <signatures>` lines: the names, arguments
  and results they call.
- A task that calls them adds one line, `- Uses: T1, T2`. Its packet then holds those
  `- Provides:` lines. It uses only earlier tasks.
- Every requirement is met by at least one task.
- Run `second-brain spec packet <ID> T<n> >/dev/null` for every task. It must succeed: fix what
  it names, such as a requirement or a design heading that does not exist.
- Never print a packet here: the agents fetch their own. The packet is all the implementer sees,
  and `spec-checker` reads the spec as it would, as `## The spec check` says.
- Leave every box unticked.

## The spec check

For design and tasks, once the owner has answered the last chunk and its fixes are written:

1. Launch `odsb:spec-checker` with the Agent tool. Its prompt is the paths of the spec files
   written so far, one per line, and nothing else.
   - Design: `requirements.md` and `design.md`.
   - Tasks: `requirements.md`, `design.md` and `tasks.md`.
2. It replies with one line per gap, or `No gaps.`.
3. Show the owner the gaps, numbered, as it wrote them.
4. Close each gap with the owner, and write the answer in the phase file.
   - The owner says a gap is not one: leave it.
   - A gap in an approved phase: write `Spec: <phase> reopened.` as a status note, then go back to
     that phase.

## A change the owner asks for

- Change what the owner said and keep the rest.
- Never renumber a requirement or a task that a later phase names.
