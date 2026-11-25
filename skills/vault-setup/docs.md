# Set up a project's docs from its code

Step 0 of `SKILL.md` has run, in project or repo mode. `SKILL.md` and `repo.md` sit beside this
file. `docs-keeper` drafts the docs from the code, and writes them once the user approves the
draft. It is an agent and cannot ask the user, so this skill holds the approval. Nothing is written
before it. The `define-validation-scope` skill follows this file too, after its own Step 0, and
holds the approval the same way.

## 1. Offer it

- Project mode, at step 7 of `## project <name>` in `SKILL.md`: offer it when the topics root holds
  no topic folder yet, as `ls -d "<vault>/<path>/<topics_root>"/*/` lists them. With
  `topics_root: "."`, the tasks, sprints and `claude/` folders are no topics.
- Each subproject's docs folder, as `second-brain subproject <project>` lists it, is no topic
  folder here, but each folder inside it is.
- Repo mode, at `## 2. The docs that follow it` in `repo.md`: offer it for the new repository.
- The `define-validation-scope` skill, at step 3 of `## 2. The project's docs` in its `SKILL.md`:
  offer it for the repo it drafts, in a project with no docs, as step 2 there tells.
- Offer it only for a repository whose state `second-brain repo <project>` shows as `ok`, as
  `docs-keeper` reads its code.
- On a no, go on as the step that offered it says.

## 2. The draft

1. Start the `docs-keeper` agent (`odsb:docs-keeper`) with the project and the repositories, and
   ask it for the draft of `Workflow 7 - Set up a project's docs`.
   - When the session cannot start an agent, say so, name `docs-keeper` as the one to run, and go
     on as the step that offered it says.
2. It returns the draft and writes nothing.
3. Show the user the whole draft, as it came: the folders and the map rows first, then each hub and
   note with its whole text, then what the code could not confirm.

## 3. The approval

1. A change the user asks for goes to `docs-keeper` with the draft, for a new draft. It checks the
   change against the code.
2. Show the user each part that changed, then ask again.
3. Nothing is written until the user approves the draft as shown.
4. A no to the whole draft writes nothing. Go on as the step that offered it says.

## 4. The write

1. On the user's approval, start `docs-keeper` again for the write of Workflow 7, with the draft as
   the user approved it.
2. Show the user its report, and name each file it kept as it was.
3. Go on as the step that offered it says. The rows written are their repositories' rows.
