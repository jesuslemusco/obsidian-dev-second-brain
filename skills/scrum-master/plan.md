# Plan an epic or a story

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Read this in plan mode only, after Step 0 of `SKILL.md`. Plan runs with or without sprints.

Write nothing, no file, no key and no note, until the owner approves the draft.

## 1. What to plan

- The owner asks for an epic and its stories, new stories under an epic that exists, or one
  story. Say epic or feature, as `## The model` in `SKILL.md` says.
- An epic that exists: read it with `second-brain task head <ID>`. Draft only its new stories.
- Take what each story is for from the owner, and from the notes and code they name. Look for
  related notes first: `second-brain search <project> <text>`.
- Ask for what they leave open, one question at a time. Never invent a story, a criterion or a
  link.
- Each story needs an id. Ask for the ids, or propose the next free ones of the project's key
  from `second-brain board <project> All`. The owner approves them with the draft.

## 2. The draft

Read story-tracker's `create.md` once, at the path `## Modes` in `SKILL.md` gives. Draft the epic
and each story in the shape its section 1 gives:

- A title, the Summary, the Description in its three-line shape with its context, Findings only
  from evidence, and at most 4 acceptance criteria.
- The epic's criteria say when it is done, such as each of its stories done. Its context lists
  its stories, one line each: the id and the title.
- Each story's topics, and its subproject in a project that has subprojects.
- Under each story, two lines: `Parent: <ID or ->` and `Waits on: <IDs or ->`. A task it waits on
  may be one that exists already.
- Check each claim about the code read-only, as its section 2 says, and name the ref.
- Keep the draft in this chat.

## 3. The approval

- Show the draft in chunks of about 200 to 300 words: the epic first, then a few stories at a
  time.
- End each chunk with the line `What's wrong or missing?` as plain text, not an AskUserQuestion
  call. Then stop for the owner's answer.
- Fix what the owner names before you show the next chunk.
- After the last chunk, ask with AskUserQuestion whether to approve the draft or change it. The
  owner says what to change in the free-text answer.
- A change: make it in the draft, show each story it changed again in full, then ask again.
- Only the owner's approval counts. Never take a change, a question or silence for one.
- No AskUserQuestion, as in a subagent: show the draft, end with the question, and write nothing.

## 4. Write

On the approval, write the draft as approved: the epic first, then each story in order.

1. Write each one through steps 1 to 5 of `## 3. Create the story` in `create.md`.
   - Step 3 sets `status=planned`, `branch="none yet"`, a `next` that names its first action
     and, for a story, `epic=<its parent>`.
   - Its `**Branch:**` line is `none yet`, with the ref the draft was checked at.
   - The status note of step 5 is `Planned: the owner approved this text.`
   - Work on it has not started, so step 6 does not weigh it yet.
2. Link each story to each task it waits on: `second-brain task dep <ID> add <other ID>`.
3. Link each story in the epic's list as `[[<its path, no .md>|<ID>]]`, with the path
   `second-brain find <ID> --project <project>` prints.
4. A step would change the approved text, such as `task new` exit 6 for an id that is taken, or
   a topic tag with no folder: stop. Show the change, and write it only once the owner approves
   it.
5. Report each story's path and the tasks it waits on.
   - A sprint in progress: offer pick, to add the new stories to it.

A change to a story's text once it is written: show it, and write it through the story-tracker
skill only once the owner approves it.
