# Adopt an existing project

Step 0 of `SKILL.md` has run: the vault is set up and the helper answers. `<path>` is the project's
folder, relative to the vault. Adopting writes only what is missing. It moves nothing, renames
nothing and rewrites no note body.

## 1. Look at what is there

- List the project's top-level folders: `ls "<vault>/<path>"`.
- Find where tasks, docs and sprint notes already live. Ask when a folder's purpose is not plain.
- Settle the three roots, each a folder path relative to the project: tasks, topics, sprints. The
  topics root is `.` when topic folders sit at the project root. A kind of note the project does
  not have yet takes the default: `tasks`, `docs`, `sprints`.
- Ask for what the files do not say: the display name, the ticket key prefixes, the "use when" line,
  and whether the project runs sprints. With no sprints there is no sprints root to settle: pass
  `--no-sprints` in place of `--sprints-root`, and skip the sprint keys when filling the profile.

## 2. Scaffold only what is missing

1. Make one call, with the project's existing path and the three roots stated:

   ```
   second-brain scaffold project <name> --path <path> --keys <K1,K2> --use-when "<one line>" \
     --tasks-root <tasks root> --topics-root <topics root> --sprints-root <sprints root>
   ```

2. It writes the roots into the new profile, creates the hubs and the board under them, adds the
   index row and prints what it created. With `--topics-root .` it creates no topics hub.
3. It never overwrites: a file that was there is reported as `exists: <path>`. Nothing lands
   outside the roots, so nothing has to be removed afterwards.
4. Exit 5: a root leaves the project, repeats another root, or sits inside the tasks root. Exit 6:
   the name, the path or a key already belongs to another project. Show the message and ask.
5. `note: the profile exists`: its roots are used and the flags are ignored. To change a root, edit
   `tasks_root`, `topics_root` or `sprints_root` in the profile, then make the same call again.

## 3. Fill the profile

- Fill the frontmatter keys as in project mode of `SKILL.md`: the same questions, the same quoting.
- That includes where the repositories are stored: `repos_root`, and `repo_paths` for one stored
  somewhere else. The working directory is inside one of the repositories: propose its parent
  folder as `repos_root`. Then show `second-brain repo <project>`.
- It also includes the branch production runs (`production_branch`, empty when it is the base
  branch) and how a deployment is confirmed, written in the opening paragraph of `## Docs`.
- For every repository named, add its Code to doc map rows as section 2 of `repo.md`, beside
  this file, says. Existing docs may answer: quote them and confirm with the user. Never invent.
- Fill the seven sections from what the user says and from existing notes. Quote, do not invent.
  Leave the template's placeholder line where nothing is known.
- Record spelling exceptions in `## Topics`, one line each, as `- <tag> -> <folder>`. An exception
  is a topic folder whose name does not lowercase into its tag.

## 4. List what is off-standard

Run `second-brain doctor <project>`. From its rows and from step 1, list what is off-standard.
Fix none of it here.

- Tasks that are not `<tasks_root>/<ID>/README.md`: step 1, `no-readme` and `task-frontmatter`.
- Notes with no status, or one outside the five: `needs-a-status`.
- Bare alias links such as `[[EX-123]]`: `unresolved-links`, and `bare-links` for `[[README]]`.
- Missing aliases: `task-frontmatter`.

## 5. Say what comes next

- Bringing an old note in means adding frontmatter and one dated status note, one note at a time,
  when the user asks. Its body is never rewritten.
- A status is never guessed. A note without one stays "Needs a status" until the user names it.
- A move is a separate, explicit step, taken only when the user asks: `second-brain snapshot`,
  then `second-brain ob move path="<vault path>" to="<folder or new path>"` so Obsidian rewrites
  the links, then `second-brain compare`. Never `mv`.
