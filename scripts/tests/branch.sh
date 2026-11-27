#!/usr/bin/env bash
# Area branch: branch, which reads a ticket's branches, a file on another branch and the work
# started with read-only git, and the docs that describe it.
# Usage: bash scripts/test.sh branch, or bash scripts/tests/branch.sh
. "$(dirname "$0")/lib.sh"

# The tasks as tasks.sh leaves them: EX-1 records the branch feature/EX-1-fix, and EX-7 is an
# environment set whose second id is the alias EX-70.
fixture_tasks

# The fixtures' commits need an identity; the helper clears every GIT_ variable for its own git.
export GIT_AUTHOR_NAME=Tester GIT_AUTHOR_EMAIL=tester@example.com
export GIT_COMMITTER_NAME=Tester GIT_COMMITTER_EMAIL=tester@example.com
# g <folder> <git args...>: run git in a fixture repository, quietly.
g() {
  local d="$1"
  shift
  git -C "$d" "$@" >/dev/null 2>&1
}
# short <folder> <ref>: the short hash git prints for a ref.
short() { git -C "$1" rev-parse --short "$2"; }

code="$tmp/code"
A="$code/example-api"
L="$code/shared-lib"
for r in "$A" "$L"; do
  mkdir -p "$r"
  g "$r" init -q
  g "$r" symbolic-ref HEAD refs/heads/main
  printf 'one\n' >"$r/a.txt"
  g "$r" add a.txt
  g "$r" commit -qm "First"
done
edit "$vault/$P/claude/profile.md" "s|^repos_root: \"\"\$|repos_root: \"$code\"|"
g "$A" checkout -q -b feature/EX-1-fix
printf 'two\n' >"$A/a.txt"
g "$A" commit -qam "Fix the totals"
mkdir -p "$A/src"
printf 'b\n' >"$A/src/b.txt"
g "$A" add src/b.txt
g "$A" commit -qm "Add b"
g "$A" checkout -q main
for b in feature/EX-10-other bugfix/ex-1-lower feature/TEX-1-near feature/EX-7-per-env; do
  g "$A" branch "$b"
done
g "$A" update-ref refs/remotes/origin/feature/EX-1-fix refs/heads/feature/EX-1-fix
hM="$(short "$A" main)"
hF="$(short "$A" feature/EX-1-fix)"

# ---------------------------------------------------------------- the branches of a ticket
sb branch Example EX-1
rc_is "branch: exit 0" 0
out_is "branch: the repo, its branch and head, the settings, the ticket's branches, the record" "repo: example-api
path: $(shown "$A")
current: main
head: $hM
base_branch: main
branch_pattern: feature/<ID>-<slug>
branch: bugfix/ex-1-lower $hM
branch: feature/EX-1-fix $hF
branch: origin/feature/EX-1-fix $hF
recorded: feature/EX-1-fix
on_ticket: no"
out_lacks "branch: a longer id is another ticket" "EX-10"
out_lacks "branch: an id inside a longer key is another ticket" "TEX-1"
g "$A" checkout -q feature/EX-1-fix
sb branch Example EX-1
out_has "branch: on the ticket's branch, it is the current one" "current: feature/EX-1-fix
head: $hF"
out_has "branch: and the current branch is on the ticket" "on_ticket: yes"
g "$A" checkout -q feature/EX-7-per-env
sb branch Example EX-70
rc_is "branch: an alias as the id, exit 0" 0
out_has "branch: an environment set's branch carries its first id" "branch: feature/EX-7-per-env $hM"
out_has "branch: being on it for the second id is no mismatch" "on_ticket: yes"
out_has "branch: the set's record" "recorded: none yet"
g "$A" checkout -q main
sb branch Example EX-99
rc_is "branch: a ticket with no story yet, exit 0" 0
is "branch: no branch carries it" "$(printf '%s\n' "$OUT" | grep -c '^branch: ' || true)" "0"
out_has "branch: and nothing is recorded" "recorded: -
on_ticket: no"
g "$A" checkout -q --detach main
sb branch Example EX-1
out_has "branch: a detached head has no current branch" "current: -
head: $hM"
g "$A" checkout -q main

# --path names another folder to read, such as another repo of the project or a git worktree.
g "$A" worktree add -q -b feature/EX-5-wt "$code/example-api-EX-5" main
sb branch Example EX-5 --path "$code/example-api-EX-5"
rc_is "branch --path: a worktree, exit 0" 0
out_has "branch --path: a worktree is its repo's" "repo: example-api
path: $(shown "$code/example-api-EX-5")
current: feature/EX-5-wt"
out_has "branch --path: on the ticket in the worktree" "on_ticket: yes"
sb branch Example EX-1 --path "$L"
out_has "branch --path: another repo of the project" "repo: shared-lib
path: $(shown "$L")"
mkdir -p "$tmp/loose"
g "$tmp/loose" init -q
sb branch Example EX-1 --path "$tmp/loose"
rc_is "branch --path: a repository the project does not list, exit 0" 0
out_has "branch --path: and it names no repo" "repo: -"
sb branch Example EX-1 --path "$tmp/nowhere"
rc_is "branch --path: a folder that is missing, exit 1" 1
err_has "branch --path: says so" "the folder is missing"
mkdir -p "$tmp/plain"
sb branch Example EX-1 --path "$tmp/plain"
rc_is "branch --path: a folder that is no git repository, exit 1" 1
err_has "branch --path: says so" "not a git repository"

# A note left in claude/subprojects/, which versions before 0.14.0 wrote, and a task's subproject
# key are read by nothing: the settings are the profile's.
mkdir -p "$vault/$P/claude/subprojects"
printf '%s\n' '---' 'type: subproject' 'repos: [shared-lib]' 'base_branch: develop' \
  'branch_pattern: "mobile/<ID>"' '---' >"$vault/$P/claude/subprojects/mobile.md"
edit "$T2" 's/^epic: "-"$/epic: "-"\
subproject: mobile/'
sb branch Example EX-2
rc_is "branch: a task's subproject key, exit 0" 0
out_has "branch: the key gives no repo" "repo: example-api"
out_has "branch: nor any setting" "base_branch: main
branch_pattern: feature/<ID>-<slug>"
is "branch: and names nothing on stderr" "$ERR" ""
sb branch Example EX-99 --path "$L"
out_has "branch: a repo a note lists reads the profile's settings" "base_branch: main"
edit "$T2" '/^subproject: mobile$/d'
rm -rf "$vault/$P/claude/subprojects"

# A story's repo is the repo it reads, before the profile's first.
sb task set EX-5 repo=shared-lib
sb branch Example EX-5
rc_is "branch: a story's repo, exit 0" 0
out_has "branch: a story's repo is the repo it reads" "repo: shared-lib
path: $(shown "$L")"
out_has "branch: with the profile's settings" "base_branch: main"
sb branch Example EX-5 --path "$A"
out_has "branch --path: the folder named wins over the story's repo" "repo: example-api"

# The default repo must have a folder.
sb branch "Example Two" TWO-1
rc_is "branch: a default repo with no location, exit 1" 1
err_has "branch: says so" "no location is recorded for shared-lib"
sb scaffold project Empty --path work/empty --keys EM
sb branch Empty EM-1
rc_is "branch: a project with no repo, exit 1" 1
err_has "branch: says to name a folder" "--path"
sb branch Empty EM-1 --path "$A"
rc_is "branch: a project with no repo reads a folder named with --path" 0

# ---------------------------------------------------------------- a file on another branch
sb branch Example EX-1 --show feature/EX-1-fix a.txt
rc_is "branch --show: exit 0" 0
out_is "branch --show: the file as it is on that branch" "two"
sb branch Example EX-1 --show main a.txt
out_is "branch --show: and on another" "one"
# A file with CRLF lines and no last newline, stored as it is: Git for Windows converts by default.
g "$A" config core.autocrlf false
printf 'x\r\ny' >"$A/crlf.txt"
g "$A" add crlf.txt
g "$A" commit -qm "A CRLF file"
hM="$(short "$A" main)"
"$SB" branch Example EX-1 --show main crlf.txt >"$tmp/shown.txt"
if cmp -s "$tmp/shown.txt" "$A/crlf.txt"; then pass "branch --show: prints the file byte for byte"; else fail "branch --show: prints the file byte for byte" "$(od -c "$tmp/shown.txt")"; fi
sb branch Example EX-1 --show nope a.txt
rc_is "branch --show: an unknown ref, exit 1" 1
sb branch Example EX-1 --show main missing.txt
rc_is "branch --show: a file the branch lacks, exit 1" 1
sb branch Example EX-1 --show feature/EX-1-fix src
rc_is "branch --show: a folder, exit 1" 1
err_has "branch --show: says it is a folder" "src at feature/EX-1-fix is a folder"
sb branch Example EX-1 --show "--output=$tmp/out.txt" a.txt
rc_is "branch --show: a ref that starts with a dash is no option, exit 5" 5
absent "branch --show: and git wrote nothing" "$tmp/out.txt"
sb branch Example EX-1 --show main
rc_is "branch --show: with no file, exit 5" 5

# ---------------------------------------------------------------- the work started
sb branch Example EX-1 --started
rc_is "branch --started: exit 0" 0
out_has "branch --started: the recorded branch against the base" "branch: feature/EX-1-fix
base: main
log:
  $(short "$A" feature/EX-1-fix) Add b
  $(short "$A" feature/EX-1-fix~1) Fix the totals
stat:
"
out_has "branch --started: the diff stat" "  2 files changed, 2 insertions(+), 1 deletion(-)"
out_has "branch --started: each file of it" "  src/b.txt | 1 +"
out_lacks "branch --started: none of the base's own commits" "A CRLF file"
g "$A" update-ref refs/remotes/origin/main main
sb branch Example EX-1 --started
out_has "branch --started: the remote base when there is one" "base: origin/main"
g "$A" branch feature/EX-6-real main
sb task set EX-6 branch=feature/EX-6-gone
sb branch Example EX-6 --started
rc_is "branch --started: a recorded branch that is gone, exit 0" 0
out_has "branch --started: takes the one branch that carries the id" "branch: feature/EX-6-real"
out_has "branch --started: no commit yet" "log: -
stat: -"
g "$A" update-ref refs/remotes/origin/feature/EX-4-remote main
sb branch Example EX-4 --started
out_has "branch --started: a remote branch alone" "branch: origin/feature/EX-4-remote"
g "$A" branch feature/EX-3-a main
g "$A" branch feature/EX-3-b main
sb branch Example EX-3 --started
rc_is "branch --started: several branches and none recorded, exit 4" 4
out_is "branch --started: lists them" "branch: feature/EX-3-a $hM
branch: feature/EX-3-b $hM"
err_has "branch --started: says how to record one" "second-brain task set EX-3 branch="
sb branch Example EX-99 --started
rc_is "branch --started: no branch carries the id, exit 1" 1

# ---------------------------------------------------------------- read-only git, no setting from outside
# A signed commit: git runs gpg.program on it when log.showSignature is on.
S="$tmp/sig"
mkdir -p "$S"
printf '#!/bin/sh\n: >"%s/ran"\ncat >/dev/null\nexit 1\n' "$S" >"$S/gpg.sh"
chmod +x "$S/gpg.sh"
# Git for Windows runs a program by its Windows path, not the shell's /c/... form.
gp="$S/gpg.sh"
case "${OSTYPE:-}" in msys* | cygwin*) gp="$(cygpath -m "$gp")" ;; esac
sig="$(printf 'tree %s\nparent %s\nauthor Tester <tester@example.com> 1700000000 +0000\ncommitter Tester <tester@example.com> 1700000000 +0000\ngpgsig -----BEGIN PGP SIGNATURE-----\n \n -----END PGP SIGNATURE-----\n\nSigned work\n' \
  "$(git -C "$A" rev-parse 'main^{tree}')" "$(git -C "$A" rev-parse main)" | git -C "$A" hash-object -t commit -w --stdin)"
g "$A" update-ref refs/heads/feature/EX-20-signed "$sig"
cfg="'log.showsignature'='true' 'gpg.program'='$gp'"
GIT_CONFIG_PARAMETERS="$cfg" git -C "$A" log -1 --format=%h feature/EX-20-signed >/dev/null 2>&1
exists "outside settings: git itself runs the program they name" "$S/ran"
rm -f "$S/ran"
before="$(git -C "$A" for-each-ref --format='%(refname) %(objectname)'; git -C "$A" config --local --list; git -C "$A" status --porcelain)"
run env GIT_CONFIG_PARAMETERS="$cfg" "$SB" branch Example EX-20 --started
rc_is "outside settings: --started still reads the work, exit 0" 0
out_has "outside settings: --started shows the signed commit" "$(short "$A" "$sig") Signed work"
absent "outside settings: --started runs no program they name" "$S/ran"
run env GIT_CONFIG_PARAMETERS="$cfg" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=log.showSignature GIT_CONFIG_VALUE_0=true \
  "$SB" branch Example EX-20 --show feature/EX-20-signed a.txt
out_is "outside settings: --show reads the file" "one"
run env GIT_CONFIG_PARAMETERS="$cfg" "$SB" branch Example EX-20
out_has "outside settings: the branches are read" "branch: feature/EX-20-signed $(short "$A" "$sig")"
absent "outside settings: --show and the branch list run no program either" "$S/ran"
g "$A" config log.showSignature true
g "$A" config gpg.program "$gp"
sb branch Example EX-20 --started
absent "repo settings: --started shows no signature, so runs no gpg.program" "$S/ran"
g "$A" config --unset log.showSignature
g "$A" config --unset gpg.program
sb branch Example EX-1
want="$OUT"
run env GIT_DIR="$L/.git" GIT_WORK_TREE="$L" "$SB" branch Example EX-1
out_is "outside settings: GIT_DIR names no other repository" "$want"
after="$(git -C "$A" for-each-ref --format='%(refname) %(objectname)'; git -C "$A" config --local --list; git -C "$A" status --porcelain)"
is "read-only: the refs, the settings and the tree are as they were" "$after" "$before"

# ---------------------------------------------------------------- what it cannot read
edit "$T5" 's/^repo: shared-lib$/repo: gone/'
sb branch Example EX-5
rc_is "branch: a story's repo the project no longer lists, exit 1" 1
err_has "branch: says the story names it, and how to set another" "EX-5 names the repo gone, which is not in repos of Example: list them with second-brain repo Example, and set one with second-brain task set EX-5 repo=<name>"
edit "$T5" 's/^repo: gone$/repo: shared-lib/'
PF="$vault/$P/claude/profile.md"
edit "$PF" 's/^base_branch: main$/base_branch: ""/'
sb branch Example EX-1 --started
rc_is "branch --started: no base branch, exit 1" 1
err_has "branch --started: says so" "no base_branch is set for Example"
edit "$PF" 's/^base_branch: ""$/base_branch: nope/'
sb branch Example EX-1 --started
rc_is "branch --started: a base branch the repo lacks, exit 1" 1
err_has "branch --started: names it" "the base branch nope is not in"
edit "$PF" 's/^base_branch: nope$/base_branch: main/'
orphan="$(printf 'tree %s\nauthor Tester <tester@example.com> 1700000000 +0000\ncommitter Tester <tester@example.com> 1700000000 +0000\n\nNo history in common\n' \
  "$(git -C "$A" rev-parse 'main^{tree}')" | git -C "$A" hash-object -t commit -w --stdin)"
g "$A" update-ref refs/heads/feature/EX-21-orphan "$orphan"
sb branch Example EX-21 --started
rc_is "branch --started: a branch with no history in common with the base, exit 1" 1
err_has "branch --started: says it cannot compare them" "git could not compare feature/EX-21-orphan with origin/main"
mkdir -p "$vault/$P/tasks/archive/2026/EX-3"
cp "$T3" "$vault/$P/tasks/archive/2026/EX-3/README.md"
sb branch Example EX-3
rc_is "branch: two tasks with the id, exit 4" 4
out_has "branch: lists them" "$P/tasks/archive/2026/EX-3/README.md"
rm -rf "$vault/$P/tasks/archive"

# ---------------------------------------------------------------- usage
sb branch
rc_is "branch: no project, exit 5" 5
sb branch Example
rc_is "branch: no id, exit 5" 5
sb branch Example EX-1 extra
rc_is "branch: an extra argument, exit 5" 5
sb branch Example EX-1 --bogus
rc_is "branch: an unknown flag, exit 5" 5
sb branch Example EX-1 --path
rc_is "branch: --path with no folder, exit 5" 5
sb branch Example EX-1 --show main a.txt --started
rc_is "branch: --show and --started together, exit 5" 5
sb branch Example EX-1/x
rc_is "branch: an id with a slash, exit 5" 5
sb branch Example ""
rc_is "branch: an empty id, exit 5" 5
err_has "branch: an empty id is no task id" "not a task id"
sb branch Example "" --started
rc_is "branch --started: an empty id, exit 5" 5
sb branch Nope EX-1
rc_is "branch: an unknown project, exit 1" 1

# ---------------------------------------------------------------- docs
sb help
out_has "help: lists branch" "branch <project> <ID> [--path DIR]"
out_has "help: and its file and started forms" "[--show <ref> <file> | --started]"
out_has "help: session-check takes --cwd, as the branch check runs it" "session-check [--cwd DIR]"
CT="$here/docs/contract.md"
file_has "contract: the branch row" "$CT" '| `branch <project> <ID> [--path <dir>]` |'
file_has "contract: the file and started forms" "$CT" '| `branch <project> <ID> [--path <dir>] --show <ref> <file>` / `--started` |'
file_has "contract: --started exits 1 for a branch with no history in common with the base" "$CT" \
  'Exit 1 when no branch carries the id, when there is no base branch, or when the branch shares no history with the base;'
file_has "contract: the helper runs git for branch" "$CT" '`second-brain <command> [args]`. Bash 3.2 and awk only, and read-only git for `branch`.'
file_has "contract: branch.sh in the code layout" "$CT" '- `scripts/lib/branch.sh` holds `cmd_branch` and its helpers, `sb_br_*`.'
file_has "guide: Claude reads a ticket's branches through the helper" "$here/docs/guide.md" '`second-brain branch <project> <ID>`'
CG="$here/CHANGELOG.md"
br_top="$(lineno "$CG" '## 0.13.0 - ')"
br_line="$(lineno "$CG" '- `second-brain branch <project> <ID>` reads a ticket'"'"'s branches')"
br_end="$(lineno "$CG" '## 0.12.0 - ')"
is "changelog: branch is under 0.13.0" "$(( ${br_top:-0} > 0 && ${br_line:-0} > ${br_top:-0} && ${br_line:-0} < ${br_end:-0} ))" "1"
br_line="$(lineno "$CG" '- story-tracker'"'"'s branch check and the scrum-master'"'"'s refinement read git through')"
is "changelog: the skills' branch check is under 0.13.0" "$(( ${br_top:-0} > 0 && ${br_line:-0} > ${br_top:-0} && ${br_line:-0} < ${br_end:-0} ))" "1"

# ---------------------------------------------------------------- result
result
