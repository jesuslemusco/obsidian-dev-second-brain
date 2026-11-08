# Finishing a passed build

Read this file only when the build finished with every task passed, as `build.md` says.

- `<path>` is the repo's path and `<branch>` the story's branch, as in `build.md`.
- Every `task note` takes `--session <session id>`, the session id for notes in `SKILL.md`.
- The story's `branch` stays `<branch>` whatever the owner picks: review fixes go on it.

## 1. The target branch

- The target is the open release branch, `release/<version>`.
- List the release branches, highest first:
  ```sh
  git -C "<path>" for-each-ref --format='%(refname:lstrip=-2)' \
    'refs/heads/release/*' 'refs/remotes/*/release/*' | sort -rVu
  ```
- The highest `v<version>` tag is the last release that shipped. It is the first line of
  `git -C "<path>" tag --list 'v*' --sort=-v:refname`.
- Only a release branch higher than that tag is open.
- With no `v<version>` tag, every release branch is open.
- The target is the highest open release branch.
- No release branch is open: ask the owner to name the target, or a version to cut.
  - Cut it from `base_branch`: `git -C "<path>" branch release/<version> <base_branch>`.
- No release branch at all: the target is `base_branch`.
- `base_branch` comes from `second-brain profile <project> --keys`.
- The repo must be on `<branch>`, and `git -C "<path>" status --porcelain` must print nothing.
  - Otherwise ask the owner to commit their changes. Never stash or discard them.

## 2. Ask the owner

- Ask with AskUserQuestion, with three options:
  - Merge `<branch>` into `<target>`.
  - Open a pull request from `<branch>` into `<target>`.
  - Keep `<branch>` as it is.
- Say in the question that typing `discard` deletes the branch.
- The owner names another target in the free-text answer: ask again, with the three options for
  that target.
- Say too that the owner can reverse a ruling of the build, or reopen the phase one touched, in
  the free-text answer, as `### The list of rulings` in `build.md` says.
  - The owner does: first
    `second-brain task set <ID> status=in-progress next="The spec skill builds the approved tasks"`.
    Then take the answer as item 3 of `## 7. When the build stops` in `build.md` says.
- Do only what the owner picks. Any other answer is `## 5. Keep`.

## 3. Merge

The merge is local. It pushes nothing.

1. Find where `<target>` is checked out: `git -C "<path>" worktree list --porcelain`.
   - A `branch refs/heads/<target>` line: `<where>` is the `worktree` line above it.
   - None: `git -C "<path>" switch <target>`, and `<where>` is `<path>`.
2. `git -C "<where>" status --porcelain` must print nothing. Otherwise ask the owner.
3. `git -C "<where>" merge --no-ff <branch> -m "Merge <branch> into <target>"`.
   - A conflict: `git -C "<where>" merge --abort`, then `## 7. A pick that fails`.
   - Never resolve a conflict yourself.
4. `git -C "<path>" switch <branch>`.
5. `second-brain task set <ID> next="Owner reviews the merge into <target>"`.
6. `second-brain task note <ID> "Finish: merged <branch> into <target> at <short hash>."`.
   - `<short hash>` is the merge commit: `git -C "<where>" rev-parse --short <target>`.
7. Say that `<target>` is not pushed. A push runs only when the owner asks, named first.

## 4. Pull request

The pick asks for two outside steps: a push and a pull request.

1. Before either runs, name both: the push of `<branch>` to `origin`, and the pull request into
   `<target>`.
2. `gh` must be installed, and `<target>` on the remote:
   `git -C "<path>" ls-remote --exit-code --heads origin <target>`.
   - Otherwise `## 7. A pick that fails`, with what is missing.
3. `git -C "<path>" push -u origin <branch>`.
4. Write the description in the pull request format the index points to.
5. In `<path>`, run `gh pr create --base <target> --head <branch> --title "<title>" --body-file -`
   with the description on stdin. The title is the story's `title`.
6. `second-brain task set <ID> next="Owner reviews the pull request"`.
7. `second-brain task note <ID> "Finish: opened a pull request into <target>: <url>."`.

## 5. Keep

- Change nothing in the repo.
- `second-brain task note <ID> "Finish: the owner kept <branch>."`.

## 6. Discard

- Delete the branch only when the owner types `discard`. A pick or a yes is not enough.
- `git -C "<path>" switch --detach`, then `git -C "<path>" branch -D <branch>`.
- Give the owner the hash git prints: `git branch <branch> <hash>` brings the branch back.
- A copy on the remote stays. Deleting it is a push: only when the owner asks, named first.
- `second-brain task set <ID> next="<branch> was discarded; the owner decides what follows"`.
- `second-brain task note <ID> "Finish: the owner typed discard; <branch> was at <short hash>."`.

## 7. A pick that fails

- A merge or a pull request fails at any step: show its error, and run no later step.
- Put `<path>` back on `<branch>`: `git -C "<path>" switch <branch>`.
- `second-brain task note <ID> "Finish: <pick> into <target> failed: <reason>; <what ran>."`.
  - `<pick>` is `merge` or `pull request`.
  - `<what ran>` names each step that ran, such as the push, or `nothing`.

## Rules

- Never force a push or rewrite history.
