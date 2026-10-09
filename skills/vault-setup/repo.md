# Add a repository to a project

Step 0 of `SKILL.md` has run. Resolve the project with `second-brain project --name "<project>"`.
Exit 1 or 4: show `second-brain projects` and ask. A repository joins the profile's Code to doc map
in the same change that adds it to `repos`. Edit the profile, `<project path>/claude/profile.md`,
with the Edit tool. Never invent a name, a location, a kind of change or a doc.

## 1. The repository

1. Run `second-brain profile <project> --keys`. It shows `repos`, `repos_root` and `repo_paths`.
2. Ask for the repository's folder name, and where it is stored on this machine.
3. Add the name to `repos:`, last. The first name stays the default for branch checks.
4. Stored under `repos_root`: write nothing more. Stored somewhere else: add `"<name>=<path>"` to
   `repo_paths:`, with `~/...` for a folder under the home directory. Not known: leave it out.
5. Add its line under `## Repos`: the folder name and what it holds, in the user's words.

## 2. The docs that follow it

1. Ask which docs follow this repository: for each kind of change that matters, which doc
   surfaces must be updated. The user names the kinds of change.
2. Add one row per kind of change to the table under `### Code to doc map`, in the profile's
   `## Docs` section: `| <repo> | <change> | <docs> |`. The first cell is the name as `repos:`
   spells it. The first real row replaces the template's `<repo>` row.
3. Add the repository's own doc files under `### Repo doc surfaces`: `- <repo>: <doc files>`.
4. The user cannot name any yet: add one row, `| <repo> | any change | none yet |`. Then append one
   dated line to the debt file named under `### Debt file`, saying this repository has no docs
   mapped yet. The gap is then visible, not silent.
5. No debt file is named there: ask for one and record its path first. The user wants none: say
   that the gap shows only as the `none yet` row.

## 3. Finish

1. Run `second-brain repo <project>` and show the rows: each path and whether it exists.
2. Run `second-brain doctor <project>`. `code-doc-map` and `repos` must be `ok`. Report every row
   that is not `ok`, with its fix.
3. Say what was added: the name, its location, its map rows and, if any, the debt line.
