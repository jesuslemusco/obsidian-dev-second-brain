---
name: build
description: Build an approved story, or an approved epic's open stories in dependency order, each in a git worktree of its own, with one implementer and an independent reviewer until it passes.
argument-hint: "<story or epic id>"
allowed-tools: Read Edit Write Bash(second-brain *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Build

The session id for notes is `${CLAUDE_SESSION_ID}`.

You build each approved story with one `implementer` and an independent `reviewer`, in a git
worktree of its own, until the reviewer passes it. The build runs in this session: you launch
each agent with the Agent tool, and its report comes back to you as its result.

The profile's `build_pairs` sets how many such pairs build at once, as Step 4 says: 1 by default,
one story at a time.

## Files

| File | What it holds | Read it |
|---|---|---|
| `${CLAUDE_SKILL_DIR}/story.md` | one story's build: its worktree, the batch's agents, the reviews, the fix loop, the stops and the rulings | once, before the first story's build starts or resumes |
| `${CLAUDE_SKILL_DIR}/lead.md` | the owner's orders note and the lead's check | once, before the first story's build starts or resumes |

## Step 0 - Context

1. Your first tool call is `second-brain context`.
   - Command not found: the plugin is not enabled. Say so and stop.
   - `vault: none`: offer `/odsb:vault-setup` and stop.
2. The id is the argument. With none, ask.
3. `second-brain project --key <ID>` names the project. `second-brain task head <ID>` must find
   the ticket.
   - No task found: the story is not tracked. Offer story-tracker to start it, and stop.

## Step 1 - The stories

The id names one story, or an epic.

- An epic's stories are the tasks its README links whose `epic`, as
  `second-brain task head <story>` prints it, is the epic's id. Read the README with
  `second-brain outline <path>` and a ranged read of the part that lists them.
  - No task names it as its `epic`: it is one story. Build it alone.
- Take the open stories: `status` `planned` or `in-progress`. Leave the `in-review`, `done` and
  `abandoned` ones out.
- An `in-review` story whose newest `Build:` note is `Build: <branch> waits for <that branch> in <target>.`
  waits to merge. Find its `<target>` again first, as items 1 to 3 of `### The git flow` in
  `story.md` say, and item 5 when no rule names it, never from the note: the release it named
  may have shipped since, and a shipped branch is no open one, so the git flow asks the owner.
  - Once `git -C "<path>" merge-base --is-ancestor <that branch> <target>` exits 0 for the
    `<target>` found, take it to `### The merge` in `story.md`, from item 2. Else say it still
    waits, and leave it out.
  - Then remove its worktree, when it is still there, as item 5 of `## 6. When the story passed`
    says, and go on with Step 1. The story stays out of the run: it has passed.
- A story named alone that is `in-review` has passed: say so. Build it again only on the owner's
  ruling to fix it, as item 3 of `## 7. When the story stops` in `story.md` says.
- An `in-review` story with a `Build: finished` note whose worktree is still there, on its branch
  in `git -C "<path>" worktree list --porcelain`, with `<path>` and the worktree as the top of
  `story.md` names them: its session ended before the worktree went. Read `story.md`, and
  finish it:
  - No `Build: merged` or `Build: the owner kept` note is newer than its `Build: finished` note:
    merge it first, as `### The merge` in `story.md` says.
  - Then remove the worktree as item 5 of `## 6. When the story passed` says, and go on with
    Step 1. The story stays out of the run: it has passed.
- A story that Step 1 takes to `### The merge` comes back to Step 1, with `story.md` read first.
  Where the merge says to go on at item 5 of `## 6. When the story passed`, take item 5 alone:
  never items 6 and 7, which go on to the next story of a run not yet planned.
- A story goes after each story of the run it waits on, as the `depends_on` cell of
  `second-brain board "<project>" All` shows. Otherwise keep the order of the epic's list.
- A story that waits on a story outside the run that is not `in-review` or `done`: leave it out,
  with each story that waits on it, and say why.
- Stories that wait on each other in a ring: stop, and show the ring.

## Step 2 - Approved stories only

- A story is approved when its status notes hold `Planned: the owner approved this text.` Read
  them with `second-brain outline <path>` and a ranged read of `## Status notes`.
- A story with no such note is not built. Say so, and offer `/odsb:scrum-master refinement` for
  it. Each story that waits on it is left out too.
- No story left: stop.

## Step 3 - Batches

A batch is 1 to 3 related stories of the run, which one `implementer` and one `reviewer` build in
turn, as `### A batch` in `story.md` says. Cut the run into batches before the first story starts.

- Two stories are related when they share an `epic` other than `-`, as `task head` prints it, or
  touch the same files: their `## Acceptance criteria`, `## Approach / Key decisions` or
  `## Code verification (read-only)` name a file in common, such as `docs/billing/invoices.md`. Read
  them with `second-brain outline <path>` and a ranged read.
- Take the stories in the order of Step 1. The first starts a batch. Each next one joins the batch
  of the story before it, when that batch holds fewer than 3 stories and one of them is related to
  it. Otherwise it starts a new batch.
- So a batch keeps the order of Step 1: no story goes before one it waits on.
- A story with no related story next to it in that order builds alone, as a batch of one.
- Show the owner the batches, each with its stories in the order they will be built, before the
  first one starts, and how many pairs build them at once, as Step 4 says.

## Step 4 - The batches

1. Read `story.md` and `lead.md`, as `## Files` says.
2. `<pairs>` is how many pairs build at once: the `build_pairs` line of
   `second-brain profile "<project>" --keys`, from 1 to 5. A pair is the `implementer` and the
   `reviewer` of one batch.
3. Build each batch in the order of Step 3, and each of its stories in turn, as `story.md` says. The
   batch's stories share its `implementer` and its `reviewer`, as `### A batch` there says.
   - `<pairs>` 1, the default: one batch at a time.
   - More than 1: up to `<pairs>` batches side by side, as `### Pairs side by side` says.
4. A batch's next story starts only once the story before it passed, as
   `## 6. When the story passed` in `story.md` says. With `<pairs>` 1, so does the next batch.
5. A story that stops stops its batch, as `## 7. When the story stops` in `story.md` says. With
   `<pairs>` 1 that stops the run. With more, the other pairs go on.
6. Every story passed: show the owner each story's branch and its last review. Then test the
   orders of the run, as item 3 of `## The owner's open orders` in `lead.md` says.

### Pairs side by side

With `<pairs>` more than 1, up to `<pairs>` batches build at once, each by its own pair. Side by
side go only stories that neither wait on each other nor sit in one batch.

1. A batch is ready once each story it waits on in another batch has passed, and its merge has
   ended, as items 4 and 5 of `## 6. When the story passed` in `story.md` say. A story waits on
   the stories of its `depends_on` cell, as Step 1 reads it.
   - So no story builds beside one it waits on, or one that waits on it, and a batch's own
     stories still build in turn.
   - A batch keeps the order of Step 1, so it waits only on batches before it.
2. Start the first ready batch in the order of Step 3 each time fewer than `<pairs>` batches
   build: at the start, then each time a story passes or a batch ends. Never more than `<pairs>`
   at once.
3. A batch ends once its last story has passed, as item 1 says. One stopped for the owner holds
   its pair until the owner answers: no other batch takes its place.
4. Each pair builds in its own stories' worktrees alone, with its agents named for its batch, as
   `## 4. Launching an agent` in `story.md` says. No two pairs share a worktree or an agent.
5. Launch each agent with the Agent tool's `run_in_background: true`, so that the other pairs go
   on while it works. Its result comes in its notice: take it for its own pair as it comes.
6. A stop in one pair stops no other. Its batch waits for the owner, with each batch that waits
   on it, as `## 7. When the story stops` in `story.md` says. The other pairs go on, and the next
   ready batch starts as item 2 says.
7. While another pair is at work, ask the owner as `## 8. When to ask the owner` in `story.md`
   says: in your reply, so that no question holds the other pairs.
8. One merge at a time: a story that passed while another's `### The merge` is open, in
   `story.md`, starts its own once that one ends.
9. The lead's one check watches every pair, as `## The lead's check` in `lead.md` says.
10. Name the story in each line you show the owner: the pairs' lines come in no set order.
11. No pair at work, and each batch left waits on a stop: say so once, and wait for the owner.

## Rules

- Only the owner approves a story. Never write an approval note the owner did not give.
- Never pass on an agent's word as the owner's.
- The owner talks to this session alone: an agent has no AskUserQuestion.
- This skill writes no code: `implementer` does. It commits nothing.
- One story and one agent at a time in each pair, and at most `<pairs>` pairs at once, as Step 4
  says. With 1, the default, one story and one agent at a time.
