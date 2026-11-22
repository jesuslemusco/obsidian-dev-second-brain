#!/usr/bin/env bash
# Area validation-run: validation run, the checks of a packet, and who runs which check.
# Usage: bash scripts/test.sh validation-run, or bash scripts/tests/validation-run.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault
# The build step of the spec skill, which docs.sh reads too.
BM="$here/skills/spec/build.md"

# ---------------------------------------------------------------- validation run
sb help
out_has "help: lists validation run" "validation run <project> <repo> [--when each-task|each-build|release] [--timeout S]"
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

- `test -f marker.txt` - runs from the repo's root - when: each task
- `test -z "$(cat)"` - reads nothing on stdin - when: Each-Task.
- `echo build-only` - a suite - when: each build
- `printf 'all good\n'` - no when, so each build
- `printf 'line one\nan Error here\nFAILED: x\n'; exit 3` - fails on purpose
  - `echo nested` - a nested item is no check - when: each task
- `echo "when: release"` - a when in the span is not read
- `sleep 30` - hangs - when: release
- `echo e2e` - costs money - when: release
- A note with no command - when: each task
- `echo odd` - when: nightly
- `echo long` - a bullet that wraps
  over two lines - when: each task
- ``echo `tick` `` - a span that holds a backtick - when: each task

### Check as a user would

- `echo user` - a user step is never run - when: each task

### A pass

- Every check passes.
EOF
# The packet names the checks implementer runs before it commits: the task's own, then each command
# validation run --when each-task runs, in order.
sb task new RN-1 --project Runs --title "Checks story"
sb task set RN-1 delivery=spec branch=feature/RN-1
sb spec new RN-1
DR="$vault/$RN/tasks/RN-1/spec"
printf '%s\n' '# RN-1 - Requirements' '' '## R1 - One' '' 'WHEN a user runs it, THE app SHALL pass.' >"$DR/requirements.md"
printf '%s\n' '# RN-1 - Tasks' '' '- [ ] T1 - With a check' '  - Requirements: R1' '  - Files: marker.txt' \
  '  - Check: `test -f marker.txt` - expected: exit 0' \
  '- [ ] T2 - No check' '  - Requirements: R1' \
  '- [ ] T3 - The template' '  - Requirements: R1' \
  '  - Check: <The command or step the implementer and the reviewer run.> - expected: <What it prints or shows.>' \
  '- [ ] T4 - None' '  - Requirements: R1' '  - Check: None' >"$DR/tasks.md"
sb spec packet RN-1 T1
rc_is "spec packet: a task with a check exits 0" 0
out_has "spec packet: names the task's check, then each each-task command, in order" "## Checks

- task: \`test -f marker.txt\` - expected: exit 0
- each task: test -f marker.txt
- each task: test -z \"\$(cat)\"
- each task: echo long
- each task: echo \`tick\` ${NL}${NL}## Validation"
for c in "echo build-only" "all good" "echo odd" "echo e2e" "A note with no command" "echo nested"; do
  is "spec packet: no each-task line for $c" "$(printf '%s\n' "$OUT" | grep -c -- "^- each task: .*$c" || true)" "0"
done
for t in T2 T3 T4; do
  sb spec packet RN-1 "$t"
  out_has "spec packet: $t has no check of its own, and still the each-task ones" "## Checks

- task: none
- each task: test -f marker.txt"
done
mv "$RVF" "$RVF.away"
sb spec packet RN-1 T1
rc_is "spec packet: no validation.md still exits 0" 0
out_has "spec packet: and says so" "validation: none (missing)"
is "spec packet: its Checks part is the task's line alone" "$(printf '%s\n' "$OUT" | sed -n '/^## Checks$/,$p')" "## Checks

- task: \`test -f marker.txt\` - expected: exit 0"
mv "$RVF.away" "$RVF"
ODIR="${TMPDIR:-}"
export TMPDIR="$tmp/tmpr"
OUT="$(printf 'some input\n' | "$SB" validation run Runs run-app --when each-task 2>"$tmp/stderr")"
RC=$?
ERR="$(cat "$tmp/stderr")"
rc_is "validation run: each-task, every check passes, exit 0" 0
is "validation run: each-task takes only the each-task bullets, in order, and names the skipped ones" "$(rows "$OUT")" \
  "test -f marker.txt|pass|0
test -z \"\$(cat)\"|pass|0
A note with no command - when: each task|skipped|-
  no command
echo long|pass|0
echo \`tick\` |pass|0"
err_has "validation run: an unknown when is named as a warning, even in a run it is not part of" \
  "note: unknown when: nightly, read as each build: \`echo odd\` - when: nightly"
log1="$(printf '%s\n' "$OUT" | head -1 | cut -f5)"
is "validation run: the log is a temp file, outside the repo and the vault" "${log1%/*/*}" "$(shown "$tmp/tmpr")"
is "validation run: a row's seconds are whole seconds" "$(printf '%s\n' "$OUT" | head -1 | cut -f4 | grep -c '^[0-9][0-9]*$')" "1"
skipped="$(printf '%s\n' "$OUT" | grep "${TAB}skipped${TAB}" | head -1)"
is "validation run: a skipped row's exit code, seconds and log are -" "$(printf '%s\n' "$skipped" | cut -f3-5)" "-${TAB}-${TAB}-"
sb validation run Runs run-app
rc_is "validation run: a failing check exits 1" 1
is "validation run: each-build is the default, and takes the each-task bullets too" "$(rows "$OUT")" \
  "test -f marker.txt|pass|0
test -z \"\$(cat)\"|pass|0
echo build-only|pass|0
printf 'all good\\n'|pass|0
printf 'line one\\nan Error here\\nFAILED: x\\n'; exit 3|fail|3
  an Error here
  FAILED: x
echo \"when: release\"|pass|0
A note with no command - when: each task|skipped|-
  no command
echo odd|pass|0
echo long|pass|0
echo \`tick\` |pass|0"
err_has "validation run: an unknown when runs as each build, with its warning" \
  "note: unknown when: nightly, read as each build: \`echo odd\` - when: nightly"
out_lacks "validation run: a nested item is no check" "nested"
out_lacks "validation run: nor a step of another part" "echo never"
out_lacks "validation run: nor a user step" "echo user"
log4="$(printf '%s\n' "$OUT" | grep "^printf 'all good" | cut -f5)"
file_has "validation run: the log holds the command's output" "$log4" "all good"
text="$OUT"
sb validation run Runs run-app --when each-build --json
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
for bad in "--when nightly" "--when" "--timeout 0" "--timeout x" "--timeout"; do
  # shellcheck disable=SC2086
  sb validation run Runs run-app $bad
  rc_is "validation run: $bad exits 5" 5
done
sb validation run Runs
rc_is "validation run: no repo exits 5" 5
sb validation run Runs run-app extra
rc_is "validation run: too many arguments exit 5" 5
sb validation Runs run-app --when each-task
rc_is "validation: --when is the run's flag alone, exit 5" 5
sb validation run Runs nope
rc_is "validation run: an unknown repo exits 1" 1
mv "$tmp/rcode/run-app" "$tmp/rcode/run-app.away"
sb validation run Runs run-app
rc_is "validation run: a repo whose folder is missing exits 1" 1
err_has "validation run: and says so" "the folder of run-app is missing"
mv "$tmp/rcode/run-app.away" "$tmp/rcode/run-app"
if [ -n "$ODIR" ]; then export TMPDIR="$ODIR"; else unset TMPDIR; fi
CT="$here/docs/contract.md"
file_has "contract: a check's first code span is its command" "$CT" "- Under \`### Checks\` a bullet's first inline code span is its command:"
file_has "contract: each bullet ends with when it runs" "$CT" '  `when: each task`, `when: each build` or `when: release`.'
line_is "contract: a bullet with no when is each build" "$CT" '- A bullet with no `when:` is `each build`.'
line_is "contract: so is an unknown one, so a typo never drops a check" "$CT" \
  '- Any other value is unknown and counts as `each build`, so a typo never drops a check.'
file_has "contract: documents validation run" "$CT" '| `validation run <project> <repo> [--when each-task\|each-build\|release] [--timeout <seconds>] [--json]` |'
file_has "contract: the fix loop's rounds" "$CT" '- Fix rounds 1 to 3 go back to the same `implementer`, with the findings in its packet. Rounds 4'
file_has "contract: the build-wide run has no agent" "$CT" '- When every task has passed, the skill runs `validation run <project> <repo> --when each-build`'
file_has "contract: a task's fails come from its history" "$CT" '- A task'"'"'s `fails` is the number of `failed` review states in its history, from every session.'
file_has "guide: each task is reviewed right after it is built" "$here/docs/guide.md" '- Each task is reviewed right after it is built, before the next one starts, so no task builds on'
file_has "guide: names validation run" "$here/docs/guide.md" '`second-brain validation run <project> <repo> --when each-task`'
file_has "changelog: names validation run" "$here/CHANGELOG.md" 'The new `second-brain validation run <project> <repo> [--when each-task|each-build|release]'
file_has "changelog: names the fix loop" "$here/CHANGELOG.md" '- The fix loop has five rounds: three on the same `implementer`, then two on a fresh one on the'
VT="$here/templates/validation-repo.md.tmpl"
file_has "validation template: asks for the command in backticks" "$VT" 'the command in backticks, then what it proves.>'
file_has "validation template: asks when each check runs" "$VT" '- <Each line ends with when it runs: when: each task, when: each build, or when: release'
file_has "validation template: and when each user step runs" "$VT" 'then what to look for, then when it runs.>'
file_has "vault-setup validation: drafts when each check runs" "$here/skills/vault-setup/validation.md" \
  '- End each check and each user step with when it runs, as `### Validation` in'
file_has "vault-setup validation: the command is the first code span" "$here/skills/vault-setup/validation.md" \
  "The command is the line's first inline code span: the helper runs it."
RV="$here/agents/reviewer.md"
file_has "reviewer: runs the checks only through validation run" "$RV" \
  '- Run the checks under `### Checks` only through'
file_has "reviewer: never runs a release check" "$RV" '- Never run a `release` check or step: only the owner asks for one.'
file_has "reviewer: a task review runs only its each-task checks" "$RV" \
  '4. Run the task'"'"'s `Check`, the checks with `--when each-task`, and each user step whose `when:` is'
file_has "reviewer: requirements first" "$RV" '3. Requirements first.'
file_has "reviewer: then code quality" "$RV" '6. Then code quality, in the diff alone. Each of these is a finding:'
is "reviewer: requirements before code quality" \
  "$(($(lineno "$RV" '3. Requirements first.') < $(lineno "$RV" '6. Then code quality, in the diff alone.')))" "1"
file_has "reviewer: a requirement not met skips the code quality pass" "$RV" 'is FAIL. Log the findings, and skip step 6.'
file_has "reviewer: a re-review reads only the fix" "$RV" \
  '- `fails` above 0: a re-review. The diff holds only the fix'"'"'s commits, and `## Issues` only the'
line_is "reviewer: has a user mode" "$RV" "## User mode"
line_is "reviewer: has a branch mode" "$RV" "## Branch mode"
file_has "reviewer: the branch review reads the whole change" "$RV" '2. Read the whole change: `git -C "<repo_path>" diff <base>...HEAD`.'
file_has "reviewer: a finished branch's finding goes on its task" "$RV" \
  '- The task is the one whose `- Files:` line in `tasks.md` holds the finding'"'"'s file. Several: the'
IM="$here/agents/implementer.md"
line_is "implementer: takes a fix message" "$IM" "## A fix message"
file_has "implementer: fetches its packet again on a fix" "$IM" \
  '- Run `second-brain spec packet <ID> <task> --project "<project>"` again, and check where you are'
file_has "implementer: a fix runs the checks again before it commits" "$IM" \
  '`## 2. Check` says, commit with the message'"'"'s last line and reply as `## 4. Report` says.'
# Who runs which check: the contract, the guide, the build and the changelog say the same.
CT="$here/docs/contract.md"
file_has "contract: says who runs which check" "$CT" \
  '- **Who runs which check.** `implementer` runs its task'"'"'s checks before it commits. `reviewer`'
file_has "contract: and the skill runs the each-build checks once" "$CT" \
  'runs them again in the task'"'"'s review. The skill runs the `each build` checks once, at the end.'
line_is "contract: implementer writes a failing test first" "$CT" \
  '- `implementer` writes a test that fails for its task'"'"'s requirement first, then makes it pass.'
line_is "contract: a task with nothing to test says why" "$CT" \
  '- A task with nothing to test, such as a doc change, gets no test, and the reply says why.'
line_is "contract: implementer's checks are its packet's" "$CT" \
  '- Its checks are the ones under its packet'"'"'s `## Checks`: the task'"'"'s `Check`, and the repo'"'"'s'
line_is "contract: it commits only when they pass" "$CT" '- It commits only when they all pass, and names each result in its reply.'
line_is "contract: it runs no other build-wide check, no release check and no user step" "$CT" \
  '- It runs no other `each build` check, no `release` check and no user step.'
line_is "contract: the suite that holds its own test is allowed" "$CT" '  even an `each build` one.'
line_is "contract: a step implementer has no tool for is skipped" "$CT" \
  '- A task `Check` that is a step its tools cannot take, such as a browser or a skill step, is'
line_is "contract: it still commits, and the review takes the step" "$CT" \
  '  reported as `Check: <step> - skipped - needs <tool>`. It still commits, and the review takes'
file_lacks "contract: no longer says implementer runs no check" "$CT" '`implementer` runs no check'
file_has "contract: the reviewer runs the task's checks again" "$CT" \
  '- It runs the task'"'"'s `Check` and the `each task` checks again, through'
file_has "contract: implementer's reply names each check's result" "$CT" \
  '`Check:` line with the result of each check it ran.'
file_has "contract: the packet has a Checks part" "$CT" \
  '`## Checks` (the checks `implementer` runs before it commits: `- task: <the item'"'"'s Check, as written>`'
GD="$here/docs/guide.md"
file_has "guide: implementer builds test-first" "$GD" '- `implementer` builds each task test-first. It writes a test that fails for the task'"'"'s'
file_has "guide: says who runs which check" "$GD" \
  '- Who runs which check: `implementer` runs the task'"'"'s `Check` and the repo'"'"'s `each task` checks'
line_is "guide: the reviewer runs them again" "$GD" \
  '- `reviewer` runs those checks again in the task'"'"'s review, with the `each task` user steps.'
file_has "guide: the full validation still runs once at the end" "$GD" \
  '- When every task has passed, the helper runs the repo'"'"'s checks once, with no agent.'
line_is "spec build: never skips the review on its check lines" "$BM" \
  '   - Its `Test:` and `Check:` lines are its own report. The review runs the checks again: never'
line_is "spec phases: implementer runs the task's check before it commits" "$here/skills/spec/phases.md" \
  '- `implementer` builds each task test-first and runs its `- Check:` before it commits. `reviewer`'
file_lacks "spec phases: no longer says reviewer runs every check" "$here/skills/spec/phases.md" '`reviewer` runs every check'
file_has "spec phases: a task's check is its narrowest command" "$here/skills/spec/phases.md" \
  'narrowest command that runs the task'"'"'s test, such as one test file, not every suite.'
file_has "changelog: names the test-first build" "$here/CHANGELOG.md" '- `implementer` builds each task test-first.'
file_has "changelog: names the packet's Checks part" "$here/CHANGELOG.md" '- The packet'"'"'s new `## Checks` part names those checks'

# ---------------------------------------------------------------- result
result
