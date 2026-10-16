---
name: vault-setup
description: Set up an Obsidian vault and its projects on the second-brain standard, and register vault skills and agents by link.
argument-hint: "[init | project <name> | adopt <path> | repo <project> | link]"
disable-model-invocation: true
allowed-tools: Read Glob Bash(second-brain *)
---

# Vault setup

Five modes: init sets up a vault, project adds a project, adopt brings an existing project onto
the standard, repo adds a repository to a project, link registers the vault's own skills and
agents. The first argument is the mode. With none, ask which.

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

## Step 0 - Context

1. Run `second-brain context` yourself, as your first tool call. `second-brain` is not found: the
   plugin is not enabled. Say so and stop. Never guess paths.
2. `vault: none` is the normal state before init, not an error. In init, go on. In any other
   mode, say that no vault is set up, offer init, and stop.
3. `vault:` shows a path: the vault is set up. Init may still run; each step skips what exists.

## init

1. Ask for the vault folder. Propose the working directory when it holds `.obsidian/`. Refuse a
   folder with no `.obsidian/`: tell the user to open it in Obsidian as a vault first, and stop.
2. Create the pointer, `~/.claude/second-brain-vault`, a link to the vault. Run
   `second-brain pointer set "<vault folder>"`. It prints the folder the pointer leads to.
   - Nothing was there: it creates the pointer.
   - The pointer already leads to this vault: it leaves it.
   - Exit 6, `the pointer leads elsewhere`: the message names the other folder. Show both folders
     and ask before changing it. On a yes, run the command again with `--replace` at the end.
   - Exit 6, `a real file or folder`: it is never replaced. Say what it is and stop.
   - Exit 5: the folder is not a vault. Show the message and stop.
   - `second-brain pointer` prints where the pointer leads, at any time.
   - Never make the pointer another way. On Windows `ln -s` copies the vault.
3. Run `second-brain root`. It must print the vault's path. Exit 2: show the message and stop.
4. Run `second-brain scaffold vault`. It creates `CLAUDE.md` (the index, with an empty
   `## Projects` table), `obsidian-conventions.md`, `claude/README.md` (the hub for the user's
   own skills and agents) and `claude/pull-request.md` (the pull request description format), and
   prints the ones it created. It never overwrites: a file that was
   there is kept and reported as `exists: <path>`.
5. The import line is `@~/.claude/second-brain-vault/CLAUDE.md`. It goes through the pointer, so
   it survives a vault move. Read `~/.claude/CLAUDE.md`.
   - It already imports this vault's `CLAUDE.md`, in that form or by the vault's own path: say so
     and change nothing.
   - Otherwise show the line. Say that file is their global instruction file, read in every
     session. Add the line at its end, or create the file with that one line, only after an
     explicit yes. On a no, leave it: the doctor will report `import`.

## project <name>

1. Ask, in one round: the folder inside the vault, as a vault-relative path such as
   `clients/acme/projects/example`; the ticket key prefixes, such as `EX,EXOPS`, or none; one line
   that says when the project applies; whether the project runs sprints. A folder that already
   holds notes is a case for adopt.
2. Run `second-brain scaffold project <name> --path <path> --keys <K1,K2> --use-when "<one line>"`.
   It creates the project hub, `claude/README.md`, `claude/profile.md`, the tasks hub and its
   board, the docs hub and the sprints hub, adds the index row, and never overwrites.
   - No sprints: add `--no-sprints`. It writes `uses_sprints: false` into the profile and creates
     no sprints hub and no `Current sprint` view. Then skip the two sprint rows of the interview.
   - Exit 5 or 6: show the message and ask. 6 means the name, the path or a key already belongs
     to another project, which the message names: ask for another one, or for different keys.
3. Interview for the profile, in one short round:

   | Key | Ask for | Written as |
   |---|---|---|
   | `tracker` | where tickets live | `"Jira"` |
   | `persona` | the role a story's description opens with | `"Example engineer"` |
   | `repos` | folder names of the code repositories, the default for branch checks first | `[example-api, example-web]` |
   | `repos_root` | the one folder those repositories usually sit in on this machine | `"~/code/acme"` or `""` |
   | `repo_paths` | each repository stored somewhere else, as `name=path` | `["example-web=~/work/example-web"]` or `[]` |
   | `base_branch` | the branch work starts from | `main` |
   | `production_branch` | the branch production runs, when it is not the base branch | `"release"` or `""` |
   | `branch_pattern` | how a ticket's branch is named | `"feature/<ID>-<slug>"` |
   | `environments` | environment names in promotion order, or none | `[dev, staging, prod]` or `[]` |
   | `sprint_length_days` | the sprint length in days | `14` |
   | `sprint_anchor_end` | the end date of the current or next sprint | `"2026-01-14"` |
   | `achievements_skill` | the skill finished stories are handed to, if any | `"<skill name>"` or `""` |

4. Write the answers into the frontmatter of `<path>/claude/profile.md` with the Edit tool. Quote
   strings and the sprint end date. Write a folder under the home directory as `~/...`. On Windows
   write any other folder with forward slashes, as in `"C:/code/acme"`: inside quotes a backslash
   is an escape. Never remove or reorder a key. Add a key from the table only when the profile
   lacks it.
5. Never invent an answer the user did not give, least of all a location. Leave that key as the
   scaffold wrote it and say which keys are still open. An empty `repos_root` is fine.
6. Run `second-brain repo <project>` and show its rows: name, path and state (`ok`, `missing` or
   `unknown`). The user sees each path and whether it exists.
7. In `## Docs` of the profile: ask how a deployment is confirmed in this project and write the
   answer in the opening paragraph. For every repository named, add its Code to doc map rows as
   section 2 of `${CLAUDE_SKILL_DIR}/repo.md` says. Fill any other section only from what the
   user says.
8. Offer to list the folders under the topics root, `ls -d "<vault>/<path>/<topics_root>"/*/`, so
   the user can confirm the topics.

## adopt <path> and repo <project>

Each has its own file: read it only in that mode, and follow it. Adopt, for a project that
already holds notes: `${CLAUDE_SKILL_DIR}/adopt.md`. Repo, to add a repository to an existing
project: `${CLAUDE_SKILL_DIR}/repo.md`. Project and adopt use its section 2, once per repository.

## link

1. Run `second-brain link --check`. It scans `claude/` at the vault root and in every indexed
   project. Each row is `name | kind | state | target`; `kind` is `skill` or `agent`. Exit 1 means
   at least one row is neither `linked` nor `foreign`.
2. Show only those rows. A `foreign` row is an entry in `~/.claude` that no vault skill or agent
   claims: the user's own global skills, or a folder a plugin manages. It is normal and never
   touched. Do not show it as a problem. Explain each row shown:
   - `missing`: not linked yet. `--apply` links it.
   - `wrong-target` or `dangling`, with a target: a link by that name leads elsewhere, or
     nowhere. `--apply` repoints or removes it only when it led into the vault.
   - `wrong-target` with target `-`: a real file or folder by that name sits in `~/.claude`. The
     helper leaves it alone and prints a `note:`. The user decides which one keeps the name.
   - `name-mismatch`: the skill folder or agent file name differs from `name` in its
     frontmatter. They must be made equal first. Propose which one to change.
   - `duplicate`: two pieces in the vault carry one name. One has to be renamed, usually the
     project one, with the project as its prefix.
   - On Windows the agents of one `claude/` folder share one link, to its `agents` folder. Their
     rows carry that link's state and change together.
3. Run `second-brain link --apply` only after the user agrees. It reports what it did as `note:`
   lines (`linked:`, `repointed:`, `removed:`), then prints the rows as they now are. Exit 1:
   show the rows that are still neither `linked` nor `foreign`. Those need the user's decision.

## Finish (every mode)

Run `second-brain doctor`, or `second-brain doctor <project>` after project, adopt and repo. A row
is `result | check | scope | count | offenders | fix`. Report every row that is not `ok`, with its
fix.

- Init never overwrites a `CLAUDE.md` that was there, so it has no `## Projects` table and `index`
  fails. Say so: the first `second-brain scaffold project` adds the table and its row.
- For the detail of a check, name `/obsidian-dev-second-brain:vault-doctor`. The user runs it.

## Rules

- Never delete. Never overwrite an existing file. The scaffold commands skip what exists.
- Never move a note with `mv`. A move is `second-brain snapshot`, then `second-brain move`.
- Outside the vault, this skill itself creates or changes two things only: the pointer, with
  `second-brain pointer set`, and, after a yes, the one import line. Links under
  `~/.claude/skills` and `~/.claude/agents` are made by `second-brain link --apply`. Never run
  `ln` or `mklink`.
- Ask, do not invent: a folder, a key prefix, a date, a location. `-` in helper output is empty.
