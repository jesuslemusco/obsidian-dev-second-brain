# Release planning

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

Read this in release-planning only, after Step 0 of `SKILL.md`. It runs with or without sprints.

Write nothing until the owner approves the draft. This workflow writes only the planned-releases
note: its release's section and the `## Epics` lines.

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
  invent a goal, a story or a link.
- A task that exists joins as it is: `second-brain task head <ID>` gives its title.
- A story or epic that does not exist yet goes through refinement first. Read `refinement.md`, at
  the path `## Workflows` in `SKILL.md` gives, and follow it for them. Then come back here with
  the ids it wrote.

## 2. The draft

Draft the release in this chat:

- `Release goals:`, one to three bullets, in the owner's words.
- The release's section of the note as it will read, in the shape of `## 5. The note`: each epic
  with its stories nested under it, and each story alone, with a one-line summary and what it
  waits on.
- A line under `## Epics` for each epic that is new to the note.

## 3. The approval

- Show the draft, and end it with the line `What's wrong or missing?` as plain text. Then stop for
  the owner's answer.
- Then ask for the approval as `## 3. Create the story` in story-tracker's `create.md` says, at
  the path `## Workflows` in `SKILL.md` gives.
- A change: make it in the draft, show each part it changed again in full, then ask again.

## 4. Write

1. On the approval, write the release's section into the note, and a line under `## Epics` for
   each new epic. Link each item by the path `second-brain find <ID> --project <project>` prints.
   - Change only those lines, with the Edit tool. Never rewrite the note.
   - No note yet: write it whole, in the shape of `## 5. The note`.
2. Report the note's path and the release's items.
   - A sprint in progress: offer sprint-planning, to pick the release's stories into it.

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
