# Adopt an existing project

Step 0 of `SKILL.md` has run. `SKILL.md`, `repo.md` and `validation.md` sit beside this file.
`<path>` is the project's folder, relative to the vault. Adopting writes only what is missing. It
moves nothing, renames nothing and rewrites no note body.

## 1. Look at what is there

- List the project's top-level folders: `ls "<vault>/<path>"`.
- Find where tasks, docs and sprint notes already live.
- Ask when a folder's purpose is not plain.
- Settle the roots, each a folder path relative to the project: tasks, topics and, when the
  project runs sprints, sprints.
- The topics root is `.` when topic folders sit at the project root.
- A kind of note the project does not have yet takes the default root: `tasks`, `docs`, `sprints`.
- Ask for what the files do not say: the display name, the ticket key prefixes, the "use when"
  line, and whether the project runs sprints.

## 2. Scaffold only what is missing

1. Make one call, with the project's existing path and the roots from section 1:

   ```
   second-brain scaffold project <name> --path <path> --keys <K1,K2> --use-when "<one line>" \
     --tasks-root <tasks root> --topics-root <topics root> --sprints-root <sprints root>
   ```

   - No sprints: pass `--no-sprints` in place of `--sprints-root`.
2. It writes the roots into the new profile, creates the hubs and the board under them, adds the
   index row and prints what it created.
   - `--topics-root .` creates no topics hub.
   - A file that was there is kept and reported as `exists: <path>`.
3. Exit 5 or 6: show the message and ask.
   - Exit 5: a root leaves the project, repeats another root, or sits inside the tasks root.
   - Exit 6: the name, the path or a key already belongs to another project.
4. `note: the profile exists`: its roots are used and the flags are ignored.
   - To change a root, edit `tasks_root`, `topics_root` or `sprints_root` in the profile, then
     make the same call again.

## 3. Fill the profile

- Fill the frontmatter keys as steps 3 to 6 of `## project <name>` in `SKILL.md` say.
- No sprints: skip `sprint_length_days` and `sprint_anchor_end`.
- The working directory is inside one of the repositories: propose its parent folder as
  `repos_root`.
- With `task_layout: archive`, the done tasks already there stay where they are. The doctor's
  `task-layout` row names the ones due.
- Archive them later, as a bulk move, only when the user asks: `second-brain snapshot`, then
  `second-brain doctor <project> --fix`, then `second-brain compare`.
- Ask how a deployment is confirmed. Write the answer in the opening paragraph of `## Docs`.
- For every repository, add its Code to doc map rows as `## 2. The docs that follow it` in
  `repo.md` says.
- Existing docs may answer: quote them and confirm with the user.
- For every repository, write its validation steps as `validation.md` says.
- Fill the seven sections from what the user says and from existing notes. Quote, do not invent.
- Leave the template's placeholder line where nothing is known.
- Record spelling exceptions in `## Topics`, one line each, as `- <tag> -> <folder>`.
- An exception is a topic folder whose name does not lowercase into its tag.

## 4. List what is off-standard

Run `second-brain doctor <project>`. From its rows and from section 1, list what is off-standard.
Fix none of it here.

- A task not at `<tasks_root>/<ID>/README.md`, or `<tasks_root>/archive/<YYYY>/<ID>/README.md`
  once archived: `task-location` when it has `type: task`, section 1 when it has no frontmatter
  yet.
- A task folder with no README: `no-readme`.
- Tasks that do not follow `task_layout`, such as an `archive` folder under the tasks root of a
  `flat` project: `task-layout`.
- A hub that is missing or empty: `hubs`.
- Notes with no status, or one outside the five: `needs-a-status`.
- Bare alias links such as `[[EX-123]]`: `unresolved-links`.
- `[[README]]` links: `bare-links`.
- Missing aliases, or a task with no `type`: `task-frontmatter`.

## 5. Say what comes next

- Bring an old note in only when the user asks, one note at a time: add frontmatter and one dated
  status note. Never rewrite its body.
- Never guess a status. A note without one stays "Needs a status" until the user names it.
- Move a note only when the user asks, as its own step: `second-brain snapshot`, then
  `second-brain move "<vault path>" "<folder or new vault path>" --dry-run` to see what it would
  rewrite, then the same command without `--dry-run`, then `second-brain compare`.
