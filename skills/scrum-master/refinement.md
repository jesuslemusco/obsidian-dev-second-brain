# Refinement

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Read this in refinement only, after Step 0 of `SKILL.md`. It runs with or without sprints.

Write nothing, no file, no key and no note, until the owner approves the draft.

## 1. What to refine

- The owner asks for an epic and its stories, new stories under an epic that exists, one story,
  or a change to stories that exist. Say epic or feature, as `## Rules` in `SKILL.md` says.
- A story or epic that exists: read it with `second-brain task head <ID>`, then
  `second-brain outline <path>` and a ranged read of its Description and acceptance criteria.
  Draft only what changes.
- Take what each story is for from the owner, and from the notes and code they name. Look for
  related notes first: `second-brain search <project> <text>`.
- Ask for what they leave open, one question at a time. Never invent a story, a criterion or a
  link.
- Each new story needs an id. Ask for the ids, or propose the next free ones of the project's key
  from `second-brain board <project> All`. The owner approves them with the draft.

## 2. The draft

Read story-tracker's `create.md` once, at the path `## Workflows` in `SKILL.md` gives. Draft the
epic and each story in the shape its section 1 gives:

- A title, the Summary, the Description in its three-line shape with its context, Findings only
  from evidence, and at most 4 acceptance criteria.
- The epic's criteria say when it is done, such as each of its stories done. Its context lists
  its stories, one line each: the id and the title.
- Each story's topics, and its subproject in a project that has subprojects.
- Under each story, two lines: `Parent: <ID or ->` and `Waits on: <IDs or ->`. A task it waits on
  may be one that exists already.
- A story that exists: show what changes beside what it says now.
- Check each claim about the code read-only, as section 2 of `create.md` says, and name the ref.
- Keep the draft in this chat.

## 3. The approval

- Show the draft in chunks of about 200 to 300 words: the epic first, then a few stories at a
  time.
- End each chunk with the line `What's wrong or missing?` as plain text, not an AskUserQuestion
  call. Then stop for the owner's answer.
- Fix what the owner names before you show the next chunk.
- After the last chunk, ask for the approval of the whole draft as `## 3. Create the story` in
  `create.md` says, without showing the draft again.
- A change: make it in the draft, show each story it changed again in full, then ask again.

## 4. Write

On the approval, write the draft as approved, through the story-tracker skill: the epic first,
then each story in order.

1. Each new epic or story: invoke the story-tracker skill with the Skill tool, as
   `odsb:story-tracker` with its id, to start it. It writes the task note from the approved text,
   as `planned`, with the parent the owner picks.
   - Invoke it, never Read its files: the Skill tool fills in the paths and the session id its
     `SKILL.md` names, and a Read leaves them as written.
   - Before it writes, story-tracker shows the owner the stories that do the same and the epics
     the story could join, and the owner picks, as `## 3. Create the story` in its `create.md`
     says. That pick is approved: step 5 does not stop for it.
   - The owner picks a story that exists in its place: story-tracker writes no new one, and names
     that story. Its change sets the draft's parent as its `epic`, unless the owner keeps it under
     its own parent.
   - From then on that story stands for the draft's id: as the parent of the draft's stories, in
     step 3 for the tasks it waits on and for each story that waits on it, and in step 4, once it
     is under the draft's parent, in the epic's list in place of that id.
   - The owner files it under another parent, or none, or keeps the story that exists under its
     own: in step 4, list it under that parent alone, and drop it from the list of the parent the
     draft named.
2. Each story or epic that exists and changed: invoke the story-tracker skill with its id, to
   update it with the approved change.
   - Each story of the draft that exists, changed or approved as it is, and has no status note
     `Planned: the owner approved this text.`: have story-tracker write it, with that id, in the
     same call or one of its own.
3. Link each story to each task it waits on: `second-brain task dep <ID> add <other ID>`. A link
   the owner dropped: `second-brain task dep <ID> remove <other ID>`.
4. In each epic's list, link each story as `[[<its path, no .md>|<ID>]]`, with the path
   `second-brain find <ID> --project <project>` prints.
5. A step would change the approved text, such as an id that is taken or a topic tag with no
   folder: stop. Show the change, and write it only once the owner approves it.
6. Report each story's path and the tasks it waits on.
   - A sprint in progress: offer sprint-planning, to pick the new stories into it.
