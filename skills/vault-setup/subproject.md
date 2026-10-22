# Add a subproject to a project

Step 0 of `SKILL.md` has run. Resolve the project with `second-brain project --name "<project>"`.
Exit 1 or 4: show `second-brain projects` and ask. A subproject is one note,
`<project path>/claude/subprojects/<name>.md`, and a docs folder, `<topics root>/<name>/`. It
splits repositories and docs, not tracking: the project keeps one ticket key and one board.
Never invent a name, a repository, a location, a branch or a doc.

## 1. Ask

In one round:

- The subproject's name: a short folder name, such as `infra`. It names the note and the docs
  folder.
- Its repositories: folder names, the default for branch checks first. Each one belongs to one
  subproject. `second-brain subproject <project>` lists the ones taken.
- Where each one is stored, when it is not under the profile's `repos_root`.
- What differs from the profile: `base_branch`, `production_branch`, `branch_pattern`,
  `environments`. Show the profile's values from `second-brain profile <project> --keys`. A key
  the user does not change stays empty and takes the profile's value.

## 2. Create it

1. Run `second-brain scaffold subproject <project> <name> --repos <R1,R2>`. It prints the note
   and the docs hub it created, links the docs hub from the topics hub, and never overwrites.
   Exit 5: the name or a repo name is not a folder name. Exit 6: the name exists in another
   letter case, or a repo belongs to another subproject, which the message names. Show it and ask.
2. Write the answers into the note's frontmatter with the Edit tool, quoted as in the profile.
   A location goes in the note's `repo_paths:` as `"<repo>=<path>"`, with `~/...` for a folder
   under the home directory.
3. Rules the user gives for this subproject go under `## Rules` in the note, one per bullet. They
   replace the placeholder line. With none, leave it.
4. For every repository, add its Code to doc map rows as section 2 of `repo.md` says, with the
   subproject's docs folder, `<topics root>/<name>/`, in the Docs cell where its docs live there.

## 3. Its tasks

A task of the subproject stays in the project's one tasks folder and names the subproject in its
frontmatter, `subproject: <name>`, spelled as the note is named. story-tracker writes it on a new
task with `second-brain task new <ID> --subproject <name>`, taking the name from the
`subproject:` line of `second-brain context` in its repos. For tasks that exist, offer to set it:
show `second-brain board <project>`, ask which tasks belong to the subproject, then run
`second-brain task set <ID> subproject=<name>` for each. Exit 1: the name is no subproject. The
board's `By subproject` view groups the tasks, and
`second-brain board <project> --subproject <name>` lists one subproject's.

## 4. Finish

1. Run `second-brain subproject <project> <name>` and show its settings: each value is the note's
   or, when the note leaves it empty, the profile's.
2. Run `second-brain repo <project>` and show the rows: each path and whether it exists.
3. Run `second-brain doctor <project>`. `subprojects` and `repos` must be `ok`. Report every row
   that is not `ok`, with its fix.
