---
name: achievements
description: Gather what your done stories delivered in a date range or a sprint, and the proposals you made, as achievements for a review or a report.
argument-hint: "[<from> <to> | sprint <id>] [project]"
allowed-tools: Read Edit Write Bash(second-brain *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Achievements

You gather the owner's achievements for one period, a date range or a sprint: one for each story
set to `done` in it, and one for each proposal the owner made. You show them in your reply.

- This skill is the one that gathers or logs an achievement, and only when the owner asks. No
  skill or agent logs one as a story finishes.

## Step 0 - Context

Run these yourself, before anything else. Chain them in one Bash call where that helps.

1. Your first tool call is `second-brain context`.
   - Command not found: the plugin is not enabled. Say so and stop.
   - `vault: none`, or exit 2: no vault is set up. Say so, offer `/odsb:vault-setup`, stop.
2. Resolve the project, first match wins: the name the user gave
   (`second-brain project --name <N>`), a ticket id (`--key EX-123`), else the `project:` line.
   - `none`, exit 1 or exit 4: show `second-brain projects` and ask.
3. `second-brain profile <project> --keys` prints the settings the steps below name.
   - Exit 1: no profile. Say so, offer `/odsb:vault-setup adopt`, stop.

## 1. The period

- The period is a date range or a sprint, from the request. With neither, ask which.
- A date range is `<from>` to `<to>`, both days in it, as `YYYY-MM-DD`.
  - Turn words such as "last month" into real dates.
  - A `<from>` after `<to>`: say so, and ask again.
- A sprint is its id, its end date. Its start is the `start` key of its note.
  - `uses_sprints: false` in Step 0's keys: the project has no sprints. Say so, and ask for a
    date range.
  - "This sprint": `second-brain sprint current <project>` prints its id and start. Exit 1: no
    sprint is in progress. Say so, and ask for the period.
  - Any other: `second-brain find "<Project> Sprint <id>" --project <project>` prints its note.
    Read its frontmatter. Exit 1: there is no such sprint. Say so, and ask again.

## 2. The done stories

1. List the project's tasks in one call: `second-brain board <project> All`.
   - One row per story, archived or not, with its `id`, `status` and `sprint` cells.
2. Keep the rows whose `status` is `done`.
3. A sprint: keep the rows whose `sprint` cell is its id. A done story keeps the sprint it
   finished in.
4. A date range: keep each story set to `done` from `<from>` to `<to>`.
   - A story records no date it was set to `done`. Only its dated status notes show it.
   - `second-brain task head <ID> --project <project>` prints its `path` and its newest status
     note. One dated before `<from>`: no note shows it set to `done` in the range, so leave it out.
   - Else read its `## Status notes`: `second-brain outline <path>`, then a ranged read.
   - Its done date is the date of the newest note that records its move to `done`. With none,
     it is the date of its newest note, and its line in the result says so.
   - No dated note at all: list it under `No done date:`, for the owner to keep or drop.
5. List each story once, under its id, whatever its aliases or its notes say. An environment set
   is one row, so one story.
6. No story is kept: say so in the result, and go on to the proposals.

## 3. One achievement per story

- `second-brain task head <ID> --project <project>` prints each story's `path`, as in step 2.
- Read each story cheapest first: `second-brain outline <path>`, then a ranged read from its
  title to `## Description`, which holds its `**Summary:**` line, and one of `## Changes`.
- Word one achievement per story, in one or two sentences: what the story delivered, from its
  Summary and its Changes.
- Say only what they say: add no number, effect or name they lack.
- `## Changes` is missing, empty or `None yet.`: word it from the Summary alone, and its line in
  the result says so.
- Each achievement names its story, by its id.

## 4. The proposals

- Ask the owner whether they made any proposals to their company or project in the period: from
  `<from>` to `<to>`, or from the sprint's start to its end.
- Ask it as plain text, not with AskUserQuestion, and stop for the answer: only the owner knows
  their proposals.
- For each proposal the owner names, ask for what their answer lacks, one question at a time:
  what it proposed, to whom, and what came of it.
- Word each one as an achievement, in one or two sentences, from the owner's words. Draw on the
  project's context, a ranged read of `<project path>/README.md`, and the stories of step 2.
- Make up no proposal. Never take one from a story's notes, a build note or the code, and add no
  fact the owner did not give.

## 5. The result

Show the result in your reply, in this shape:

```
Achievements: Example, 2026-11-01 to 2026-11-30

Stories:
- EX-123: <what it delivered>.
- EX-130: <what it delivered>. Done date from its newest note.

Proposals:
- <the proposal, worded as an achievement>.

2 stories, 1 proposal.
```

- A sprint's first line is `Achievements: <Project>, sprint <id>, <start> to <id>`.
- The stories go by id. With none, or no proposal, the list holds `- None.`
- A change the owner asks for: make it, and show the result again.
- Then offer once to write it to the project's achievements note, as `## 6. The note` says.

## 6. The note

Only on the owner's ask, write the result to `<project path>/<topics_root>/achievements.md`.
`second-brain project --name "<project>"` prints the project's path, and Step 0's keys its
`topics_root`.

- No note yet: write it whole, with the Write tool, in the shape below.
- A note: `second-brain outline <note>` lists its periods. Add the period's section after the
  last one, with the Edit tool. Never rewrite the note.
- The period has a section already: show it, and replace it only on the owner's yes.
- Link each story by the path `second-brain find <ID> --project <project>` prints.
- Report the note's path.

```markdown
---
aliases:
  - "<Project> Achievements"
type: note
tags:
  - type/note
---

> Up: [[<project path>/<topics_root>/README|<Project> Docs Hub]]

# <Project> Achievements

What the done stories delivered and the proposals the owner made, one section per period.

## 2026-11-01 to 2026-11-30

Stories:
- [[<path>|EX-123]] - <what it delivered>.

Proposals:
- <the proposal, worded as an achievement>.
```

- A period's heading is `## <from> to <to>`, or `## Sprint <id>` for a sprint.
- The note holds no status: a story's status stays in its task note.
