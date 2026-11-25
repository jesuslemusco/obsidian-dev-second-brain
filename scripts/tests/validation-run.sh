#!/usr/bin/env bash
# Area validation-run: validation run, and who runs which check.
# Usage: bash scripts/test.sh validation-run, or bash scripts/tests/validation-run.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault

# ---------------------------------------------------------------- validation run
sb help
out_has "help: lists validation run" "validation run <project> <repo> [--when each-story|each-merge|release]"
out_has "help: the validation run line itself names --path" \
  "validation run <project> <repo> [--when each-story|each-merge|release] [--path DIR]"
out_has "help: and under it --changed and --timeout" "              [--changed BASE] [--timeout S]"
out_has "help: and what --path stands for" "(DIR stands in for the repo's folder, such as a git worktree)"
out_has "help: and what --changed does" "(--changed skips a check whose paths: the diff from BASE does not touch)"
RN="work/runs"
mkdir -p "$tmp/rcode/run-app" "$tmp/tmpr"
: >"$tmp/rcode/run-app/marker.txt"
sb scaffold project Runs --path "$RN" --keys RN
edit "$vault/$RN/claude/profile.md" "s|^repos: \\[\\]\$|repos: [run-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/rcode\"|"
RVF="$vault/$RN/claude/validation.md"
cat >"$RVF" <<'EOF'
# Runs validation

## run-app

### Set up and start

- `echo never` - not a check

### Checks

- `test -f marker.txt` - runs from the repo's root - when: each story
- `test -z "$(cat)"` - reads nothing on stdin, an old name - when: Each-Task.
- `echo build-only` - a suite, an old name - when: each build
- `echo merge-only` - a suite - when: Each-Merge.
- `printf 'all good\n'` - no when, so each merge
- `printf 'line one\nan Error here\nFAILED: x\n'; exit 3` - fails on purpose
  - `echo nested` - a nested item is no check - when: each task
- `echo "when: release"` - a when in the span is not read
- `sleep 30` - hangs - when: release
- `echo e2e` - costs money - when: release
- A note with no command - when: each story
- `echo odd` - when: nightly
- `echo long` - a bullet that wraps
  over two lines - when: each task
- ``echo `tick` `` - a span that holds a backtick - when: each story

### Check as a user would

- `echo user` - a user step is never run - when: each task

### A pass

- Every check passes.
EOF
ODIR="${TMPDIR:-}"
export TMPDIR="$tmp/tmpr"
OUT="$(printf 'some input\n' | "$SB" validation run Runs run-app --when each-story 2>"$tmp/stderr")"
RC=$?
ERR="$(cat "$tmp/stderr")"
rc_is "validation run: each-story, every check passes, exit 0" 0
story_rows="test -f marker.txt|pass|0
test -z \"\$(cat)\"|pass|0
A note with no command - when: each story|skipped|-
  no command
echo long|pass|0
echo \`tick\` |pass|0"
is "validation run: each-story takes only the each-story bullets and the old each-task ones, in order, and names the skipped ones" \
  "$(rows "$OUT")" "$story_rows"
err_has "validation run: an unknown when is named as a warning, even in a run it is not part of" \
  "note: unknown when: nightly, read as each merge: \`echo odd\` - when: nightly"
is "validation run: an old when is no unknown one, and gets no warning" "$(printf '%s\n' "$ERR" | grep -c '^note:')" "1"
log1="$(printf '%s\n' "$OUT" | head -1 | cut -f5)"
is "validation run: the log is a temp file, outside the repo and the vault" "${log1%/*/*}" "$(shown "$tmp/tmpr")"
is "validation run: a row's seconds are whole seconds" "$(printf '%s\n' "$OUT" | head -1 | cut -f4 | grep -c '^[0-9][0-9]*$')" "1"
skipped="$(printf '%s\n' "$OUT" | grep "${TAB}skipped${TAB}" | head -1)"
is "validation run: a skipped row's exit code, seconds and log are -" "$(printf '%s\n' "$skipped" | cut -f3-5)" "-${TAB}-${TAB}-"
OUT="$(printf 'some input\n' | "$SB" validation run Runs run-app --when each-task 2>"$tmp/stderr")"
RC=$?
rc_is "validation run: --when each-task, the old name, exits 0" 0
is "validation run: --when each-task reads as each-story" "$(rows "$OUT")" "$story_rows"
sb validation run Runs run-app
rc_is "validation run: a failing check exits 1" 1
merge_rows="test -f marker.txt|pass|0
test -z \"\$(cat)\"|pass|0
echo build-only|pass|0
echo merge-only|pass|0
printf 'all good\\n'|pass|0
printf 'line one\\nan Error here\\nFAILED: x\\n'; exit 3|fail|3
  an Error here
  FAILED: x
echo \"when: release\"|pass|0
A note with no command - when: each story|skipped|-
  no command
echo odd|pass|0
echo long|pass|0
echo \`tick\` |pass|0"
is "validation run: each-merge is the default, and takes the each-story bullets and the old each-build ones too" \
  "$(rows "$OUT")" "$merge_rows"
err_has "validation run: an unknown when runs as each merge, with its warning" \
  "note: unknown when: nightly, read as each merge: \`echo odd\` - when: nightly"
sb validation run Runs run-app --when each-merge
is "validation run: --when each-merge is the default's run" "$(rows "$OUT")" "$merge_rows"
sb validation run Runs run-app --when each-build
is "validation run: --when each-build, the old name, reads as each-merge" "$(rows "$OUT")" "$merge_rows"
out_lacks "validation run: a nested item is no check" "nested"
out_lacks "validation run: nor a step of another part" "echo never"
out_lacks "validation run: nor a user step" "echo user"
log4="$(printf '%s\n' "$OUT" | grep "^printf 'all good" | cut -f5)"
file_has "validation run: the log holds the command's output" "$log4" "all good"
text="$OUT"
sb validation run Runs run-app --when each-merge --json
rc_is "validation run --json: exits as the text does" 1
json_ok "validation run --json: parses as JSON"
json_is "validation run --json: the same fields as the text" 'for r in d:
    print("|".join([r["command"], r["result"], "-" if r["exit"] is None else str(r["exit"])]))
    for l in r["lines"]: print("  " + l)' "$(rows "$text")"
json_is "validation run --json: each row has its seconds and log" \
  'print(all(set(r) == {"command", "result", "exit", "seconds", "log", "lines"} for r in d))' "True"
json_is "validation run --json: exit and seconds are numbers, null when skipped" \
  'print(sorted(set((type(r["exit"]).__name__, type(r["seconds"]).__name__, r["result"]) for r in d)))' \
  "[('NoneType', 'NoneType', 'skipped'), ('int', 'int', 'fail'), ('int', 'int', 'pass')]"
sb validation run Runs run-app --when release --timeout 1
rc_is "validation run: a timeout fails, exit 1" 1
out_has "validation run: release takes the release bullets too" "echo e2e${TAB}pass${TAB}0"
trow="$(printf '%s\n' "$OUT" | grep '^sleep 30')"
is "validation run: a command stopped at the timeout fails with exit code 124" "$(printf '%s\n' "$trow" | cut -f2,3)" "fail${TAB}124"
is "validation run: and is stopped soon after it" "$(($(printf '%s\n' "$trow" | cut -f4) < 10))" "1"
case "$OUT" in
  *"sleep 30${TAB}fail${TAB}124${TAB}"*"
  stopped after 1 seconds"*) pass "validation run: its first line names the timeout" ;;
  *) fail "validation run: its first line names the timeout" "in: $OUT" ;;
esac
# A timeout stops what the command started too: the child never writes its file.
cat >"$RVF" <<'EOF'
## run-app

### Checks

- `(sleep 3; echo late >late.txt) & sleep 30` - a child that outlives its parent
EOF
sb validation run Runs run-app --timeout 1
rc_is "validation run: a command with a child times out" 1
sleep 4
absent "validation run: and its child is stopped with it" "$tmp/rcode/run-app/late.txt"
# What a command leaves running when it exits is stopped before the next one starts.
cat >"$RVF" <<'EOF'
## run-app

### Checks

- `(sleep 2; echo late >late3.txt) & exit 0` - leaves a child behind
- `sleep 3; test ! -f late3.txt` - the next check runs alone
EOF
sb validation run Runs run-app
rc_is "validation run: a command that leaves a child passes" 0
out_has "validation run: the next check sees nothing of it" "sleep 3; test ! -f late3.txt${TAB}pass${TAB}0"
absent "validation run: and the child is stopped, never past the run" "$tmp/rcode/run-app/late3.txt"
printf '%s\n' '## run-app' '' '### Set up and start' '' '- Nothing.' >"$RVF"
sb validation run Runs run-app
rc_is "validation run: a section with no Checks exits 0" 0
out_is "validation run: and prints no row" ""
err_has "validation run: and says so" "note: no ### Checks in $RN/claude/validation.md"
sb validation run Runs run-app --json
out_is "validation run --json: no row is an empty array" "[]"
for bad in "--when nightly" "--when" "--timeout 0" "--timeout x" "--timeout" "--changed" "--changed --json" "--changed -x"; do
  # shellcheck disable=SC2086
  sb validation run Runs run-app $bad
  rc_is "validation run: $bad exits 5" 5
done
sb validation run Runs
rc_is "validation run: no repo exits 5" 5
sb validation run Runs run-app extra
rc_is "validation run: too many arguments exit 5" 5
sb validation Runs run-app --when each-story
rc_is "validation: --when is the run's flag alone, exit 5" 5
sb validation Runs run-app --changed HEAD
rc_is "validation: --changed is the run's flag alone, exit 5" 5
sb validation run Runs nope
rc_is "validation run: an unknown repo exits 1" 1
mv "$tmp/rcode/run-app" "$tmp/rcode/run-app.away"
sb validation run Runs run-app
rc_is "validation run: a repo whose folder is missing exits 1" 1
err_has "validation run: and says so" "the folder of run-app is missing"
mv "$tmp/rcode/run-app.away" "$tmp/rcode/run-app"
# --path stands in for the repo's folder, such as a git worktree of it: the checks run there.
mkdir -p "$tmp/rtree"
cat >"$RVF" <<'EOF'
## run-app

### Checks

- `pwd -P >where.txt` - names the folder it runs from - when: each task
EOF
sb validation run Runs run-app --when each-task --path "$tmp/rtree"
rc_is "validation run --path: exits 0" 0
is "validation run --path: the check runs from the folder it names" "$(cat "$tmp/rtree/where.txt" 2>/dev/null)" "$(cd "$tmp/rtree" && pwd -P)"
absent "validation run --path: not from the repo's recorded folder" "$tmp/rcode/run-app/where.txt"
sb validation run Runs run-app --path "$tmp/rtree/../rtree" --when each-task
rc_is "validation run --path: a path with .. in it is taken, flags in any order" 0
mv "$tmp/rcode/run-app" "$tmp/rcode/run-app.away"
rm -f "$tmp/rtree/where.txt"
sb validation run Runs run-app --when each-task --path "$tmp/rtree"
rc_is "validation run --path: the repo's own folder may be missing" 0
exists "validation run --path: and the check still runs in the folder named" "$tmp/rtree/where.txt"
mv "$tmp/rcode/run-app.away" "$tmp/rcode/run-app"
sb validation run Runs run-app --path "$tmp/no-such-tree"
rc_is "validation run --path: a folder that is not there exits 1" 1
err_has "validation run --path: and names it" "the folder is missing: $(shown "$tmp/no-such-tree")"
sb validation run Runs run-app --path
rc_is "validation run --path: no value exits 5" 5
sb validation run Runs run-app --path ""
rc_is "validation run --path: an empty value exits 5" 5
sb validation run Runs --path "$tmp/rtree"
rc_is "validation run --path: no repo exits 5" 5
sb validation Runs --path "$tmp/rtree"
rc_is "validation --path: no repo exits 5" 5
sb validation new Runs run-app --path "$tmp/rtree"
rc_is "validation new: takes no --path, exit 5" 5
sb validation Runs run-app --path "$tmp/rtree"
rc_is "validation --path: a vault home exits 0" 0
is "validation --path: a vault home's file is the vault's" "$(printf '%s\n' "$OUT" | head -1)" "path: $RN/claude/validation.md"
# A repo home's validation.md is read from the folder --path names: the branch's own checks.
WN="work/trees"
mkdir -p "$tmp/wcode/tree-app" "$tmp/wtree"
sb scaffold project Trees --path "$WN" --keys WT
edit "$vault/$WN/claude/profile.md" "s|^repos: \\[\\]\$|repos: [tree-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/wcode\"|; s|^validation_home: vault\$|validation_home: repo|"
printf '%s\n' '# tree-app validation' '' '## tree-app' '' '### Checks' '' '- `echo recorded` - the recorded folder'"'"'s check - when: each task' >"$tmp/wcode/tree-app/validation.md"
printf '%s\n' '# tree-app validation' '' '## tree-app' '' '### Checks' '' '- `echo tree` - the tree'"'"'s check - when: each task' >"$tmp/wtree/validation.md"
sb validation Trees tree-app --path "$tmp/wtree"
rc_is "validation --path: a repo home exits 0" 0
is "validation --path: a repo home's file is the one in the folder named" "$(printf '%s\n' "$OUT" | head -1)" "path: $(shown "$tmp/wtree")/validation.md"
out_has "validation --path: with its own checks" "echo tree"
out_lacks "validation --path: not the recorded folder's" "echo recorded"
sb validation run Trees tree-app --when each-task --path "$tmp/wtree"
rc_is "validation run --path: a repo home exits 0" 0
is "validation run --path: runs the checks of the folder named" "$(rows "$OUT")" "echo tree|pass|0"
sb validation run Trees tree-app --when each-task
is "validation run: without --path, the recorded folder's checks" "$(rows "$OUT")" "echo recorded|pass|0"
rm -f "$tmp/wtree/validation.md"
sb validation Trees tree-app --path "$tmp/wtree"
rc_is "validation --path: a folder with no validation.md exits 1" 1
err_has "validation --path: and points to validation new" "no validation.md for tree-app"
edit "$vault/$WN/claude/profile.md" 's|^repos_root: .*$|repos_root: ""|'
printf '%s\n' '# tree-app validation' '' '## tree-app' '' '### Checks' '' '- `echo tree` - the tree'"'"'s check - when: each task' >"$tmp/wtree/validation.md"
sb validation run Trees tree-app --when each-task --path "$tmp/wtree"
rc_is "validation run --path: a repo with no recorded location still runs in the folder named" 0
sb validation run Trees tree-app --when each-task
rc_is "validation run: and without --path, no location exits 1" 1
# paths: and --changed: a check that names its paths runs only when the diff from the base touches
# one of them, and a check with none runs every time.
GN="work/gits"
GC="$tmp/gcode/git-app"
mkdir -p "$GC/src/deep" "$GC/docs" "$GC/lib"
# Git looks for no repo above the temp dir, so a folder that is no repo is none here.
export GIT_CEILING_DIRECTORIES="$tmp"
gitc() { git -C "$GC" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
gitc init -q
printf 'a\n' >"$GC/src/main.sh"
printf 'a\n' >"$GC/src/deep/x.sh"
printf 'a\n' >"$GC/docs/guide.md"
printf 'a\n' >"$GC/README.md"
gitc add -A
gitc commit -q -m one
gbase="$(git -C "$GC" rev-parse HEAD)"
sb scaffold project Gits --path "$GN" --keys GI
edit "$vault/$GN/claude/profile.md" "s|^repos: \\[\\]\$|repos: [git-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/gcode\"|"
cat >"$vault/$GN/claude/validation.md" <<'EOF'
## git-app

### Checks

- `echo always` - names no paths, so it runs every time - when: each story
- `echo src` - the code - paths: src/** - when: each story
- `echo docs` - the docs - paths: `docs/*.md`, `README.md` - when: each story
- `echo top` - the top folder of the code alone - paths: src/*.sh - when: each story
- `echo lib` - paths after the when - when: each story - paths: lib/**.
- `echo empty` - an empty paths runs every time - paths: - when: each story
- `echo merge` - a later stage - paths: src/** - when: each merge
EOF
unchanged="no change to its paths since $gbase"
sb validation run Gits git-app --when each-story --changed "$gbase"
rc_is "validation run --changed: no change, exit 0" 0
is "validation run --changed: with no change, only the checks that name no paths run" "$(rows "$OUT")" \
  "echo always|pass|0
echo src|skipped|-
  $unchanged
echo docs|skipped|-
  $unchanged
echo top|skipped|-
  $unchanged
echo lib|skipped|-
  $unchanged
echo empty|pass|0"
sb validation run Gits git-app --when each-story
is "validation run: without --changed, a check with paths runs every time" "$(rows "$OUT")" \
  "echo always|pass|0
echo src|pass|0
echo docs|pass|0
echo top|pass|0
echo lib|pass|0
echo empty|pass|0"
printf 'b\n' >>"$GC/src/deep/x.sh"
gitc commit -q -am two
sb validation run Gits git-app --when each-story --changed "$gbase"
is "validation run --changed: a committed change runs the checks whose globs match it, and * stays in its folder" "$(rows "$OUT")" \
  "echo always|pass|0
echo src|pass|0
echo docs|skipped|-
  $unchanged
echo top|skipped|-
  $unchanged
echo lib|skipped|-
  $unchanged
echo empty|pass|0"
sb validation run Gits git-app --when each-merge --changed "$gbase"
out_has "validation run --changed: each-merge takes the later stage, with its paths" "echo merge${TAB}pass${TAB}0"
printf 'b\n' >>"$GC/README.md"
: >"$GC/lib/new.sh"
sb validation run Gits git-app --changed "$gbase" --when each-story
is "validation run --changed: a change not committed counts, and so does a new file git does not ignore; globs in code spans and paths after the when are read" \
  "$(rows "$OUT")" \
  "echo always|pass|0
echo src|pass|0
echo docs|pass|0
echo top|skipped|-
  $unchanged
echo lib|pass|0
echo empty|pass|0"
printf 'lib/\n' >"$GC/.gitignore"
gitc checkout -q -- README.md
gitc add .gitignore
gitc commit -q -m three
gbase="$(git -C "$GC" rev-parse HEAD)"
unchanged="no change to its paths since $gbase"
sb validation run Gits git-app --when each-story --changed "$gbase"
out_has "validation run --changed: a file git ignores is no change" "echo lib${TAB}skipped${TAB}-"
gitc mv docs/guide.md guide.md
gitc commit -q -m four
sb validation run Gits git-app --when each-story --changed "$gbase"
out_has "validation run --changed: a file moved away counts at the path it left" "echo docs${TAB}pass${TAB}0"
sb validation run Gits git-app --when each-story --changed HEAD --json
json_is "validation run --changed --json: a skipped row names why" \
  'print([r["lines"] for r in d if r["command"] == "echo src"])' "[['no change to its paths since HEAD']]"
sb validation run Gits git-app --when each-story --changed no-such-commit
rc_is "validation run --changed: a base that is no commit exits 1" 1
err_has "validation run --changed: and names it" "no commit no-such-commit in $(shown "$GC")"
out_is "validation run --changed: and runs nothing" ""
sb validation run Runs run-app --when each-story --changed HEAD
rc_is "validation run --changed: a folder that is no git repo exits 1" 1
err_has "validation run --changed: and names the folder" "no commit HEAD in $(shown "$tmp/rcode/run-app")"
unset GIT_CEILING_DIRECTORIES
if [ -n "$ODIR" ]; then export TMPDIR="$ODIR"; else unset TMPDIR; fi
CT="$here/docs/contract.md"
file_has "contract: a check's first code span is its command" "$CT" "- Under \`### Checks\` a bullet's first inline code span is its command:"
file_has "contract: each bullet ends with its stage" "$CT" '  stage: `when: each story`, `when: each merge` or `when: release`.'
file_has "contract: each story runs in the story's review" "$CT" '- `each story` runs in each story'"'"'s review. `each merge` runs on the branch a story merges into,'
file_has "contract: release only in a project that plans releases" "$CT" '  once the merge is made and before it is pushed. `release` is for a project that plans releases:'
line_is "contract: no stage needs sprints or a release branch" "$CT" \
  '- No stage needs sprints or a release branch: a story merges wherever the project'"'"'s git flow says.'
line_is "contract: the old names read as the new ones" "$CT" \
  '- `each task` and `each build`, the names before 0.13.0, read as `each story` and `each merge`.'
line_is "contract: a bullet with no when is each merge" "$CT" '- A bullet with no `when:` is `each merge`.'
line_is "contract: so is an unknown one, so a typo never drops a check" "$CT" \
  '- Any other value is unknown and counts as `each merge`, so a typo never drops a check.'
line_is "contract: a check may name its paths" "$CT" \
  '- A check may name the paths it covers, as `paths: <glob>, ...`. A story'"'"'s review runs it only'
file_has "contract: a glob is matched as git matches a glob pathspec" "$CT" \
  '  matches a `:(glob)` pathspec: `*` and `?` stay within a folder, and `**` crosses folders.'
line_is "contract: --changed runs a check with globs only when the diff touches one" "$CT" \
  '- With `--changed <base>`, `validation run` runs a check that has globs only when the diff from'
file_has "contract: documents validation run" "$CT" '| `validation run <project> <repo> [--when each-story\|each-merge\|release] [--changed <base>] [--timeout <seconds>] [--path <dir>] [--json]` |'
file_has "contract: validation takes --path" "$CT" '| `validation <project> <repo> [--path <dir>] [--json]` |'
file_has "contract: a worktree is checked in place" "$CT" '  take `--path <worktree>`, so the checks run on the branch under review, not on the repo'"'"'s'
file_has "guide: names validation run" "$here/docs/guide.md" '`second-brain validation run <project> <repo> --when each-story`'
file_has "guide: names the stages" "$here/docs/guide.md" '- `each story` runs in each story'"'"'s review. `each merge` runs on the branch a story merges into,'
file_has "guide: names paths" "$here/docs/guide.md" '- A check that only some files can break names them, as `paths: <glob>, ...`. A story'"'"'s review'
file_has "changelog: validation takes --path" "$here/CHANGELOG.md" '- `second-brain validation <project> <repo>` and `validation run` take `--path <dir>`: a folder'
file_has "changelog: names validation run" "$here/CHANGELOG.md" 'The new `second-brain validation run <project> <repo> [--when each-task|each-build|release]'
file_has "changelog: names the stages" "$here/CHANGELOG.md" '  `when:` is `each story`, in the story'"'"'s review, `each merge`, on the branch a story merges into'
file_has "changelog: names paths" "$here/CHANGELOG.md" '- A check may name the paths it covers, as `paths: <glob>, ...`, matched as git matches a'
file_has "changelog: names --changed" "$here/CHANGELOG.md" '- `second-brain validation run` takes `--changed <base>`: a check with `paths:` runs only when the'
VT="$here/templates/validation-repo.md.tmpl"
file_has "validation template: asks for the command in backticks" "$VT" 'the command in backticks, then what it proves.>'
file_has "validation template: asks when each check runs" "$VT" '- <Each line ends with when it runs: when: each story, in each story'"'"'s review, when: each merge,'
file_has "validation template: asks for the paths a check covers" "$VT" '- <A check that only some files can break names them before its when, such as paths: src/**, docs/*.md.'
file_has "validation template: and when each user step runs" "$VT" 'then what to look for, then when it runs.>'
file_has "vault-setup validation: drafts when each check runs" "$here/skills/vault-setup/validation.md" \
  '- End each check and each user step with when it runs, as `### Validation` in'
file_has "vault-setup validation: the command is the first code span" "$here/skills/vault-setup/validation.md" \
  "The command is the line's first inline code span: the helper runs it."
RV="$here/agents/reviewer.md"
file_has "reviewer: runs the checks only through validation run" "$RV" \
  '- Run the checks under `### Checks` only through'
file_has "reviewer: never runs a release check" "$RV" '- Never run a `release` check or step: only the owner asks for one.'
file_has "reviewer: a story review runs the each-story checks its change touches" "$RV" \
  '   the checks with `--when each-story --changed <base>`, with the base of your prompt, and each'
file_has "reviewer: requirements first" "$RV" '4. Requirements first.'
file_has "reviewer: then code quality" "$RV" '7. Then code quality, in the change step 3 reads alone'
rq_line="$(lineno "$RV" '4. Requirements first.')"
cq_line="$(lineno "$RV" '7. Then code quality, in the change step 3 reads alone')"
is "reviewer: requirements before code quality" "$((${rq_line:-0} < ${cq_line:-0}))" "1"
file_has "reviewer: a re-review reads only the fix" "$RV" '`git -C "<worktree>" diff <hash>..HEAD`, the fix'"'"'s commits alone.'
IM="$here/agents/implementer.md"
line_is "implementer: takes a story fix" "$IM" "### A story fix"
file_has "implementer: a fix runs the checks again before it commits" "$IM" \
  '- Fix each, with its proposed fix or a better one, as `## 1. Build test-first` says. Then take'
# Who runs which check: the contract, the guide, the build and the changelog say the same.
CT="$here/docs/contract.md"
file_has "contract: says who runs which check" "$CT" \
  '- **Who runs which check.** `implementer` runs its test and the repo'"'"'s `each story` checks that'
file_has "contract: and the reviewer runs the same checks and the each-story user steps in each review" "$CT" \
  '  its change touches before it commits. `reviewer` runs the same checks and the `each story` user'
line_is "contract: implementer writes a failing test first" "$CT" \
  '- `implementer` writes a test that fails for the story'"'"'s criterion first, then makes it pass.'
line_is "contract: a change with nothing to test says why" "$CT" \
  '- A change with nothing to test, such as a doc change, gets no test, and the reply says why.'
line_is "contract: implementer's checks are its test and the each-story ones its change touches" "$CT" \
  '- Its checks are its own test and the repo'"'"'s `each story` checks that its change touches, through'
line_is "contract: it commits only when they pass" "$CT" '- It commits only when they all pass, and names each result in its reply.'
line_is "contract: it runs no other each-merge check, no release check and no user step" "$CT" \
  '- It runs no other `each merge` check, no `release` check and no user step.'
line_is "contract: the suite that holds its own test is allowed" "$CT" '  even an `each merge` one.'
file_lacks "contract: no longer says implementer runs no check" "$CT" '`implementer` runs no check'
file_has "contract: implementer's reply names each check's result" "$CT" \
  '`Check:` line with the result of each check it ran.'
file_has "build: never skips the review on its check lines" "$here/skills/build/story.md" \
  '   - Its `Test:` and `Check:` lines are its own report. The review runs the checks again: never'
file_has "changelog: names the test-first build" "$here/CHANGELOG.md" '- `implementer` builds each task test-first.'

# ---------------------------------------------------------------- result
result
