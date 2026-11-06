# Write a repo's validation steps

Step 0 of `SKILL.md` has run. Resolve the project with `second-brain project --name "<project>"`.
Exit 1 or 4: show `second-brain projects` and ask. `validation.md` says how to run and check a
repo's code, and the agents that build and review a change run its steps: a step that is wrong or
missing lets a broken change through. Never invent a step.

## 1. Where it lives

1. Run `second-brain validation <project>`. Each row is a repo, its home (`vault` or `repo`), the
   path and the state: `ok`, `missing`, `no-section`, or `unknown` when a repo home has no recorded
   location.
2. A repo's home is `validation_home` in its subproject's note, else in the profile: `vault` keeps
   every repo's section in `claude/validation.md`, `repo` puts a `validation.md` at the root of the
   repo. To change it, ask, then edit the key with the Edit tool.
3. `unknown`: the repo has no recorded location. Add it as section 1 of `repo.md` says, first.

## 2. Write each repo's section

1. A repo that is `missing` or `no-section`: run `second-brain validation new <project> <repo>`.
   It writes the file or adds the section, and never changes one that is there.
2. Read what the repo already says, at the path `second-brain repo <project> <repo>` prints: its
   README, its scripts (`package.json`, `Makefile`, `pyproject.toml` and the like) and its CI
   config, such as `.github/workflows/`. Draft the four parts from them:
   - `### Set up and start`: the commands that install, build and start it from a fresh clone.
   - `### Checks`: each command that must pass, such as the tests, the linter and the build, and
     what it proves.
   - `### Check as a user would`: the steps that use a change the way a user does, such as
     opening the page, calling the endpoint or running the command, and what to look for.
   - `### A pass`: what must be true for a change to pass.
3. Show the draft and ask the user to confirm or correct each part. Write only what they confirm,
   in place of the `<...>` lines, with the Edit tool. A part they cannot fill yet keeps its
   `<...>` line, and the doctor's `validation` row keeps naming it.
4. Read it back with `second-brain validation <project> <repo>`.

## 3. Finish

Run `second-brain doctor <project>`. `validation` is `ok` once every repo's section is written.
Say which repos are done and which parts are still open.
