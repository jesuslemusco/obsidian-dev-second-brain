---
name: vault-setup
description: Set up an Obsidian vault and its projects on the second-brain standard, and register vault skills and agents by link.
argument-hint: "[init | project <name> | adopt <path> | repo <project> | subproject <project> | validation <project> | link]"
disable-model-invocation: true
allowed-tools: Read Glob Bash(second-brain *)
---

# Vault setup

The first argument is the mode. With none, ask which.

- `init`: set up a vault.
- `project <name>`: add a project.
- `adopt <path>`: bring a project that already holds notes onto the standard.
- `repo <project>`: add a repository to a project.
- `subproject <project>`: add a subproject, repos with their own branches and docs folder.
- `validation <project>`: write or fix how each repo is run and checked.
- `link`: register the vault's own skills and agents.

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

## Step 0 - Context

1. Run `second-brain context` yourself, as your first tool call.
   - `second-brain` is not found: the plugin is not enabled. Say so and stop. Never guess paths.
2. `vault: none` is the normal state before init, not an error.
   - In init, go on.
   - In any other mode, say that no vault is set up, offer init, and stop.
3. `vault:` shows a path: the vault is set up. Init may still run: each of its steps skips what
   exists.

## init

1. Ask for the vault folder.
   - Propose the working directory when it holds `.obsidian/`.
   - Refuse a folder with no `.obsidian/`. Tell the user to open it in Obsidian as a vault first,
     and stop.
2. Run `second-brain pointer set "<vault folder>"`. It makes the pointer,
   `~/.claude/second-brain-vault`, and prints the folder it leads to.
   - Exit 0: the pointer leads to the vault, made now or already there.
   - Exit 6, `the pointer leads elsewhere`: the message names the other folder. Show both folders
     and ask before changing it. On a yes, run the command again with `--replace` at the end.
   - Exit 6, `a real file or folder`: it is never replaced. Say what it is and stop.
   - Exit 5: the folder is not a vault. Show the message and stop.
   - `second-brain pointer` prints where the pointer leads, at any time.
3. Run `second-brain root`. It must print the vault's path. Exit 2: show the message and stop.
4. Run `second-brain scaffold vault`. It prints each file it created: `CLAUDE.md`,
   `obsidian-conventions.md`, `claude/README.md` and `claude/pull-request.md`.
   - `exists: <path>`: that file was there and is kept.
5. Read `~/.claude/CLAUDE.md`. The import line is `@~/.claude/second-brain-vault/CLAUDE.md`.
   - It already imports this vault's `CLAUDE.md`, in that form or by the vault's own path: say so
     and change nothing.
   - Otherwise show the line, and say that `~/.claude/CLAUDE.md` is their global instruction file,
     read in every session.
   - Only after an explicit yes, add the line at its end, or create the file with that one line.
   - On a no, leave it. The doctor will report `import`.

## project <name>

1. Ask, in one round:
   - the folder inside the vault, as a vault-relative path such as
     `clients/acme/projects/example`;
   - the ticket key prefixes, such as `EX,EXOPS`, or none;
   - one line that says when the project applies;
   - whether the project runs sprints.
2. Run `second-brain scaffold project <name> --path <path> --keys <K1,K2> --use-when "<one line>"`.
   It creates the project's notes and its index row, and prints what it created.
   - The folder already holds notes: use adopt instead.
   - No sprints: add `--no-sprints`, and skip the two sprint rows of the interview in step 3.
   - Exit 5: show the message and ask.
   - Exit 6: the name, the path or a key belongs to another project, which the message names.
     Show the message and ask for another one, or for different keys.
3. Interview for the profile, in one short round:

   | Key | Ask for | Written as |
   |---|---|---|
   | `tracker` | where tickets live | `"Jira"` |
   | `persona` | the role a story's description opens with | `"Example engineer"` |
   | `task_layout` | whether a done or abandoned task moves once to `<tasks_root>/archive/<YYYY>/<ID>/`, or every task stays in its folder | `archive` or `flat` |
   | `archive_after_days` | with `archive` only: the days a done task stays in the live folder before the doctor names it | `14` |
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
   | `delivery` | whether stories are built from an approved spec of requirements, design and tasks, or straight from the README | `spec` or `direct` |
   | `spec_home` | with `spec`: whether a story's spec lives in its task folder or in `spec/<ID>/` in the repo | `vault` or `repo` |
   | `validation_home` | whether `validation.md`, how to run and check each repo, is `claude/validation.md` or a file at each repo's root | `vault` or `repo` |

4. Write the answers into the frontmatter of `<path>/claude/profile.md` with the Edit tool.
   - Quote strings and the sprint end date.
   - Write a folder under the home directory as `~/...`.
   - On Windows, write any other folder with forward slashes, as in `"C:/code/acme"`: inside
     quotes a backslash is an escape.
   - Never remove or reorder a key.
   - Add a key from the table only when the profile lacks it.
5. A key the user gave no answer for stays as the scaffold wrote it. Say which keys are still
   open.
   - An empty `repos_root` is fine.
6. Run `second-brain repo <project>` and show its rows: name, path and state, `ok`, `missing` or
   `unknown`.
7. Fill `## Docs` of the profile:
   - Ask how a deployment is confirmed in this project. Write the answer in its opening paragraph.
   - For every repository named, add its Code to doc map rows as
     `## 2. The docs that follow it` in `${CLAUDE_SKILL_DIR}/repo.md` says.
   - Fill any other section only from what the user says.
8. Offer to list the folders under the topics root, so the user can confirm the topics:
   `ls -d "<vault>/<path>/<topics_root>"/*/`.
9. `scaffold project` leaves the template's `<...>` lines in the project hub, `claude/README.md`
   and the profile.
   - Ask for one paragraph on the project and for its rules. Write them in place of those lines.
   - Delete a line the user has nothing for.
10. Write each repo's validation steps as `${CLAUDE_SKILL_DIR}/validation.md` says.
    - With `validation_home: repo`, `claude/validation.md` is not used. Ask, then delete it and
      its line in `claude/README.md`.

## adopt <path>, repo <project>, subproject <project> and validation <project>

Each of these modes has its own file. Read a mode's file only in that mode, or when a step points
to it, and follow it.

- adopt: `${CLAUDE_SKILL_DIR}/adopt.md`
- repo: `${CLAUDE_SKILL_DIR}/repo.md`
- subproject: `${CLAUDE_SKILL_DIR}/subproject.md`
- validation: `${CLAUDE_SKILL_DIR}/validation.md`

In project and adopt, offer subproject when the user names repositories that differ in branches
or docs.

## link

1. Run `second-brain link --check`. Each row is `name | kind | state | target`, with `kind`
   `skill` or `agent`.
   - Exit 1: at least one row is neither `linked` nor `foreign`.
2. Show only the rows that are neither `linked` nor `foreign`.
   - `foreign` is an entry in `~/.claude` that no vault skill or agent claims, such as the user's
     own global skills or a folder a plugin manages. It is normal and never touched: do not show
     it as a problem.
3. Explain each row shown:
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
4. Run `second-brain link --apply` only after the user agrees.
   - It prints what it did as `note:` lines, `linked:`, `repointed:` or `removed:`, then the rows
     as they now are.
   - Exit 1: show the rows still neither `linked` nor `foreign`. Those need the user's decision.

## Finish (every mode)

Run `second-brain doctor`, or `second-brain doctor <project>` after a mode that names one. Each
row is `result | check | scope | count | offenders | fix`. Report every row that is not `ok`, with
its fix.

- `index` fails after init when `CLAUDE.md` was there before and has no `## Projects` table. Say
  so: the first `second-brain scaffold project` adds the table and its row.
- For the detail of a check, offer the vault-doctor skill. On a yes, call it with the Skill tool
  as `obsidian-dev-second-brain:vault-doctor`.

## Rules

- Never delete a file without asking.
- Never overwrite an existing file. The scaffold commands skip what exists.
- Never move a note with `mv`. A move is `second-brain snapshot`, then `second-brain move`.
- Outside the vault, this skill itself writes two things only: the pointer, with
  `second-brain pointer set`, and, after a yes, the one import line.
- Links under `~/.claude/skills` and `~/.claude/agents` are made by `second-brain link --apply`.
  Never run `ln` or `mklink`.
- Ask, do not invent: an answer, a folder, a key prefix, a date, a location, a rule.
- `-` in helper output is empty.
