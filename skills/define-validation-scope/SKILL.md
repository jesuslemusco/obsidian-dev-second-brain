---
name: define-validation-scope
description: Propose which checks run at each validation stage of a repo, with their paths, from the project's docs or its code, and write the repo's section once the owner approves.
argument-hint: "[project] [repo]"
allowed-tools: Read Grep Glob Edit Bash(second-brain *) Bash(ls -d *)
---

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

# Define validation scope

You draft, with the owner, one repo's section of `validation.md`: each check's command, its
stage and the paths it covers, and the steps that check a change as a user would. You draft from
the project's docs, or from the repo's code when it has none. Write nothing until the owner
approves the draft. The section's shape is under `### Validation` in
`${CLAUDE_PLUGIN_ROOT}/docs/contract.md`.

The first argument is the project, the second the repo. With none, take them from the request.

## Step 0 - Context

1. Run `second-brain context` yourself, as your first tool call.
   - `second-brain` is not found: the plugin is not enabled. Say so and stop. Never guess paths.
   - `vault: none`: no vault is set up. Say so, offer `/odsb:vault-setup init`, and stop. The user
     runs it by name.
2. Resolve the project, first match wins: the name given, with
   `second-brain project --name "<name>"`, which prints its vault path, else the `project:` and
   `project_path:` lines.
   - `none`, exit 1 or exit 4: show `second-brain projects` and ask.
3. `second-brain profile <project> --keys` prints its `topics_root`.
   - Exit 1: no profile. Say so, offer `/odsb:vault-setup adopt`, and stop.
4. Run `second-brain validation <project>`. Each row is a repo: its name, its home, `vault` or
   `repo`, the path of its file and its state.
   - The repo is the one given. With none, show the rows and ask which. For several, take each in
     turn, from `## 1` to `## 6`.
   - State `unknown`: the repo has no recorded location. Say so, offer
     `/odsb:vault-setup validation <project>`, which records it, and stop.
5. Find the repo's folder with `second-brain repo <project> <repo>`.
   - Exit 1: show its message and stop. The draft needs the repo's code.

## 1. The stages the project uses

- Every project uses `each story`, run in each story's review, and `each merge`, run on the
  branch a story merges into before its push.
- `release` is only for a project that plans releases: one whose planned-releases note,
  `<vault>/<project path>/<topics_root>/planned-releases.md`, is there, as `ls -d "<that path>"`
  shows.
- In a project that plans no releases, draft no `release` check and no `release` user step.
  A check the code keeps for a release, such as an end-to-end suite that costs money, goes under
  `Left out:` in the draft, for the owner to place at another stage or leave out.

## 2. The project's docs

1. The project's docs are its topic notes, under the topics root in the vault, and the repo's own
   doc files, named under `### Repo doc surfaces` in `second-brain profile <project> Docs`.
2. It has none when the topics root holds no topic folder, as `## 1. Offer it` in
   `${CLAUDE_PLUGIN_ROOT}/skills/vault-setup/docs.md` counts them, and `### Repo doc surfaces`
   names no doc file of the repo.
3. A project with none: offer `docs-keeper`'s setup first, for this repo, as that file says. This
   step is the one that offered it.
   - Declined already in this session, such as at step 7 of vault-setup's project mode: take it
     as a no, and offer it no second time.
   - Once it has written the docs, read them as step 4 says.
   - On a no, or when it writes nothing, read the repo's code as `## 3. The repo's code` says, and
     draft from it alone.
4. A project with docs: read the ones on how the repo is set up, tested, built and laid out,
   cheapest first: a vault note with `second-brain outline <path>`, then a ranged read, and a doc
   file of the repo with Read. Draft from them: the suites, linters and builds they name, what
   each one proves, and the folders of each part of the code.
   - Then read the code as `## 3. The repo's code` says, to take each command as the code spells
     it, and to add what the docs leave out.
   - A command the docs name that the code does not hold goes under `Not confirmed:` in the draft,
     never under `### Checks`.

## 3. The repo's code

Read the repo's folder, the path step 5 of Step 0 printed, with Read, Glob and Grep. Run none of
its commands.

- Its test scripts: the test, lint and build entries of `package.json` `scripts`, the targets of a
  `Makefile`, and the test runners in a `scripts/` or `bin/` folder.
- Its CI workflows, such as `.github/workflows/*.yml` or `.gitlab-ci.yml`: the commands each job
  runs, the events it runs on, and the `paths:` filter of its trigger.
- Its package manifests, such as `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml` or
  `pom.xml`: the install and build commands, and each workspace or module, a part of the code
  with a folder of its own.

## 4. The draft

Draft the repo's section in the shape of
`${CLAUDE_PLUGIN_ROOT}/templates/validation-repo.md.tmpl`: its four level-3 headings, in order,
with the drafted lines in place of the template's `<...>` lines.

- `### Set up and start`: the commands that install, build and start it from a fresh clone, in
  order.
- `### Checks`: one bullet per check: its command the line's first code span, then what it
  proves, then its `paths:` when it has them, then its `when:`:
  `` - `npm run test:api` - the API suite - paths: api/**, `package.json` - when: each story ``.
- The stage of each check, one of the stages of `## 1`:
  - `when: each story` for one each story's review runs, quick enough for every change, such
    as a linter, a type check or the suite of one part of the code.
  - `when: each merge` for one that runs once a story merges, such as the full suite or the
    build. A CI job that runs on each push to the base branch is one.
  - `when: release`, in a project that plans releases, for one that costs money or takes long,
    such as an end-to-end suite.
- The `paths:` of a check that only some files can break, such as the suite of one part: the
  folders of that part's code and tests, and each config file it reads, as globs from the repo's
  root. `*` stays within a folder, and `**` crosses folders.
  - A CI job's `paths:` filter, or a workspace's folder, gives them.
  - A check that any file can break, such as the linter of the whole repo or the build, has no
    `paths:`.
- `### Check as a user would`: one bullet per step, which starts with its tool, a skill by name,
  a command, an API call or a query, then what to look for, then its `when:`.
  A user step takes no `paths:`.
  - A step on a page needs a browser, and the plugin ships none. Offer a browser skill this
    session lists, else ask which one the repo uses.
- `### A pass`: what a pass needs, such as every check above passing and the user steps working.
- A part that neither the docs nor the code fill keeps its `<...>` line.
- Never invent a command, a glob, a stage or a step.

Show the draft in this order:

1. The section as it will read, whole.
2. `Sources:` each check and step, with the doc or the code file it comes from.
3. `Left out:` each check left out and why, such as one kept for a release in a project that plans
   none. `Not confirmed:` each command the docs name that the code does not hold.
4. A section that holds lines already, state `ok`: each line the draft changes, adds or drops,
   beside the line it replaces.

## 5. The approval

1. Show the draft, and end it with the line `What's wrong or missing?` as plain text. Then stop for
   the owner's answer.
2. A change the owner asks for: make it in the draft, and show each part it changed again, in
   full. Then ask again.
   - A change that names a command or a glob: check it against the code, as
     `## 3. The repo's code` reads it, and say what the code does not hold.
3. Nothing is written until the owner approves the draft as shown.
   - With no change left, ask for that approval. Only a plain yes is one.
4. A no to the whole draft writes nothing. Say that the section stays as it was.

## 6. The write

1. On the owner's approval, take the repo's state from `second-brain validation <project>`:
   - `missing` or `no-section`: run `second-brain validation new <project> <repo>`. It writes the
     section from the template, and prints the path of its file.
   - `empty` or `ok`: the section is there, and `validation new` never changes it.
2. Write the approved lines with the Edit tool, each in place of its `<...>` line or of the line
   it changes. Change no other line, and no other repo's section.
   - An `empty` section gets the four parts under its heading.
   - With a `repo` home, the file is the repo's own `validation.md`: say so, as a change for the
     owner to commit.
3. Read it back with `second-brain validation <project> <repo>`. It must print the section as
   approved.
4. Run `second-brain doctor <project>`. Report its `validation` row, and each other row that is
   not `ok`, with its fix.
5. Say what was written, which parts keep their `<...>` line, and what was left out.

## Rules

- Ask, do not invent: a command, a glob, a stage, a tool or a step.
- This skill writes only the repo's section: through `second-brain validation new` and the Edit
  tool, once the owner approves. The docs are `docs-keeper`'s to write.
- Run none of the repo's commands: the draft comes from its files.
- `-` in helper output is empty.
