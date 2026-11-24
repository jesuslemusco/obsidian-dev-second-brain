# The lead's orders and check

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Read this file once, as `## Files` in `SKILL.md` says. You are the lead of the build: you keep
the owner's orders, and check on them while one is open.

- `<ID>` is the id the build runs on: a story's, or an epic's.
- `<project path>`, `<vault>`, `<path>`, `<worktree>` and `<branch>` are as the top of
  `story.md` says.

## The owner's open orders

Keep the owner's open orders in a note in the vault,
`<project path>/claude/lead-agent-task-memory.md`. It tells the lead's check, and a new session,
what is still owed.

- An order is what the owner asked you to do, in their words: the request that ran the skill, and
  each later one, such as a `release` check or an answer at a stop that sends the build on. The
  check's own prompt is no order.
- Under `## Open orders`, the note holds each open order: its date, its id, the owner's words as
  written, a `Done when:` line, and a `Now:` line on what works on it, such as you, an agent by
  its name, or a check that runs.
- Under `## Done`, each order done, with what finished it. Last, one `Last check:` line per id:
  the time of its newest check, and what it found.
- Another build of the project may keep its orders in the same note. Your own are the orders of
  `<ID>`. An order of another id is another session's: leave it as it is.
- `Done when:` is one condition that a command, a file or a branch state shows to hold or not.
  Name what shows it: a command and its exit code or what it prints, a file and the line it holds,
  or where a branch is.
- A judgement, such as "the build looks good", is no condition.
- Its command only reads: never one that pushes, merges, fetches or writes.
- Conditions that a check can test:
  - A story merged into the release:
    `git -C "<path>" merge-base --is-ancestor <branch> release/<version>` exits 0.
  - A release shipped: `git -C "<path>" ls-remote --tags origin v<version>` prints a line.
  - A pull request's checks passed: in `<path>`, `gh pr checks <number>` exits 0.
  - A line in a file of the repo: `grep -qxF "<line>" "<path>/<file>"` exits 0.
  - The order that ran the build, in no other words: each story of the run holds a
    `Build: finished` status note newer than its run's start. That is the newest of its
    `Build: started on <branch> at <short hash>.` and `Build: resumed on <branch> at <short hash>.`
    notes. Read them from `## Status notes`, as the top of `story.md` says.
- Never change or drop a `Done when:` line without the owner, even when it looks out of reach. A
  condition the owner gives replaces it, and their words join the order's.

1. When the build starts or resumes, add the order that ran it, unless the note holds it already.
   - No note yet: write it with the Write tool, as below. Then add its line to the project's
     Claude hub, `<project path>/claude/README.md`, in the list at its top, after the profile's
     line, unless the hub has it already:
     `- Lead memory: [[<project path>/claude/lead-agent-task-memory|<project> Lead Memory]] - the owner's open orders.`
   - Once the note is there, change it only with the Edit tool, never a whole rewrite, so that you
     never overwrite another session's orders.
2. A new order: add it under `## Open orders`. Keep each `Now:` line true as the work moves on.
   - Write its `Done when:` line from the owner's words as you add it, for the order that ran the
     build too.
   - Their words give no condition, such as "keep an eye on it": ask the owner for one in your
     reply. Until they answer, its line is `Done when: asked the owner.`, which never holds.
3. An order done: take it to `## Done`, with what finished it.
   - It is done when its `Done when:` condition holds. Name what showed it, such as the command
     and what it printed.
   - The owner stops the build or drops an order, at a stop or not: it is done, stopped by the
     owner.
4. No order of `<ID>` open: stop the lead's check, as its item 6 says.
   - An order of another id still open: leave the note and its hub line.
   - No order of any id open: remove the hub's line, then the note:
     `rm "<vault>/<project path>/claude/lead-agent-task-memory.md"`. It is your own note: removing
     it is no destructive action of `## 8. When to ask the owner` in `story.md`.
   - `second-brain unresolved "<project>"` must then list no link to the note.

The note, with each `<...>` filled. A nested item is indented with a tab, as the vault's writing
style says:

```markdown
---
aliases:
  - "<project> Lead Memory"
type: ops
tags:
  - type/ops
---

> Up: [[<project path>/claude/README|<project> Claude Hub]]

# <project> lead memory

## Open orders

- <YYYY-MM-DD> <ID>: "<the owner's words, as written>"
	- Done when: <one condition that a command, a file or a branch state shows>.
	- Now: <what works on it: you, an agent by its name, or a check that runs>.

## Done

- <YYYY-MM-DD> <ID>: "<the owner's words, as written>" - <what finished it>.

Last check: <ID> at <YYYY-MM-DD HH:MM> - <what it found>.
```

## The lead's check

While an order of `<ID>` is open, check on it at the pace the profile sets. An agent can go idle
with no report and no notice that wakes you.

1. Start it when the build starts or resumes, as item 7 of `## 2. The worktree` in `story.md`
   says. Keep one check at a time.
   - Its pace is the `lead_check_minutes` line of `second-brain profile "<project>" --keys`: 10,
     12, 15, 20, 30 or 60 minutes. No line, `-` or any other value: 20.
   - Its cron line runs at minute 7, then once more each time that many minutes pass, up to
     minute 59, so no check falls on :00 or :30. With 20: `7,27,47 * * * *`.
   - In Claude Code, run `CronList` first. A job that already has the prompt below and that cron
     line is the check: keep it, and start none. One with the prompt and another line: delete it
     with `CronDelete`.
   - Else create it with `CronCreate`: that cron line, `recurring: true`, and the prompt
     `Check on the open orders of <ID>, as the lead's check in lead.md of the build skill says.`
   - It is session-only: never pass `durable: true`. Keep its job id, from `CronCreate` or
     `CronList`.
   - No scheduling tool: check on each notice that comes to you instead, from an agent or from a
     run in the background.
2. Read the orders note. Of each open order of `<ID>`, test its `Done when:` condition, then ask:
   are you or an agent working toward it? Look at the agent at work, the worktree and the running
   checks, as item 1 of `### An agent with no report` in `story.md` says.
   - Run the condition's command as it is written, or read its file or branch. It holds only when
     what it names shows, such as exit 0 or the line.
   - A condition you cannot test, such as one whose command is not found: it does not hold. Say
     so once, not at each check.
   - An order with no `Done when:` line: write one from its words, as item 2 of
     `## The owner's open orders` says.
   - The note is missing while an order of `<ID>` is open: write it again with your open orders,
     as item 1 of `## The owner's open orders` says, and go on. Never stop the check for it.
3. Then, for each order:
   - Its condition holds: take it to `## Done`, as `## The owner's open orders` says.
   - Never close an order whose condition does not hold, and never change a condition to close
     one.
   - A report you have not taken yet: take it now, as the step that launched its agent says.
   - An agent idle with no report: take it as `### An agent with no report` in `story.md` says.
   - An agent at work, a check that still runs, or a question to the owner: wait.
   - No one works toward it, and the owner has not since interrupted you or told you to hold: go
     on with its next step now. Otherwise wait for the owner, and say so.
   - A next step that item 5 rules out waits for the owner too: say so.
   - Waiting for the owner: say it once, not at each check.
4. Write the `Last check:` line of `<ID>` with the Edit tool: the time, and what the check found.
5. The check never pushes, merges or takes another outside action.
6. Stop it once no order of `<ID>` is open. In Claude Code, run `CronDelete` with the job id.
