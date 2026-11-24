# Release planning

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Read this in release-planning only, after Step 0 of `SKILL.md`. It runs with or without sprints.

Write nothing, no file, no key and no note, until the owner approves the draft.

## 1. The release

- The note is `<project path>/<topics_root>/planned-releases.md` in the vault.
  - `second-brain project --name "<project>"` prints the project's path, and
    `second-brain profile <project> --keys` its `topics_root`.
- Read it cheapest first: `second-brain outline <note>`, then a ranged read of `## Epics` and of
  the release's section.
- No note yet: it is written with the approved plan, in the shape `## 5. The note` gives.
- The owner names the release: its version, or the one marked `next`. A new release takes the
  version the owner gives.
- Ask for its goals, and for the epics and stories it holds. Ask one question at a time. Never
  invent a goal, a story, a criterion or a link.
- A task that exists joins as it is: `second-brain task head <ID>` gives its title. Draft only the
  new epics and stories.
- Look for related notes first: `second-brain search <project> <text>`.
- Each new story needs an id. Ask for the ids, or propose the next free ones of the project's key
  from `second-brain board <project> All`. The owner approves them with the draft.

## 2. The draft

Read story-track's `create.md` once, at the path `## Workflows` in `SKILL.md` gives. Draft the
release in this chat:

- `Release goals:`, one to three bullets, in the owner's words.
- Each new epic and story in the shape section 1 of `create.md` gives: a title, the Summary, the
  Description in its three-line shape with its context, Findings only from evidence, and at most
  4 acceptance criteria.
- An epic's criteria say when it is done, such as each of its stories done. Its context lists its
  stories, one line each: the id and the title.
- Each story's topics, and its subproject in a project that has subprojects.
- Under each story, two lines: `Parent: <ID or ->` and `Waits on: <IDs or ->`. A task it waits on
  may be one that exists already.
- Check each claim about the code read-only, as section 2 of `create.md` says, and name the ref.
- Last, the release's section of the note as it will read, in the shape of `## 5. The note`.

## 3. The approval

- Show the draft in chunks of about 200 to 300 words: the goals and each epic first, then a few
  stories at a time, then the note's section.
- End each chunk with the line `What's wrong or missing?` as plain text, not an AskUserQuestion
  call. Then stop for the owner's answer.
- Fix what the owner names before you show the next chunk.
- After the last chunk, ask with AskUserQuestion whether to approve the draft or change it. The
  owner says what to change in the free-text answer.
- A change: make it in the draft, show each part it changed again in full, then ask again.
- Only the owner's approval counts. Never take a change, a question or silence for one.
- No AskUserQuestion, as in a subagent: show the draft, end with the question, and write nothing.

## 4. Write

On the approval, write the draft as approved, in this order:

1. Each new epic, then each story: invoke the story-track skill with the Skill tool, as
   `odsb:story-track` with its id, to start it. It writes the task note from the approved text,
   as `planned`, with its parent.
   - Invoke it, never Read its files: the Skill tool fills in the paths and the session id its
     `SKILL.md` names, and a Read leaves them as written.
2. Link each story to each task it waits on: `second-brain task dep <ID> add <other ID>`.
3. In each new epic's list, link each story as `[[<its path, no .md>|<ID>]]`, with the path
   `second-brain find <ID> --project <project>` prints.
4. Write the release's section into the note, and a line under `## Epics` for each new epic. Link
   each item by the path `find` prints.
   - Change only those lines, with the Edit tool. Never rewrite the note.
   - No note yet: write it whole, in the shape of `## 5. The note`.
5. A step would change the approved text, such as an id that is taken or a topic tag with no
   folder: stop. Show the change, and write it only once the owner approves it.
6. Report the note's path, and each story's path and the tasks it waits on.
   - A sprint in progress: offer sprint-planning, to pick the new stories into it.

A change to a story's text once it is written: show it, and write it through the story-track
skill only once the owner approves it.

## 5. The note

```markdown
---
aliases:
  - "<Project> Planned Releases"
type: note
tags:
  - type/note
---

> Up: [[<project path>/<topics_root>/README|<Project> Docs Hub]]

# <Project> Planned Releases

The releases ahead, and the epics and stories planned for each. A story's status and next step
live in its task note; this note says only which release it goes to.

## Epics

- EPIC: [[<path>|EX-1]] - <one-line summary>. <the releases it spans>.

## 0.2.0 - next

Release goals:
- <a goal>

- EPIC: [[<path>|EX-1]] - <one-line summary>.
	- STORY: [[<path>|EX-2]] - <one-line summary>.
	- STORY: [[<path>|EX-3]] - <one-line summary>. After EX-2.
- STORY: [[<path>|EX-4]] - <one-line summary>.
```

- Releases go oldest first, under `## Epics`.
- The release in work is `## <version> - next`. Only one release is `next`.
- A release once out is `## <version> - released <YYYY-MM-DD>`, when the owner says it is out.
  One still ahead has no suffix.
- An epic's stories nest under its line, indented with one tab.
- A last `## Not yet in a release` section may hold the items kept for later.
- The note holds no status: a story's status and next step stay in its task note.
