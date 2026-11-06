# Writing a phase

Step 2 of `SKILL.md` reads this file. Each phase is one file, `<dir>/<phase>.md`, at the path
`second-brain spec <ID>` prints. In the vault, keep the frontmatter and the up link the template
wrote. Replace every `<...>` line of the template.

## What to read, once

Use what this session already knows, and read only what is missing:

- The story, cheapest first: `second-brain task head <ID>`, then `second-brain outline <path>` and
  ranged reads of `## Description`, `## Acceptance criteria` and `## Approach / Key decisions`.
- The phases before this one: requirements before the design, both before the tasks. The owner
  approved them. Build on them and never change them here.
- The code the story touches, read-only, at the path `second-brain repo <project> <repo>`
  prints: the files the story and the earlier phases name, and what they call. Not the whole
  repo. Note the branch and short hash you read.
- How the repo is checked: `second-brain validation <project> <repo>`.

## requirements

- One `## R<n> - <short name>` section per requirement, numbered from R1.
- The requirement in one sentence: `WHEN <trigger>, THE <part of the system> SHALL <response>.`
  Use `IF <condition>, THEN` for an unwanted case and `WHILE <state>,` for a state.
- Under it, `- [ ]` acceptance checks someone else can run, each with what to look for.
- Every acceptance criterion of the story is met by at least one requirement. What the story
  leaves out stays out.

## design

- Keep the template's headings and add one only when it is needed. Keep each heading short, with
  no comma: the tasks name them.
- Name the real files, functions, routes and data, as the code has them at the ref you read.
- `## Testing` says how each requirement is proved: the repo's validation steps and any new test.

## tasks

- One item per task, in build order. A task is small enough for one agent with a fresh context
  to build and commit: one concern, a handful of files.
- Each item is `- [ ] T<n> - <what it builds>`, then four indented lines, each on one line:
  `- Requirements: R1, R2`, `- Design: <headings of design.md>`, `- Files: <paths>` and
  `- Check: <how the reviewer knows it works>`.
- Every requirement is met by at least one task.
- Run `second-brain spec packet <ID> T<n>` for every task. It must succeed: it fails on a
  requirement or a design heading that does not exist. Fix what it names. The packet is all the
  implementer will see, so read one back and check it is enough to build the task from.
- Leave every box unticked.

## A change the owner asks for

Change what the owner said and keep the rest. Never renumber a requirement or a task that a later
phase names.
