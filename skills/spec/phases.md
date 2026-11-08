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

## How the build runs

Write every phase for the build `agents/spec-lead.md` runs.

- No requirement or task asks `implementer` to run a check: `reviewer` runs every check.
- A check that needs the whole branch, such as every suite passing,
  belongs to the final validation, not to one task's review.

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
  `- Check: <how the reviewer knows it works>`.
- Every requirement is met by at least one task.
- Run `second-brain spec packet <ID> T<n>` for every task. It must succeed: fix what it names,
  such as a requirement or a design heading that does not exist.
- The packet is all the implementer sees: read one back and check it is enough to build the task
  from.
- Leave every box unticked.

## A change the owner asks for

- Change what the owner said and keep the rest.
- Never renumber a requirement or a task that a later phase names.
