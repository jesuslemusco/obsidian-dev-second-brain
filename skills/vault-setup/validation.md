# Write a repo's validation steps

Step 0 of `SKILL.md` has run. Resolve the project with `second-brain project --name "<project>"`.
Exit 1 or 4: show `second-brain projects` and ask. Never invent a step.

## 1. Where it lives

1. Run `second-brain validation <project>` and read each repo's home and state.
2. A repo's home is `validation_home` in its subproject's note, else in the profile:
   - `vault`: every repo's section is in `claude/validation.md`.
   - `repo`: each repo has a `validation.md` at its root.
3. To change a home, ask, then edit `validation_home` with the Edit tool.
4. State `unknown`: ask where the repo is stored and record it, as steps 2 and 4 of
   `## 1. The repository` in `repo.md` say.

## 2. Write each repo's section

1. State `missing` or `no-section`: run `second-brain validation new <project> <repo>`. It never
   changes a section that is there.
2. Find the repo's folder with `second-brain repo <project> <repo>`. Read its README, its scripts,
   such as `package.json`, `Makefile` or `pyproject.toml`, and its CI config, such as
   `.github/workflows/`.
3. Draft the four parts from them:
   - `### Set up and start`: the commands that install, build and start it from a fresh clone.
   - `### Checks`: each command that must pass, such as the tests, the linter and the build, and
     what it proves.
   - `### Check as a user would`: the steps that use a change as a user does, such as opening the
     page, calling the endpoint or running the command, and what to look for.
   - `### A pass`: what must be true for a change to pass.
4. Show the draft and ask the user to confirm or correct each part.
5. Write only what they confirm, in place of the `<...>` lines, with the Edit tool.
6. A part they cannot fill yet keeps its `<...>` line.
7. Read it back with `second-brain validation <project> <repo>`.

## 3. Finish

Run `second-brain doctor <project>`. Its `validation` row is `ok` once every repo's section is
written. Say which repos are done and which parts are still open.
