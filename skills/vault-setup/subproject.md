# Add a subproject to a project

Step 0 of `SKILL.md` has run. Resolve the project with `second-brain project --name "<project>"`.
Exit 1 or 4: show `second-brain projects` and ask. A subproject is one note,
`<project path>/claude/subprojects/<name>.md`, and a docs folder, `<topics root>/<name>/`. It
splits repositories and docs, not tracking: the project keeps one ticket key and one board.
Never invent a name, a repository, a location, a branch or a doc.

## 1. Ask

In one round:

- The subproject's name: a short folder name, such as `infra`.
- Its repositories, as folder names, the default for branch checks first. Each one belongs to one
  subproject: `second-brain subproject <project>` lists the ones taken.
- Where each one is stored, when it is not under the profile's `repos_root`.
- What differs from the profile: `base_branch`, `production_branch`, `branch_pattern`,
  `environments`. Show the profile's values from `second-brain profile <project> --keys`.

## 2. Create it

1. Run `second-brain scaffold subproject <project> <name> --repos <R1,R2>`.
   - It prints the note and the docs hub it creates, and links the hub from the topics hub.
   - It never overwrites.
   - Exit 5: the name or a repo name is not a folder name.
   - Exit 6: the name exists in another letter case, or a repo belongs to another subproject.
   - Exit 5 or 6: show the message and ask.
2. Write the answers into the note's frontmatter with the Edit tool, quoted as in the profile.
   - A key the user does not change stays empty and takes the profile's value.
   - Record each location in the note's `repo_paths:`, as step 4 of `## 1. The repository` in
     `repo.md` says.
3. Rules the user gives for this subproject go under `## Rules` in the note, one per bullet, in
   place of the placeholder line. With none, leave the placeholder.
4. For every repository, add its Code to doc map rows as `## 2. The docs that follow it` in
   `repo.md` says. Where its docs live in `<topics root>/<name>/`, the Docs cell names that folder.
5. Ask whether this subproject's `delivery`, `spec_home` or `validation_home` differs from the
   profile's, and write the answer as step 2 says.
6. Write each repository's validation steps as `validation.md` says.

## 3. Its tasks

A task of the subproject stays in the project's one tasks folder. It names the subproject in its
frontmatter, `subproject: <name>`, spelled as the note is named.

- A new task: story-tracker writes it, as step 1 of `## 3. Create the story` in
  `skills/story-tracker/create.md` says.
- Tasks that exist: offer to set it. Show `second-brain board <project>`, ask which tasks belong
  to the subproject, then run `second-brain task set <ID> subproject=<name>` for each.
- Exit 1 from `task set`: the name is no subproject.
- `second-brain board <project> --subproject <name>` lists one subproject's tasks. The board's
  `By subproject` view groups them.

## 4. Finish

1. Run `second-brain subproject <project> <name>` and show its settings.
2. Run `second-brain repo <project>` and show its rows.
3. Run `second-brain doctor <project>`. `subprojects` and `repos` must be `ok`. Report every row
   that is not `ok`, with its fix.
