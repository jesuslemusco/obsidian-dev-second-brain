# Add a repository to a project

Step 0 of `SKILL.md` has run. Resolve the project with `second-brain project --name "<project>"`.
Exit 1 or 4: show `second-brain projects` and ask. Edit the profile,
`<project path>/claude/profile.md`, with the Edit tool. Add the repository to `repos` and to the
Code to doc map in the same change. Never invent a name, a location, a kind of change or a doc.

## 1. The repository

1. Run `second-brain profile <project> --keys` and read `repos`, `repos_root` and `repo_paths`.
2. Ask for the repository's folder name, and where it is stored on this machine.
3. Add the name to `repos:`, last: the first name stays the default for branch checks.
4. Record where it is stored:
   - Under `repos_root`: write nothing more.
   - Elsewhere: add `"<name>=<path>"` to `repo_paths:`. Write a folder under the home directory
     as `~/...`.
   - On Windows, write the path with forward slashes, as in `C:/work/example-web`: inside quotes
     a backslash is an escape.
   - Not known: leave it out.
5. Add its line under `## Repos`: the folder name and what it holds, in the user's words.

## 2. The docs that follow it

1. Ask, for each kind of change that matters, which docs must be updated.
2. Add one row per kind of change to the table under `### Code to doc map`, in `## Docs` of the
   profile: `| <repo> | <change> | <docs> |`.
   - The first cell is the name as `repos:` spells it.
   - The first real row replaces the template's `<repo>` row.
3. Add the repository's own doc files under `### Repo doc surfaces`: `- <repo>: <doc files>`.
4. The user cannot name any docs yet:
   - Add one row, `| <repo> | any change | none yet |`.
   - Append one dated line to the debt file named under `### Debt file`: this repository has no
     docs mapped yet.
   - No debt file is named there: ask for one and write its path there first.
   - The user wants no debt file: say that the gap shows only as the `none yet` row.

## 3. Finish

1. Run `second-brain repo <project>` and show its rows: each path and whether it exists.
2. Write the repository's validation steps as `validation.md`, beside this file, says.
3. Run `second-brain doctor <project>`. `code-doc-map` and `repos` must be `ok`. Report every row
   that is not `ok`, with its fix.
4. Say what was added: the name, its location, its map rows and, if any, the debt line.
