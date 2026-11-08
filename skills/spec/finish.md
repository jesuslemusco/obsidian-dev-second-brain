# Finishing a passed build

Read this file only when `spec-lead` finished with every task passed.

- `<path>` is the repo's path and `<branch>` the story's branch, as in Step 3 of `SKILL.md`.
- Every `task note` takes `--session <session id>`, the session id for notes in `SKILL.md`.

## 1. The target branch

- The target is the release branch, `release/<version>`, as `## Releases` in `docs/guide.md`
  says.
- List them with `git -C "<path>" branch -a --list 'release/*' '*/release/*'`. The target is the
  highest version.
- No release branch: the target is `base_branch`, from `second-brain profile <project> --keys`.
- The repo must be on `<branch>`, and `git -C "<path>" status --porcelain` must print nothing.
  - Otherwise ask the owner to commit their changes. Never stash or discard them.

## 2. Ask the owner

- Ask with AskUserQuestion, with three options:
  - Merge `<branch>` into `<target>`.
  - Open a pull request from `<branch>` into `<target>`.
  - Keep `<branch>` as it is.
- Say in the question that typing `discard` deletes the branch.
- The owner names another target in the free-text answer: use it.
- Do only what the owner picks. Any other answer keeps the branch.

## 3. Merge

The merge is local. It pushes nothing.

1. `git -C "<path>" switch <target>`.
2. `git -C "<path>" merge --no-ff <branch> -m "Merge <branch> into <target>"`.
   - A conflict: `git -C "<path>" merge --abort`, then `git -C "<path>" switch <branch>`. Say so
     and keep the branch. Never resolve a conflict yourself.
3. `second-brain task set <ID> branch=<target> next="Owner reviews the merge on <target>"`.
4. `second-brain task note <ID> "Finish: merged <branch> into <target> at <short hash>."`.
5. Say that `<target>` is not pushed. A push runs only when the owner asks, named first.

## 4. Pull request

The pick asks for two outside steps: a push and a pull request.

1. Before either runs, name both: the push of `<branch>` to `origin`, and the pull request into
   `<target>`.
2. `gh` must be installed, and `<target>` on the remote:
   `git -C "<path>" ls-remote --exit-code --heads origin <target>`.
   - Otherwise say which is missing, and keep the branch.
3. `git -C "<path>" push -u origin <branch>`.
4. Write the description in the pull request format the index points to. Its template is
   `templates/pull-request.md.tmpl`.
5. In `<path>`, run `gh pr create --base <target> --head <branch> --title "<title>" --body-file -`
   with the description on stdin. The title is the story's `title`.
6. `second-brain task set <ID> branch=<branch> next="Owner reviews the pull request"`.
7. `second-brain task note <ID> "Finish: opened a pull request into <target>: <url>."`.

A step fails: show its error, say what ran before it, and stop.

## 5. Keep

- Change nothing in the repo.
- `second-brain task note <ID> "Finish: the owner kept <branch>."`.

## 6. Discard

- Delete the branch only when the owner types `discard`. A pick or a yes is not enough.
- `git -C "<path>" switch <target>`, then `git -C "<path>" branch -D <branch>`.
- Give the owner the hash git prints: `git branch <branch> <hash>` brings the branch back.
- A copy on the remote stays. Deleting it is a push: only when the owner asks, named first.
- `second-brain task note <ID> "Finish: the owner typed discard; <branch> was at <short hash>."`.

## Rules

- Never force a push or rewrite history.
